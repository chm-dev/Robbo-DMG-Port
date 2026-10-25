/* External-RAM save record (bank 11).
 *
 * The MidnightTrace MBC5 board exposes its 128 KiB FRAM as ordinary MBC5
 * cartridge RAM.  The ROM header advertises MBC5+RAM (the battery bit is
 * harmless for FRAM and makes emulator/flashcart save handling behave like a
 * normal battery save).  Bank 0 is enough for the single record.
 *
 * Record layout (8 bytes at 0xA000):
 *   0..3  'R','B','B','O'
 *   4     format version
 *   5     highest level (1..LEVEL_COUNT)
 *   6     checksum
 *   7     0xA5 marker
 *
 * The magic first byte is cleared before the data is rewritten and restored
 * last, so a torn write is rejected by the next load.
 */
#pragma bank 11

#include <gb/gb.h>
#include <stdint.h>

#include "save.h"
#include "../gen/levels.h"

#define SAVE_RAM        ((volatile uint8_t *)0xA000)
#define SAVE_MAGIC_0    0x52u   /* 'R' */
#define SAVE_MAGIC_1    0x42u   /* 'B' */
#define SAVE_MAGIC_2    0x42u   /* 'B' */
#define SAVE_MAGIC_3    0x4Fu   /* 'O' */
#define SAVE_VERSION    1u
#define SAVE_MARKER     0xA5u
#define SAVE_CHECK_SEED 0x3Cu

#define SAVE_OFS_MAGIC  0
#define SAVE_OFS_VERSION 4
#define SAVE_OFS_LEVEL  5
#define SAVE_OFS_CHECK  6
#define SAVE_OFS_MARKER 7

static uint8_t save_check(uint8_t level)
{
    return (uint8_t)(level ^ SAVE_VERSION ^ SAVE_CHECK_SEED);
}

uint8_t save_load(void) BANKED
{
    uint8_t level = SAVE_NO_LEVEL;
    uint8_t stored;

    ENABLE_RAM;
    SWITCH_RAM(0);

    if (SAVE_RAM[SAVE_OFS_MAGIC + 0] == SAVE_MAGIC_0 &&
        SAVE_RAM[SAVE_OFS_MAGIC + 1] == SAVE_MAGIC_1 &&
        SAVE_RAM[SAVE_OFS_MAGIC + 2] == SAVE_MAGIC_2 &&
        SAVE_RAM[SAVE_OFS_MAGIC + 3] == SAVE_MAGIC_3 &&
        SAVE_RAM[SAVE_OFS_VERSION] == SAVE_VERSION &&
        SAVE_RAM[SAVE_OFS_MARKER] == SAVE_MARKER) {
        stored = SAVE_RAM[SAVE_OFS_LEVEL];
        if (stored >= 1 && stored <= LEVEL_COUNT &&
            SAVE_RAM[SAVE_OFS_CHECK] == save_check(stored)) {
            level = stored;
        }
    }

    DISABLE_RAM;
    return level;
}

uint8_t save_store(uint8_t level) BANKED
{
    uint8_t old = save_load();

    if (level < 1) level = 1;
    if (level > LEVEL_COUNT) level = LEVEL_COUNT;
    /* Level 1 is the fresh-cart state and must never create a save. */
    if (level < 2 || level <= old) return old;

    ENABLE_RAM;
    SWITCH_RAM(0);

    /* Invalidate first, write the payload, then publish the magic last. */
    SAVE_RAM[SAVE_OFS_MAGIC] = 0x00;
    SAVE_RAM[SAVE_OFS_MAGIC + 1] = SAVE_MAGIC_1;
    SAVE_RAM[SAVE_OFS_MAGIC + 2] = SAVE_MAGIC_2;
    SAVE_RAM[SAVE_OFS_MAGIC + 3] = SAVE_MAGIC_3;
    SAVE_RAM[SAVE_OFS_VERSION] = SAVE_VERSION;
    SAVE_RAM[SAVE_OFS_LEVEL] = level;
    SAVE_RAM[SAVE_OFS_CHECK] = save_check(level);
    SAVE_RAM[SAVE_OFS_MARKER] = SAVE_MARKER;
    SAVE_RAM[SAVE_OFS_MAGIC] = SAVE_MAGIC_0;

    DISABLE_RAM;
    return level;
}

void save_erase(void) BANKED
{
    uint8_t i;

    ENABLE_RAM;
    SWITCH_RAM(0);
    for (i = 0; i < 8; i++) SAVE_RAM[i] = 0x00;
    DISABLE_RAM;
}
