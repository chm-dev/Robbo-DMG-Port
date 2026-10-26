/*
 * Robbo - Game Boy port
 * Checkpoint 2: zoomed-in 16x16 view, movement, wall collision, bolt pickup,
 * stone/box pushing, sliding boxes and pause.
 *
 * Controls:
 *   D-pad  move / push
 *   A + direction  face/fire
 *   B + direction  pan the camera; release B to restore the view
 *   Start  open the pause menu
 *   Pause menu: Up/Down select, Left/Right set the warp level,
 *               A activates, Start/B close and resume
 *
 * Debug build only (-DDEBUG_STATE, roms/robbo-debug.gb):
 *   Select next level
 *   Select + Right / Left  +10 / -10 levels
 *   Select + Up            previous level
 *   Select + Down          warp to level 18 (turret/perf test level)
 *   Select + A             warp to level 30 (box/bolt test level)
 *   Select + B             back to level 1
 *   Start + Select         preview the ending sequence
 */
#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "core/game.h"
#include "gb/color.h"
#include "gb/ending.h"
#include "gb/intro.h"
#include "gb/render.h"
#include "gb/save.h"
#include "gb/screens.h"
#include "gb/sound.h"
#include "gb/title.h"
#include "gen/levels.h"

#define LOGIC_TICK_FRAMES 6
#define MOVE_REPEAT_FRAMES 6
#define PAN_REPEAT_FRAMES 3

#define PAUSE_PENDING_NONE    0
#define PAUSE_PENDING_RESUME  1
#define PAUSE_PENDING_RESTART 2

/* The Select level-warp block is a development aid and is absent from the
 * release ROM.  The gameplay loop must also ignore Select there instead of
 * freezing the logic/input tick while it is held. */
#ifdef DEBUG_STATE
#define DEBUG_WARP_HELD(pad) ((pad) & J_SELECT)
#else
#define DEBUG_WARP_HELD(pad) 0
#endif

static uint8_t level = 1;
static uint8_t saved_level = 0;
static uint8_t paused = 0;
static uint8_t pause_pending = PAUSE_PENDING_NONE;
static uint8_t move_delay = 0;
static uint8_t tick_timer = 0;
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
    PLATFORM_WAIT_VBL();
}

/* Restore the gameplay tiles the title overwrote, then rebuild the selected
 * planet.  Level 1 is only a fallback for a missing/corrupt selection. */
static void load_first_level(uint8_t start_level)
{
    if (start_level < 1) start_level = 1;
    if (start_level > LEVEL_COUNT) start_level = LEVEL_COUNT;

    pause_menu_abort();
    render_restore_tiles();
    level = start_level;
    game_load_level(level);
    paused = 0;
    pause_pending = PAUSE_PENDING_NONE;
    move_delay = 0;
    tick_timer = 0;
    SHOW_WIN;
    DISPLAY_ON;
}

/* The ending leaves the display off and the HUD hidden.  The pause menu's
 * EXIT entry uses the same return-to-title path.  The title may delete the
 * save, so re-read it before starting. */
static void return_to_title(void)
{
    uint8_t start_level;

    pause_menu_abort();
    DISPLAY_OFF;
    HIDE_WIN;
    sfx_stop();
    start_level = title_show(saved_level);
    saved_level = save_load();
    load_first_level(start_level);
}

void main(void)
{
    uint8_t pad, prev = 0;
    uint8_t dir = 0xFF;
    uint16_t sound_time;

    /* NES: clear the PRG-RAM BSS (the GB runtime does this itself). */
    PLATFORM_RAM_INIT();

    DISPLAY_OFF;
    sound_init();
    render_init();
    color_init();
    render_camera_reset();

    /* The title screen overwrites the gameplay tile range with its logo and
     * font; load_first_level() restores it before drawing the selected
     * planet.  A fresh cart has no save and therefore starts at level 1. */
    saved_level = save_load();
    return_to_title();

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

        /* Read input once per frame.  Keeping the edge state identical for the
         * intro and gameplay means START/SELECT behave the same in both. */
        pad = joypad();
        debug_pad = pad;

#ifdef DEBUG_STATE
        /* Debug builds only: START+SELECT previews the end-game sequence.
         * Checked before the pause/warp handlers so neither single button
         * fires.  The release ROM has no test hook here. */
        if ((pad & (J_START | J_SELECT)) == (J_START | J_SELECT) &&
            (prev & (J_START | J_SELECT)) != (J_START | J_SELECT)) {
            pan_cancel(0);
            ending_show();
            return_to_title();
            prev = joypad();
            continue;
        }
#endif

#ifdef DEBUG_STATE
        /* Debug builds: Select warps through the level list.  The release ROM
         * omits this block entirely. */
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
                level = 18;  /* turret perf test level (was 23 bomb/question) */
            } else {
                level++;
                if (level > LEVEL_COUNT) level = 1;
            }
            pan_cancel(0);
            pause_menu_abort();
            DISPLAY_OFF;
            game_load_level(level);
            paused = 0;
            pause_pending = PAUSE_PENDING_NONE;
            move_delay = 0;
            tick_timer = 0;
            DISPLAY_ON;
            prev = pad;
            continue;
        }
