#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "render.h"
#include "color.h"
#include "variants.h"
#include "../core/game.h"
#include "../gen/tiles.h"

#define MAP_METAROWS RENDER_RING_ROWS
#ifndef NINTENDO_NES
/* Rows kept current on each side of the 8-row view.  A sub-cell scroll shows
 * at most 9 rows; the margin gives ~32px of lead so a row is already resident
 * before it can scroll into view (the risky direction is upwards). */
#define CAM_MARGIN 2
#endif

uint8_t map_row_level[RENDER_RING_ROWS];

#ifdef NINTENDO_NES
/* NES playfield ring: 15 metarows = 240 px, stored in nametable 0 with the
 * hardware vertical wrap.  The HUD lives in nametable 1 (see
 * platform_compat.c) and is selected by the scanline split below. */
#define NES_HUD_LINE 32      /* 4 tile rows: pad, HUD, HUD, pad */
#define NES_SPLIT_SCANLINE (NES_HUD_LINE - 1)
/* Packed NES attribute shadow for the ring (8 bytes per 32x32 attribute
 * row).  We own this because GBDK's 16x16 API cannot express a half-row
 * update without clobbering the neighbouring metarow. */
static uint8_t nes_attr_shadow[8 * 8];
static uint8_t nes_split_bkg;
#endif

/* Dirty-cell bitmap (one bit per map cell).  Insertion is O(1); the old
 * 64-entry list cost a linear de-dup scan per mark and silently dropped
 * updates past 64 during large cascades. */
#define DIRTY_WORDS ((MAP_CELLS + 7) / 8)
static uint8_t dirty_bits[DIRTY_WORDS];
static uint8_t dirty_any;

static const uint8_t turret_mt[4] = {
    MT_TURRET_R, MT_TURRET_D, MT_TURRET_L, MT_TURRET_U
};
/* Source sprite order is [direction * 2 + step]: right, down, left, up. */
static const uint8_t robbo_mt_base[4] = { 0, 2, 4, 6 };

uint8_t render_robbo_spawn;

uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra)
{
    if (IS_WALL(type)) {
        /* Slot 5 is the fixed black cave fill; every visible wall uses the
         * single dynamic metatile loaded for the current four-level block. */
        return (WALL_SLOT(type) == 5) ? MT_WALL_CAVE : MT_WALL;
    }

    switch (type) {
        case CT_EMPTY:      return MT_EMPTY;
        case CT_GROUND:     return MT_GROUND;
        case CT_STONE:      return MT_STONE;
        case CT_PUSHABLE:   return MT_PUSHABLE;
        case CT_DOOR:       return MT_DOOR;
        case CT_SPACESHIP:
            if (screws_left == 0 || (extra & 1)) {
                return (anim_slow & 1) ? MT_SPACESHIP_1 : MT_SPACESHIP_0;
            }
            return MT_SPACESHIP_0;
        case CT_QUESTION:   return MT_QUESTION;
        case CT_BOMB:       return MT_BOMB;
        case CT_KEY:        return MT_KEY;
        case CT_SCREW:      return MT_SCREW;
        case CT_AMMO:       return MT_AMMO;
        case CT_TURRET:     return turret_mt[extra & 3];
        case CT_TELEPORT:
            if (color_on) {
                /* CGB frame 0 uses the variant whose middle block is black
                 * instead of blue; the ring stays blue in both frames. */
                return (anim_slow & 1) ? MT_TELEPORT_1 : MT_TELEPORT_CGB;
            }
            return (uint8_t)(MT_TELEPORT_0 + (anim_slow & 1));
        case CT_MUSTACHE:   return MT_MUSTACHE_0 + (anim_frame & 1);
        case CT_BUTTERFLY:  return MT_BUTTERFLY_0 + (anim_frame & 1);
        case CT_BEAR:       return ((extra & 4) ? MT_BEAR_2 : MT_BEAR_0) + (anim_frame & 1);
        case CT_LAVA:       return MT_LAVA_0;
        case CT_EXTRA_LIFE: return MT_EMPTY;  /* hidden easter egg */
        case CT_MAGNET:     return (extra & 2) ? MT_MAGNET_1 : MT_MAGNET_0;
        case CT_ROBBO:
            if (render_robbo_spawn == 1) return MT_SPACESHIP_0;
            if (render_robbo_spawn >= 2) {
                return (uint8_t)(MT_EXPLOSION_0 + (render_robbo_spawn - 2));
            }
            return MT_ROBBO_0 + robbo_mt_base[extra & 3] +
                   (robbo_step_timer ? 1 : 0);
        case CT_BULLET: {
            uint8_t dir = extra & 3;
            if (((extra >> 2) & 3) == 2) return MT_BLASTER;
            return MT_BULLET_0 + (uint8_t)((dir & 1) * 2) + (anim_slow & 1);
        }
        case CT_BARRIER:    return MT_BARRIER_0 + (anim_slow & 1);
        case CT_EXPLOSION: {
            uint8_t t = extra & 7;
            uint8_t frame;
            if (t > 5) t = 5;
            frame = (t >= 3) ? (uint8_t)(6 - t) : t;
            return MT_EXPLOSION_0 + frame;
        }
        default:            return MT_EMPTY;
    }
}

