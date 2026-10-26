#ifndef SCREENS_H
#define SCREENS_H

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

/* Pause-menu phase, exposed for the input handler and regression tests. */
#define PAUSE_STATE_CLOSED  0
#define PAUSE_STATE_OPENING 1
#define PAUSE_STATE_READY   2
#define PAUSE_STATE_CLOSING 3

/* Pause-menu actions returned by pause_menu_update(). */
#define PAUSE_ACTION_NONE    0
#define PAUSE_ACTION_WARP    1
#define PAUSE_ACTION_RESTART 2
#define PAUSE_ACTION_EXIT    3
#define PAUSE_ACTION_CLOSE   4

/* The menu is a compact BG overlay: 15x9 tiles, centered over the playfield.
 * The HUD window stays at the bottom.  Opening draws a few rows per frame;
 * closing restores the original playfield tiles the same way. */
extern uint8_t pause_menu_state;
extern uint8_t pause_menu_bg_x;
extern uint8_t pause_menu_bg_y;

/* level is the current planet; max_level is the highest planet the player may
 * warp to (the saved highest level, or the current level when there is no
 * save). */
void pause_menu_open(uint8_t level, uint8_t max_level) BANKED;
/* Start the restore pass.  pause_menu_step() returns 1 when it completes.
 * Used after Start/B (resume) or A RESTART. */
void pause_menu_begin_close(void) BANKED;
/* Drop the menu without restoring (used when the level/title is about to be
 * rebuilt). */
void pause_menu_abort(void) BANKED;
/* Draw/open or restore a few rows.  Returns 1 on the frame a close finishes. */
uint8_t pause_menu_step(void) BANKED;
/* Handle input while paused.  Only A activates an item; Start/B ask to close. */
uint8_t pause_menu_update(uint8_t pad, uint8_t prev, uint8_t *warp_level) BANKED;

#endif /* SCREENS_H */
