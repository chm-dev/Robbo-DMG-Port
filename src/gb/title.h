#ifndef TITLE_H
#define TITLE_H

#include <gb/gb.h>

/* Draw the title screen and wait for A or START.  Entry expects the display
 * off (the caller has already run render_init()); exit leaves it off and the
 * window hidden so the caller can restore the gameplay tileset and level. */
void title_show(void) BANKED;

#endif /* TITLE_H */
