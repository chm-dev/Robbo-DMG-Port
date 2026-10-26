/*
 * Level-entry and death-respawn presentation (Atari ENTCV / WFAC port).
 *
 * Source sequence after a death (R1.ASM ZYTY -> WYBC -> PLA1 -> ENTCV):
 *   - 48 ticks of the room's explosion animation,
 *   - the whole cave is rebuilt from the pristine level copy (all pickups,
 *     actors, screws, doors and the capsule are back; ammo/keys reset),
 *   - ENTCV paints the playfield column by column, right to left, waiting an
 *     extra VBlank after every other column,
 *   - MFX1 points FADR at Robbo's start cell, so the display list scrolls the
 *     view back to the start while the paint finishes,
 *   - WFAC waits for that scroll to stop, plays the entry sound and animates
 *     the spawn cell.  In the source the cell holds the $1B waiting glyph (the
 *     "capsule" pod) until then; WFAC writes 'j' and the NEXT chain runs
 *     j -> k -> l -> m -> '*', i.e. the four explosion frames $02/$04/$06/$08
 *     followed by Robbo.  Control returns only after that.
 *
 * The GB view is 10x8 cells rather than the Atari's full-width 16x10, so the
 * column sweep starts at the rightmost visible column and wraps; this keeps
 * the first painted column on screen.  The waiting pod uses the capsule
 * metatile; the morph plays the four explosion metatiles before Robbo.
 */
#pragma bank 13

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "intro.h"
#include "color.h"
#include "render.h"
#include "sound.h"
#include "variants.h"
#include "../core/game.h"
#include "../gen/tiles.h"

/* 0 paint, 1 pan, 2 appear. */
#define INTRO_PAINT  0
#define INTRO_PAN    1
#define INTRO_APPEAR 2

/* Atari WFAC: j/k/l/m each last one CHNGCV update.  The GB logic tick is
 * 6 frames, so the four explosion frames take 24 frames before Robbo. */
#define INTRO_SPAWN_STEP_FRAMES 6
#define INTRO_SPAWN_FRAMES (INTRO_SPAWN_STEP_FRAMES * 4)
#define INTRO_RING_ROWS 16
#define INTRO_CAM_MARGIN 2

/* Bind the row ring to the current camera band without drawing.  A new level
 * uses this instead of a bulk level draw: the paint owns every tile. */
static void intro_bind_rows(void)
{
    uint8_t first = (cam_y > INTRO_CAM_MARGIN) ?
        (uint8_t)(cam_y - INTRO_CAM_MARGIN) : 0;
    uint8_t r;

    for (r = 0; r < INTRO_RING_ROWS; r++) {
        uint8_t level_y = (uint8_t)(first + r);
        map_row_level[level_y & (INTRO_RING_ROWS - 1)] = level_y;
    }
}

/* Clear the whole 32x32 BG tile map, keeping the ring identities intact. */
static void intro_blank(void)
{
    fill_bkg_rect(0, 0, 32, 32, metatile_tiles[MT_EMPTY << 2]);
    color_fill_attrs(0, 0, 32, 32, COLOR_PAL_NORMAL);
}

/* Paint one source-map column across the ring.  The 2x32-tile column is built
 * in this buffer during the *previous* frame; the VBlank tick then only does
 * the 64 VRAM writes.  Building the column at VBlank time used to push the
 * writes into mode 3, where SameBoy/real hardware discard them (Gearboy is
 * lenient, which made the bug look emulator-specific). */
static uint8_t intro_col_buf[64];
static uint8_t intro_attr_buf[64];
static uint8_t intro_write_x;

