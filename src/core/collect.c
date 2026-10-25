/* collect.c - per-tick actor list scan, banked to keep bank 0's budget.
 *
 * Scans map_type once per logic tick and rebuilds the turret/enemy/bomb/
 * explosion/magnet/spaceship/teleport lists plus the barrier row bitmaps.
 * The consumer loops tolerate stale entries by re-checking map_type.
 */
#pragma bank 15

#include <gb/gb.h>
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

void collect_actors(void) BANKED
{
    uint16_t i;

    turret_count = 0;
    enemy_count = 0;
    bomb_count = 0;
    explosion_count = 0;
    magnet_count = 0;
    spaceship_count = 0;
    teleport_count = 0;
    barrier_row_lo = 0;
    barrier_row_hi = 0;

    /* Count down from MAP_CELLS so the index lives in a register pair and the
     * loop is a single 16-bit decrement + zero test, rather than a pointer scan
     * that keeps p on the stack and re-derives idx per hit. */
    for (i = MAP_CELLS; i != 0; ) {
        uint8_t cat = type_cat[map_type[--i]];

        if (cat == CAT_NONE) continue;
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
}
