/* CGB colour support (bank 10).  On DMG every entry point is a no-op. */
#ifndef GB_COLOR_H
#define GB_COLOR_H

#include <gb/gb.h>
#include <stdint.h>

#include "../gen/tiles.h"

/* BG palette slots. */
#define COLOR_PAL_NORMAL  0   /* level normal palette */
#define COLOR_PAL_WALL    1   /* level inverse palette (COL3 outline) */
#define COLOR_PAL_CAVE    2   /* solid COLPF0 cave fill */
#define COLOR_PAL_UI      3   /* HUD, title text, pause menu */
#define COLOR_PAL_LOGO    4   /* title logo bevel */
#define COLOR_PAL_ENDING  5   /* ending scene and text */
#define COLOR_PAL_OBJ     6   /* inverse objects: crates, doors, teleports */

/* 1 when running on CGB hardware.  Read this in the render paths. */
extern uint8_t color_on;

/* Metatile -> palette slot (attribute byte value). */
#define COLOR_MT_PAL(mt) \
    (((mt) == MT_WALL || (mt) == MT_TELEPORT_0 || \
      (mt) == MT_TELEPORT_1) ? COLOR_PAL_WALL : \
     ((mt) == MT_WALL_CAVE) ? COLOR_PAL_CAVE : \
     ((mt) == MT_STONE || (mt) == MT_DOOR) ? COLOR_PAL_OBJ : \
     COLOR_PAL_NORMAL)

void color_init(void) BANKED;
void color_level_pal(uint8_t level) BANKED;
void color_flash(uint8_t on) BANKED;
void color_fill_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                      uint8_t pal) BANKED;
void color_fill_win_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                          uint8_t pal) BANKED;
void color_row_attr(uint8_t map_row, const uint8_t *pals) BANKED;
void color_cell_attr(uint8_t tx, uint8_t ty, uint8_t pal) BANKED;
void color_hud_attr(void) BANKED;

#endif
