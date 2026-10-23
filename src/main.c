/*
 * Robbo - Game Boy port
 * Checkpoint 2: zoomed-in 16x16 view, movement, wall collision, bolt pickup,
 * stone/box pushing, sliding boxes and pause.
 *
 * Controls:
 *   D-pad  move / push
 *   A + direction  face/fire
 *   B + direction  pan the camera; release B to restore the view
 *   Start  pause / resume
 *   Select next level (debug)
 *   Select + Right / Left  +10 / -10 levels
 *   Select + Up            previous level
 *   Select + Down          warp to level 23 (bomb/question test level)
 *   Select + A             warp to level 30 (box/bolt test level)
 *   Select + B             back to level 1
 */
#include <gb/gb.h>
#include <stdint.h>

#include "core/game.h"
#include "gb/render.h"
#include "gb/sound.h"
#include "gen/levels.h"

#define LOGIC_TICK_FRAMES 6
#define MOVE_REPEAT_FRAMES 6
#define PAN_REPEAT_FRAMES 3

static uint8_t level = 1;
static uint8_t paused = 0;
static uint8_t move_delay = 0;
static uint8_t tick_timer = 0;
static uint8_t pause_draw = 0;
static uint8_t game_complete = 0;
static uint8_t pan_active = 0;
static uint8_t pan_delay = 0;
static uint16_t pan_saved_x = 0;
static uint16_t pan_saved_y = 0;

static void pan_cancel(uint8_t restore)
{
    if (pan_active && restore) {
        render_camera_set_q(pan_saved_x, pan_saved_y);
    }
    pan_active = 0;
    pan_delay = 0;
}

static void pan_step(uint8_t dir)
{
    render_camera_pan_step(dir);
}

static void wait_vbl(void)
{
    VBL_DONE = 0;
    while (!VBL_DONE) {}
}

void main(void)
{
    uint8_t pad, prev = 0;
    uint8_t dir = 0xFF;
    uint16_t sound_time;

    DISPLAY_OFF;
    sound_init();
    game_init();
    DISPLAY_ON;

    sound_time = sys_time;

    while (1) {
        wait_vbl();
        debug_ticks++;

        /* The game loop can take more than one VBlank per iteration.  Advance
         * the effect player once per elapsed frame so sounds keep the 60 Hz
         * timing they were authored for. */
        {
            uint16_t now = sys_time;
            uint8_t elapsed = (uint8_t)(now - sound_time);
            sound_time = now;
            if (elapsed > 4) elapsed = 4;
            while (elapsed--) sfx_update();
        }

        if (game_complete) {
            pad = joypad();
            if ((pad & (J_START | J_SELECT)) && !(prev & (J_START | J_SELECT))) {
                game_complete = 0;
                level = 1;
                pan_cancel(0);
                paused = 0;
                move_delay = 0;
                tick_timer = 0;
                DISPLAY_OFF;
                game_load_level(level);
                DISPLAY_ON;
            }
            prev = pad;
            continue;
        }

        /* All VRAM writes happen here, at the start of VBlank.  The camera
         * itself is applied by the VBlank handler; this only publishes the
         * next goal (or steps a teleport/pan). */
        if (!pan_active) render_camera();
        if (paused && !cam_override) cam_smooth = 0;
        game_teleport_camera_ready();
        render_sync_rows();
        if (pause_draw) {
            pause_draw = 0;
            render_pause();
        } else if (hud_dirty) {
            hud_dirty = 0;
            render_hud();
        }
        render_flush_cells();

        /* Advance frame-rate visual timers after the cells are flushed, so a
         * freshly queued step pose is drawn before the timer starts counting. */
        game_frame();

        pad = joypad();
        debug_pad = pad;

        if ((pad & J_START) && !(prev & J_START)) {
            paused = !paused;
            pan_cancel(1);
            if (paused) pause_draw = 1;
            else hud_dirty = 1;
        }

        if ((pad & J_SELECT) && !(prev & J_SELECT)) {
            if (pad & J_A) {
                level = 30;
            } else if (pad & J_B) {
                level = 1;
            } else if (pad & J_RIGHT) {
                level = (level + 10 > LEVEL_COUNT) ? LEVEL_COUNT : (level + 10);
            } else if (pad & J_LEFT) {
                level = (level > 10) ? (level - 10) : 1;
            } else if (pad & J_UP) {
                level = (level > 1) ? (level - 1) : LEVEL_COUNT;
            } else if (pad & J_DOWN) {
                level = 23;  /* bomb/question test level */
            } else {
                level++;
                if (level > LEVEL_COUNT) level = 1;
            }
            pan_cancel(0);
            DISPLAY_OFF;
            game_load_level(level);
            paused = 0;
            move_delay = 0;
            tick_timer = 0;
            DISPLAY_ON;
            prev = pad;
            continue;
        }

        if (!paused && !(pad & J_SELECT)) {
            if (++tick_timer >= LOGIC_TICK_FRAMES) {
                tick_timer = 0;
                game_tick();
            }

            if (pad & J_RIGHT) dir = 0;
            else if (pad & J_DOWN) dir = 1;
            else if (pad & J_LEFT) dir = 2;
            else if (pad & J_UP) dir = 3;
            else dir = 0xFF;

            /* B + d-pad inspects the map; releasing B restores the view
             * that was active when B was pressed. */
            if ((pad & J_B) && !(prev & J_B) && !pan_active && !robbo_busy) {
                pan_active = 1;
                cam_smooth = 0;
                __critical {
                    pan_saved_x = cam_qx;
                    pan_saved_y = cam_qy;
                }
                pan_delay = 0;
                move_delay = 0;
            }

            if (pan_active) {
                if (!(pad & J_B)) {
                    render_camera_set_q(pan_saved_x, pan_saved_y);
                    pan_active = 0;
                    pan_delay = 0;
                } else if (dir != 0xFF) {
                    if (pan_delay == 0) {
                        pan_step(dir);
                        pan_delay = PAN_REPEAT_FRAMES;
                    } else {
                        pan_delay--;
                    }
                } else {
                    pan_delay = 0;
                }
            }

            if (!pan_active && !robbo_busy && !robbo_no_move) {
                uint8_t fire_held = pad & J_A;

                if (fire_held) {
                    /* Holding A is aim mode: a direction changes facing and
                     * fires, but never moves Robbo. */
                    if (dir != 0xFF) {
                        game_face(dir);
                        game_fire();
                    }
                    move_delay = 0;
                } else {
                    if (dir != 0xFF) {
                        if (move_delay == 0) {
                            game_try_move(dir);
                            game_check_enemies();
                            move_delay = MOVE_REPEAT_FRAMES;
                        } else {
                            move_delay--;
                        }
                    } else {
                        move_delay = 0;
                    }
                }
            }
        }

        if (game_restart_requested) {
            game_restart_requested = 0;
            pan_cancel(0);
            DISPLAY_OFF;
            level = level_planet;
            game_load_level(level);
            paused = 0;
            move_delay = 0;
            tick_timer = 0;
            DISPLAY_ON;
            prev = pad;
            continue;
        }

        if (game_level_advance_requested) {
            game_level_advance_requested = 0;
            pan_cancel(0);
            if (level_planet >= LEVEL_COUNT) {
                game_complete = 1;
                render_camera_reset();
                DISPLAY_OFF;
                render_victory();
                DISPLAY_ON;
            } else {
                level = level_planet + 1;
                DISPLAY_OFF;
                game_load_level(level);
                DISPLAY_ON;
            }
            paused = 0;
            move_delay = 0;
            tick_timer = 0;
            prev = pad;
            continue;
        }

        prev = pad;
    }
}
