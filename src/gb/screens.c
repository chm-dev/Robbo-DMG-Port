/* Low-frequency screens kept out of the full bank 0.
 *
 * The pause menu is a compact BG overlay rather than a window-layer panel.
 * The window layer is locked to the right/bottom edges; drawing on the BG
 * lets the menu be 15x9 tiles in the middle of the view and leaves the HUD
 * window visible at the bottom.  The menu is opened/closed a few rows per
 * frame.  Closing rebuilds the covered tiles from map_type/map_extra, which is
 * exact because the camera and game logic are frozen while paused.
 *
 * The BG tile coordinates are offset by cam_scx/cam_scy, so the panel is
 * positioned in the visible view even when the smooth camera is between cells.
 */
#pragma bank 9

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "../core/game.h"
#include "../gen/levels.h"
#include "../gen/tiles.h"
#include "color.h"
#include "render.h"
#include "screens.h"
#include "sound.h"

#define MENU_W 15
#define MENU_H 9

/* Desired top-left in screen pixels.  The BG scroll shifts the panel by up to
 * seven pixels; it remains centered and fully on-screen. */
#define MENU_SCREEN_X 24
#define MENU_SCREEN_Y 20

#define MENU_TITLE_ROW    1
#define MENU_WARP_ROW     3
#define MENU_RESTART_ROW  5
#define MENU_EXIT_ROW     7

#define MENU_ITEM_WARP     0
#define MENU_ITEM_RESTART  1
#define MENU_ITEM_EXIT     2
#define MENU_ITEM_COUNT    3

#define MENU_REPEAT_FRAMES 6
#define MENU_STEP_ROWS     4

uint8_t pause_menu_state;
uint8_t pause_menu_bg_x;
uint8_t pause_menu_bg_y;

static uint8_t menu_shown_row;
static uint8_t menu_restore_next;
static uint8_t menu_sel;
static uint8_t menu_level;
static uint8_t menu_max_level;
static uint8_t menu_repeat;
static uint16_t menu_dirty;

static const uint8_t menu_item_row[MENU_ITEM_COUNT] = {
    MENU_WARP_ROW, MENU_RESTART_ROW, MENU_EXIT_ROW
};

static void menu_clear_row(uint8_t *row)
{
    uint8_t i;

    for (i = 0; i < MENU_W; i++) row[i] = hud_bg_tile;
}

static void menu_put_text(uint8_t *row, uint8_t col, const char *text)
{
    while (*text && col < MENU_W) {
        uint8_t tile = font_tiles[(uint8_t)*text++];
        if (tile != 0xFF) row[col] = tile;
        col++;
    }
}

static void menu_put_level(uint8_t *row, uint8_t col, uint8_t level)
{
    if (level > 99) level = 99;
    row[col] = font_tiles[(uint8_t)('0' + (level / 10) % 10)];
    row[col + 1] = font_tiles[(uint8_t)('0' + level % 10)];
}

static void menu_draw_row(uint8_t row)
{
    uint8_t buf[MENU_W];

    menu_clear_row(buf);

    switch (row) {
        case MENU_TITLE_ROW:
            menu_put_text(buf, 4, "PAUSED");
            break;

        case MENU_WARP_ROW:
            if (menu_sel == MENU_ITEM_WARP) buf[0] = font_tiles[(uint8_t)'>'];
            menu_put_text(buf, 2, "WARP TO ");
            buf[10] = font_tiles[(uint8_t)'<'];
            menu_put_level(buf, 11, menu_level);
            buf[13] = font_tiles[(uint8_t)'>'];
            break;

        case MENU_RESTART_ROW:
            if (menu_sel == MENU_ITEM_RESTART) buf[0] = font_tiles[(uint8_t)'>'];
            menu_put_text(buf, 2, "RESTART");
            break;

        case MENU_EXIT_ROW:
            if (menu_sel == MENU_ITEM_EXIT) buf[0] = font_tiles[(uint8_t)'>'];
            menu_put_text(buf, 2, "EXIT TO MENU");
            break;

        default:
            break;
    }

    set_bkg_tiles(pause_menu_bg_x, (uint8_t)(pause_menu_bg_y + row),
                  MENU_W, 1, buf);

    if (color_on) {
        uint8_t i;
        for (i = 0; i < MENU_W; i++) buf[i] = COLOR_PAL_UI;
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles(pause_menu_bg_x, (uint8_t)(pause_menu_bg_y + row),
                      MENU_W, 1, buf);
        VBK_REG = VBK_TILES;
    }
}