static uint8_t empty_tile(void)
{
    return metatile_tiles[MT_EMPTY * 4];
}

/* Attribute byte for one map cell.  All walls share the single dynamic wall
 * metatile; the Atari normal-palette variant (glyph $00) is the same tile
 * drawn with the level's *normal* palette instead of the inverse wall palette,
 * exactly like the GBC (state 9 -> palette 0).  CGB only - the DMG path never
 * publishes attributes, so both variants look identical there. */
uint8_t render_cell_palette(uint8_t type, uint8_t extra, uint8_t mt)
{
#ifdef NINTENDO_NES
    /* Phase 2 still runs the temporary grayscale palette: every playfield
     * cell uses BG slot 0.  Phase 3 maps NORMAL/WALL/CAVE/UI onto the four
     * NES slots and replaces this with the real attribute value. */
    (void)type;
    (void)extra;
    (void)mt;
    return COLOR_PAL_NORMAL;
#else
    if (IS_WALL(type) && (extra & WALL_EXTRA_NORMAL)) return COLOR_PAL_NORMAL;
    return COLOR_MT_PAL(mt);
#endif
}

static void draw_metatile(uint8_t mt, uint8_t tx, uint8_t ty)
{
    /* One library copy for the whole 2x2 metatile.  set_bkg_tile_xy() per
     * tile is ~400 cycles each here; this keeps the tested address path but
     * makes the cost a single call. */
    const uint8_t *t = &metatile_tiles[mt << 2];
    set_bkg_tiles(tx, ty, 2, 2, t);
}

