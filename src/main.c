/*
 * Robbo - Game Boy port
 * Checkpoint 2: zoomed-in 16x16 view, movement, wall collision, bolt pickup,
 * stone/box pushing, sliding boxes and pause.
 *
 * Controls:
 *   D-pad  move / push
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
#include "gen/levels.h"

#define LOGIC_TICK_FRAMES 6
#define MOVE_REPEAT_FRAMES 6

static uint8_t level = 1;
static uint8_t paused = 0;
static uint8_t move_delay = 0;
static uint8_t tick_timer = 0;
static uint8_t pause_draw = 0;
static uint8_t game_complete = 0;

static void wait_vbl(void)
{
    VBL_DONE = 0;
    while (!VBL_DONE) {}
}

void main(void)
{
    uint8_t pad, prev = 0;
    uint8_t dir = 0xFF;

    DISPLAY_OFF;
    game_init();
    DISPLAY_ON;

    while (1) {
        wait_vbl();
        debug_ticks++;

        if (game_complete) {
            pad = joypad();
            if ((pad & (J_START | J_SELECT)) && !(prev & (J_START | J_SELECT))) {
                game_complete = 0;
                level = 1;
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

        /* All VRAM writes happen here, at the start of VBlank. */
        render_camera();
        render_apply_camera();
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

        pad = joypad();
        debug_pad = pad;

        if ((pad & J_START) && !(prev & J_START)) {
            paused = !paused;
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

            if (!robbo_busy) {
                uint8_t fire_held = pad & (J_A | J_B);

                if (pad & J_RIGHT) dir = 0;
                else if (pad & J_DOWN) dir = 1;
                else if (pad & J_LEFT) dir = 2;
                else if (pad & J_UP) dir = 3;
                else dir = 0xFF;

                if (fire_held) {
                    /* Holding fire is aim mode: a direction changes facing and
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
            if (level_planet >= LEVEL_COUNT) {
                game_complete = 1;
                cam_x = 0;
                cam_y = 0;
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
