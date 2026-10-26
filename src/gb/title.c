/* Atari/GBC title screen, adapted to the DMG palette.
 *
 * Layout is the same 20x18 grid as robbo-gbc/src/menu.c:
 *   rows 0..2   authentic RoDDo logo (three-phase shade rotation)
 *   rows 4..6   credits
 *   rows 8..10  controls
 *   row 11/17   rules around a 5-line typewriter window
 *
 * When a save exists, A/START stops the typewriter and opens a start-level
 * menu in the same window.  Left/Right select the planet, Up/Down choose
 * DELETE SAVE GAME, and A starts (or asks to confirm deletion).  The number
 * uses the game's authentic 8x16 HUD digits.  Without a save, A/START starts
 * level 1 directly.
 *
 * The GBC palette bands become separate 1bpp I.FNT tile sets; the logo's
 * temporal hue cycle becomes three pre-rendered bevel-shade variants.  See
 * gb/tools/gen_title.py.  Kept in bank 11 to leave bank 0 for gameplay.
 */
#pragma bank 11

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "title.h"
#include "../gen/levels.h"
#include "../gen/title_data.h"
#include "color.h"
#include "render.h"
#include "save.h"
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

#define MENU_MODE_SCROLL  0
#define MENU_MODE_START   1
#define MENU_MODE_DELETE  2

#define MENU_ROW_HEADING  0
#define MENU_ROW_DIGIT_TOP 1
#define MENU_ROW_DIGIT_BOTTOM 2
#define MENU_ROW_DELETE   4
#define MENU_REPEAT_FRAMES 6

/* Four scratch 8x8 tiles above the 240-tile title overlay.  They hold dimmed
 * copies of the current level's HUD digits while DELETE is selected. */
#define TITLE_DIM_DIGIT_BASE 240

