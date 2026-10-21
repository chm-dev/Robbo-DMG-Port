#include <gb/gb.h>
#include <stdint.h>

#include "render.h"
#include "../core/game.h"
#include "../gen/tiles.h"

#define MAP_METAROWS 16
#define HUD_X 0
#define MAX_DIRTY 64

static uint8_t map_row_level[MAP_METAROWS];

static uint16_t dirty_cells[MAX_DIRTY];
static uint8_t dirty_count;

static const uint8_t turret_mt[4] = {
    MT_TURRET_R, MT_TURRET_D, MT_TURRET_L, MT_TURRET_U
};
static const uint8_t bullet_mt[4] = {
    MT_BULLET_0,  /* right: horizontal */
    MT_BULLET_2,  /* down: vertical */
    MT_BULLET_1,  /* left: horizontal */
    MT_BULLET_3   /* up: vertical */
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
        case CT_SPACESHIP:  return ((extra & 1) || screws_left == 0) ? MT_SPACESHIP_1 : MT_SPACESHIP_0;
        case CT_QUESTION:   return MT_QUESTION;
        case CT_BOMB:       return MT_BOMB;
        case CT_KEY:        return MT_KEY;
        case CT_SCREW:      return MT_SCREW;
        case CT_AMMO:       return MT_AMMO;
        case CT_TURRET:     return turret_mt[extra & 3];
        case CT_TELEPORT:   return MT_TELEPORT_0;
        /* Sprite animation is intentionally static for now; the second
         * frames remain available in the sheet for later use. */
        case CT_MUSTACHE:   return MT_MUSTACHE_0;
        case CT_BUTTERFLY:  return MT_BUTTERFLY_0;
        case CT_BEAR:       return (extra & 4) ? MT_BEAR_2 : MT_BEAR_0;
        case CT_LAVA:       return MT_LAVA_0;
        case CT_MAGNET:     return (extra & 2) ? MT_MAGNET_1 : MT_MAGNET_0;
        case CT_ROBBO:      return MT_ROBBO_0 + robbo_mt_base[extra & 3];
        case CT_BULLET:     return bullet_mt[extra & 3];
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
    const uint8_t *t = &metatile_tiles[mt * 4];
    set_bkg_tile_xy(tx, ty, t[0]);
    set_bkg_tile_xy(tx + 1, ty, t[1]);
    set_bkg_tile_xy(tx, ty + 1, t[2]);
    set_bkg_tile_xy(tx + 1, ty + 1, t[3]);
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

static void lcd_isr(void)
{
    /* The window covers the whole screen from WY down.  Turn it off as soon as
     * the 16px HUD has been drawn; the VBlank handler re-enables it. */
    if (LY_REG == 16) {
        LCDC_REG &= (uint8_t)~LCDCF_WINON;
    }
}

void render_apply_camera(void)
{
    SCX_REG = (uint8_t)(cam_x * 16);
    SCY_REG = (uint8_t)(((cam_y & (MAP_METAROWS - 1)) * 16) - 16);
}

static void vbl_isr(void)
{
    LCDC_REG |= LCDCF_WINON;
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

    move_win(7, 0);

    LCDC_REG |= LCDCF_ON | LCDCF_WINON;

    LYC_REG = 16;
    STAT_REG = STATF_LYC;
    add_LCD(lcd_isr);
    add_VBL(vbl_isr);
    set_interrupts(VBL_IFLAG | LCD_IFLAG);
}

void render_level(void)
{
    uint8_t row;

    dirty_count = 0;

    for (row = 0; row < MAP_METAROWS; row++) {
        draw_level_row(row, row);
    }

    render_hud();
}

void render_hud(void)
{
    uint8_t win[40];
    uint8_t g, i, x;
    uint8_t values[5];
    uint8_t icons[5] = {
        MT_HUD_SCREW, MT_HUD_AMMO, MT_HUD_KEY, MT_HUD_LIVES, MT_HUD_PLANET
    };

    for (i = 0; i < 40; i++) win[i] = empty_tile();

    if (screws_left > 99) values[0] = 99; else values[0] = screws_left;
    if (ammo > 99) values[1] = 99; else values[1] = ammo;
    if (keys > 99) values[2] = 99; else values[2] = keys;
    values[3] = 0;
    values[4] = level_planet;

    for (g = 0; g < 5; g++) {
        const uint8_t *icon = &metatile_tiles[icons[g] * 4];
        uint8_t tens = (values[g] / 10) % 10;
        uint8_t ones = values[g] % 10;

        x = HUD_X + g * 4;
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

void render_pause(void)
{
    uint8_t row0[20];
    uint8_t row1[20];
    const char *msg = "PAUSED";
    uint8_t i;

    for (i = 0; i < 20; i++) {
        row0[i] = empty_tile();
        row1[i] = empty_tile();
    }
    for (i = 0; msg[i]; i++) {
        row0[7 + i] = font_tiles[(uint8_t)msg[i]];
    }
    set_win_tiles(0, 0, 20, 1, row0);
    set_win_tiles(0, 1, 20, 1, row1);
}

void render_flash_set(uint8_t on)
{
    BGP_REG = on ? 0xC4 : 0xE4;
}

static void draw_bg_text(const char *text, uint8_t x, uint8_t y)
{
    while (*text) {
        uint8_t tile = font_tiles[(uint8_t)*text];
        if (tile != 0xFF) {
            set_bkg_tile_xy(x, y, tile);
        }
        x++;
        text++;
    }
}

void render_victory(void)
{
    uint8_t buf[32];
    uint8_t x, y;
    uint8_t empty = empty_tile();

    BGP_REG = 0xE4;
    SCX_REG = 0;
    SCY_REG = 0;

    for (x = 0; x < 32; x++) buf[x] = empty;
    for (y = 0; y < 32; y++) {
        set_bkg_tiles(0, y, 32, 1, buf);
    }
    for (x = 0; x < 20; x++) buf[x] = empty;
    set_win_tiles(0, 0, 20, 1, buf);
    set_win_tiles(0, 1, 20, 1, buf);

    draw_bg_text("CONGRATULATIONS", 2, 7);
    draw_bg_text("YOU WIN", 6, 9);
    draw_bg_text("PRESS START", 4, 11);
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
    uint8_t i;
    uint16_t idx = ((uint16_t)y << 8) | x;

    for (i = 0; i < dirty_count; i++) {
        if (dirty_cells[i] == idx) return;
    }
    if (dirty_count < MAX_DIRTY) {
        dirty_cells[dirty_count++] = idx;
    }
}

void render_flush_cells(void)
{
    uint8_t i;
    for (i = 0; i < dirty_count; i++) {
        draw_cell_now(dirty_cells[i] & 0xFF, dirty_cells[i] >> 8);
    }
    dirty_count = 0;
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
