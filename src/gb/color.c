/* CGB colour support.
 *
 * The DMG build keeps its shade-index renderer; on a Game Boy Color the same
 * tiles are drawn through per-cell BG palettes (VRAM bank 1 attributes) and
 * the authentic per-level Atari palettes.  The DMG path is untouched: every
 * entry point checks color_on and returns immediately on DMG hardware.
 *
 * Art-role index order (see gb/tools/gen_level_pal.py):
 *   0 = bright (Robbo, bolts), 1 = background, 2 = mid, 3 = dark outlines.
 *
 * Bank 10 also holds the generated level palette table.
 */
#pragma bank 10

#include <gb/gb.h>
#include <gb/cgb.h>
#include <stdint.h>

#include "color.h"
#include "../gen/level_pal.h"

BANKREF(color_init)

uint8_t color_on;

/* Current level palettes in art-index order, kept so the last-bolt flash can
 * swap the background entry and restore it without re-reading the table. */
static uint16_t pal_cur[12];

/* Fixed palettes: UI (HUD/title/pause), title logo, ending scene. */
static const uint16_t pal_ui[4]   = { 0x7FFF, 0x56B5, 0x294A, 0x0000 };
static const uint16_t pal_logo[4] = { 0x7FFF, 0x03FF, 0x029F, 0x0000 };
static const uint16_t pal_ending[4] = { 0x0000, 0x35AD, 0x6B5A, 0x7FFF };
/* Sprite entries (0 is transparent): 1 = dark, 2 = light, 3 = white. */
static const uint16_t pal_sprite[4] = { 0x0000, 0x35AD, 0x7FFF, 0x7FFF };

void color_init(void) BANKED
{
    /* _cpu is set by the GBDK runtime from the boot ROM's A register. */
    color_on = (uint8_t)(_cpu == CGB_TYPE);
    if (!color_on) return;

    set_bkg_palette(COLOR_PAL_UI, 1, (const palette_color_t *)pal_ui);
    set_bkg_palette(COLOR_PAL_LOGO, 1, (const palette_color_t *)pal_logo);
    set_bkg_palette(COLOR_PAL_ENDING, 1, (const palette_color_t *)pal_ending);
    set_sprite_palette(0, 1, (const palette_color_t *)pal_sprite);
}

void color_level_pal(uint8_t level) BANKED
{
    const uint16_t *src;
    uint8_t i;

    if (!color_on) return;
    if (level < 1) level = 1;
    if (level > LEVEL_PAL_COUNT) level = LEVEL_PAL_COUNT;

    src = level_pal_data[level - 1];
    for (i = 0; i < 4; i++) {
        pal_cur[i] = src[i];
        pal_cur[4 + i] = src[4 + i];
        /* Cave fill is solid COLPF0 = art index 3 of the normal palette. */
        pal_cur[8 + i] = src[3];
    }
    /* Palettes 0..2 are contiguous: normal, walls, cave fill. */
    set_bkg_palette(0, 3, (const palette_color_t *)pal_cur);
}

/* Last-bolt flash: the DMG build swaps the background shade (BGP 0xE0).
 * On CGB the same effect rewrites palette entry 1 (the background role) of
 * the two playfield palettes. */
void color_flash(uint8_t on) BANKED
{
    static uint16_t pal_flash[8];
    uint16_t flash;
    uint8_t i;

    if (!color_on) return;
    if (!on) {
        set_bkg_palette(0, 2, (const palette_color_t *)pal_cur);
        return;
    }

    flash = (pal_cur[1] == 0x7FFF) ? 0x0000 : 0x7FFF;
    for (i = 0; i < 4; i++) {
        pal_flash[i] = pal_cur[i];
        pal_flash[4 + i] = pal_cur[4 + i];
    }
    pal_flash[1] = flash;
    pal_flash[5] = flash;
    set_bkg_palette(0, 2, (const palette_color_t *)pal_flash);
}

/* Fill a rectangle of BG attributes (VRAM bank 1).  Used by the title,
 * ending and level-entry paths; the gameplay row/cell writers set attributes
 * inline in render.c. */
void color_fill_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                      uint8_t pal) BANKED
{
    uint8_t buf[32];
    uint8_t i;

    if (!color_on) return;
    if (w > 32) w = 32;
    for (i = 0; i < w; i++) buf[i] = pal;
    for (i = 0; i < h; i++) {
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles(x, (uint8_t)(y + i), w, 1, buf);
        VBK_REG = VBK_TILES;
    }
}

void color_fill_win_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                          uint8_t pal) BANKED
{
    uint8_t buf[32];
    uint8_t i;

    if (!color_on) return;
    if (w > 32) w = 32;
    for (i = 0; i < w; i++) buf[i] = pal;
    for (i = 0; i < h; i++) {
        VBK_REG = VBK_ATTRIBUTES;
        set_win_tiles(x, (uint8_t)(y + i), w, 1, buf);
        VBK_REG = VBK_TILES;
    }
}

/* Publish one metatile row's attributes: 32 palette bytes (2 per cell) are
 * duplicated into the two 8x8 tile rows of the ring. */
void color_row_attr(uint8_t map_row, const uint8_t *pals) BANKED
{
    static uint8_t buf[64];
    uint8_t i;

    if (!color_on) return;
    for (i = 0; i < 32; i++) {
        buf[i] = pals[i];
        buf[32 + i] = pals[i];
    }
    set_bkg_attributes(0, (uint8_t)(map_row * 2), 32, 2, buf);
}

void color_cell_attr(uint8_t tx, uint8_t ty, uint8_t pal) BANKED
{
    uint8_t a[4];

    a[0] = a[1] = a[2] = a[3] = pal;
    set_bkg_attributes(tx, ty, 2, 2, a);
}

void color_hud_attr(void) BANKED
{
    uint8_t buf[40];
    uint8_t i;

    for (i = 0; i < 40; i++) buf[i] = COLOR_PAL_UI;
    VBK_REG = VBK_ATTRIBUTES;
    set_win_tiles(0, 0, 20, 2, buf);
    VBK_REG = VBK_TILES;
}
