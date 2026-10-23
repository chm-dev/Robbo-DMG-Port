/*
 * Bear (left/right-hand wall follower) update.
 *
 * Kept in a bank: the side-first rule plus sensible_bears guard is larger
 * than bank 0 can hold.  This matches the Atari/GNU BEAR / BEAR_B update:
 * try the side first, then forward, then rotate in place.  The open-space
 * guard prevents a lone bear from circling itself in a 2x2 loop.
 */
#pragma bank 10

#include <stdint.h>
#include <gb/gb.h>

#include "game.h"
#include "../gb/render.h"

static const int8_t bear_dx[4] = { 1, 0, -1, 0 };
static const int8_t bear_dy[4] = { 0, 1, 0, -1 };

static uint8_t bear_cell_empty(int16_t x, int16_t y)
{
    if (x < 0 || y < 0 || x >= MAP_W || y >= level_height) return 0;
    return map_type[(uint16_t)y * MAP_W + (uint8_t)x] == CT_EMPTY;
}

static uint8_t bear_cell_is_bear(int16_t x, int16_t y)
{
    if (x < 0 || y < 0 || x >= MAP_W || y >= level_height) return 0;
    return map_type[(uint16_t)y * MAP_W + (uint8_t)x] == CT_BEAR;
}

uint16_t bear_step(uint16_t idx, uint8_t state) BANKED
{
    uint8_t extra = map_extra[idx];
    uint8_t dir = extra & 3;
    uint8_t left = (extra & 4) ? 0 : 1;
    uint8_t side_dir = left ? (uint8_t)((dir + 3) & 3)
                            : (uint8_t)((dir + 1) & 3);
    int16_t x = (int16_t)(idx % MAP_W);
    int16_t y = (int16_t)(idx / MAP_W);
    int16_t sx = x + bear_dx[side_dir];
    int16_t sy = y + bear_dy[side_dir];
    int16_t fx = x + bear_dx[dir];
    int16_t fy = y + bear_dy[dir];
    uint8_t side_empty = bear_cell_empty(sx, sy);
    uint8_t forward_empty = bear_cell_empty(fx, fy);
    uint8_t forceforward = 0;
    uint16_t nidx;

    if (side_empty) {
        int16_t sbx = sx + bear_dx[(dir + 2) & 3];
        int16_t sby = sy + bear_dy[(dir + 2) & 3];
        uint8_t turn_after = left ? (uint8_t)((dir + 1) & 3)
                                  : (uint8_t)((dir + 3) & 3);
        int16_t bx = sbx + bear_dx[turn_after];
        int16_t by = sby + bear_dy[turn_after];

        if (bear_cell_empty(bx, by) &&
            (bear_cell_empty(sbx, sby) || bear_cell_is_bear(sbx, sby))) {
            forceforward = 1;
        }
    }

    if (side_empty && !forceforward) {
        dir = side_dir;
    } else if (!forward_empty) {
        dir = left ? (uint8_t)((dir + 1) & 3)
                   : (uint8_t)((dir + 3) & 3);
        map_extra[idx] = (uint8_t)((extra & ~3) | dir);
        map_obj[idx] = state;
        return idx;
    }

    if (dir == side_dir) {
        nidx = (uint16_t)sy * MAP_W + (uint8_t)sx;
    } else {
        nidx = (uint16_t)fy * MAP_W + (uint8_t)fx;
    }

    map_type[nidx] = CT_BEAR;
    map_extra[nidx] = (uint8_t)((extra & ~3) | dir);
    map_obj[nidx] = state;
    map_type[idx] = CT_EMPTY;
    map_extra[idx] = 0;
    map_obj[idx] = 0;
    render_cell((uint8_t)x, (uint8_t)y);
    render_cell(nidx % MAP_W, nidx / MAP_W);
    return nidx;
}