static void draw_level_row(uint8_t level_y, uint8_t map_row)
{
    uint8_t x;

#ifdef NINTENDO_NES
    static uint8_t row_tiles[64];
    static uint8_t row_pals[16];
    uint8_t attr_row = (uint8_t)(map_row >> 1);
    uint8_t shift = (uint8_t)((map_row & 1) ? 4 : 0);
    uint8_t *a = &nes_attr_shadow[(uint16_t)attr_row * 8];

    for (x = 0; x < MAP_W; x++) {
        uint8_t mt;
        uint8_t type = CT_EMPTY;
        uint8_t extra = 0;
        const uint8_t *t;

        if (level_y < level_height) {
            uint16_t idx = (uint16_t)level_y * MAP_W + x;
            type = map_type[idx];
            extra = map_extra[idx];
        }
        mt = render_metatile_for_cell(type, extra);
        t = &metatile_tiles[(uint16_t)mt << 2];
        row_tiles[(uint8_t)(x << 1)] = t[0];
        row_tiles[(uint8_t)(x << 1) + 1] = t[1];
        row_tiles[32 + (uint8_t)(x << 1)] = t[2];
        row_tiles[32 + (uint8_t)(x << 1) + 1] = t[3];
        row_pals[x] = render_cell_palette(type, extra, mt);
    }

    /* One packed attribute byte covers two metatiles in this row.  The other
     * metarow in the 32x32 block keeps its bits from the shadow. */
    for (x = 0; x < 8; x++) {
        uint8_t p0 = row_pals[(uint8_t)(x << 1)];
        uint8_t p1 = row_pals[(uint8_t)(x << 1) + 1];
        uint8_t packed = (uint8_t)((p0 | (uint8_t)(p1 << 2)) << shift);
        a[x] = (uint8_t)((a[x] & (uint8_t)~(0x0Fu << shift)) | packed);
    }

    set_bkg_tiles(0, (uint8_t)(map_row << 1), 32, 2, row_tiles);
    set_bkg_attributes(0, (uint8_t)(attr_row << 2), 32, 4, a);
    map_row_level[map_row] = level_y;
#else
    static uint8_t row_pal[MAP_W * 2];

    for (x = 0; x < MAP_W; x++) {
        uint8_t mt;
        uint8_t type = CT_EMPTY;
        uint8_t extra = 0;
        if (level_y < level_height) {
            uint16_t idx = (uint16_t)level_y * MAP_W + x;
            type = map_type[idx];
            extra = map_extra[idx];
            mt = render_metatile_for_cell(type, extra);
        } else {
            mt = MT_EMPTY;
        }
        draw_metatile(mt, x * 2, map_row * 2);
        row_pal[x * 2] = row_pal[x * 2 + 1] =
            render_cell_palette(type, extra, mt);
    }
    map_row_level[map_row] = level_y;
    if (color_on) color_row_attr(map_row, row_pal);
#endif
}


#ifdef NINTENDO_NES
/* Ring scroll: position of the view's first cell inside the 240 px ring,
 * plus the sub-cell offset.  Row r always lives in slot r % 15. */
static void nes_update_ring_scroll(void)
{
    uint8_t cell = (uint8_t)(cam_qy >> 8);
    uint8_t sub = (uint8_t)((cam_qy >> 4) & 15);
    uint8_t slot = cell;
    uint8_t ring;

    while (slot >= RENDER_RING_ROWS) slot = (uint8_t)(slot - RENDER_RING_ROWS);
    ring = (uint8_t)((uint16_t)slot * 16u + sub);

    cam_x = 0;
    cam_scx = 0;
    cam_y = cell;
    cam_scy = ring;

    /* The playfield starts NES_HUD_LINE px below the top of the screen.
     * GBDK's LCD handler adds the split scanline to bkg_scroll_y and wraps
     * at 240.  bkg_scroll_y is therefore the GB-style layer offset: setting
     * it to (ring - NES_HUD_LINE) makes the NMI write the absolute scroll
     * value `ring`, so scanline 32 shows the ring row `cam_y` exactly. */
    {
        uint16_t v = (uint16_t)ring + (240u - NES_HUD_LINE);
        if (v >= 240u) v = (uint16_t)(v - 240u);
        nes_split_bkg = (uint8_t)v;
    }
}
#endif

void render_apply_camera(void)
{
#ifdef NINTENDO_NES
    nes_update_ring_scroll();
#else
    SCX_REG = cam_scx;
    /* SCY wraps modulo 256 (the ring is 16 metatile rows). */
    SCY_REG = cam_scy;
#endif
}


/* Port of robbo-gbc's camera_ease(): move 1/8 of the remaining distance,
 * with a 3 px/frame cap.  Q4 units give the same sub-pixel settle as GBC. */
static uint16_t cam_ease_step(uint16_t cur, uint16_t tgt)
{
    uint16_t dist, step;

    if (cur == tgt) return cur;
    dist = (cur < tgt) ? (uint16_t)(tgt - cur) : (uint16_t)(cur - tgt);
    step = (uint16_t)((dist + 7) >> 3);
    if (step > 48) step = 48;
    return (cur < tgt) ? (uint16_t)(cur + step) : (uint16_t)(cur - step);
}

