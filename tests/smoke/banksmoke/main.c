/*
 * Phase 0 smoke test: prove that banked code in bank 2 can be called and that
 * banked data in bank 2 can be read from bank 0.
 *
 * The ROM passes when the screen is a 3-tile stripe:
 *   tile 0 = banked function returned the expected magic
 *   tile 1 = banked data byte matched
 *   tile 2 = always set (so a blank screen is distinguishable from a pass)
 */
#include <gb/gb.h>
#include <gbdk/platform.h>
#include <stdint.h>

#define BANK_SMOKE_MAGIC 0xA7u

extern uint8_t bank2_value(void) BANKED;
extern uint8_t bank2_read(uint8_t index) BANKED;

static const uint8_t pass_tile[16] = {
    0x00, 0x00, 0x18, 0x18, 0x3C, 0x3C, 0x7E, 0x7E,
    0x7E, 0x7E, 0x3C, 0x3C, 0x18, 0x18, 0x00, 0x00,
};
static const uint8_t fail_tile[16] = {
    0xFF, 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81,
    0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF, 0xFF,
};
static const uint8_t blank_tile[16] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

void main(void)
{
    uint8_t tile, ok = 0;

    DISPLAY_OFF;

    set_bkg_data(0, 1, pass_tile);
    set_bkg_data(1, 1, fail_tile);
    set_bkg_data(2, 1, blank_tile);

    /* A clear field so the checks stand out. */
    for (ok = 0; ok < 18; ok++) {
        uint8_t x;
        for (x = 0; x < 20; x++) {
            set_bkg_tile_xy(x, ok, 2);
        }
    }

    /* Row 8: one status tile per check, centred-ish. */
    tile = (bank2_value() == BANK_SMOKE_MAGIC) ? 0 : 1;
    set_bkg_tiles(8, 8, 1, 1, &tile);

    tile = (bank2_read(0) == 0x5Au) ? 0 : 1;
    set_bkg_tiles(10, 8, 1, 1, &tile);

    tile = 0;
    set_bkg_tiles(12, 8, 1, 1, &tile);

    SCX_REG = 0;
    SCY_REG = 0;
    SHOW_BKG;
    DISPLAY_ON;

    while (1) {
        vsync();
    }
}
