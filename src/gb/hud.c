/* HUD window renderer.
 *
 * Banked out of bank 0 (which is nearly full) and paired with the CGB
 * attribute write for the same 20x2 window.
 */
#pragma bank 10

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "render.h"
#include "color.h"
#include "../core/game.h"
#include "../gen/tiles.h"

void render_hud(void) BANKED
{
#ifdef NINTENDO_NES
    uint8_t win[64];
    uint8_t g, i, x;
    uint8_t values[4];
    uint8_t icons[4] = {
        MT_HUD_SCREW, MT_HUD_AMMO, MT_HUD_KEY, MT_HUD_PLANET
    };
    /* Four groups evenly spread across the 32-tile NES HUD: first flush
     * left, last flush right, gaps equalised. */
    static const uint8_t hud_x_nes[4] = { 0, 9, 19, 28 };

    for (i = 0; i < 64; i++) win[i] = hud_bg_tile;

    if (screws_left > 99) values[0] = 99; else values[0] = screws_left;
    if (ammo > 99) values[1] = 99; else values[1] = ammo;
    if (keys > 99) values[2] = 99; else values[2] = keys;
    values[3] = level_planet;

    for (g = 0; g < 4; g++) {
        const uint8_t *icon = &metatile_tiles[(uint16_t)icons[g] * 4];
        uint8_t tens = (uint8_t)((values[g] / 10) % 10);
        uint8_t ones = (uint8_t)(values[g] % 10);

        x = hud_x_nes[g];
        win[x] = icon[0];
        win[x + 1] = icon[1];
        win[32 + x] = icon[2];
        win[32 + x + 1] = icon[3];

        win[x + 2] = digit_tiles[tens][0];
        win[32 + x + 2] = digit_tiles[tens][1];
        win[x + 3] = digit_tiles[ones][0];
        win[32 + x + 3] = digit_tiles[ones][1];
    }

    nes_hud_write(win);
    nes_hud_attrs(0);
#else
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
        uint8_t tens = (uint8_t)((values[g] / 10) % 10);
        uint8_t ones = (uint8_t)(values[g] % 10);

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

    if (color_on) color_hud_attr();
#endif
}
