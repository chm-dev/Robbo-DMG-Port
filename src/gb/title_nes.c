/* NES title screen, ported from the Atari TITLE.ASM layout.
 *
 * The Atari title is a 32x24 character screen whose content is 256x240 px,
 * exactly the NES resolution, so the vertical layout maps almost one-to-one:
 *
 *   rows  3..7   authentic 5-letter BIGR logo (28x5 tiles)
 *   row   9      (c) 1989 BY AVALON
 *   rows 11..12  PROGRAM AND GRAPHICS / JANUSZ PELC
 *   rows 14..17  English control lines from the Game Boy title
 *   row   18     rule
 *   rows 19..26  8-line typewriter window (32 columns, Atari 8-line grid)
 *   row   27     rule
 *
 * The logo uses the original TITLE.ASM BIGR 56x8 block map: each source
 * pixel is one 4x4 colour square, so the 56x8 map becomes 28x5 NES 8x8 tiles
 * (224x40 px).  gen_title.py writes the tiles in GBDK's interleaved 2bpp
 * format to title_logo_nes.c.  The CHR stays fixed; the three foreground
 * palette entries rotate for the colour animation.
 *
 * Text is the Game Boy English text; the 32-column reflow lives in
 * title_data.c (`title_instr32`).  The start-level menu keeps the GB
 * behaviour and is drawn in the Atari window instead of the GB 20x5 box.
 *
 * This file is NES-only (`build.ps1` excludes *_nes.c from Game Boy builds).
 * The GB implementation remains in title.c.
 */
#pragma bank 11

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "title.h"
#include "../gen/levels.h"
#include "../gen/title_data.h"
#include "../gen/title_logo_nes.h"
#include "color.h"
#include "render.h"
#include "save.h"
#include "sound.h"

#define TITLE_COLS       32
#define TITLE_ROWS       30

#define LOGO_X            2
#define LOGO_Y            3
#define LOGO_TW           TITLE_NES_LOGO_TW
#define LOGO_TH           TITLE_NES_LOGO_TH

/* The old GB logo phases occupy 0..125; the NES logo reuses 0..139 (five
 * 8px tile rows, each holding one 4px glyph row plus its 1px gap) and two
 * spare slots for the generated rule and black tiles. */
#define NES_RULE_TILE   140
#define NES_BLANK_TILE  141

#define ROW_COPYRIGHT     9
#define ROW_CREDITS      11
#define ROW_CTRL1        14
#define ROW_CTRL2        15
#define ROW_CTRL3        17
#define ROW_RULE_TOP     18
#define WINDOW_Y         19
#define WINDOW_H          8
#define ROW_RULE_BOT     (WINDOW_Y + WINDOW_H)   /* 27 */

#define CHAR_DELAY_BASE   2
#define HOLD_LINE        15
#define HOLD_BLANK        8
#define HOLD_END        180
#define LOGO_PHASE_FRAMES 35

#define MENU_MODE_SCROLL  0
#define MENU_MODE_START   1
#define MENU_MODE_DELETE  2

#define MENU_ROW_HEADING  0
#define MENU_ROW_DIGIT_TOP 1
#define MENU_ROW_DIGIT_BOTTOM 2
#define MENU_ROW_DELETE   4
#define MENU_REPEAT_FRAMES 6

static uint8_t row_buf[TITLE_COLS];
static uint8_t tile_buf[16];
static uint8_t logo_color_phase;
static uint8_t logo_phase_timer;

static void title_wait_vbl(void)
{
    PLATFORM_WAIT_VBL();
}

/* ------------------------------------------------------------------ */
/* Text helpers                                                        */
/* ------------------------------------------------------------------ */

static void title_fill_row(uint8_t y, uint8_t tile)
{
    uint8_t i;

    for (i = 0; i < TITLE_COLS; i++) row_buf[i] = tile;
    set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
}

