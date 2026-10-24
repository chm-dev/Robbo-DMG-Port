/* Atari TITLE.ASM CONGR ending, ported from robbo-gbc/src/ending.c.
 *
 * The GBC sequence is kept pose for pose: Robbo walks in, the ship lands, he
 * waves, boards and the ship departs, then the two message pages fade in and
 * dissolve cell by cell before the closing raster wipe.
 *
 * DMG adaptation:
 *   - One BG palette (BGP = 0xE4).  The GBC per-tile scene palettes are baked
 *     into the generated tile set (see gb/tools/gen_ending.py).
 *   - Robbo is a 2x2 sprite: the only sprite user in this port.  OBP0 = 0x18
 *     maps the raw source tile indices to the same shades as the background.
 *   - The GBC's per-scanline text fade becomes a short BGP shade fade; the
 *     animated hatch is a single tile rewritten each PAL frame.
 *   - The GBC window raster wipe keeps its window + 117-step motion, with a
 *     fixed four-shade band.
 *
 * Timing uses the GBC's PAL-frame clock (one PAL frame is 3287/2744 Game Boy
 * frames) on an absolute deadline, so drawing time is included per interval.
 */
#pragma bank 12

#include <gb/gb.h>
#include <stdint.h>

#include "ending.h"
#include "render.h"
#include "sound.h"
#include "../gen/ending_data.h"

#define POSE_FRAMES 8
#define HIDDEN      0xFF

/* Message-page fade: hatch/glyph shades go from black to light/white. */
static const uint8_t fade_bgp[6] = {
    0xCF, 0xCE, 0xCD, 0xCC, 0xC8, 0xC4
};

static const uint8_t head_row[2] = { ENDING_HEAD_ROW_0, ENDING_HEAD_ROW_1 };
static const uint8_t head_x0[2] = { ENDING_HEAD_X0_0, ENDING_HEAD_X0_1 };
static const uint8_t head_x1[2] = { ENDING_HEAD_X1_0, ENDING_HEAD_X1_1 };

static uint16_t pal_fraction, reveal_rng;
static uint8_t pal_frame, pattern_active, ship_row, text_page;

uint8_t ending_active;
uint8_t ending_page;

/* ------------------------------------------------------------------ */
/* Timing and sound                                                    */
/* ------------------------------------------------------------------ */

static void wait_one_vbl(void)
{
    VBL_DONE = 0;
    while (!VBL_DONE) {
    }
}

static void clock_reset(void)
{
    pal_fraction = 0;
    pal_frame = 0;
}

/* One PAL frame: 3287/2744 Game Boy frames, i.e. six frames per five PAL
 * frames.  Counted in VBlanks so the motion does not depend on the ROM's
 * clock globals, and the effect player gets its usual once-per-frame tick. */
static void ew(uint8_t frames)
{
    while (frames--) {
        uint8_t n = 1;

        pal_fraction += 543;
        if (pal_fraction >= 2744) {
            pal_fraction -= 2744;
            n = 2;
        }
        while (n--) {
            wait_one_vbl();
            sfx_update();
        }
        pal_frame++;
        if (pattern_active) {
            uint8_t tile[16], row, bits;

            for (row = 0; row < 8; row++) {
                bits = ending_pattern_rows[(uint8_t)(row - pal_frame) & 7];
                tile[row * 2] = bits;       /* DMG shade index 1 */
                tile[row * 2 + 1] = 0;
            }
            set_bkg_data(ENDING_PATTERN_TILE, 1, tile);
        }
    }
}

/* ------------------------------------------------------------------ */
/* Scene                                                               */
/* ------------------------------------------------------------------ */

static void draw_mt(uint8_t col, uint8_t row, uint8_t off)
{
    uint8_t tiles[4];

    tiles[0] = off;
    tiles[1] = (uint8_t)(off + 1);
    tiles[2] = (uint8_t)(off + 2);
    tiles[3] = (uint8_t)(off + 3);
    set_bkg_tiles(col, row, 2, 2, tiles);
}

static void bg_cell(uint8_t col, uint8_t row)
{
    uint8_t tile = ENDING_BLANK_TILE;
    uint8_t i;

    if (row >= ENDING_GROUND_ROW) {
        tile = (uint8_t)(ENDING_GROUND + (col & 1) +
                         ((row - ENDING_GROUND_ROW) ? 2 : 0));
    } else {
        for (i = 0; i < 17; i++) {
            if (ending_stars[i][0] == col && ending_stars[i][1] == row) {
                tile = (uint8_t)(ENDING_STAR + 1);
                break;
            }
        }
    }
    set_bkg_tile_xy(col, row, tile);
}