static void title_wait_vbl(void)
{
    PLATFORM_WAIT_VBL();
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

/* Copy one white HUD digit half into a dim tile: colour 0 (the white glyph)
 * becomes colour 1 (the grey font shade); the black border stays colour 3. */
static void title_dim_digit(uint8_t digit, uint8_t half, uint8_t *dst)
{
    const uint8_t *src = &title_tiles[title_hud_digits[digit][half] * 16];
    uint8_t i;

    for (i = 0; i < 16; i += 2) {
        uint8_t lo = src[i];
        uint8_t hi = src[i + 1];
        uint8_t zero = (uint8_t)~(lo | hi);
        dst[i] = (uint8_t)(lo | zero);
        dst[i + 1] = hi;
    }
}

/* Build and publish the two dim tiles for one half of the 8x16 level number.
 * Called only while DELETE is selected, in the same VBlank slice as the row. */
static void title_dim_digit_row(uint8_t level, uint8_t half)
{
    uint8_t buf[32];

    title_dim_digit((level / 10) % 10, half, buf);
    title_dim_digit(level % 10, half, buf + 16);
    set_bkg_data((uint8_t)(TITLE_DIM_DIGIT_BASE + (half ? 2 : 0)), 2, buf);
}

/* One row of the start-level menu.  Rows are published individually so a
 * redraw never exceeds the VBlank budget. */
static void title_start_menu_row(uint8_t row, uint8_t level, uint8_t sel)
{
    uint8_t buf[TITLE_COLS];
    const char *text = 0;
    const uint8_t *font = title_font_gray;
    uint8_t x = 0;
    uint8_t i;

    for (i = 0; i < TITLE_COLS; i++) buf[i] = TITLE_BLACK_TILE;

    if (row == MENU_ROW_HEADING) {
        text = "STARTING LEVEL";
        font = sel ? title_font_gray : title_font_white;
        x = (uint8_t)((TITLE_COLS - 14) >> 1);
        if (sel == 0) buf[x - 1] = title_font_white[(uint8_t)'>'];
    } else if (row == MENU_ROW_DIGIT_TOP) {
        if (sel) {
            title_dim_digit_row(level, 0);
            buf[9] = TITLE_DIM_DIGIT_BASE;
            buf[10] = (uint8_t)(TITLE_DIM_DIGIT_BASE + 1);
        } else {
            buf[9] = title_hud_digits[(level / 10) % 10][0];
            buf[10] = title_hud_digits[level % 10][0];
        }
    } else if (row == MENU_ROW_DIGIT_BOTTOM) {
        if (sel) {
            title_dim_digit_row(level, 1);
            buf[9] = (uint8_t)(TITLE_DIM_DIGIT_BASE + 2);
            buf[10] = (uint8_t)(TITLE_DIM_DIGIT_BASE + 3);
        } else {
            buf[9] = title_hud_digits[(level / 10) % 10][1];
            buf[10] = title_hud_digits[level % 10][1];
        }
    } else if (row == MENU_ROW_DELETE) {
        text = "DELETE SAVE GAME";
        font = sel ? title_font_white : title_font_gray;
        x = 2;
        if (sel == 1) buf[1] = title_font_white[(uint8_t)'>'];
    }

    if (text) {
        for (i = 0; text[i] && (uint8_t)(x + i) < TITLE_COLS; i++) {
            uint8_t tile = font[(uint8_t)text[i]];
            if (tile != 0xFF) buf[x + i] = tile;
        }
    }

    set_bkg_tiles(0, (uint8_t)(TITLE_WINDOW_Y + row), TITLE_COLS, 1, buf);

    /* The active option uses the normal UI palette; inactive options use the
     * darker title grey on CGB.  Attributes are ignored on DMG. */
    color_fill_attrs(0, (uint8_t)(TITLE_WINDOW_Y + row), TITLE_COLS, 1,
                     (row == MENU_ROW_DELETE)
                         ? (sel ? COLOR_PAL_UI : COLOR_PAL_TITLE_DIM)
                         : (sel ? COLOR_PAL_TITLE_DIM : COLOR_PAL_UI));
}

static void title_confirm_row(uint8_t row)
{
    uint8_t buf[TITLE_COLS];
    const char *text = 0;
    const uint8_t *font = title_font_gray;
    uint8_t x = 0;
    uint8_t i;

    for (i = 0; i < TITLE_COLS; i++) buf[i] = TITLE_BLACK_TILE;

    if (row == 0) {
        text = "DELETE SAVE GAME?";
        font = title_font_white;
        x = (uint8_t)((TITLE_COLS - 17) >> 1);
    } else if (row == 2) {
        text = "A YES  B NO";
        font = title_font_gray;
        x = (uint8_t)((TITLE_COLS - 11) >> 1);
    }

    if (text) {
        for (i = 0; text[i] && (uint8_t)(x + i) < TITLE_COLS; i++) {
            uint8_t tile = font[(uint8_t)text[i]];
            if (tile != 0xFF) buf[x + i] = tile;
        }
    }

    set_bkg_tiles(0, (uint8_t)(TITLE_WINDOW_Y + row), TITLE_COLS, 1, buf);
    color_fill_attrs(0, (uint8_t)(TITLE_WINDOW_Y + row), TITLE_COLS, 1,
                     COLOR_PAL_UI);
}

uint8_t title_show(uint8_t saved_level) BANKED
{
    uint8_t visible[TITLE_WINDOW_H];
    uint8_t next_line, col, cur_len, state, delay, hold, shift_row;
    uint8_t blink, logo_phase, i;
    uint8_t pad, prev = 0;
    uint8_t menu_mode, menu_sel, menu_level, menu_dirty, menu_repeat;
    uint8_t scroll_redraw;
    uint8_t start_level;

    if (saved_level < 1 || saved_level > LEVEL_COUNT) saved_level = 0;

    /* The VBlank camera handler keeps applying cam_scx/cam_scy after the
     * display is turned off, so reset the gameplay camera before entering
     * the title.  Without this, EXIT TO MENU after playing at a scrolled
     * camera position shifts the whole title screen left/up. */
    render_camera_reset();

    DISPLAY_OFF;
    HIDE_WIN;
    SCX_REG = 0;
    SCY_REG = 0;
    BGP_REG = 0xE4;

    set_bkg_data(0, TITLE_TILE_COUNT, title_tiles);

    /* Black playfield, like the Atari/GBC title. */
    title_fill(0, 0, 32, 32, TITLE_BLACK_TILE);
    /* CGB: UI palette everywhere, warm palette on the logo block. */
    color_fill_attrs(0, 0, 32, 32, COLOR_PAL_UI);
    color_fill_attrs(TITLE_LOGO_X, 0, TITLE_LOGO_TW, TITLE_LOGO_TH,
                     COLOR_PAL_LOGO);
    /* CGB: the two instruction-window rules are dark red, as on the GBC. */
    color_fill_attrs(0, TITLE_RULE_TOP, TITLE_COLS, 1, COLOR_PAL_RULE);
    color_fill_attrs(0, TITLE_RULE_BOT, TITLE_COLS, 1, COLOR_PAL_RULE);
    /* CGB: inactive menu options get a darker grey than the normal UI text. */
    color_title_dim_palette();

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
    menu_mode = MENU_MODE_SCROLL;
    menu_sel = 0;
    menu_level = saved_level ? saved_level : 1;
    menu_dirty = 0;
    menu_repeat = 0;
    scroll_redraw = 0;
    start_level = 1;

    sfx_stop();
    SHOW_BKG;
    DISPLAY_ON;

    while (1) {
        title_wait_vbl();
        sfx_update();
        pad = joypad();

        blink++;
        if ((blink & (LOGO_PHASE_FRAMES - 1)) == 0) {
            if (++logo_phase >= LOGO_PHASES) logo_phase = 0;
            title_draw_logo((uint8_t)(TITLE_LOGO_0 + logo_phase * TITLE_LOGO_TILES));
        }

        if (menu_mode == MENU_MODE_SCROLL) {
            if (scroll_redraw) {
                /* After a delete, blank the old menu rows one per frame and
                 * restart the typewriter from the first instruction line. */
                uint8_t y = (uint8_t)(TITLE_WINDOW_Y +
                    (TITLE_WINDOW_H - scroll_redraw));
                title_draw_line(y, 0xFF);
                color_fill_attrs(0, y, TITLE_COLS, 1, COLOR_PAL_UI);
                scroll_redraw--;
                if (scroll_redraw == 0) {
                    next_line = 0;
                    for (i = 0; i < TITLE_WINDOW_H; i++) visible[i] = 0xFF;
                    visible[TITLE_WINDOW_H - 1] = next_line++;
                    col = 0;
                    cur_len = title_line_len(visible[TITLE_WINDOW_H - 1]);
                    state = 0;
                    delay = 0;
                    hold = 0;
                    shift_row = 0;
                }
            } else if (state == 0) {
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

            /* Atari-style: no PRESS START prompt; A or START begins (or, with
             * a save, opens the start-level menu). */
            if ((pad & (J_START | J_A)) && !(prev & (J_START | J_A))) {
                if (saved_level) {
                    menu_mode = MENU_MODE_START;
                    menu_sel = 0;
                    menu_level = saved_level;
                    menu_repeat = 0;
                    menu_dirty = (uint8_t)((1u << TITLE_WINDOW_H) - 1u);
                } else {
                    start_level = 1;
                    break;
                }
            }
        } else if (menu_mode == MENU_MODE_START) {
            if (menu_dirty) {
                for (i = 0; i < TITLE_WINDOW_H; i++) {
                    uint8_t bit = (uint8_t)(1u << i);
                    if (menu_dirty & bit) {
                        title_start_menu_row(i, menu_level, menu_sel);
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
                    menu_dirty |= (uint8_t)((1u << MENU_ROW_HEADING) |
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
                    menu_dirty |= (uint8_t)((1u << MENU_ROW_DIGIT_TOP) |
                                            (1u << MENU_ROW_DIGIT_BOTTOM));
                }

                if (edge & J_A) {
                    if (menu_sel == 1) {
                        menu_mode = MENU_MODE_DELETE;
                        menu_repeat = 0;
                        menu_dirty = (uint8_t)((1u << TITLE_WINDOW_H) - 1u);
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
                for (i = 0; i < TITLE_WINDOW_H; i++) {
                    uint8_t bit = (uint8_t)(1u << i);
                    if (menu_dirty & bit) {
                        title_confirm_row(i);
                        menu_dirty &= (uint8_t)~bit;
                        break;
                    }
                }
            } else {
                uint8_t edge = (uint8_t)(pad & (uint8_t)~prev);

                if (edge & J_A) {
                    /* Confirmed: erase, then return to the normal scrolling
                     * title.  With no save, A/START now starts level 1. */
                    save_erase();
                    saved_level = 0;
                    start_level = 1;
                    menu_mode = MENU_MODE_SCROLL;
                    menu_sel = 0;
                    menu_level = 1;
                    menu_repeat = 0;
                    menu_dirty = 0;
                    scroll_redraw = TITLE_WINDOW_H;
                } else if (edge & (J_B | J_START)) {
                    /* Cancel: back to the level/delete menu. */
                    menu_mode = MENU_MODE_START;
                    menu_sel = 0;
                    menu_repeat = 0;
                    menu_dirty = (uint8_t)((1u << TITLE_WINDOW_H) - 1u);
                }
            }
        }

        prev = pad;
    }

    /* Release wait is bounded: a stuck harness/emulator input must not leave
     * the title spinning forever, and 30 frames is imperceptible on hardware. */
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
