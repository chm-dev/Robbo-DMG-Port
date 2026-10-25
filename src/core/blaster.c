/* Atari DZ3 blaster projectile.
 *
 * A blaster is a projectile head that advances one cell per logic tick and
 * leaves a fading explosion behind it.  It consumes ordinary map cells but
 * stops on walls and machinery.  The GBC BLASTER case is the reference; this
 * lives in a bank so the consumer rules and tile/trail handling do not grow
 * bank 0.
 */
#pragma bank 14

#include <gb/gb.h>
#include <stdint.h>

#include "game.h"
#include "../gb/render.h"
#include "../gb/sound.h"

/* Objects the blaster cannot break through (GBC BLASTER update case). */
static uint8_t blaster_blocks(uint8_t type)
{
    if (IS_WALL(type)) return 1;
    switch (type) {
        case CT_DOOR:
        case CT_STONE:
        case CT_PUSHABLE:
        case CT_SPACESHIP:
        case CT_KEY:
        case CT_SCREW:
        case CT_TURRET:
        case CT_TELEPORT:
        case CT_MAGNET:
        case CT_BULLET:
            return 1;
        default:
            return 0;
    }
}

/* Returns the new head cell, or 0xFFFF when the projectile dies.  The caller
 * owns bullet_cells and removes the old entry on 0xFFFF. */
uint16_t blaster_step(uint16_t bidx, uint8_t be) BANKED
{
    uint8_t bdir = be & 3;
    uint8_t owner = (be >> 4) & 1;
    uint8_t bx = (uint8_t)(bidx % MAP_W);
    uint8_t by = (uint8_t)(bidx / MAP_W);
    uint8_t nbx = bx;
    uint8_t nby = by;
    uint8_t target;
    uint16_t nidx;

    if (bdir == 0) nbx++;
    else if (bdir == 1) nby++;
    else if (bdir == 2) { if (nbx > 0) nbx--; }
    else { if (nby > 0) nby--; }

    if (nbx >= MAP_W || nby >= level_height) {
        spawn_explosion_timer(bidx, 3);
        return 0xFFFF;
    }

    nidx = (uint16_t)nby * MAP_W + nbx;
    target = map_type[nidx];

    if (target == CT_EMPTY) {
        spawn_explosion_timer(bidx, 4);
        map_type[nidx] = CT_BULLET;
        map_extra[nidx] = be;
        render_cell(nbx, nby);
        return nidx;
    }

    if (target == CT_ROBBO) {
        if (owner) game_barrier_hit(nidx);
        spawn_explosion_timer(bidx, 3);
        return 0xFFFF;
    }

    if (target == CT_BOMB) {
        game_barrier_hit(nidx);          /* lights the fuse */
        spawn_explosion_timer(bidx, 3);
        return 0xFFFF;
    }

    if (blaster_blocks(target)) {
        sfx_play_note(SFX_HIT_WALL);
        spawn_explosion_timer(bidx, 3);
        return 0xFFFF;
    }

    /* Consume the cell and advance the head into it. */
    game_barrier_hit(nidx);
    spawn_explosion_timer(bidx, 4);
    map_type[nidx] = CT_BULLET;
    map_extra[nidx] = be;
    render_cell(nbx, nby);
    return nidx;
}