static void title_fill(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t tile)
{
    uint8_t i;

    if (w > TITLE_COLS) w = TITLE_COLS;
    for (i = 0; i < w; i++) row_buf[i] = tile;
    for (i = 0; i < h; i++) set_bkg_tiles(x, (uint8_t)(y + i), w, 1, row_buf);
}

static uint8_t title_line_len(uint8_t line)
{
    uint8_t n = 0;

    if (line == 0xFF) return 0;
    while (n < TITLE_INSTR32_WIDTH && title_instr32[line][n]) n++;
    return n;
}

/* Draw one full 32-column window line.  The heading (line 0) uses the
 * inverse I.FNT tiles, all other lines use the grey font. */
static void title_draw_line(uint8_t y, uint8_t line)
{
    const uint8_t *font = title_font_gray;
    uint8_t col;

    for (col = 0; col < TITLE_COLS; col++) row_buf[col] = NES_BLANK_TILE;

    if (line != 0xFF) {
        if (line == 0) font = title_font_inverse;
        for (col = 0; col < TITLE_INSTR32_WIDTH; col++) {
            char c = title_instr32[line][col];
            uint8_t tile;

            if (c == 0 || c == ' ') continue;
            tile = font[(uint8_t)c];
            if (tile != 0xFF) row_buf[col] = tile;
        }
    }
    set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
}

/* Draw a one-line ASCII string at x using the grey I.FNT tiles. */
static void title_text(uint8_t x, uint8_t y, const char *text)
{
    uint8_t i;

    title_fill_row(y, NES_BLANK_TILE);
    for (i = 0; text[i] && (uint8_t)(x + i) < TITLE_COLS; i++) {
        uint8_t tile;

        if (text[i] == ' ') continue;
        tile = title_font_gray[(uint8_t)text[i]];
        if (tile != 0xFF) row_buf[x + i] = tile;
    }
    set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
}

static void title_draw_static(void)
{
    uint8_t i;

    /* copyright: tile + space + text, centred as 16 cells */
    title_fill_row(ROW_COPYRIGHT, NES_BLANK_TILE);
    row_buf[8] = TITLE_COPYRIGHT_TILE;
    for (i = 0; i < 14; i++) {
        char c = "1989 BY AVALON"[i];
        if (c != ' ') row_buf[10 + i] = title_font_gray[(uint8_t)c];
    }
    set_bkg_tiles(0, ROW_COPYRIGHT, TITLE_COLS, 1, row_buf);

    title_text(6, ROW_CREDITS, "PROGRAM AND GRAPHICS");
    title_text(10, (uint8_t)(ROW_CREDITS + 1), "JANUSZ PELC");
    title_text(6, ROW_CTRL1, "CONTROL:  D-PAD");
    title_text(6, ROW_CTRL2, "FIRE:     A + D-PAD");
    title_text(6, ROW_CTRL3, "PAN:      B + D-PAD");

    title_fill(0, ROW_RULE_TOP, TITLE_COLS, 1, NES_RULE_TILE);
    title_fill(0, ROW_RULE_BOT, TITLE_COLS, 1, NES_RULE_TILE);
}

/* Convert a DMG title tile (glyph = colour 0, background = colour 3) into the
 * NES text convention (glyph = colour 1, background = colour 3). */
static void title_convert_tile(uint8_t index)
{
    const uint8_t *src = &title_tiles[index * 16];
    uint8_t i;

    for (i = 0; i < 16; i += 2) {
        uint8_t lo = src[i];
        uint8_t hi = src[i + 1];
        uint8_t zero = (uint8_t)~(lo | hi);

        tile_buf[i] = (uint8_t)(lo | zero);
        tile_buf[i + 1] = hi;
    }
    set_bkg_data(index, 1, tile_buf);
}