#ifdef NINTENDO_NES
/* VBL: ease the camera, then publish the stationary HUD at the top of the
 * frame.  The LCD handler below switches to the playfield at NES_HUD_LINE.
 * Both handlers only touch GBDK's shadow registers; the NMI applies them. */
static void vbl_isr(void)
{
    if (cam_smooth) {
        cam_qx = cam_ease_step(cam_qx, (uint16_t)((uint16_t)cam_goal_x << 8));
        cam_qy = cam_ease_step(cam_qy, (uint16_t)((uint16_t)cam_goal_y << 8));
    }

    nes_update_ring_scroll();

    bkg_scroll_x = 0;
    bkg_scroll_y = 0;
    if (nes_hud_enabled) {
        shadow_PPUCTRL |= 0x01;     /* base nametable 1 (HUD) */
    } else {
        shadow_PPUCTRL &= (uint8_t)~0x01;
    }
}

static void nes_lcd_isr(void)
{
    if (nes_hud_enabled) {
        shadow_PPUCTRL &= (uint8_t)~0x01;   /* base nametable 0 (playfield) */
        bkg_scroll_x = 0;
        bkg_scroll_y = nes_split_bkg;
    } else {
        bkg_scroll_y = 0;
    }
}
#else
/* Only the VBlank handler advances and applies the camera.  Main publishes
 * cell-aligned goals atomically, so SCX/SCY never change mid-frame. */
static void vbl_isr(void)
{
    if (cam_smooth) {
        cam_qx = cam_ease_step(cam_qx, (uint16_t)((uint16_t)cam_goal_x << 8));
        cam_qy = cam_ease_step(cam_qy, (uint16_t)((uint16_t)cam_goal_y << 8));
        cam_scx = (uint8_t)(cam_qx >> 4);
        cam_scy = (uint8_t)(cam_qy >> 4);
        cam_x = (uint8_t)(cam_qx >> 8);
        cam_y = (uint8_t)(cam_qy >> 8);
    }
    render_apply_camera();
}
#endif


void render_init(void)
{
#ifdef NINTENDO_NES
    uint8_t empty = empty_tile();

    /* The display is already off: GBDK writes tiles and the nametable
     * directly.  NT0 is the playfield ring; NT1 holds the stationary HUD. */
    {
        SWITCH_ROM_MBC5(8);
        set_bkg_data(0, TILESET_COUNT, tileset_data);
        SWITCH_ROM_MBC5(0);
    }

    fill_bkg_rect(0, 0, 32, 30, empty);
    nes_hud_fill();

    _lcd_scanline = NES_SPLIT_SCANLINE;

    add_VBL(vbl_isr);
    add_LCD(nes_lcd_isr);
    set_interrupts(VBL_IFLAG | LCD_IFLAG);

    /* NES: install the temporary grayscale palette (no-op on GB). */
    platform_palette_init();
#else
    uint8_t buf[32];
    uint8_t x, y;
    uint8_t empty = empty_tile();

    BGP_REG = 0xE4;
    SCX_REG = 0;
    SCY_REG = 0;

    /* Select the 0x8000 tile-data base BEFORE copying tiles: GBDK's
     * set_bkg_data() writes according to the current LCDC tile-data mode. */
    LCDC_REG = LCDCF_WIN9C00 | LCDCF_BG8000 | LCDCF_BGON;

    {
        SWITCH_ROM_MBC5(8);
        set_bkg_data(0, TILESET_COUNT, tileset_data);
        SWITCH_ROM_MBC5(0);
    }

    for (x = 0; x < 32; x++) buf[x] = empty;
    for (y = 0; y < 32; y++) {
        set_bkg_tiles(0, y, 32, 1, buf);
    }

    for (x = 0; x < 20; x++) buf[x] = empty;
    for (y = 0; y < 2; y++) {
        set_win_tiles(0, y, 20, 1, buf);
    }

    /* HUD sits in the bottom 16px of the 144px screen. */
    move_win(6, 128);

    LCDC_REG |= LCDCF_ON | LCDCF_WINON;

    add_VBL(vbl_isr);
    set_interrupts(VBL_IFLAG);
#endif
}


