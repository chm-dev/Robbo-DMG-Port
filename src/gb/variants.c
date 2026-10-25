/* Palette-dependent object tiles.
 *
 * The bullet, enemy and box tiles are exclusive to their metatiles, so the
 * variants are loaded over the same VRAM tile range.  Small chunks keep each
 * upload comfortably inside one VBlank during a level transition.
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
static uint8_t bullet_stage;
static uint8_t blaster_done;

static void load_bullet_chunk(uint8_t alt)
{
    /* Projectile tiles are 8 per chunk (BULLET_VARIANT_COUNT is currently 8);
     * the blaster head is a separate two-tile range, loaded on the next step. */
    uint8_t first = (uint8_t)(bullet_stage * VAR_CHUNK);
    uint8_t count = (uint8_t)(BULLET_VARIANT_COUNT - first);
    uint8_t dest = (uint8_t)(BULLET_VARIANT_BASE + first);
    const uint8_t *src;

    if (count > VAR_CHUNK) count = VAR_CHUNK;
    src = alt ? &bullet_variant_tiles[(uint16_t)first * 16]
              : &tileset_data[(uint16_t)dest * 16];
    set_bkg_data(dest, count, src);
    bullet_stage++;
}

static void load_blaster(uint8_t alt)
{
    set_bkg_data(BLASTER_VARIANT_BASE, BLASTER_VARIANT_COUNT,
                 alt ? blaster_variant_tiles
                     : &tileset_data[(uint16_t)BLASTER_VARIANT_BASE * 16]);
    blaster_done = 1;
}

static void load_boxes(uint8_t alt)
{
    if (alt) {
        set_bkg_data(STONE_VARIANT_BASE, STONE_VARIANT_COUNT,
                     stone_variant_tiles);
        set_bkg_data(PUSHABLE_VARIANT_BASE, PUSHABLE_VARIANT_COUNT,
                     pushable_variant_tiles);
    } else {
        set_bkg_data(STONE_VARIANT_BASE, STONE_VARIANT_COUNT,
                     &tileset_data[(uint16_t)STONE_VARIANT_BASE * 16]);
        set_bkg_data(PUSHABLE_VARIANT_BASE, PUSHABLE_VARIANT_COUNT,
                     &tileset_data[(uint16_t)PUSHABLE_VARIANT_BASE * 16]);
    }
    current_mask ^= VAR_BOXES_ALT;
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
        uint8_t alt = (uint8_t)(desired_mask & VAR_BULLETS_ALT);
        if ((uint16_t)bullet_stage * VAR_CHUNK < BULLET_VARIANT_COUNT) {
            load_bullet_chunk(alt);
            return 1;
        }
        if (!blaster_done) {
            load_blaster(alt);
            return 1;
        }
        bullet_stage = 0;
        blaster_done = 0;
        current_mask ^= VAR_BULLETS_ALT;
        return 1;
    }

    if ((desired_mask ^ current_mask) & VAR_BADDIES_BRIGHT) {
        load_baddie_chunk((uint8_t)(desired_mask & VAR_BADDIES_BRIGHT));
        return 1;
    }

    if ((desired_mask ^ current_mask) & VAR_BOXES_ALT) {
        load_boxes((uint8_t)(desired_mask & VAR_BOXES_ALT));
        return 1;
    }

    return 0;
}

void variants_reset(void) BANKED
{
    desired_mask = 0;
    current_mask = 0;
    baddie_stage = 0;
    bullet_stage = 0;
    blaster_done = 0;
}

void variants_request(uint8_t mask, uint8_t apply_now) BANKED
{
    desired_mask = mask;
    baddie_stage = 0;
    bullet_stage = 0;
    blaster_done = 0;
    if (apply_now) {
        while (load_next_chunk()) {}
    }
}

uint8_t variants_step(void) BANKED
{
    return load_next_chunk();
}
