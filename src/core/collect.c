/* collect.c - per-tick actor list scan, banked to keep bank 0's budget.
 *
 * Scans map_type once per logic tick and rebuilds the turret/enemy/bomb/
 * explosion/magnet/spaceship/teleport lists plus the barrier row bitmaps.
 * The consumer loops tolerate stale entries by re-checking map_type.
 *
 * The scan is split into two 248-byte halves indexed by an 8-bit counter.
 * That lets SDCC use constant-base,Y addressing for both halves instead of
 * rebuilding a 16-bit map_type address for every one of the 496 cells; the
 * scan is the single largest per-tick cost on the 6502.  The order is still
 * the original descending 495..0, so list order (and actor processing order)
 * is unchanged.
 */
#pragma bank 15

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "game.h"

/* Category lookup: 0 = not tracked, else which list. */
#define CAT_NONE 0
#define CAT_TURRET 1
#define CAT_ENEMY 2
#define CAT_BOMB 3
#define CAT_EXPLOSION 4
#define CAT_MAGNET 5
#define CAT_SPACESHIP 6
#define CAT_TELEPORT 7
#define CAT_BARRIER 8

static const uint8_t type_cat[31] = {
    CAT_NONE,       /* CT_EMPTY */
    CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE,
    CAT_NONE,       /* CT_GROUND */
    CAT_NONE,       /* CT_STONE */
    CAT_NONE,       /* CT_PUSHABLE */
    CAT_NONE,       /* CT_DOOR */
    CAT_SPACESHIP,  /* CT_SPACESHIP */
    CAT_NONE,       /* CT_QUESTION */
    CAT_BOMB,       /* CT_BOMB */
    CAT_NONE,       /* CT_KEY */
    CAT_NONE,       /* CT_SCREW */
    CAT_TURRET,     /* CT_TURRET */
    CAT_NONE,       /* CT_AMMO */
    CAT_TELEPORT,   /* CT_TELEPORT */
    CAT_ENEMY,      /* CT_MUSTACHE */
    CAT_ENEMY,      /* CT_BUTTERFLY */
    CAT_ENEMY,      /* CT_BEAR */
    CAT_NONE,       /* CT_LAVA */
    CAT_MAGNET,     /* CT_MAGNET */
    CAT_NONE,       /* CT_ROBBO */
    CAT_NONE,       /* CT_BULLET */
    CAT_EXPLOSION,  /* CT_EXPLOSION */
    CAT_NONE,       /* CT_EXTRA_LIFE */
    CAT_BARRIER,    /* CT_BARRIER */
};

/* map_type split into two equal halves so each can be indexed with a uint8_t.
 * The 8-bit index is what keeps the per-cell address setup out of the loop. */
typedef struct {
    uint8_t lo[248];
    uint8_t hi[248];
} collect_map_t;
#define COLLECT_MAP ((const collect_map_t *)map_type)

static void collect_add(uint16_t i, uint8_t cat);

/* Only called for cells whose category is non-zero.  The category is re-read
 * here instead of being passed from the scan loop: SDCC otherwise hoists the
 * second-argument setup into the fast path for all 496 cells.  These are not
 * static because the NES scan below calls them directly from inline asm. */
void collect_hi(uint8_t j)
{
    collect_add((uint16_t)(248 + j), type_cat[COLLECT_MAP->hi[j]]);
}

void collect_lo(uint8_t j)
{
    collect_add((uint16_t)j, type_cat[COLLECT_MAP->lo[j]]);
}

static void collect_add(uint16_t i, uint8_t cat)
{
    switch (cat) {
    case CAT_TURRET:
        if (turret_count < MAX_TURRET_LIST) turret_list[turret_count++] = i;
        break;
    case CAT_ENEMY:
        if (enemy_count < MAX_ENEMY_LIST) enemy_list[enemy_count++] = i;
        break;
    case CAT_BOMB:
        if (bomb_count < MAX_BOMB_LIST) bomb_list[bomb_count++] = i;
        break;
    case CAT_EXPLOSION:
        if (explosion_count < MAX_EXPLOSION_LIST) explosion_list[explosion_count++] = i;
        break;
    case CAT_MAGNET:
        if (magnet_count < MAX_MAGNET_LIST) magnet_list[magnet_count++] = i;
        break;
    case CAT_SPACESHIP:
        if (spaceship_count < MAX_SPACESHIP_LIST) spaceship_list[spaceship_count++] = i;
        break;
    case CAT_BARRIER:
        if (i < 256) barrier_row_lo |= (uint16_t)(1u << (i >> 4));
        else barrier_row_hi |= (uint16_t)(1u << ((i >> 4) - 16));
        break;
    default:    /* CAT_TELEPORT */
        if (teleport_count < MAX_TELEPORT_LIST) teleport_list[teleport_count++] = i;
        break;
    }
}

void collect_actors(void) BANKED
{
#ifndef NINTENDO_NES
    uint8_t j;
#endif

    turret_count = 0;
    enemy_count = 0;
    bomb_count = 0;
    explosion_count = 0;
    magnet_count = 0;
    spaceship_count = 0;
    teleport_count = 0;
    barrier_row_lo = 0;
    barrier_row_hi = 0;

    /* Descending scan order, high half first, exactly like the original
     * for (i = MAP_CELLS; i != 0; ) loop. */
#ifdef NINTENDO_NES
    /* Hand-written 6502 scan.  X is the 8-bit index so the map read is a
     * 4-cycle absolute,X load; SDCC's C version rebuilds a 16-bit address
     * for every cell and measured ~38 cycles/cell instead of ~19 here.
     * The helpers are only called for the few non-empty cells. */
    __asm
        ldx #248
    90101$:
        dex
        lda _map_type+248,x
        tay
        lda _type_cat,y
        beq 90102$
        txa
        pha
        jsr _collect_hi
        pla
        tax
    90102$:
        cpx #0
        bne 90101$

        ldx #248
    90103$:
        dex
        lda _map_type,x
        tay
        lda _type_cat,y
        beq 90104$
        txa
        pha
        jsr _collect_lo
        pla
        tax
    90104$:
        cpx #0
        bne 90103$
    __endasm;
#else
    for (j = 248; j != 0; ) {
        j--;
        if (type_cat[COLLECT_MAP->hi[j]]) collect_hi(j);
    }
    for (j = 248; j != 0; ) {
        j--;
        if (type_cat[COLLECT_MAP->lo[j]]) collect_lo(j);
    }
#endif
}
