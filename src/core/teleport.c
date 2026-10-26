/*
 * Teleport landing resolution (bank 14).
 *
 * GNU Robbo walks the teleports of the same group in id order, wrapping, and
 * uses the first one with a free neighbouring cell; the source teleport is the
 * last candidate.  If every landing is blocked it teleports Robbo in place
 * ("protect from freezing the game").  That in-place case is also what keeps a
 * lone self-linked teleport (Atari L7) enterable.
 *
 * The generated destination table stores one ring per group: a cell's
 * map_extra indexes teleport_dest[] for the next member, so following it from
 * a destination visits every member of that group.  Keeping this walk out of
 * bank 0 leaves its tight budget for the main game loop.
 */
#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#ifdef NINTENDO_NES
/* Moved to bank 15 so game.c (bank 14) has the whole 16 KiB switchable bank. */
#pragma bank 15
#else
#pragma bank 14
#endif

#include "game.h"

#define TELEPORT_NONE 0xFFFF

static const int8_t tp_dx[4] = { 1, 0, -1, 0 };
static const int8_t tp_dy[4] = { 0, 1, 0, -1 };

static uint16_t teleport_scan(uint16_t base, uint8_t *pdir)
{
    uint8_t i;
    uint8_t dir = *pdir;
    uint8_t bx = base % MAP_W;
    uint8_t by = base / MAP_W;

    for (i = 0; i < 4; i++) {
        int16_t nx = (int16_t)bx + tp_dx[dir];
        int16_t ny = (int16_t)by + tp_dy[dir];
        if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
            uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
            if (map_type[nidx] == CT_EMPTY) {
                *pdir = dir;
                return nidx;
            }
        }
        dir ^= (uint8_t)(3 - (i & 1));
    }

    *pdir = dir;
    return TELEPORT_NONE;
}

uint16_t game_teleport_find_next(uint16_t entry_idx, uint16_t dest_idx) BANKED
{
    uint8_t dir = robbo_dir;
    uint8_t steps = level_teleport_count;
    uint16_t first = dest_idx;
    uint16_t candidate;

    /* Try the linked destination first, then every other member of the
     * group (including the source teleport last) before giving up. */
    while (steps--) {
        if (map_type[dest_idx] != CT_TELEPORT) break;
        candidate = teleport_scan(dest_idx, &dir);
        if (candidate != TELEPORT_NONE) {
            robbo_dir = dir;
            return candidate;
        }
        if (map_extra[dest_idx] >= level_teleport_count) break;
        dest_idx = teleport_dest[map_extra[dest_idx]];
        if (dest_idx == first) break;
    }

    /* A destination that is not a teleport (orphan link) keeps the
     * historical entry-side fallback. */
    if (map_type[first] != CT_TELEPORT) {
        candidate = teleport_scan(entry_idx, &dir);
        robbo_dir = dir;
        return candidate;
    }

    /* Every landing in the group is blocked: teleport in place.  Robbo's own
     * cell is used, not the entry teleport cell, which is never a landing. */
    robbo_dir = dir;
    return (uint16_t)robbo_y * MAP_W + robbo_x;
}