void render_restore_tiles(void)
{
    /* The title screen loads its own font/logo over the gameplay tiles.
     * Re-copy the full active set before rebuilding a level.  Must stay in
     * bank 0: a banked function cannot switch to bank 8 and keep executing. */
    SWITCH_ROM_MBC5(8);
    set_bkg_data(0, TILESET_COUNT, tileset_data);
    SWITCH_ROM_MBC5(0);
    /* The title/ending overwrote the active tiles; the object variants are
     * gone too, so the next level load starts from the base set. */
    variants_reset();
}

/* Set by render_set_level_palette(); the wall loader needs it. */
static uint8_t level_palette;

void render_set_wall_style(uint8_t cell)
{
    /* Load one 16x16 wall cell from bank 8 into the reserved four-tile slot.
     * game_load_level() calls this while the display is off.
     * Palette 1 (level 2, 6, ...) swaps the wall's white/light-gray shades;
     * the other DMG palettes and CGB keep the sheet's original wall art.
     * NES colours are not ported yet (phase 3), so it always uses the base
     * sheet art. */
#ifdef NINTENDO_NES
    sheet_load_metatile(cell, WALL_TILE_BASE);
#else
    if (!color_on && level_palette == 1) {
        sheet_load_metatile_swap02(cell, WALL_TILE_BASE);
    } else {
        sheet_load_metatile(cell, WALL_TILE_BASE);
    }
#endif
}


/* Keep the dirty bitmap clear while the intro owns the screen.  The death
 * wipe may leave cells queued; flushing them after the map reload would reveal
 * restored items before their column is painted. */
void render_intro_clear_dirty(void)
{
    uint8_t i;
    for (i = 0; i < DIRTY_WORDS; i++) dirty_bits[i] = 0;
    dirty_any = 0;
}

/* render_hud() lives in hud.c (bank 10). */

/* One palette per level inside a four-level wall block.  Shade 0 may become
 * white or light gray (never dark gray/black), so Robbo always stays bright:
 *   normal, rotated (white->light gray), black background, white background. */
static const uint8_t level_bgp[4] = { 0xE4, 0xC9, 0x9C, 0xE1 };

void render_set_level_palette(uint8_t level)
{
    level_palette = (uint8_t)((level - 1) & 3);
    BGP_REG = level_bgp[level_palette];
    color_level_pal(level);
}

uint8_t render_level_background(void)
{
    /* CGB uses the authentic per-level palette, where object colours already
     * contrast with the floor: the DMG shade-shift tile variants are not
     * needed.  NES uses the same base art until phase 3 adds its palettes.
     * Value 4 matches no variant condition in game.c. */
#ifdef NINTENDO_NES
    return 4;
#else
    if (color_on) return 4;
    return (uint8_t)((level_bgp[level_palette] >> 2) & 3);
#endif
}

void render_flash_set(uint8_t on)
{
    /* Flash only the background shade: white on every floor except pure
     * white, which flashes black.  All other shades stay as-is. */
    uint8_t bgp = level_bgp[level_palette];
    if (on) {
        uint8_t bg = (uint8_t)((bgp >> 2) & 3);
        uint8_t flash = (uint8_t)((bg == 0) ? 3 : 0);
        bgp = (uint8_t)((bgp & (uint8_t)~0x0Cu) | (uint8_t)(flash << 2));
    }
    BGP_REG = bgp;
    color_flash(on);
}

