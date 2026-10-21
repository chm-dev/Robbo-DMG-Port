#ifndef RENDER_H
#define RENDER_H

#include <stdint.h>
#include <gb/gb.h>

void render_init(void);
void render_level(void);
void render_hud(void);
void render_pause(void) BANKED;
void render_victory(void) BANKED;
void render_flash_set(uint8_t on);
void render_camera(void);
void render_apply_camera(void);
void render_sync_rows(void);
void render_cell(uint8_t x, uint8_t y);
void render_flush_cells(void);
uint8_t render_metatile_for_cell(uint8_t type, uint8_t extra);

#endif /* RENDER_H */