#endif

        if (game_level_advance_requested) {
            game_level_advance_requested = 0;
            pan_cancel(0);
            pause_menu_abort();
            if (level_planet >= LEVEL_COUNT) {
                ending_show();
                return_to_title();
            } else {
                level = level_planet + 1;
                /* Progress is the only thing that creates/advances a save.
                 * save_store() keeps the highest level, so replaying from a
                 * lower planet can never downgrade the recorded progress. */
                {
                    uint8_t stored = save_store(level);
                    if (stored > saved_level) saved_level = stored;
                }
                /* NXCV already cleared the playfield; load and paint the next
                 * level in without a black frame. */
                game_load_level_after_clear(level);
                paused = 0;
                pause_pending = PAUSE_PENDING_NONE;
                move_delay = 0;
                tick_timer = 0;
            }
            prev = pad;
            continue;
        }

        /* Atari NXCV level-complete clear: erase the finished room one column
         * at a time (right to left, with the odd-column pause), then let the
         * advance handler load the next level.  The display stays on. */
        if (game_transition_active) {
            if (!intro_clear_tick()) {
                game_transition_active = 0;
                game_level_advance_requested = 1;
            }
            render_flush_cells();
            prev = pad;
            continue;
        }

        /* Level entry / death respawn.  VRAM is written only from the intro's
         * per-frame VBlank slice: the screen is painted a column at a time and
         * the camera glides to the start instead of snapping behind a black
         * frame.  game_tick() and player input stay disabled until the spawn
         * materialize completes. */
        if (intro_active) {
            uint8_t row_queued;

            intro_tick();
            row_queued = render_sync_rows();
            if (hud_dirty && !row_queued) {
                hud_dirty = 0;
                render_hud();
            }
            render_flush_cells();
            prev = pad;
            continue;
        }

        /* Pause menu.  It only opens during live gameplay; the intro,
         * transition and advance handlers above run to completion first.
         * While paused the menu is the only input consumer and the logic
         * tick / movement block at the bottom is skipped. */
        if (!paused) {
            if ((pad & J_START) && !(prev & J_START)) {
                uint8_t warp_max = (saved_level > level) ? saved_level : level;

                paused = 1;
                pause_pending = PAUSE_PENDING_NONE;
                cam_smooth = 0;
                pan_cancel(1);
                pause_menu_open(level, warp_max);
            }
        } else {
            uint8_t warp_level;
            uint8_t pause_action = pause_menu_update(pad, prev, &warp_level);

            if (pause_action == PAUSE_ACTION_WARP) {
                pause_menu_abort();
                paused = 0;
                pause_pending = PAUSE_PENDING_NONE;
                level = warp_level;
                pan_cancel(0);
                move_delay = 0;
                tick_timer = 0;
                DISPLAY_OFF;
                game_load_level(level);
                DISPLAY_ON;
                prev = pad;
                continue;
            }
            if (pause_action == PAUSE_ACTION_RESTART) {
                /* Restore the playfield first, then run the normal death
                 * sequence so the explosion is not hidden by the menu. */
                pause_menu_begin_close();
                pause_pending = PAUSE_PENDING_RESTART;
            } else if (pause_action == PAUSE_ACTION_CLOSE) {
                pause_menu_begin_close();
                pause_pending = PAUSE_PENDING_RESUME;
            } else if (pause_action == PAUSE_ACTION_EXIT) {
                pause_menu_abort();
                paused = 0;
                pause_pending = PAUSE_PENDING_NONE;
                return_to_title();
                prev = joypad();
                continue;
            }
        }

        /* All VRAM writes happen here, at the start of VBlank.  The camera
         * itself is applied by the VBlank handler; this only publishes the
         * next goal (or steps a teleport/pan).  While paused the playfield and
         * BG overlay are frozen: do not run row sync/dirty flushes or the
         * step-pose timer, or they could draw over the menu. */
        {
            uint8_t row_queued = 0;

            if (!paused) {
                if (!pan_active) render_camera();
                game_teleport_camera_ready();
                row_queued = render_sync_rows();
            }
            if (hud_dirty && !row_queued) {
                hud_dirty = 0;
                render_hud();
            }
        }
        if (paused) {
            if (pause_menu_step()) {
                if (pause_pending == PAUSE_PENDING_RESTART) {
                    pause_pending = PAUSE_PENDING_NONE;
                    paused = 0;
                    pan_cancel(0);
                    kill_robbo();
                } else {
                    pause_pending = PAUSE_PENDING_NONE;
                    paused = 0;
                }
            }
        }
        if (!paused) {
            render_flush_cells();

            /* Advance frame-rate visual timers after the cells are flushed, so
             * a freshly queued step pose is drawn before the timer starts
             * counting.  Frozen while the pause overlay is on screen. */
            game_frame();
        }

        if (!paused && !DEBUG_WARP_HELD(pad)) {
            if (++tick_timer >= LOGIC_TICK_FRAMES) {
                tick_timer = 0;
                tick_phase = 1;  /* arm the split logic tick */
            }
            game_tick_step();

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
            pause_menu_abort();
            level = level_planet;
            /* Keep the display on: game_respawn_level() restores the map and
             * starts the intro, which repaints the wiped room and pans from
             * the death view back to Robbo's start. */
            game_respawn_level(level);
            paused = 0;
            pause_pending = PAUSE_PENDING_NONE;
            move_delay = 0;
            tick_timer = 0;
            prev = pad;
            continue;
        }

        prev = pad;
    }
}
