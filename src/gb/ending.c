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

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "ending.h"
#include "color.h"
#include "render.h"
#include "sound.h"
#include "../gen/ending_data.h"

#define POSE_FRAMES 8
#define HIDDEN      0xFF

/* The GBC/GB ending fills the whole 160x144 screen.  The NES screen is 32x30
 * tiles, so the 20x18 scene and both text pages are centred on a cell-aligned
 * offset (6 tiles = 3 attribute cells on each axis) and the surround is
 * cleared to the black sky tile. */
/* The GBC/GB ending fills the whole 160x144 screen.  The NES screen is 32x30
 * tiles, so the 20x18 scene and both text pages are centred on a cell-aligned
 * offset (6 tiles = 3 attribute cells on each axis) and the surround is
 * cleared to the black sky tile. */
#ifdef NINTENDO_NES
#define ENDING_TILE_X 6
#define ENDING_TILE_Y 6
/* NES BG slots owned by the ending (see color.c): scene/ground and text. */
#define ENDING_PAL_SCENE  0
#define ENDING_PAL_TEXT   2
/* One PAL frame per step of the tile-row wipe: 18 rows x 6 is the GB's 117
 * 1.23px steps in the same ~2 s. */
#define WIPE_ROW_FRAMES   6
#else
#define ENDING_TILE_X 0
#define ENDING_TILE_Y 0
#define ENDING_PAL_SCENE  COLOR_PAL_NORMAL
#define ENDING_PAL_TEXT   COLOR_PAL_ENDING
#endif
#define ENDING_TX(col) ((uint8_t)((col) + ENDING_TILE_X))
#define ENDING_TY(row) ((uint8_t)((row) + ENDING_TILE_Y))
#define ENDING_PX_X    ((uint8_t)(ENDING_TILE_X * 8))
#define ENDING_PX_Y    ((uint8_t)(ENDING_TILE_Y * 8))

/* Message-page fade: hatch/glyph shades go from black to light/white. */
#ifndef NINTENDO_NES
static const uint8_t fade_bgp[6] = {
    0xCF, 0xCE, 0xCD, 0xCC, 0xC8, 0xC4
};
#endif

static const uint8_t head_row[2] = { ENDING_HEAD_ROW_0, ENDING_HEAD_ROW_1 };
static const uint8_t head_x0[2] = { ENDING_HEAD_X0_0, ENDING_HEAD_X0_1 };
static const uint8_t head_x1[2] = { ENDING_HEAD_X1_0, ENDING_HEAD_X1_1 };

static uint16_t pal_fraction, reveal_rng;
static uint8_t pal_frame, pattern_active, ship_row, text_page;

#ifdef NINTENDO_NES
/* A text page has 360 cells.  The GB loop re-randomises forever, which on NES
 * means endless per-frame VRAM writes; GBDK buffers those in a 136-byte PPU
 * queue (__vram_transfer_buffer) drained during VBlank, and a queue fed every
 * frame for a long time desyncs -- first as a stray glyph on screen, later as
 * a page whose text never unveils.  Draw every cell exactly once, six per PAL
 * frame, walking a stride that is coprime with 360 (so the order is scattered
 * but every cell is visited), then stop touching VRAM until START. */
#define REVEAL_STRIDE     77
#define REVEAL_PER_FRAME  6
#define REVEAL_FRAMES     ((360 + REVEAL_PER_FRAME - 1) / REVEAL_PER_FRAME)
static uint16_t reveal_pos;
#endif

uint8_t ending_active;
uint8_t ending_page;

/* ------------------------------------------------------------------ */
/* Timing and sound                                                    */
/* ------------------------------------------------------------------ */

static void wait_one_vbl(void)
{
    PLATFORM_WAIT_VBL();
}

static void clock_reset(void)
{
    pal_fraction = 0;
    pal_frame = 0;
}

/* One PAL frame: 3287/2744 Game Boy frames, i.e. six frames per five PAL
 * frames.  Counted in VBlanks so the motion does not depend on the ROM's
 * clock globals, and the effect player gets its usual once-per-frame tick. */