static void title_prepare_tiles(void)
{
    uint8_t d, i;

    title_convert_tile(TITLE_COPYRIGHT_TILE);
    for (d = 0; d < 10; d++) {
        title_convert_tile(title_hud_digits[d][0]);
        title_convert_tile(title_hud_digits[d][1]);
    }

    /* Blue rule: two scanlines of colour 2 on a black (colour 0) field.
     * GBDK's 2bpp layout interleaves the two planes per row: bytes 2y/2y+1
     * are the low/high plane of row y.  Set only the high plane so both
     * scanlines use palette entry 2. */
    for (i = 0; i < 16; i++) tile_buf[i] = 0;
    tile_buf[11] = 0xFF;   /* row 5, high plane */
    tile_buf[13] = 0xFF;   /* row 6, high plane */
    set_bkg_data(NES_RULE_TILE, 1, tile_buf);

    /* Shared black blank tile (colour 0 = backdrop). */
    for (i = 0; i < 16; i++) tile_buf[i] = 0;
    set_bkg_data(NES_BLANK_TILE, 1, tile_buf);
}

/* ------------------------------------------------------------------ */
/* Atari BIGR logo                                                     */
/* ------------------------------------------------------------------ */

static void logo_draw_names(void)
{
    uint8_t tr, tc;

    for (tr = 0; tr < LOGO_TH; tr++) {
        for (tc = 0; tc < LOGO_TW; tc++) row_buf[tc] = (uint8_t)(tr * LOGO_TW + tc);
        set_bkg_tiles(LOGO_X, (uint8_t)(LOGO_Y + tr), LOGO_TW, 1, row_buf);
    }
}

/* The logo CHR is generated from the authentic 8x56 BIGR block map by
 * gen_title.py.  It is already in GBDK's interleaved (lo,hi) 2bpp order, so
 * every 4x4 source block becomes a solid 4x4 colour square on screen.  Only
 * the palette entries rotate; rewriting 140 CHR tiles piecemeal would tear
 * the logo. */
static void logo_step(void)
{
    if (++logo_phase_timer < LOGO_PHASE_FRAMES) return;
    logo_phase_timer = 0;
    logo_color_phase = (uint8_t)((logo_color_phase + 1) & 3);
    color_title_nes(logo_color_phase);
}

/* ------------------------------------------------------------------ */
/* Start-level / delete menu                                           */
/* ------------------------------------------------------------------ */

static void menu_row(uint8_t row, uint8_t level, uint8_t sel)
{
    uint8_t y = (uint8_t)(WINDOW_Y + row);
    uint8_t i;

    if (row == MENU_ROW_HEADING) {
        const char *text = "STARTING LEVEL";
        uint8_t x = (uint8_t)((TITLE_COLS - 14) >> 1);

        title_fill_row(y, NES_BLANK_TILE);
        for (i = 0; i < 14; i++) row_buf[x + i] = title_font_gray[(uint8_t)text[i]];
        if (sel == 0) row_buf[x - 2] = title_font_gray[(uint8_t)'>'];
        set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
    } else if (row == MENU_ROW_DIGIT_TOP || row == MENU_ROW_DIGIT_BOTTOM) {
        uint8_t half = (row == MENU_ROW_DIGIT_TOP) ? 0 : 1;

        title_fill_row(y, NES_BLANK_TILE);
        row_buf[15] = title_hud_digits[(level / 10) % 10][half];
        row_buf[16] = title_hud_digits[level % 10][half];
        set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
    } else if (row == MENU_ROW_DELETE) {
        const char *text = "DELETE SAVE GAME";
        uint8_t x = (uint8_t)((TITLE_COLS - 16) >> 1);

        title_fill_row(y, NES_BLANK_TILE);
        for (i = 0; i < 16; i++) row_buf[x + i] = title_font_gray[(uint8_t)text[i]];
        if (sel == 1) row_buf[x - 2] = title_font_gray[(uint8_t)'>'];
        set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
    } else {
        title_fill_row(y, NES_BLANK_TILE);
    }
}