static void draw_scene(void)
{
    uint8_t x, y;

    for (y = 0; y < 18; y++) {
        for (x = 0; x < 20; x++) {
            set_bkg_tile_xy(x, y, ENDING_BLANK_TILE);
        }
    }
    for (x = 0; x < 17; x++) {
        bg_cell(ending_stars[x][0], ending_stars[x][1]);
    }
    for (x = 0; x < 20; x = (uint8_t)(x + 2)) {
        draw_mt(x, ENDING_GROUND_ROW, ENDING_GROUND);
    }
}

static void robbo_hide(void)
{
    uint8_t i;

    for (i = 0; i < 4; i++) move_sprite(i, 0, 0);
}

static void robbo_at(uint8_t x, uint8_t frame)
{
    uint8_t i, sx;

    if (x == HIDDEN) {
        robbo_hide();
        return;
    }
    for (i = 0; i < 4; i++) {
        sx = (uint8_t)(x + ((i & 1) ? 8 : 0));
        set_sprite_tile(i, (uint8_t)(ENDING_SPRITE_BASE + frame + i));
        set_sprite_prop(i, S_PRIORITY);
        move_sprite(i,
                    (uint8_t)(sx + 8),
                    (uint8_t)(ENDING_FEET_ROW * 8 + 16 + ((i & 2) ? 8 : 0)));
    }
}

static void scene_pose(uint8_t x, uint8_t frame, int8_t atari_ship_y)
{
    uint8_t col, row, shipl, shipr;

    ew(POSE_FRAMES);

    if (ship_row != HIDDEN) {
        for (row = ship_row; row < (uint8_t)(ship_row + 2); row++) {
            for (col = ENDING_SHIP_COL; col < ENDING_SHIP_COL + 4; col++) {
                bg_cell(col, row);
            }
        }
    }

    ship_row = (atari_ship_y < 0)
        ? HIDDEN
        : (uint8_t)((uint8_t)atari_ship_y * 7 / 6);

    robbo_at(x, frame);

    if (ship_row != HIDDEN) {
        /* The Atari ship alternates its inverse colour with RTC bit 4. */
        shipl = (pal_frame & 16) ? ENDING_SHIPL_FLASH : ENDING_SHIPL;
        shipr = (pal_frame & 16) ? ENDING_SHIPR_FLASH : ENDING_SHIPR;
        draw_mt(ENDING_SHIP_COL, ship_row, shipl);
        draw_mt((uint8_t)(ENDING_SHIP_COL + 2), ship_row, shipr);
    }
}

/* ------------------------------------------------------------------ */
/* Message pages                                                       */
/* ------------------------------------------------------------------ */

static void text_cell(uint8_t x, uint8_t y)
{
    uint8_t c = (uint8_t)ending_message[text_page][y][x];
    uint8_t tile;
    uint8_t inverse;

    if (c == '~') {
        tile = ENDING_PATTERN_TILE;
    } else {
        inverse = (y == head_row[text_page] &&
                   x >= head_x0[text_page] && x < head_x1[text_page]);
        tile = inverse ? ending_font_inverse[c] : ending_font[c];
        if (tile == 0xFF) tile = ENDING_BLACK_TILE;
    }
    set_bkg_tile_xy(x, y, tile);
}

/* Fourteen cells per PAL frame, as the GBC port scales the Atari buffer. */
static void reveal_cells(void)
{
    uint8_t i;
    uint16_t position;

    for (i = 0; i < 14; i++) {
        reveal_rng ^= (uint16_t)(reveal_rng << 7);
        reveal_rng ^= (uint16_t)(reveal_rng >> 9);
        reveal_rng ^= (uint16_t)(reveal_rng << 3);
        position = (uint16_t)(reveal_rng % 360);
        text_cell((uint8_t)(position % 20), (uint8_t)(position / 20));
    }
}

