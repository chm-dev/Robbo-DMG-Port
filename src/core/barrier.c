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
 *
 * A wall-to-wall run is scanned once: the scan builds the 16-bit field mask
 * and the run bounds in the same pass, then the wave rotates that mask and
 * touches only the cells whose bit changed.  This avoids the old repeated
 * `y * 16 + x` addressing and the separate left/right expansion walks.
 */
#pragma bank 15

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

/* Rotate one wall-to-wall run.  old is the pre-step field mask; bit i is
 * column left + i. */
static void barrier_wave(uint16_t row, uint8_t y, uint8_t left, uint8_t n,
                         uint8_t dir, uint16_t old)
{
    uint8_t i;
    uint8_t x;
    uint16_t full;
    uint16_t top;
    uint16_t bit;
    uint16_t new_mask;
    uint16_t changed;
    /* Walk the run through 8-bit indices; the 6502 gets (ptr),y addressing
     * instead of recomputing y * 16 + x for every cell. */
    uint8_t *type = &map_type[row + left];
    uint8_t *extra = &map_extra[row + left];

    if (n < 2 || n > 16) return;

    full = (n == 16) ? (uint16_t)0xFFFF : (uint16_t)(((uint16_t)1u << n) - 1);
    if (old == full) return;

    /* Top bit of the run; computed once instead of shifting by n - 1 in each
     * direction branch. */
    top = 1;
    for (i = 1; i < n; i++) top <<= 1;

    if (dir == 2) {                 /* west: cell i gets old i+1, wrap 0 -> n-1 */
        new_mask = (uint16_t)(old >> 1);
        if (old & 1u) new_mask |= top;
    } else if (dir == 0) {          /* east: cell i gets old i-1, wrap n-1 -> 0 */
        new_mask = (uint16_t)(old << 1);
        if (old & top) new_mask |= 1u;
    } else {
        return;
    }
    new_mask &= full;

    /* Only changed cells need map work: a growing cell consumes its contents,
     * a shrinking cell becomes empty.  Unchanged barrier cells stay put. */
    changed = (uint16_t)(old ^ new_mask);
    if (changed == 0) return;

    x = left;
    bit = 1;
    for (i = 0; i < n; i++, x++, bit <<= 1) {
        if (changed & bit) {
            if (new_mask & bit) {
                uint16_t idx;

                if (type[i] == CT_ROBBO) {
                    game_barrier_hit((uint16_t)(row + x));
                    continue;
                }
                idx = (uint16_t)(row + x);
                if (type[i] != CT_EMPTY) {
                    game_barrier_hit(idx);
                }
                type[i] = CT_BARRIER;
                extra[i] = dir;
            } else {
                type[i] = CT_EMPTY;
                extra[i] = 0;
            }
            render_cell(x, y);
        }
    }
}

static void barrier_row(uint16_t row, uint8_t y, uint8_t animate)
{
    /* Row base pointer: the scan uses x as an 8-bit index, so the compiler
     * emits (ptr),y loads instead of a 16-bit index increment per cell. */
    uint8_t *type = &map_type[row];
    uint8_t x = 0;
    uint8_t left = 0;
    uint8_t dir = 0;
    uint16_t old = 0;
    uint16_t bit = 1;
#ifdef NINTENDO_NES
    /* The field animates every other tick; mark the whole row once instead of
     * calling render_cell() for each barrier cell. */
    uint16_t marks = 0;
#endif

    while (x < MAP_W) {
        uint8_t t = type[x];

        if (IS_WALL(t)) {
            if (old) {
                barrier_wave(row, y, left, (uint8_t)(x - left), dir, old);
            }
            left = (uint8_t)(x + 1);
            old = 0;
            bit = 1;
            x++;
            continue;
        }

        if (t == CT_BARRIER) {
            if (old == 0) dir = map_extra[row + x] & 3;
            old |= bit;
            if (animate) {
#ifdef NINTENDO_NES
                marks |= bit;
#else
                render_cell(x, y);
#endif
            }
        }
        bit <<= 1;
        x++;
    }

    if (old) {
        barrier_wave(row, y, left, (uint8_t)(MAP_W - left), dir, old);
    }
#ifdef NINTENDO_NES
    if (marks) render_mark_row(y, marks);
#endif
}

void barrier_tick(uint16_t row_lo, uint16_t row_hi, uint8_t animate) BANKED
{
    uint8_t y = 0;
    uint16_t row = 0;
    uint16_t bit = 1;

    /* Rows 0..15 use row_lo, rows 16..30 use row_hi.  Shifting the test bit
     * incrementally avoids a variable 1 << (y & 15) shift for every row. */
    while (y < 16 && y < level_height) {
        if (row_lo & bit) barrier_row(row, y, animate);
        y++;
        row = (uint16_t)(row + MAP_W);
        bit <<= 1;
    }
    bit = 1;
    while (y < level_height) {
        if (row_hi & bit) barrier_row(row, y, animate);
        y++;
        row = (uint16_t)(row + MAP_W);
        bit <<= 1;
    }
}
