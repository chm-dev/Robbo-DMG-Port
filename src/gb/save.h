#ifndef SAVE_H
#define SAVE_H

#include <gb/gb.h>
#include <stdint.h>

/* Simple battery-less save: the highest planet reached is stored in the
 * cartridge's external RAM (FRAM on the MidnightTrace board).  A record is
 * only written when a new highest level is reached, so starting a lower
 * planet never overwrites progress. */

#define SAVE_NO_LEVEL 0

/* Read the saved highest level.  Returns SAVE_NO_LEVEL (0) when no valid
 * record exists, or a value in 1..LEVEL_COUNT. */
uint8_t save_load(void) BANKED;

/* Store level if it is higher than the current record.  Returns the saved
 * level after the operation.  Level 1 is ignored, so a fresh record stays at
 * SAVE_NO_LEVEL until the player reaches level 2. */
uint8_t save_store(uint8_t level) BANKED;

/* Erase the record. */
void save_erase(void) BANKED;

#endif /* SAVE_H */