static void text_wipe(void)
{
    uint8_t tiles[20];
    uint8_t x, y;
    uint16_t step;

    pattern_active = 0;
    DISPLAY_OFF;
    BGP_REG = 0xE4;

    for (x = 0; x < 20; x++) tiles[x] = ENDING_BLACK_TILE;
    for (y = 0; y < 18; y++) set_win_tiles(0, y, 20, 1, tiles);
    for (x = 0; x < 20; x++) tiles[x] = ENDING_WIPE_TILE;
    set_win_tiles(0, 0, 20, 1, tiles);

    move_win(7, 144);
    SHOW_WIN;
    DISPLAY_ON;
    clock_reset();
    sfx_play_note(SFX_KEY);

    for (step = 1; step <= 117; step++) {
        ew(1);
        move_win(7, (uint8_t)(144 - (uint8_t)(step * 144 / 117)));
    }

    for (x = 0; x < 20; x++) tiles[x] = ENDING_BLACK_TILE;
    set_win_tiles(0, 0, 20, 1, tiles);
    sfx_play_note(SFX_LAST_BOLT);
}

static void ending_text(void)
{
    uint8_t tiles[20];
    uint8_t x, y, f;

    DISPLAY_OFF;
    HIDE_SPRITES;

    /* The debug trigger and the closing scene can leave START held. */
    while (joypad() & J_START) ew(1);

    for (text_page = 0; text_page < 2; text_page++) {
        ending_page = text_page;
        DISPLAY_OFF;
        BGP_REG = 0xCF;
        pattern_active = 1;
        for (x = 0; x < 20; x++) tiles[x] = ENDING_PATTERN_TILE;
        for (y = 0; y < 18; y++) set_bkg_tiles(0, y, 20, 1, tiles);
        DISPLAY_ON;
        clock_reset();

        for (f = 0; f < 6; f++) {
            BGP_REG = fade_bgp[f];
            ew(8);
        }

        if (text_page == 0) {
            sfx_play_def(&sfx_explosion);
        }
        reveal_rng = 0xACE1;
        do {
            reveal_cells();
            ew(1);
        } while (!(joypad() & J_START));

        /* One press advances one page, even when START is held down. */
        while (joypad() & J_START) ew(1);
    }

    text_wipe();

    DISPLAY_OFF;
    HIDE_WIN;
    move_win(6, 128);       /* restore the gameplay HUD position */
}

/* ------------------------------------------------------------------ */
/* Entry point                                                         */
/* ------------------------------------------------------------------ */

void ending_show(void) BANKED
{
    uint8_t i;

    ending_active = 1;
    ending_page = 0;

    sfx_stop();
    render_camera_reset();
    DISPLAY_OFF;
    HIDE_WIN;
    HIDE_SPRITES;
    SCX_REG = 0;
    SCY_REG = 0;
    BGP_REG = 0x1B;         /* scene: index 0 black .. 3 white */
    OBP0_REG = 0x18;

    set_bkg_data(0, ENDING_TILE_COUNT, ending_tiles);
    set_sprite_data(ENDING_SPRITE_BASE, ENDING_SPRITE_TILES,
                    ending_sprite_tiles);
    draw_scene();
    SPRITES_8x8;
    ENABLE_OAM_DMA;         /* the first (and only) sprite user in the port */
    robbo_hide();
    ship_row = HIDDEN;
    pattern_active = 0;
    SHOW_BKG;
    SHOW_SPRITES;
    DISPLAY_ON;
    clock_reset();
    ew(51);

    sfx_play_note(SFX_EXTRA_LIFE);
    for (i = 0; i < 9; i++) {
        scene_pose((uint8_t)(144 - i * 4),
                   (i & 1) ? ENDING_WALK1 : ENDING_WALK2, -1);
    }
    scene_pose(108, ENDING_STAND, -1);
    ew(11);

    sfx_play_note(SFX_MAGNET);
    for (i = 0; i < 12; i++) {
        scene_pose(108, (i & 1) ? ENDING_STAND2 : ENDING_STAND, (int8_t)i);
    }

    sfx_play_note(SFX_LAST_BOLT);
    for (i = 0; i < 14; i++) {
        scene_pose(108, ENDING_WAVE2, 12);
        scene_pose(108, ENDING_WAVE1, 12);
    }

    for (i = 0; i < 9; i++) {
        scene_pose((uint8_t)(108 - i * 4),
                   (i & 1) ? ENDING_WALK1 : ENDING_WALK2, 12);
    }

    sfx_play_note(SFX_LEVEL_START);
    for (i = 0; i < 14; i++) {
        scene_pose(HIDDEN, ENDING_STAND, (int8_t)(12 - (int8_t)i));
    }
    sfx_play_note(SFX_EXTRA_LIFE);
    ew(51);

    ending_text();

    sfx_stop();
    HIDE_SPRITES;
    DISABLE_OAM_DMA;
    OBP0_REG = 0xE4;
    BGP_REG = 0xE4;
    ending_active = 0;
}