static void intro_prepare_column(uint8_t col)
{
    uint8_t first = (cam_y > INTRO_CAM_MARGIN) ?
        (uint8_t)(cam_y - INTRO_CAM_MARGIN) : 0;
    uint8_t r;

    for (r = 0; r < INTRO_RING_ROWS; r++) {
        uint8_t level_y = (uint8_t)(first + r);
        uint8_t map_row = level_y & (INTRO_RING_ROWS - 1);
        uint8_t mt, pal;
        uint8_t type = CT_EMPTY;
        uint8_t extra = 0;
        const uint8_t *t;

        if (map_row_level[map_row] == level_y && level_y < level_height) {
            uint16_t idx = (uint16_t)level_y * MAP_W + col;
            type = map_type[idx];
            extra = map_extra[idx];
        }
        mt = render_metatile_for_cell(type, extra);
        pal = render_cell_palette(type, extra, mt);

        t = &metatile_tiles[mt << 2];
        intro_col_buf[(map_row << 2) + 0] = t[0];
        intro_col_buf[(map_row << 2) + 1] = t[1];
        intro_col_buf[(map_row << 2) + 2] = t[2];
        intro_col_buf[(map_row << 2) + 3] = t[3];
        intro_attr_buf[(map_row << 2) + 0] = pal;
        intro_attr_buf[(map_row << 2) + 1] = pal;
        intro_attr_buf[(map_row << 2) + 2] = pal;
        intro_attr_buf[(map_row << 2) + 3] = pal;
    }

    intro_write_x = (uint8_t)(col << 1);
}

/* One GBDK map write; the library handles VRAM access timing. */
static void intro_write_column(void)
{
    set_bkg_tiles(intro_write_x, 0, 2, 32, intro_col_buf);
    if (color_on) {
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles(intro_write_x, 0, 2, 32, intro_attr_buf);
        VBK_REG = VBK_TILES;
    }
}

/* Intro pan step: the normal VBlank ease has a very long 1/16-px tail (about
 * 60 frames even for a one-row difference), which is fine for gameplay but
 * would stall the level-entry sequence.  Keep the same 3 px/frame cap and 1/8
 * approach, but never step less than half a pixel so the pan actually lands. */
static uint16_t intro_pan_step(uint16_t cur, uint16_t tgt)
{
    uint16_t dist;
    uint16_t step;

    if (cur == tgt) return cur;
    dist = (cur < tgt) ? (uint16_t)(tgt - cur) : (uint16_t)(cur - tgt);
    step = (uint16_t)((dist + 7) >> 3);
    if (step > 48) step = 48;
    if (step < 8) step = 8;
    if (step > dist) step = dist;
    return (cur < tgt) ? (uint16_t)(cur + step) : (uint16_t)(cur - step);
}

uint8_t intro_active = 0;
static uint8_t intro_phase;
static uint8_t intro_col;
static uint8_t intro_left;
static uint8_t intro_wait;
static uint8_t intro_appear;
static uint8_t intro_wall_pending;

/* NXCV clear state. */
static uint8_t clear_active;
static uint8_t clear_col;
static uint8_t clear_left;
static uint8_t clear_wait;

/* Fill one 2x32-tile BG-map column with the empty tile.  Used by the NXCV
 * level-complete clear.  Use GBDK's map write (same reason as the intro
 * paint): direct writes can land outside VBlank and be discarded. */
static void intro_clear_column(uint8_t col)
{
    uint8_t empty = metatile_tiles[MT_EMPTY << 2];
    uint8_t i;

    for (i = 0; i < 64; i++) intro_col_buf[i] = empty;
    for (i = 0; i < 64; i++) intro_attr_buf[i] = COLOR_PAL_NORMAL;
    set_bkg_tiles((uint8_t)(col << 1), 0, 2, 32, intro_col_buf);
    if (color_on) {
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles((uint8_t)(col << 1), 0, 2, 32, intro_attr_buf);
        VBK_REG = VBK_TILES;
    }
}

void intro_clear_begin(void) BANKED
{
    clear_active = 1;
    clear_col = MAP_W - 1;
    clear_left = MAP_W;
    clear_wait = 0;
    /* Atari PLA1 leaves DLSA untouched: freeze the view at the exit so the
     * next level starts from this exact camera position. */
    cam_smooth = 0;
}

uint8_t intro_clear_tick(void) BANKED
{
    if (!clear_active) return 0;

    if (clear_wait) {
        clear_wait = 0;
        return 1;
    }

    intro_clear_column(clear_col);
    clear_left--;
    if (clear_left == 0) {
        clear_active = 0;
        return 0;
    }

    clear_wait = (uint8_t)(clear_col & 1);
    clear_col = clear_col ? (uint8_t)(clear_col - 1) : (MAP_W - 1);
    return 1;
}