/* Rewrite the animated hatch tile, once per PAL frame.  That is a single
 * 18-byte queue entry per frame -- the same order as the playfield row writer
 * -- so it is safe on NES as long as the reveal itself is bounded (see
 * reveal_cells()). */
static void pattern_step(void)
{
    uint8_t tile[16], row, bits;

    for (row = 0; row < 8; row++) {
        bits = ending_pattern_rows[(uint8_t)(row - pal_frame) & 7];
#ifdef NINTENDO_NES
        /* NES text palette: hatch = index 2 (grey), page = 3. */
        tile[row * 2] = (uint8_t)~bits;
        tile[row * 2 + 1] = 0xFF;
#else
        tile[row * 2] = bits;       /* DMG shade index 1 */
        tile[row * 2 + 1] = 0;
#endif
    }
    set_bkg_data(ENDING_PATTERN_TILE, 1, tile);
}

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
        if (pattern_active) pattern_step();
    }
}

/* ------------------------------------------------------------------ */
/* Scene                                                               */
/* ------------------------------------------------------------------ */

static void draw_mt(uint8_t col, uint8_t row, uint8_t off, uint8_t pal)
{
    uint8_t tiles[4];
#ifndef NINTENDO_NES
    uint8_t attrs[4];
#endif

    tiles[0] = off;
    tiles[1] = (uint8_t)(off + 1);
    tiles[2] = (uint8_t)(off + 2);
    tiles[3] = (uint8_t)(off + 3);
    set_bkg_tiles(ENDING_TX(col), ENDING_TY(row), 2, 2, tiles);
#ifndef NINTENDO_NES
    if (color_on) {
        attrs[0] = attrs[1] = attrs[2] = attrs[3] = pal;
        set_bkg_attributes(ENDING_TX(col), ENDING_TY(row), 2, 2, attrs);
    }
#else
    /* NES attributes are one palette per 16x16 cell and the whole scene uses
     * slot 0, so no attribute change is needed.  The ship's landing flash is
     * an art-level swap of its ring colour only (the 2x2 metatile can land on
     * an odd metatile row, where an attribute change would repaint sky). */
    (void)pal;
#endif
}

static void bg_cell(uint8_t col, uint8_t row)
{
    uint8_t tile = ENDING_BLANK_TILE;
    uint8_t pal = COLOR_PAL_NORMAL;
    uint8_t i;

    if (row >= ENDING_GROUND_ROW) {
        tile = (uint8_t)(ENDING_GROUND + (col & 1) +
                         ((row - ENDING_GROUND_ROW) ? 2 : 0));
        pal = COLOR_PAL_WALL;
    } else {
        for (i = 0; i < 17; i++) {
            if (ending_stars[i][0] == col && ending_stars[i][1] == row) {
                tile = (uint8_t)(ENDING_STAR + 1);
                break;
            }
        }
    }
    set_bkg_tile_xy(ENDING_TX(col), ENDING_TY(row), tile);
#ifndef NINTENDO_NES
    if (color_on) set_bkg_attributes(ENDING_TX(col), ENDING_TY(row), 1, 1, &pal);
#else
    (void)pal;
#endif
}

#ifdef NINTENDO_NES
/* The GB ending covers all 160x144 px; the NES screen is wider and taller, so
 * clear the whole nametable to the black sky tile and give every 16x16 cell
 * the scene palette before the centred scene/text is drawn. */
static void nes_clear_screen(void)
{
    uint8_t row[32];
    uint8_t x, y;

    for (x = 0; x < 32; x++) row[x] = ENDING_BLANK_TILE;
    for (y = 0; y < 30; y++) set_bkg_tiles(0, y, 32, 1, row);
    color_fill_attrs(0, 0, 32, 30, ENDING_PAL_SCENE);
}
#endif

