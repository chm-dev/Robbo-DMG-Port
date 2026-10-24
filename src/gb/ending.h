#ifndef ENDING_H
#define ENDING_H

#include <gb/gb.h>

/* Full Atari/GBC ending: starship scene, two message pages and the closing
 * wipe.  Runs with the display under its own control and returns with the
 * display off, the HUD window hidden and the gameplay window position
 * restored.  Call from the level-complete path (last planet) or the
 * START+SELECT debug chord. */
void ending_show(void) BANKED;

/* Non-zero while the ending owns the screen.  Exposed for the checkpoint. */
extern uint8_t ending_active;

/* Current message page (0 or 1).  Exposed for the checkpoint. */
extern uint8_t ending_page;

#endif /* ENDING_H */
