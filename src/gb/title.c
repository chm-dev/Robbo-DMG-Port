/* Atari/GBC title screen, adapted to the DMG palette.
 *
 * Layout is the same 20x18 grid as robbo-gbc/src/menu.c:
 *   rows 0..2   authentic RoDDo logo (three-phase shade rotation)
 *   rows 4..6   credits
 *   rows 8..10  controls
 *   row 11/17   rules around a 5-line typewriter window
 *
 * The GBC palette bands become separate 1bpp I.FNT tile sets; the logo's
 * temporal hue cycle becomes three pre-rendered bevel-shade variants.  See
 * gb/tools/gen_title.py.  Kept in bank 11 to leave bank 0 for gameplay.
 */
#pragma bank 11

#include <gb/gb.h>
#include <stdint.h>

#include "title.h"
#include "../gen/title_data.h"
#include "sound.h"

#define TITLE_COLS      20
#define TITLE_LOGO_X     3
#define TITLE_WINDOW_Y  12
#define TITLE_WINDOW_H   5
#define TITLE_BOTTOM    (TITLE_WINDOW_Y + TITLE_WINDOW_H - 1)
#define TITLE_RULE_TOP  11
#define TITLE_RULE_BOT  17

#define CHAR_DELAY       2
#define HOLD_LINE       28
#define HOLD_BLANK      12
#define HOLD_END       180
#define LOGO_PHASE_FRAMES 16
#define LOGO_PHASES       3

static void title_wait_vbl(void)
{
    VBL_DONE = 0;
    while (!VBL_DONE) {
    }
}

static void title_fill(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t tile)
{
    uint8_t buf[32];
    uint8_t i;

    for (i = 0; i < w; i++) buf[i] = tile;
    for (i = 0; i < h; i++) set_bkg_tiles(x, (uint8_t)(y + i), w, 1, buf);
}

static void title_text(uint8_t x, uint8_t y, const char *text, const uint8_t *font)
{
    uint8_t buf[TITLE_COLS];
    uint8_t n = 0;

    while (text[n] && n < TITLE_COLS) {
        uint8_t tile = font[(uint8_t)text[n]];
        buf[n] = (tile == 0xFF) ? TITLE_BLACK_TILE : tile;
        n++;
    }
    if (n) set_bkg_tiles(x, y, n, 1, buf);
}

static uint8_t title_line_len(uint8_t line)
{
    uint8_t n = 0;

    if (line == 0xFF) return 0;
    while (n < TITLE_INSTR_WIDTH && title_instr[line][n]) n++;
    return n;
}

static void title_draw_line(uint8_t y, uint8_t line)
{
    uint8_t buf[TITLE_COLS];
    uint8_t col;

    for (col = 0; col < TITLE_COLS; col++) {
        uint8_t tile = TITLE_BLACK_TILE;
        if (line != 0xFF) {
            char c = title_instr[line][col];
            if (c) {
                if (line == 0) {
                    /* The heading is inverse-video; its spaces stay black. */
                    if (c != ' ') {
                        tile = title_font_inverse[(uint8_t)c];
                    }
                } else {
                    tile = title_font_gray[(uint8_t)c];
                }
                if (tile == 0xFF) tile = TITLE_BLACK_TILE;
            }
        }
        buf[col] = tile;
    }
    set_bkg_tiles(0, y, TITLE_COLS, 1, buf);
}

static void title_draw_logo(uint8_t base)
{
    uint8_t buf[TITLE_LOGO_TW];
    uint8_t row, x;

    for (row = 0; row < TITLE_LOGO_TH; row++) {
        for (x = 0; x < TITLE_LOGO_TW; x++) {
            buf[x] = (uint8_t)(base + row * TITLE_LOGO_TW + x);
        }
        set_bkg_tiles(TITLE_LOGO_X, row, TITLE_LOGO_TW, 1, buf);
    }
}