void intro_begin(uint8_t mode) BANKED
{
    intro_active = 1;
    intro_phase = INTRO_PAINT;

    /* Visible-first column order: start at the right edge of the entry view
     * (cam_x + VIEW_COLS - 1) and wrap through all 16 map columns. */
    intro_col = (uint8_t)(cam_x + (VIEW_COLS - 1));
    if (intro_col >= MAP_W) intro_col = MAP_W - 1;
    intro_left = MAP_W;
    intro_wait = 0;
    intro_appear = 0;

    /* Keep the player inert until the spawn morph finishes.  The cell shows
     * the waiting capsule while the map is painted and the camera pans. */
    robbo_busy = 1;
    render_robbo_spawn = 1;
    cam_smooth = 0;
    intro_wall_pending = (uint8_t)(mode == INTRO_MODE_AFTER_CLEAR);
    render_intro_clear_dirty();
    /* Bind the ring before preparing the first column: otherwise that column
     * is filled from whatever identities the previous level left behind and
     * its non-empty cells are painted as empty. */
    intro_bind_rows();
    intro_prepare_column(intro_col);

    /* A fresh level starts behind a black frame and is painted from empty.
     * A respawn paints over the wiped room; after the NXCV clear the screen is
     * already empty. */
    if (mode == INTRO_MODE_NEW) intro_blank();
}

void intro_tick(void) BANKED
{
    if (!intro_active) return;

    if (intro_phase == INTRO_PAINT) {
        /* Palette-dependent object tiles change with the four-level palette.
         * One 8-tile chunk per VBlank keeps the upload safe while the display
         * is on during a level-complete transition. */
        if (variants_step()) return;
        if (intro_wall_pending) {
            /* The wall glyph changes every four levels.  Load the new 16x16
             * cell here, in this frame's VBlank slice, before anything is
             * painted with it. */
            render_set_wall_style(level_wall_cell);
            intro_wall_pending = 0;
            return;
        }
        if (intro_wait) {
            /* No VRAM work this frame; build the next column for the next
             * VBlank slice. */
            intro_wait = 0;
            intro_prepare_column(intro_col);
            return;
        }

        intro_write_column();
        intro_left--;

        if (intro_left == 0) {
            /* ENTCV ends with the view still wherever the death happened; the
             * intro now pans it to the start-centered goal.  cam_smooth stays
             * clear because intro_tick() drives this pan itself. */
            intro_phase = INTRO_PAN;
            return;
        }

        /* Match ENTCV's extra VBlank after every other column. */
        intro_wait = (uint8_t)(intro_col & 1);
        intro_col = intro_col ? (uint8_t)(intro_col - 1) : (MAP_W - 1);
        if (!intro_wait) intro_prepare_column(intro_col);
        return;
    }

    if (intro_phase == INTRO_PAN) {
        uint16_t tgt_x = (uint16_t)((uint16_t)cam_goal_x << 8);
        uint16_t tgt_y = (uint16_t)((uint16_t)cam_goal_y << 8);
        uint16_t next_x = intro_pan_step(cam_qx, tgt_x);
        uint16_t next_y = intro_pan_step(cam_qy, tgt_y);

        if (next_x != cam_qx || next_y != cam_qy) {
            render_camera_set_q(next_x, next_y);
        }
        if (next_x == tgt_x && next_y == tgt_y) {
            /* WFAC: the pod disappears into explosion frame 0 and the entry
             * jingle starts; the next four steps run below. */
            intro_phase = INTRO_APPEAR;
            intro_appear = 0;
            render_robbo_spawn = 2;  /* MT_EXPLOSION_0 */
            render_cell(robbo_x, robbo_y);
            sfx_play_note(SFX_LEVEL_START);
        }
        return;
    }

    /* Spawn morph: four explosion frames (Atari $02/$04/$06/$08), then Robbo.
     * Each step lasts one logic tick's worth of frames. */
    intro_appear++;
    if (intro_appear >= INTRO_SPAWN_FRAMES) {
        render_robbo_spawn = 0;
        render_cell(robbo_x, robbo_y);
        /* Draw the final Robbo cell now: the step that ends the intro can run
         * late enough in the frame that the main loop's flush already ran. */
        render_flush_cells();
        intro_active = 0;
        robbo_busy = 0;
        cam_smooth = 1;
    } else {
        uint8_t frame = (uint8_t)(intro_appear / INTRO_SPAWN_STEP_FRAMES);
        uint8_t spawn = (uint8_t)(2 + frame);
        if (spawn != render_robbo_spawn) {
            render_robbo_spawn = spawn;
            render_cell(robbo_x, robbo_y);
        }
    }
}