static void confirm_row(uint8_t row)
{
    uint8_t y = (uint8_t)(WINDOW_Y + row);
    uint8_t i;

    if (row == 0) {
        const char *text = "DELETE SAVE GAME?";
        uint8_t x = (uint8_t)((TITLE_COLS - 17) >> 1);

        title_fill_row(y, NES_BLANK_TILE);
        for (i = 0; i < 17; i++) row_buf[x + i] = title_font_gray[(uint8_t)text[i]];
        set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
    } else if (row == 2) {
        const char *text = "A YES  B NO";
        uint8_t x = (uint8_t)((TITLE_COLS - 11) >> 1);

        title_fill_row(y, NES_BLANK_TILE);
        for (i = 0; i < 11; i++) row_buf[x + i] = title_font_gray[(uint8_t)text[i]];
        set_bkg_tiles(0, y, TITLE_COLS, 1, row_buf);
    } else {
        title_fill_row(y, NES_BLANK_TILE);
    }
}

/* ------------------------------------------------------------------ */
/* Title loop                                                          */
/* ------------------------------------------------------------------ */

uint8_t title_show(uint8_t saved_level) BANKED
{
    uint8_t visible[WINDOW_H];
    uint8_t next_line, col, cur_len, state, delay, hold, shift_row;
    uint8_t blink, i;
    uint8_t start_delay;
    uint8_t pad, prev = 0;
    uint8_t menu_mode, menu_sel, menu_level, menu_dirty, menu_repeat;
    uint8_t scroll_redraw;
    uint8_t start_level;

    if (saved_level < 1 || saved_level > LEVEL_COUNT) saved_level = 0;

    render_camera_reset();
    DISPLAY_OFF;
    HIDE_WIN;

    set_bkg_data(0, TITLE_TILE_COUNT, title_tiles);
    title_prepare_tiles();

    /* Black playfield and the three static sections. */
    title_fill(0, 0, TITLE_COLS, TITLE_ROWS, NES_BLANK_TILE);
    title_draw_static();

    /* TITLE.ASM's SETUP copies MASK+2/MASK+3 ($FA,$5A) over the padding
     * bytes.  This 16-bit pattern has no 00 bit pairs, and 2-bit rotations
     * preserve that property, so every glyph pixel always gets a colour. */
    /* The authentic BIGR block map lives in title_nes_data.c, already in
     * GBDK's interleaved 2bpp format. */
    logo_color_phase = 0;
    logo_phase_timer = 0;
    color_title_nes(0);
    set_bkg_data(0, TITLE_NES_LOGO_TILE_COUNT, title_nes_logo);
    logo_draw_names();

    /* NES attributes: one palette per 16x16 cell.  The logo block uses slot
     * 0; bright copyright/credits/rules slot 1; controls and the instruction
     * window slot 2.  The menu later switches the window to slot 3. */
    color_fill_attrs(0, 0, TITLE_COLS, TITLE_ROWS, 1);
    color_fill_attrs(0, LOGO_Y, TITLE_COLS, LOGO_TH, 0);
    color_fill_attrs(0, ROW_CTRL1, TITLE_COLS, 4, 2);
    color_fill_attrs(0, WINDOW_Y, TITLE_COLS, WINDOW_H, 2);

    for (i = 0; i < WINDOW_H; i++) {
        visible[i] = 0xFF;
        title_draw_line((uint8_t)(WINDOW_Y + i), 0xFF);
    }

    next_line = 0;
    visible[WINDOW_H - 1] = next_line++;
    col = 0;
    cur_len = title_line_len(visible[WINDOW_H - 1]);
    state = 0;
    delay = 0;
    hold = 0;
    shift_row = 0;
    blink = 0;
    menu_mode = MENU_MODE_SCROLL;
    menu_sel = 0;
    menu_level = saved_level ? saved_level : 1;
    menu_dirty = 0;
    menu_repeat = 0;
    scroll_redraw = 0;
    start_delay = 120;   /* Atari-style pause before the first character */
    start_level = 1;

    sfx_stop();
    SHOW_BKG;
    DISPLAY_ON;

    while (1) {
        title_wait_vbl();
        sfx_update();
        pad = joypad();

        logo_step();
        blink++;

        if (menu_mode == MENU_MODE_SCROLL) {
            if (scroll_redraw) {
                uint8_t y = (uint8_t)(WINDOW_Y + (WINDOW_H - scroll_redraw));

                title_draw_line(y, 0xFF);
                scroll_redraw--;
                if (scroll_redraw == 0) {
                    next_line = 0;
                    for (i = 0; i < WINDOW_H; i++) visible[i] = 0xFF;
                    visible[WINDOW_H - 1] = next_line++;
                    col = 0;
                    cur_len = title_line_len(visible[WINDOW_H - 1]);
                    state = 0;
                    delay = 0;
                    hold = 0;
                    shift_row = 0;
                }
            } else if (start_delay) {
                start_delay--;
            } else if (state == 0) {
                if (col < cur_len) {
                    uint8_t caret = ((blink >> 3) & 1) ? TITLE_CARET_TILE : NES_BLANK_TILE;
                    set_bkg_tile_xy(col, (uint8_t)(WINDOW_Y + WINDOW_H - 1), caret);
                }
                if (col >= cur_len) {
                    if (col < TITLE_COLS)
                        set_bkg_tile_xy(col, (uint8_t)(WINDOW_Y + WINDOW_H - 1), NES_BLANK_TILE);
                    state = 1;
                    hold = (next_line == TITLE_INSTR32_NLINES) ? HOLD_END :
                           (cur_len ? HOLD_LINE : HOLD_BLANK);
                } else if (delay) {
                    delay--;
                } else {
                    char c = title_instr32[visible[WINDOW_H - 1]][col];
                    const uint8_t *font = (visible[WINDOW_H - 1] == 0)
                        ? title_font_inverse : title_font_gray;
                    uint8_t tile = (c == ' ') ? NES_BLANK_TILE : font[(uint8_t)c];

                    if (tile == 0xFF) tile = NES_BLANK_TILE;
                    set_bkg_tile_xy(col, (uint8_t)(WINDOW_Y + WINDOW_H - 1), tile);
                    if (c != ' ') sfx_click();
                    col++;
                    delay = (uint8_t)(CHAR_DELAY_BASE + (c & 3));
                }
            } else if (state == 1) {
                if (hold) {
                    hold--;
                } else {
                    /* Clear the old bottom line before scrolling it up, so the
                     * heading is not visible twice during the 7-frame shift. */
                    title_draw_line((uint8_t)(WINDOW_Y + WINDOW_H - 1), 0xFF);
                    for (i = 0; i < WINDOW_H - 1; i++) visible[i] = visible[i + 1];
                    shift_row = 0;
                    state = 2;
                    sfx_beep();
                }
            } else {
                if (shift_row < WINDOW_H - 1) {
                    title_draw_line((uint8_t)(WINDOW_Y + shift_row), visible[shift_row]);
                    shift_row++;
                } else {
                    title_draw_line((uint8_t)(WINDOW_Y + WINDOW_H - 1), 0xFF);
                    if (next_line < TITLE_INSTR32_NLINES) {
                        visible[WINDOW_H - 1] = next_line++;
                    } else {
                        visible[WINDOW_H - 1] = 0xFF;
                        if (++next_line >= TITLE_INSTR32_NLINES + WINDOW_H) next_line = 0;
                    }
                    col = 0;
                    cur_len = title_line_len(visible[WINDOW_H - 1]);
                    state = 0;
                    delay = 0;
                }
            }

            if ((pad & (J_START | J_A)) && !(prev & (J_START | J_A))) {
                if (saved_level) {
                    menu_mode = MENU_MODE_START;
                    menu_sel = 0;
                    menu_level = saved_level;
                    menu_repeat = 0;
                    menu_dirty = 0xFFu;
                    color_fill_attrs(0, WINDOW_Y, TITLE_COLS, WINDOW_H, 3);
                } else {
                    start_level = 1;
                    break;
                }
            }
        } else if (menu_mode == MENU_MODE_START) {
            if (menu_dirty) {
                for (i = 0; i < WINDOW_H; i++) {
                    uint8_t bit = (uint8_t)(1u << i);
                    if (menu_dirty & bit) {
                        menu_row(i, menu_level, menu_sel);
                        menu_dirty &= (uint8_t)~bit;
                        break;
                    }
                }
            } else {
                uint8_t edge = (uint8_t)(pad & (uint8_t)~prev);
                uint8_t old_level = menu_level;
                uint8_t dir = 0;

                if (edge & (J_UP | J_DOWN)) {
                    menu_sel ^= 1;
                    menu_dirty = (uint8_t)((1u << MENU_ROW_HEADING) |
                                           (1u << MENU_ROW_DIGIT_TOP) |
                                           (1u << MENU_ROW_DIGIT_BOTTOM) |
                                           (1u << MENU_ROW_DELETE));
                    menu_repeat = 0;
                }

                if (menu_sel == 0) {
                    if (edge & J_LEFT) {
                        dir = 2;
                        menu_repeat = MENU_REPEAT_FRAMES;
                    } else if (edge & J_RIGHT) {
                        dir = 1;
                        menu_repeat = MENU_REPEAT_FRAMES;
                    } else if (pad & (J_LEFT | J_RIGHT)) {
                        if (menu_repeat == 0) {
                            dir = (pad & J_RIGHT) ? 1 : 2;
                            menu_repeat = MENU_REPEAT_FRAMES;
                        } else {
                            menu_repeat--;
                        }
                    } else {
                        menu_repeat = 0;
                    }
                } else {
                    menu_repeat = 0;
                }

                if (dir == 1) {
                    if (menu_level < saved_level) menu_level++;
                } else if (dir == 2) {
                    if (menu_level > 1) menu_level--;
                }
                if (menu_level != old_level) {
                    menu_dirty = (uint8_t)((1u << MENU_ROW_DIGIT_TOP) |
                                           (1u << MENU_ROW_DIGIT_BOTTOM));
                }

                if (edge & J_A) {
                    if (menu_sel == 1) {
                        menu_mode = MENU_MODE_DELETE;
                        menu_repeat = 0;
                        menu_dirty = 0xFFu;
                    } else {
                        start_level = menu_level;
                        break;
                    }
                } else if (edge & J_START) {
                    start_level = menu_level;
                    break;
                }
            }
        } else {
            if (menu_dirty) {
                for (i = 0; i < WINDOW_H; i++) {
                    uint8_t bit = (uint8_t)(1u << i);
                    if (menu_dirty & bit) {
                        confirm_row(i);
                        menu_dirty &= (uint8_t)~bit;
                        break;
                    }
                }
            } else {
                uint8_t edge = (uint8_t)(pad & (uint8_t)~prev);

                if (edge & J_A) {
                    save_erase();
                    saved_level = 0;
                    start_level = 1;
                    menu_mode = MENU_MODE_SCROLL;
                    menu_sel = 0;
                    menu_level = 1;
                    menu_repeat = 0;
                    menu_dirty = 0;
                    scroll_redraw = WINDOW_H;
                    color_fill_attrs(0, WINDOW_Y, TITLE_COLS, WINDOW_H, 2);
                } else if (edge & (J_B | J_START)) {
                    menu_mode = MENU_MODE_START;
                    menu_sel = 0;
                    menu_repeat = 0;
                    menu_dirty = 0xFFu;
                }
            }
        }

        prev = pad;
    }

    {
        uint8_t release_wait = 30;
        while (release_wait-- && (joypad() & (J_START | J_A))) {
            title_wait_vbl();
        }
    }
    sfx_stop();
    DISPLAY_OFF;
    return start_level;
}