/* Rebuild one overlay row from the level data.  A BG tile maps to a metatile
 * quadrant: tile x/y -> cell x/y and quadrant x/y. */
static void menu_restore_row(uint8_t row)
{
    uint8_t buf[MENU_W];
    uint8_t attr[MENU_W];
    uint8_t col;
    uint8_t tile_y = (uint8_t)(pause_menu_bg_y + row);

    for (col = 0; col < MENU_W; col++) {
        uint8_t tile_x = (uint8_t)(pause_menu_bg_x + col);
        uint8_t map_row = (uint8_t)((tile_y >> 1) & 15);
        uint8_t level_y = map_row_level[map_row];
        uint8_t cell_x = (uint8_t)((tile_x >> 1) & 15);
        uint8_t type = CT_EMPTY;
        uint8_t extra = 0;
        uint8_t mt;

        if (level_y < level_height) {
            uint16_t idx = ((uint16_t)level_y << 4) | cell_x;
            type = map_type[idx];
            extra = map_extra[idx];
        }
        mt = render_metatile_for_cell(type, extra);

        buf[col] = metatile_tiles[(uint16_t)mt * 4 +
                                  ((tile_y & 1) << 1) + (tile_x & 1)];
        attr[col] = render_cell_palette(type, extra, mt);
    }

    set_bkg_tiles(pause_menu_bg_x, tile_y, MENU_W, 1, buf);
    if (color_on) {
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles(pause_menu_bg_x, tile_y, MENU_W, 1, attr);
        VBK_REG = VBK_TILES;
    }
}

void pause_menu_open(uint8_t level, uint8_t max_level) BANKED
{
    if (max_level < 1) max_level = 1;
    if (max_level > LEVEL_COUNT) max_level = LEVEL_COUNT;
    if (level < 1) level = 1;
    if (level > max_level) level = max_level;

    pause_menu_bg_x = (uint8_t)((cam_scx + MENU_SCREEN_X) >> 3);
    pause_menu_bg_y = (uint8_t)((cam_scy + MENU_SCREEN_Y) >> 3);

    menu_shown_row = 0;
    menu_restore_next = 0;
    menu_sel = MENU_ITEM_WARP;
    menu_level = level;
    menu_max_level = max_level;
    menu_repeat = 0;
    menu_dirty = 0;
    pause_menu_state = PAUSE_STATE_OPENING;
    sfx_play_note(SFX_EXTRA_LIFE);
}

void pause_menu_begin_close(void) BANKED
{
    if (pause_menu_state == PAUSE_STATE_CLOSED ||
        pause_menu_state == PAUSE_STATE_CLOSING) {
        return;
    }

    menu_restore_next = 0;
    menu_dirty = 0;
    pause_menu_state = PAUSE_STATE_CLOSING;
}

void pause_menu_abort(void) BANKED
{
    pause_menu_state = PAUSE_STATE_CLOSED;
    menu_dirty = 0;
    menu_shown_row = 0;
    menu_restore_next = 0;
}

