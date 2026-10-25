/* Palette-dependent object tiles.
 *
 * The bullet and enemy tiles are exclusive to their metatiles, so the
 * variants are loaded over the same VRAM tile range.  Eight tiles per call
 * keeps each upload comfortably inside one VBlank during a level transition.
 */
#pragma bank 1

#include <gb/gb.h>
#include <stdint.h>

#include "variants.h"
#include "../gen/tiles.h"

#define VAR_CHUNK 8

static uint8_t desired_mask;
static uint8_t current_mask;
static uint8_t baddie_stage;

static void load_bullets(uint8_t alt)
{
    if (alt) {
        set_bkg_data(BULLET_VARIANT_BASE, BULLET_VARIANT_COUNT,
                     bullet_variant_tiles);
    } else {
        set_bkg_data(BULLET_VARIANT_BASE, BULLET_VARIANT_COUNT,
                     &tileset_data[(uint16_t)BULLET_VARIANT_BASE * 16]);
    }
}

static void load_baddie_chunk(uint8_t bright)
{
    uint8_t dest;
    const uint8_t *src;

    switch (baddie_stage) {
        case 0:
            dest = BADDIE_VARIANT_BASE;
            src = bright ? baddie_variant_tiles
                         : &tileset_data[(uint16_t)BADDIE_VARIANT_BASE * 16];
            break;
        case 1:
            dest = (uint8_t)(BADDIE_VARIANT_BASE + VAR_CHUNK);
            src = bright ? &baddie_variant_tiles[VAR_CHUNK * 16]
                         : &tileset_data[(uint16_t)(BADDIE_VARIANT_BASE + VAR_CHUNK) * 16];
            break;
        case 2:
            dest = BEAR_VARIANT_BASE;
            src = bright ? bear_variant_tiles
                         : &tileset_data[(uint16_t)BEAR_VARIANT_BASE * 16];
            break;
        default:
            dest = (uint8_t)(BEAR_VARIANT_BASE + VAR_CHUNK);
            src = bright ? &bear_variant_tiles[VAR_CHUNK * 16]
                         : &tileset_data[(uint16_t)(BEAR_VARIANT_BASE + VAR_CHUNK) * 16];
            break;
    }

    set_bkg_data(dest, VAR_CHUNK, src);
    baddie_stage++;
    if (baddie_stage == 4) {
        baddie_stage = 0;
        current_mask ^= VAR_BADDIES_BRIGHT;
    }
}

static uint8_t load_next_chunk(void)
{
    if ((desired_mask ^ current_mask) & VAR_BULLETS_ALT) {
        load_bullets((uint8_t)(desired_mask & VAR_BULLETS_ALT));
        current_mask ^= VAR_BULLETS_ALT;
        return 1;
    }

    if ((desired_mask ^ current_mask) & VAR_BADDIES_BRIGHT) {
        load_baddie_chunk((uint8_t)(desired_mask & VAR_BADDIES_BRIGHT));
        return 1;
    }

    return 0;
}

void variants_reset(void) BANKED
{
    desired_mask = 0;
    current_mask = 0;
    baddie_stage = 0;
}

void variants_request(uint8_t mask, uint8_t apply_now) BANKED
{
    desired_mask = mask;
    baddie_stage = 0;
    if (apply_now) {
        while (load_next_chunk()) {}
    }
}

uint8_t variants_step(void) BANKED
{
    return load_next_chunk();
}