void title_show(void) BANKED
{
    uint8_t visible[TITLE_WINDOW_H];
    uint8_t next_line, col, cur_len, state, delay, hold, shift_row;
    uint8_t blink, logo_phase, i;

    DISPLAY_OFF;
    HIDE_WIN;
    SCX_REG = 0;
    SCY_REG = 0;
    BGP_REG = 0xE4;

    set_bkg_data(0, TITLE_TILE_COUNT, title_tiles);

    /* Black playfield, like the Atari/GBC title. */
    title_fill(0, 0, 32, 32, TITLE_BLACK_TILE);

    title_draw_logo(TITLE_LOGO_0);

    /* credits (bright) */
    set_bkg_tile_xy(2, 4, TITLE_COPYRIGHT_TILE);
    title_text(4, 4, "1989 BY AVALON", title_font_white);
    title_text(0, 5, "PROGRAM AND GRAPHICS", title_font_white);
    title_text(4, 6, "JANUSZ PELC", title_font_white);

    /* controls (grey) */
    title_text(0, 8, "CONTROL:  D-PAD", title_font_gray);
    title_text(0, 9, "FIRE:     A + D-PAD", title_font_gray);
    title_text(0, 10, "PAN:      B + D-PAD", title_font_gray);

    /* rules around the instruction window */
    title_fill(0, TITLE_RULE_TOP, TITLE_COLS, 1, TITLE_RULE_TILE);
    title_fill(0, TITLE_RULE_BOT, TITLE_COLS, 1, TITLE_RULE_TILE);

    for (i = 0; i < TITLE_WINDOW_H; i++) {
        visible[i] = 0xFF;
        title_draw_line((uint8_t)(TITLE_WINDOW_Y + i), 0xFF);
    }

    next_line = 0;
    visible[TITLE_WINDOW_H - 1] = next_line++;
    col = 0;
    cur_len = title_line_len(visible[TITLE_WINDOW_H - 1]);
    state = 0;
    delay = 0;
    hold = 0;
    shift_row = 0;
    blink = 0;
    logo_phase = 0;

    sfx_stop();
    SHOW_BKG;
    DISPLAY_ON;

    while (1) {
        title_wait_vbl();
        sfx_update();

        blink++;
        if ((blink & (LOGO_PHASE_FRAMES - 1)) == 0) {
            if (++logo_phase >= LOGO_PHASES) logo_phase = 0;
            title_draw_logo((uint8_t)(TITLE_LOGO_0 + logo_phase * TITLE_LOGO_TILES));
        }

        if (state == 0) {
            /* Type the bottom window line, with the blinking caret. */
            if (col < cur_len) {
                uint8_t caret = ((blink >> 3) & 1) ? TITLE_CARET_TILE : TITLE_BLACK_TILE;
                set_bkg_tile_xy(col, TITLE_BOTTOM, caret);
            }
            if (col >= cur_len) {
                if (col < TITLE_COLS) set_bkg_tile_xy(col, TITLE_BOTTOM, TITLE_BLACK_TILE);
                state = 1;
                hold = (next_line == TITLE_INSTR_NLINES) ? HOLD_END :
                       (cur_len ? HOLD_LINE : HOLD_BLANK);
            } else if (delay) {
                delay--;
            } else {
                char c = title_instr[visible[TITLE_WINDOW_H - 1]][col];
                uint8_t tile = (visible[TITLE_WINDOW_H - 1] == 0 && c != ' ')
                    ? title_font_inverse[(uint8_t)c]
                    : title_font_gray[(uint8_t)c];
                if (tile == 0xFF) tile = TITLE_BLACK_TILE;
                set_bkg_tile_xy(col, TITLE_BOTTOM, tile);
                if (c != ' ') sfx_click();
                col++;
                delay = CHAR_DELAY;
            }
        } else if (state == 1) {
            if (hold) {
                hold--;
            } else {
                for (i = 0; i < TITLE_WINDOW_H - 1; i++) {
                    visible[i] = visible[i + 1];
                }
                shift_row = 0;
                state = 2;
                /* Line feed: the current line moves up and the new bottom
                 * line is created.  Sound the beep at that moment. */
                sfx_beep();
            }
        } else {
            /* Spread the four shifted rows over four frames so every VRAM
             * write fits comfortably in VBlank. */
            if (shift_row < TITLE_WINDOW_H - 1) {
                title_draw_line((uint8_t)(TITLE_WINDOW_Y + shift_row), visible[shift_row]);
                shift_row++;
            } else {
                title_draw_line(TITLE_BOTTOM, 0xFF);
                if (next_line < TITLE_INSTR_NLINES) {
                    visible[TITLE_WINDOW_H - 1] = next_line++;
                } else {
                    visible[TITLE_WINDOW_H - 1] = 0xFF;
                    if (++next_line >= TITLE_INSTR_NLINES + TITLE_WINDOW_H) {
                        next_line = 0;
                    }
                }
                col = 0;
                cur_len = title_line_len(visible[TITLE_WINDOW_H - 1]);
                state = 0;
                delay = 0;
            }
        }

        /* Atari-style: no PRESS START prompt; A or START begins. */
        if (joypad() & (J_START | J_A)) break;
    }

    waitpadup();
    sfx_stop();
    DISPLAY_OFF;
}
