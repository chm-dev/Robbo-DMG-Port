#ifndef INTRO_H
#define INTRO_H

#include <stdint.h>
#include <gbdk/platform.h>
#include "platform_compat.h"

/* Level entry / respawn sequence, ported from the Atari ENTCV + WFAC flow:
 *
 *   1. the playfield is painted in one column at a time (right to left in the
 *      source; the GB starts with the visible columns so it is seen at once);
 *   2. the camera glides to the start-centered view;
 *   3. the spawn cell flickers while the entry jingle plays;
 *   4. control returns to the player.
 *
 * A respawn keeps the display on: the map is restored in WRAM, the wiped
 * screen is repainted, and the camera pans from the death view to Robbo's
 * start instead of snapping there behind a black frame.
 *
 * The Atari level-complete transition (NXCV) is the same paint in reverse:
 * the finished playfield is cleared column by column right-to-left, then the
 * next level is loaded and painted in.  intro_clear_begin()/intro_clear_tick()
 * drive that clear from the main loop; game_load_level_after_clear() then
 * starts the normal paint without blanking VRAM again.
 *
 * intro_begin() is called by game_load_level()/game_respawn_level() while the
 * display is off (new level) or on (respawn/after-clear).  intro_tick() and
 * intro_clear_tick() must be called once per frame from the main loop. */
#define INTRO_MODE_NEW          0  /* display off, screen blanked by the intro */
#define INTRO_MODE_RESPAWN      1  /* display on, paint over the wiped room  */
#define INTRO_MODE_AFTER_CLEAR  2  /* display on, screen already empty        */

extern uint8_t intro_active;

void intro_begin(uint8_t mode) BANKED;
void intro_tick(void) BANKED;
void intro_clear_begin(void) BANKED;
/* Returns 1 while the clear is running, 0 on the frame it finishes. */
uint8_t intro_clear_tick(void) BANKED;

#endif /* INTRO_H */
