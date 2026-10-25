#ifndef VARIANTS_H
#define VARIANTS_H

#include <stdint.h>
#include <gb/gb.h>

/* Palette-dependent object tile variants. */
/* Alternate projectile shade: white on a dark gray floor, one shade darker
 * on a white floor. */
#define VAR_BULLETS_ALT    0x01
#define VAR_BADDIES_BRIGHT 0x02   /* black floor: enemies one shade brighter */

void variants_reset(void) BANKED;
/* mask: VAR_* bits.  apply_now: load immediately (display must be off);
 * otherwise variants_step() uploads one 8-tile chunk per call (VBlank-safe). */
void variants_request(uint8_t mask, uint8_t apply_now) BANKED;
/* Returns 1 if a chunk was uploaded this call, 0 when the current and
 * requested variants match. */
uint8_t variants_step(void) BANKED;

#endif
