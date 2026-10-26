/* Atari ZAPO barrier (the `=` force field).
 *
 * The field is a horizontal run of barrier cells between two walls.  On every
 * step it advances one cell in its packed direction and wraps around the run,
 * which is what makes a shot gap travel along the row (the player has to chase
 * it).  Whatever the field advances onto is consumed: demolition objects use
 * their normal destroy path, other explodable cells explode, and the rest is
 * overwritten by the barrier.  Reaching Robbo kills him.
 *
 * The row mask is collected by game.c's existing map scan; this banked module
 * only does the rare per-row wave work.
 */
#pragma bank 14

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "game.h"
#include "../gb/render.h"

void game_barrier_hit(uint16_t idx) BANKED
{
    uint8_t type = map_type[idx];

    if (type == CT_ROBBO) {
        kill_robbo();
    } else if (is_demolishable(type)) {
        demolish_cell(idx);
    } else {
        blast_cell(idx, 3);
    }
}

static void barrier_wave(uint8_t y, uint8_t left, uint8_t right, uint8_t dir)
{
    uint16_t row = (uint16_t)y * MAP_W;
    uint8_t n = (uint8_t)(right - left + 1);
    uint16_t old = 0;
    uint16_t full;
    uint8_t i;

    if (n < 2 || n > 16) return;

    for (i = 0; i < n; i++) {
        if (map_type[row + left + i] == CT_BARRIER) {
            old |= (uint16_t)(1u << i);
        }
    }
    full = (uint16_t)((1u << n) - 1);
    /* A solid field has no visual gap to move; its cells are identical, so
     * skipping the wave is both correct and keeps busy levels cheap. */
    if (old == full) return;

    for (i = 0; i < n; i++) {
        uint8_t src;
        uint16_t idx;

        if (dir == 2) {                 /* west: left <- right neighbour */
            src = (i == (uint8_t)(n - 1)) ? 0 : (uint8_t)(i + 1);
        } else if (dir == 0) {          /* east: right <- left neighbour */
            src = (i == 0) ? (uint8_t)(n - 1) : (uint8_t)(i - 1);
        } else {
            return;
        }

        if ((old >> src) & 1u) {
            if ((old >> i) & 1u) continue;
            idx = (uint16_t)(row + left + i);
            if (map_type[idx] == CT_ROBBO) {
                game_barrier_hit(idx);
                continue;
            }
            if (map_type[idx] != CT_EMPTY) {
                game_barrier_hit(idx);
            }
            map_type[idx] = CT_BARRIER;
            map_extra[idx] = dir;
            render_cell((uint8_t)(left + i), y);
        } else if ((old >> i) & 1u) {
            idx = (uint16_t)(row + left + i);
            map_type[idx] = CT_EMPTY;
            map_extra[idx] = 0;
            render_cell((uint8_t)(left + i), y);
        }
    }
}

static void barrier_row(uint8_t y, uint8_t animate)
{
    uint8_t x = 0;

    while (x < MAP_W) {
        uint8_t dir;
        uint8_t left;
        uint8_t right;

        if (map_type[(uint16_t)y * MAP_W + x] != CT_BARRIER) {
            x++;
            continue;
        }

        dir = map_extra[(uint16_t)y * MAP_W + x] & 3;
        left = x;
        right = x;
        while (left > 0 &&
               !IS_WALL(map_type[(uint16_t)y * MAP_W + left - 1])) {
            left--;
        }
        while (right + 1 < MAP_W &&
               !IS_WALL(map_type[(uint16_t)y * MAP_W + right + 1])) {
            right++;
        }

        barrier_wave(y, left, right, dir);
        x = (uint8_t)(right + 1);
    }

    if (animate) {
        for (x = 0; x < MAP_W; x++) {
            if (map_type[(uint16_t)y * MAP_W + x] == CT_BARRIER) {
                render_cell(x, y);
            }
        }
    }
}

void barrier_tick(uint16_t row_lo, uint16_t row_hi, uint8_t animate) BANKED
{
    uint8_t y;

    for (y = 0; y < level_height; y++) {
        uint16_t mask = (y < 16) ? row_lo : row_hi;
        uint8_t bit = (uint8_t)(y & 15);
        if (!(mask & (uint16_t)(1u << bit))) continue;
        barrier_row(y, animate);
    }
}
