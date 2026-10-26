/* External-RAM save record (bank 11).
 *
 * The MidnightTrace MBC5 board exposes its 128 KiB FRAM as ordinary MBC5
 * cartridge RAM.  The ROM header advertises MBC5+RAM (the battery bit is
 * harmless for FRAM and makes emulator/flashcart save handling behave like a
 * normal battery save).
 *
 * Record layout (8 bytes):
 *   0..3  'R','B','B','O'
 *   4     format version
 *   5     highest level (1..LEVEL_COUNT)
 *   6     checksum
 *   7     0xA5 marker
 *
 * Two records are kept, at 0x0100 and 0x0110.  A new level always rewrites
 * the stale copy, so the newer progress record stays intact if the write
 * fails halfway.  Nothing is written to 0xA000: on some FRAM boards the cell
 * at the base of the RAM window never stores, and a record placed there reads
 * back as an erased 0xFF forever.  A legacy record at 0xA000 is still
 * accepted so saves from older builds load, but it is never written again.
 *
 * Inside a record the magic first byte is cleared before the data is
 * rewritten and restored last, and the result is read back.  A write that
 * does not verify is retried instead of silently dropping the progress.
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

/* Records written before v2 lived at the window base; read only. */
#define SAVE_SLOT_LEGACY 0x0000u
#define SAVE_SLOT_A      0x0100u
#define SAVE_SLOT_B      0x0110u

#define SAVE_WRITE_TRIES 3u

static uint8_t save_check(uint8_t level)
{
    return (uint8_t)(level ^ SAVE_VERSION ^ SAVE_CHECK_SEED);
}

/* Validate the record at `ofs`.  Requires cartridge RAM to be enabled. */
static uint8_t save_slot_level(uint16_t ofs)
{
    volatile uint8_t *rec = SAVE_RAM + ofs;
    uint8_t level;

    if (rec[SAVE_OFS_MAGIC + 0] != SAVE_MAGIC_0 ||
        rec[SAVE_OFS_MAGIC + 1] != SAVE_MAGIC_1 ||
        rec[SAVE_OFS_MAGIC + 2] != SAVE_MAGIC_2 ||
        rec[SAVE_OFS_MAGIC + 3] != SAVE_MAGIC_3 ||
        rec[SAVE_OFS_VERSION] != SAVE_VERSION ||
        rec[SAVE_OFS_MARKER] != SAVE_MARKER) {
        return SAVE_NO_LEVEL;
    }

    level = rec[SAVE_OFS_LEVEL];
    if (level < 1 || level > LEVEL_COUNT ||
        rec[SAVE_OFS_CHECK] != save_check(level)) {
        return SAVE_NO_LEVEL;
    }
    return level;
}

/* Write and verify one record.  Requires RAM to be enabled.
 * Returns non-zero when the record reads back correctly. */
static uint8_t save_slot_write(uint16_t ofs, uint8_t level)
{
    volatile uint8_t *rec = SAVE_RAM + ofs;
    uint8_t tries;

    for (tries = 0; tries < SAVE_WRITE_TRIES; tries++) {
        /* Invalidate first, write the payload, then publish the magic last. */
        rec[SAVE_OFS_MAGIC] = 0x00;
        rec[SAVE_OFS_MAGIC + 1] = SAVE_MAGIC_1;
        rec[SAVE_OFS_MAGIC + 2] = SAVE_MAGIC_2;
        rec[SAVE_OFS_MAGIC + 3] = SAVE_MAGIC_3;
        rec[SAVE_OFS_VERSION] = SAVE_VERSION;
        rec[SAVE_OFS_LEVEL] = level;
        rec[SAVE_OFS_CHECK] = save_check(level);
        rec[SAVE_OFS_MARKER] = SAVE_MARKER;
        rec[SAVE_OFS_MAGIC] = SAVE_MAGIC_0;

        if (save_slot_level(ofs) == level) return 1;
    }

    /* Leave nothing behind that a later boot could accept as valid. */
    rec[SAVE_OFS_MAGIC] = 0x00;
    return 0;
}

static uint8_t save_max(uint8_t a, uint8_t b)
{
    return (a > b) ? a : b;
}

uint8_t save_load(void) BANKED
{
    uint8_t best;

    ENABLE_RAM;
    SWITCH_RAM(0);

    best = save_slot_level(SAVE_SLOT_LEGACY);
    best = save_max(best, save_slot_level(SAVE_SLOT_A));
    best = save_max(best, save_slot_level(SAVE_SLOT_B));

    DISABLE_RAM;
    return best;
}

uint8_t save_store(uint8_t level) BANKED
{
    uint8_t old = save_load();
    uint8_t slot_a;
    uint8_t slot_b;
    uint16_t target;
    uint8_t ok;

    if (level < 1) level = 1;
    if (level > LEVEL_COUNT) level = LEVEL_COUNT;
    /* Level 1 is the fresh-cart state and must never create a save. */
    if (level < 2 || level <= old) return old;

    ENABLE_RAM;
    SWITCH_RAM(0);

    slot_a = save_slot_level(SAVE_SLOT_A);
    slot_b = save_slot_level(SAVE_SLOT_B);

    /* Overwrite the stale copy so the good one survives a failed write. */
    target = (slot_a <= slot_b) ? SAVE_SLOT_A : SAVE_SLOT_B;

    ok = save_slot_write(target, level);
    if (!ok) {
        ok = save_slot_write((target == SAVE_SLOT_A) ? SAVE_SLOT_B : SAVE_SLOT_A,
                             level);
    }

    DISABLE_RAM;
    return ok ? level : old;
}

void save_erase(void) BANKED
{
    uint8_t i;

    ENABLE_RAM;
    SWITCH_RAM(0);
    /* Clear the legacy record too, or a deleted save would come back. */
    for (i = 0; i < 8; i++) SAVE_RAM[SAVE_SLOT_LEGACY + i] = 0x00;
    for (i = 0; i < 8; i++) SAVE_RAM[SAVE_SLOT_A + i] = 0x00;
    for (i = 0; i < 8; i++) SAVE_RAM[SAVE_SLOT_B + i] = 0x00;
    DISABLE_RAM;
}