uint8_t render_sync_rows(void)
{
#ifdef NINTENDO_NES
    uint8_t i;
    uint8_t slot;
    uint8_t level_y;
    uint8_t extra_slot = render_ring_slot((uint8_t)(cam_y + 14));
    uint8_t extra_row;
    uint8_t moving_up = (nes_pan_dir == 3) ||
        (nes_pan_dir == 0 && cam_goal_y < cam_y);

    if (nes_pan_dir == 1) moving_up = 0;

    /* The off-screen ring slot is prefetched with the row we are about to
     * scroll into view: above when the camera is moving up, below otherwise.
     * It is never visible, so it can be repainted without a hold. */
    extra_row = moving_up
        ? (uint8_t)((cam_y > 0) ? (cam_y - 1) : 0xFF)
        : (uint8_t)(cam_y + 14);
    if (extra_row >= level_height) extra_row = 0xFF;

    if (map_row_level[extra_slot] != extra_row) {
        draw_level_row(extra_row, extra_slot);
        return 1;
    }

    /* Make sure every row of the visible 13-row view is resident.  Normally
     * only the prefetch above is needed; this loop repairs the ring after a
     * teleport or a direction change. */
    for (i = 0; i < VIEW_ROWS; i++) {
        level_y = (uint8_t)(cam_y + i);
        slot = render_ring_slot(level_y);
        if (map_row_level[slot] != level_y) {
            draw_level_row(level_y, slot);
            return 1;
        }
    }

    return 0;
#else
    uint8_t i;
    uint8_t first = (cam_y > CAM_MARGIN) ? (uint8_t)(cam_y - CAM_MARGIN) : 0;

    for (i = 0; i < (VIEW_ROWS + 2 * CAM_MARGIN); i++) {
        uint8_t level_y = (uint8_t)(first + i);
        uint8_t map_row = level_y & (MAP_METAROWS - 1);
        if (map_row_level[map_row] != level_y) {
            draw_level_row(level_y, map_row);
        }
    }
    return 0;
#endif
}


static void draw_cell_now(uint8_t x, uint8_t y)
{
    uint8_t map_row = render_ring_slot(y);
    uint8_t mt;
    uint16_t idx;

    if (map_row_level[map_row] != y) return;
    idx = (uint16_t)y * MAP_W + x;
    mt = render_metatile_for_cell(map_type[idx], map_extra[idx]);
    draw_metatile(mt, x * 2, map_row * 2);
#ifdef NINTENDO_NES
    {
        /* Keep the packed NES attribute shadow in sync and publish the whole
         * 32x32 attribute row (the two metarows of the block share a byte). */
        uint8_t pal = render_cell_palette(map_type[idx], map_extra[idx], mt);
        uint8_t attr_row = (uint8_t)(map_row >> 1);
        uint8_t shift = (uint8_t)((map_row & 1) ? 4 : 0);
        uint8_t *a = &nes_attr_shadow[(uint16_t)attr_row * 8];
        uint8_t byte = (uint8_t)(x >> 1);
        uint8_t bit = (uint8_t)(shift + ((x & 1) ? 2 : 0));

        a[byte] = (uint8_t)((a[byte] & (uint8_t)~(0x03u << bit)) |
                            (uint8_t)(pal << bit));
        set_bkg_attributes(0, (uint8_t)(attr_row << 2), 32, 4, a);
    }
#else
    if (color_on) {
        color_cell_attr((uint8_t)(x * 2), (uint8_t)(map_row * 2),
                        render_cell_palette(map_type[idx], map_extra[idx], mt));
    }
#endif
}

void render_cell(uint8_t x, uint8_t y)
{
    uint16_t idx = ((uint16_t)y << 4) | x;

    dirty_bits[idx >> 3] |= (uint8_t)(1u << (idx & 7));
    dirty_any = 1;
}

void render_flush_cells(void)
{
    uint8_t i, p;
    uint16_t idx;

    if (!dirty_any) return;
    dirty_any = 0;
    for (i = 0; i < DIRTY_WORDS; i++) {
        uint8_t b = dirty_bits[i];
        if (!b) continue;
        dirty_bits[i] = 0;
        for (p = 0; p < 8; p++) {
            if (!(b & (uint8_t)(1u << p))) continue;
            idx = (uint16_t)((i << 3) | p);
            draw_cell_now((uint8_t)(idx & 0x0F), (uint8_t)(idx >> 4));
        }
    }
}


