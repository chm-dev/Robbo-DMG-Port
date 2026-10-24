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
