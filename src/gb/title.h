#ifndef TITLE_H
#define TITLE_H

#include <gb/gb.h>

/* Draw the title screen and wait for A or START.  A valid saved level
 * (1..LEVEL_COUNT) opens the start-level menu; 0 starts level 1 directly.
 * Returns the level selected on the menu (always 1 when there is no save).
 * Entry expects the display off (the caller has already run render_init());
 * exit leaves it off and the window hidden so the caller can restore the
 * gameplay tileset and level. */
uint8_t title_show(uint8_t saved_level) BANKED;

#endif /* TITLE_H */