static void draw_scene(void)
{
    uint8_t x, y;

    for (y = 0; y < 18; y++) {
        for (x = 0; x < 20; x++) {
            set_bkg_tile_xy(ENDING_TX(x), ENDING_TY(y), ENDING_BLANK_TILE);
        }
    }
#ifdef NINTENDO_NES
    /* One slot covers sky, ship and ground (the Atari ending has no per-band
     * palette), and nes_clear_screen() already painted the whole map. */
#else
    color_fill_attrs(0, 0, 20, 18, COLOR_PAL_NORMAL);
#endif
    for (x = 0; x < 17; x++) {
        bg_cell(ending_stars[x][0], ending_stars[x][1]);
    }
    for (x = 0; x < 20; x = (uint8_t)(x + 2)) {
        draw_mt(x, ENDING_GROUND_ROW, ENDING_GROUND, COLOR_PAL_WALL);
    }
}

static void robbo_hide(void)
{
    uint8_t i;

    for (i = 0; i < 4; i++) {
#ifdef NINTENDO_NES
        /* OAM y >= 240 is off-screen; GB-style (0,0) would show the sprite at
         * the top-left corner because NES OAM y = sprite top - 1. */
        move_sprite(i, 0, 240);
#else
        move_sprite(i, 0, 0);
#endif
    }
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
        /* move_sprite() writes the OAM entry unchanged on both targets, so the
         * device offsets differ: a GB sprite is drawn 8 px right and 16 px
         * below its OAM value, while an NES sprite starts at OAM x and one
         * line below OAM y.  Robbo's 2x2 block must end on the ground surface
         * (scene row ENDING_FEET_ROW + 2), i.e. its top row is
         * ENDING_FEET_ROW * 8 in scene pixels. */
#ifdef NINTENDO_NES
        move_sprite(i,
                    (uint8_t)(sx + ENDING_PX_X),
                    (uint8_t)(ENDING_FEET_ROW * 8 + ENDING_PX_Y - 1 +
                              ((i & 2) ? 8 : 0)));
#else
        move_sprite(i,
                    (uint8_t)(sx + 8),
                    (uint8_t)(ENDING_FEET_ROW * 8 + 16 +
                              ((i & 2) ? 8 : 0)));
#endif
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
        /* The Atari ship alternates its inverse colour with RTC bit 4.  On NES
         * the flash is carried by the tile art (see gen_ending.py): only the
         * COLPF2 ring (art index 3) is remapped, so the hull and trim stay
         * static while the ring blinks white. */
        uint8_t ship_pal = (pal_frame & 16) ? COLOR_PAL_WALL : COLOR_PAL_NORMAL;
        shipl = (pal_frame & 16) ? ENDING_SHIPL_FLASH : ENDING_SHIPL;
        shipr = (pal_frame & 16) ? ENDING_SHIPR_FLASH : ENDING_SHIPR;
        draw_mt(ENDING_SHIP_COL, ship_row, shipl, ship_pal);
        draw_mt((uint8_t)(ENDING_SHIP_COL + 2), ship_row, shipr, ship_pal);
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
    set_bkg_tile_xy(ENDING_TX(x), ENDING_TY(y), tile);
}

/* Fourteen cells per PAL frame, as the GBC port scales the Atari buffer. */
static void reveal_cells(void)
{
    uint8_t i;

#ifdef NINTENDO_NES
    for (i = 0; i < REVEAL_PER_FRAME; i++) {
        reveal_pos = (uint16_t)(reveal_pos + REVEAL_STRIDE);
        if (reveal_pos >= 360) reveal_pos = (uint16_t)(reveal_pos - 360);
        text_cell((uint8_t)(reveal_pos % 20), (uint8_t)(reveal_pos / 20));
    }
#else
    uint16_t position;

    for (i = 0; i < 14; i++) {
        reveal_rng ^= (uint16_t)(reveal_rng << 7);
        reveal_rng ^= (uint16_t)(reveal_rng >> 9);
        reveal_rng ^= (uint16_t)(reveal_rng << 3);
        position = (uint16_t)(reveal_rng % 360);
        text_cell((uint8_t)(position % 20), (uint8_t)(position / 20));
    }
#endif
}

