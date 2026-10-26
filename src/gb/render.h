#ifndef RENDER_H
#define RENDER_H

#include <stdint.h>
#include <gbdk/platform.h>
#include "platform_compat.h"

void render_init(void);
void render_restore_tiles(void);
void render_set_wall_style(uint8_t cell);
void render_set_level_palette(uint8_t level);
uint8_t render_level_background(void);
/* Row-ring slot -> source level row, managed by render_sync_rows().  The
 * level-intro module (bank 13) paints columns directly and needs this map. */
extern uint8_t map_row_level[];
void render_intro_clear_dirty(void);
/* Spawn-cell override while the intro owns the level:
 *   0 = normal Robbo, 1 = waiting capsule,
 *   2..5 = explosion frames 0..3 (Atari $02/$04/$06/$08), then Robbo.
 * Robbo stays in map_type[] the whole time; only the metatile is substituted. */
extern uint8_t render_robbo_spawn;
void render_hud(void) BANKED;
void render_flash_set(uint8_t on);
void render_camera(void) BANKED;
void render_camera_snap(void) BANKED;
void render_camera_reset(void) BANKED;
void render_camera_pan_step(uint8_t dir) BANKED;
void render_camera_set_q(uint16_t qx, uint16_t qy) BANKED;
void render_apply_camera(void);
void render_sync_rows(void);
void render_cell(uint8_t x, uint8_t y);
void render_flush_cells(void);
uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra);
/* CGB attribute byte used for a map cell (render.c).  Shared with the banked
 * intro column painter so entry/respawn keeps the wall colour variant. */
uint8_t render_cell_palette(uint8_t type, uint8_t extra, uint8_t mt);

#endif /* RENDER_H */
