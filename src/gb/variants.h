#ifndef VARIANTS_H
#define VARIANTS_H

#include <stdint.h>
#include <gb/gb.h>

/* Palette-dependent object tile variants. */
/* Projectile variants: the default light-gray floor uses the black tiles, the
 * white/dark-gray floors use the shifted tiles, and the black floor keeps the
 * base tiles. */
#define VAR_BULLETS_ALT    0x01
#define VAR_BULLETS_BLACK  0x02
#define VAR_BULLETS_MASK   (VAR_BULLETS_ALT | VAR_BULLETS_BLACK)
#define VAR_BADDIES_BRIGHT 0x04   /* black floor: enemies one shade brighter */
#define VAR_BOXES_ALT      0x08   /* dark gray floor: stone/pushable reflections */
#define VAR_ROBBO_SWAP     0x10   /* default/palette 3: Robbo 2<->3 */
#define VAR_ROBBO_SWAP02   0x20   /* palette 1: Robbo white/light-gray 0<->2 */
#define VAR_ROBBO_MASK     (VAR_ROBBO_SWAP | VAR_ROBBO_SWAP02)

void variants_reset(void) BANKED;
/* Select the palette-dependent object tiles for a background shade:
 * 0 white, 1 default light-gray, 2 dark-gray, 3 black, 4 CGB (no DMG variants). */
void variants_request_for_bg(uint8_t bg, uint8_t apply_now) BANKED;
/* mask: VAR_* bits.  apply_now: load immediately (display must be off);
 * otherwise variants_step() uploads one 8-tile chunk per call (VBlank-safe). */
void variants_request(uint8_t mask, uint8_t apply_now) BANKED;
/* Returns 1 if a chunk was uploaded this call, 0 when the current and
 * requested variants match. */
uint8_t variants_step(void) BANKED;

#endif