static void text_wipe(void)
{
    uint8_t tiles[20];
    uint8_t x, y;

    pattern_active = 0;

#ifdef NINTENDO_NES
    /* The GB wipe slides the hardware Window layer over the page.  NES has no
     * window, so draw the same curtain with BG rows: the band tile is the
     * rising edge and every row behind it (below) turns black.  The page is
     * left as it is -- the text stays visible above the edge and is wiped
     * row by row, instead of vanishing before the curtain starts. */
    clock_reset();
    sfx_play_note(SFX_KEY);

    for (y = 18; y-- > 0;) {
        for (x = 0; x < 20; x++) tiles[x] = ENDING_WIPE_TILE;
        set_bkg_tiles(ENDING_TILE_X, ENDING_TY(y), 20, 1, tiles);
        ew(WIPE_ROW_FRAMES);
        for (x = 0; x < 20; x++) tiles[x] = ENDING_BLACK_TILE;
        set_bkg_tiles(ENDING_TILE_X, ENDING_TY(y), 20, 1, tiles);
    }
    sfx_play_note(SFX_LAST_BOLT);
#else
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
    {
        uint16_t step;

        for (step = 1; step <= 117; step++) {
            ew(1);
            move_win(7, (uint8_t)(144 - (uint8_t)(step * 144 / 117)));
        }
    }

    for (x = 0; x < 20; x++) tiles[x] = ENDING_BLACK_TILE;
    set_win_tiles(0, 0, 20, 1, tiles);
    sfx_play_note(SFX_LAST_BOLT);
#endif
}

static void ending_text(void)
{
    uint8_t tiles[20];
    uint8_t x, y, f;

    DISPLAY_OFF;
    HIDE_SPRITES;
    /* Text pages keep the fixed grey ramp; the scene attributes are per-cell. */
    color_fill_attrs(ENDING_TILE_X, ENDING_TILE_Y, 20, 18, ENDING_PAL_TEXT);

    /* The debug trigger and the closing scene can leave START held. */
    while (joypad() & J_START) ew(1);

    for (text_page = 0; text_page < 2; text_page++) {
        ending_page = text_page;
        DISPLAY_OFF;
        BGP_REG = 0xCF;
#ifdef NINTENDO_NES
        color_ending_text_fade(0);
#endif
        pattern_active = 1;
        for (x = 0; x < 20; x++) tiles[x] = ENDING_PATTERN_TILE;
        for (y = 0; y < 18; y++) set_bkg_tiles(ENDING_TILE_X, ENDING_TY(y), 20, 1, tiles);
        DISPLAY_ON;
        clock_reset();

        for (f = 0; f < 6; f++) {
#ifdef NINTENDO_NES
            color_ending_text_fade(f);
#else
            BGP_REG = fade_bgp[f];
#endif
            ew(8);
        }

        if (text_page == 0) {
            sfx_play_def(&sfx_explosion);
        }
#ifdef NINTENDO_NES
        reveal_pos = 0;
        for (y = 0; y < REVEAL_FRAMES; y++) {
            reveal_cells();
            ew(1);
        }
        /* Page complete: no more tile writes until the player continues.
         * Only the hatch CHR animation keeps running (one queue entry per
         * PAL frame, the same load the game's row writer has). */
        while (!(joypad() & J_START)) ew(1);
#else
        reveal_rng = 0xACE1;
        do {
            reveal_cells();
            ew(1);
        } while (!(joypad() & J_START));
#endif

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
#ifndef NINTENDO_NES
    if (color_on) {
        /* Ground and ship-flash tiles carry PF3 in shade 2 for DMG; CGB wants
         * the original palette indices.  The NES tile set is generated with
         * real palette roles instead (see gen_ending.py). */
        set_bkg_data(ENDING_SHIPL, 8, ending_scene_cgb);
        set_bkg_data(ENDING_GROUND, 4, ending_ground_cgb);
    }
#endif
    set_sprite_data(ENDING_SPRITE_BASE, ENDING_SPRITE_TILES,
                    ending_sprite_tiles);
#ifdef NINTENDO_NES
    /* Centre the 20x18 GBC scene on the 32x30 NES screen. */
    nes_clear_screen();
#else
    /* CGB: one grey ramp palette covers the scene and both text pages; the
     * per-scanline DMG fade stays a single palette (accepted simplification). */
    color_fill_attrs(0, 0, 32, 32, COLOR_PAL_NORMAL);
    color_fill_win_attrs(0, 0, 20, 18, COLOR_PAL_ENDING);
#endif
    color_ending_scene();
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
