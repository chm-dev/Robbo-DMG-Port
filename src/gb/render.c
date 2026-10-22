#include <gb/gb.h>
#include <stdint.h>

#include "render.h"
#include "../core/game.h"
#include "../gen/tiles.h"

#define MAP_METAROWS 16

static uint8_t map_row_level[MAP_METAROWS];

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

uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra)
{
    if (IS_WALL(type)) return MT_WALL;

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
        case CT_TELEPORT:   return MT_TELEPORT_0 + (anim_slow & 1);
        case CT_MUSTACHE:   return MT_MUSTACHE_0 + (anim_frame & 1);
        case CT_BUTTERFLY:  return MT_BUTTERFLY_0 + (anim_frame & 1);
        case CT_BEAR:       return ((extra & 4) ? MT_BEAR_2 : MT_BEAR_0) + (anim_frame & 1);
        case CT_LAVA:       return MT_LAVA_0;
        case CT_MAGNET:     return (extra & 2) ? MT_MAGNET_1 : MT_MAGNET_0;
        case CT_ROBBO:      return MT_ROBBO_0 + robbo_mt_base[extra & 3] +
                                   (robbo_step_anim & 1);
        case CT_BULLET: {
            uint8_t dir = extra & 3;
            return MT_BULLET_0 + (uint8_t)((dir & 1) * 2) + (anim_slow & 1);
        }
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

    for (x = 0; x < MAP_W; x++) {
        uint8_t mt;
        if (level_y < level_height) {
            uint16_t idx = level_y * MAP_W + x;
            mt = render_metatile_for_cell(map_type[idx], map_extra[idx]);
        } else {
            mt = MT_EMPTY;
        }
        draw_metatile(mt, x * 2, map_row * 2);
    }
    map_row_level[map_row] = level_y;
}

void render_apply_camera(void)
{
    SCX_REG = (uint8_t)(cam_x * 16);
    /* The HUD window covers the bottom 16px, so the top of the screen is the
     * first visible map row. */
    SCY_REG = (uint8_t)((cam_y & (MAP_METAROWS - 1)) * 16);
}

static void vbl_isr(void)
{
    render_apply_camera();
}

void render_init(void)
{
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
        SWITCH_ROM_MBC5(1);
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
}

void render_level(void)
{
    uint8_t row;

    for (row = 0; row < DIRTY_WORDS; row++) dirty_bits[row] = 0;
    dirty_any = 0;

    for (row = 0; row < MAP_METAROWS; row++) {
        draw_level_row(row, row);
    }

    render_hud();
}

void render_hud(void)
{
    uint8_t win[40];
    uint8_t g, i, x;
    uint8_t values[4];
    uint8_t icons[4] = {
        MT_HUD_SCREW, MT_HUD_AMMO, MT_HUD_KEY, MT_HUD_PLANET
    };

    for (i = 0; i < 40; i++) win[i] = hud_bg_tile;

    if (screws_left > 99) values[0] = 99; else values[0] = screws_left;
    if (ammo > 99) values[1] = 99; else values[1] = ammo;
    if (keys > 99) values[2] = 99; else values[2] = keys;
    values[3] = level_planet;

    for (g = 0; g < 4; g++) {
        const uint8_t *icon = &metatile_tiles[icons[g] * 4];
        uint8_t tens = (values[g] / 10) % 10;
        uint8_t ones = values[g] % 10;

        /* First item is flush left and last item is flush right; the two
         * spare columns are distributed between the inner gaps. */
        static const uint8_t hud_x[4] = { 0, 5, 11, 16 };
        x = hud_x[g];
        win[x] = icon[0];
        win[x + 1] = icon[1];
        win[20 + x] = icon[2];
        win[20 + x + 1] = icon[3];

        win[x + 2] = digit_tiles[tens][0];
        win[20 + x + 2] = digit_tiles[tens][1];
        win[x + 3] = digit_tiles[ones][0];
        win[20 + x + 3] = digit_tiles[ones][1];
    }

    set_win_tiles(0, 0, 20, 2, win);
}

void render_flash_set(uint8_t on)
{
    /* Background is shade 1 now; map only that shade to white so walls stay
     * dark during the last-bolt flash. */
    BGP_REG = on ? 0xE0 : 0xE4;
}

void render_sync_rows(void)
{
    uint8_t i;
    for (i = 0; i < VIEW_ROWS; i++) {
        uint8_t level_y = cam_y + i;
        uint8_t map_row = level_y & (MAP_METAROWS - 1);
        if (map_row_level[map_row] != level_y) {
            draw_level_row(level_y, map_row);
        }
    }
}

static void draw_cell_now(uint8_t x, uint8_t y)
{
    uint8_t map_row = y & (MAP_METAROWS - 1);
    uint16_t idx;

    if (map_row_level[map_row] != y) return;
    idx = (uint16_t)y * MAP_W + x;
    draw_metatile(render_metatile_for_cell(map_type[idx], map_extra[idx]),
                  x * 2, map_row * 2);
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

void render_camera(void)
{
    uint8_t max_x = MAP_W - VIEW_COLS;
    uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;

    if (cam_override) {
        /* Teleport: pan one cell every other frame toward the arrival area. */
        if (cam_pan_timer < 2) {
            cam_pan_timer++;
            return;
        }
        cam_pan_timer = 0;

        if (cam_x < cam_target_x) cam_x++;
        else if (cam_x > cam_target_x) cam_x--;
        if (cam_y < cam_target_y) cam_y++;
        else if (cam_y > cam_target_y) cam_y--;
        return;
    }

    if (robbo_x < cam_x + 2) {
        cam_x = (robbo_x >= 2) ? (robbo_x - 2) : 0;
    } else if (robbo_x > cam_x + 7) {
        cam_x = robbo_x - 7;
    }
    if (cam_x > max_x) cam_x = max_x;

    if (robbo_y < cam_y + 2) {
        cam_y = (robbo_y >= 2) ? (robbo_y - 2) : 0;
    } else if (robbo_y > cam_y + 5) {
        cam_y = robbo_y - 5;
    }
    if (cam_y > max_y) cam_y = max_y;
}
