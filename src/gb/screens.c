/* Low-frequency screens kept out of the full bank 0. */
#pragma bank 9

#include <gb/gb.h>
#include <stdint.h>

#include "../gen/tiles.h"
#include "render.h"

static uint8_t screen_empty_tile(void)
{
    return metatile_tiles[MT_EMPTY * 4];
}

void render_pause(void) BANKED
{
    uint8_t row0[20];
    uint8_t row1[20];
    const char *msg = "PAUSED";
    uint8_t i;
    uint8_t empty = screen_empty_tile();

    for (i = 0; i < 20; i++) {
        row0[i] = empty;
        row1[i] = empty;
    }
    for (i = 0; msg[i]; i++) {
        row0[7 + i] = font_tiles[(uint8_t)msg[i]];
    }
    set_win_tiles(0, 0, 20, 1, row0);
    set_win_tiles(0, 1, 20, 1, row1);
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

void render_victory(void) BANKED
{
    uint8_t buf[32];
    uint8_t x, y;
    uint8_t empty = screen_empty_tile();

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