uint8_t pause_menu_step(void) BANKED
{
    uint8_t i;

    if (pause_menu_state == PAUSE_STATE_OPENING) {
        for (i = 0; i < MENU_STEP_ROWS && menu_shown_row < MENU_H; i++) {
            menu_draw_row(menu_shown_row++);
        }
        if (menu_shown_row >= MENU_H) pause_menu_state = PAUSE_STATE_READY;
    } else if (pause_menu_state == PAUSE_STATE_READY) {
        if (menu_dirty) {
            for (i = 0; i < MENU_H; i++) {
                uint16_t bit = (uint16_t)(1u << i);
                if (menu_dirty & bit) {
                    menu_draw_row(i);
                    menu_dirty &= (uint16_t)~bit;
                }
            }
        }
    } else if (pause_menu_state == PAUSE_STATE_CLOSING) {
        for (i = 0; i < MENU_STEP_ROWS && menu_restore_next < MENU_H; i++) {
            menu_restore_row(menu_restore_next++);
        }
        if (menu_restore_next >= MENU_H) {
            pause_menu_state = PAUSE_STATE_CLOSED;
            return 1;
        }
    }

    return 0;
}

uint8_t pause_menu_update(uint8_t pad, uint8_t prev, uint8_t *warp_level) BANKED
{
    uint8_t edge = (uint8_t)(pad & (uint8_t)~prev);
    uint8_t old_sel;
    uint8_t dir = 0;

    if (pause_menu_state == PAUSE_STATE_CLOSED ||
        pause_menu_state == PAUSE_STATE_CLOSING) {
        return PAUSE_ACTION_NONE;
    }

    /* Start and B close/resume at every stage of the menu. */
    if (edge & (J_START | J_B)) return PAUSE_ACTION_CLOSE;

    if (pause_menu_state != PAUSE_STATE_READY || menu_dirty) {
        return PAUSE_ACTION_NONE;
    }

    /* Up/down selects an item; the selection wraps. */
    old_sel = menu_sel;
    if (edge & J_UP) {
        menu_sel = (menu_sel == 0) ? (MENU_ITEM_COUNT - 1) : (uint8_t)(menu_sel - 1);
    } else if (edge & J_DOWN) {
        menu_sel = (menu_sel + 1 >= MENU_ITEM_COUNT) ? 0 : (uint8_t)(menu_sel + 1);
    }
    if (menu_sel != old_sel) {
        menu_dirty |= (uint16_t)(1u << menu_item_row[old_sel]);
        menu_dirty |= (uint16_t)(1u << menu_item_row[menu_sel]);
        /* Do not let a held left/right immediately adjust the level while
         * the player is only moving the selection onto WARP. */
        if (menu_sel == MENU_ITEM_WARP) menu_repeat = MENU_REPEAT_FRAMES;
    }

    /* Only the WARP row reacts to left/right.  A fresh press changes the
     * level immediately; holding it repeats after MENU_REPEAT_FRAMES. */
    if (menu_sel == MENU_ITEM_WARP) {
        uint8_t lr = (uint8_t)(pad & (J_LEFT | J_RIGHT));
        uint8_t lr_prev = (uint8_t)(prev & (J_LEFT | J_RIGHT));

        if (lr != lr_prev) {
            if (pad & J_RIGHT) dir = 1;
            else if (pad & J_LEFT) dir = 2;
            menu_repeat = MENU_REPEAT_FRAMES;
        } else if (lr) {
            if (menu_repeat == 0) {
                if (pad & J_RIGHT) dir = 1;
                else dir = 2;
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

    if (dir) {
        uint8_t old_level = menu_level;

        if (dir == 1) {
            if (menu_level < menu_max_level) menu_level++;
        } else {
            if (menu_level > 1) menu_level--;
        }
        if (menu_level != old_level) {
            menu_dirty |= (uint16_t)(1u << MENU_WARP_ROW);
        }
    }

    *warp_level = menu_level;

    if (edge & J_A) {
        if (menu_sel == MENU_ITEM_WARP) return PAUSE_ACTION_WARP;
        if (menu_sel == MENU_ITEM_RESTART) return PAUSE_ACTION_RESTART;
        return PAUSE_ACTION_EXIT;
    }

    return PAUSE_ACTION_NONE;
}
