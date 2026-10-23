/*
 * Smooth camera target and position helpers.
 *
 * The camera position lives in Q4 (1/16 px).  Main publishes a cell-aligned
 * goal using the classic 2-cell dead zone; the VBlank handler in render.c
 * eases the Q4 position toward it (see cam_ease_step).  Keeping this code out
 * of bank 0 pays for that VBlank handler.
 *
 * Q4 layout: one cell = 16 px = 256 Q4, so cell = q >> 8 and px = q >> 4.
 */
#pragma bank 15

#include <gb/gb.h>
#include <stdint.h>

#include "render.h"
#include "../core/game.h"

static uint8_t cam_goal_axis(uint8_t robbo, uint8_t goal,
                             uint8_t lo, uint8_t hi, uint8_t max)
{
    if (robbo < (uint8_t)(goal + lo)) {
        goal = (robbo >= lo) ? (uint8_t)(robbo - lo) : 0;
    } else if (robbo > (uint8_t)(goal + hi)) {
        goal = (uint8_t)(robbo - hi);
    }
    return (goal > max) ? max : goal;
}

static uint8_t cam_max_x(void)
{
    return MAP_W - VIEW_COLS;
}

static uint8_t cam_max_y(void)
{
    return (level_height > VIEW_ROWS) ? (uint8_t)(level_height - VIEW_ROWS) : 0;
}

/* Derive the cell origin and the pixel scroll from the Q4 position. */
static void cam_sync(void)
{
    cam_scx = (uint8_t)(cam_qx >> 4);
    cam_scy = (uint8_t)(cam_qy >> 4);
    cam_x = (uint8_t)(cam_qx >> 8);
    cam_y = (uint8_t)(cam_qy >> 8);
}

void render_camera_snap(void) BANKED
{
    cam_smooth = 0;
    cam_goal_x = cam_goal_axis(robbo_x, 0, 2, 7, cam_max_x());
    cam_goal_y = cam_goal_axis(robbo_y, 0, 2, 5, cam_max_y());
    cam_qx = (uint16_t)((uint16_t)cam_goal_x << 8);
    cam_qy = (uint16_t)((uint16_t)cam_goal_y << 8);
    cam_sync();
}

void render_camera_reset(void) BANKED
{
    cam_smooth = 0;
    cam_goal_x = 0;
    cam_goal_y = 0;
    cam_qx = 0;
    cam_qy = 0;
    cam_sync();
}

void render_camera_set_q(uint16_t qx, uint16_t qy) BANKED
{
    cam_qx = qx;
    cam_qy = qy;
    cam_sync();
}

void render_camera_pan_step(uint8_t dir) BANKED
{
    uint16_t max_qx = (uint16_t)((uint16_t)cam_max_x() << 8);
    uint16_t max_qy = (uint16_t)((uint16_t)cam_max_y() << 8);

    if (dir == 0) {
        cam_qx = (cam_qx + 256u > max_qx) ? max_qx : (uint16_t)(cam_qx + 256u);
    } else if (dir == 1) {
        cam_qy = (cam_qy + 256u > max_qy) ? max_qy : (uint16_t)(cam_qy + 256u);
    } else if (dir == 2) {
        cam_qx = (cam_qx >= 256u) ? (uint16_t)(cam_qx - 256u) : 0;
    } else {
        cam_qy = (cam_qy >= 256u) ? (uint16_t)(cam_qy - 256u) : 0;
    }
    cam_sync();
}

void render_camera(void) BANKED
{
    if (cam_override) {
        /* Teleport: pan one cell every other frame toward the arrival area. */
        cam_smooth = 0;
        if (cam_pan_timer < 2) {
            cam_pan_timer++;
            return;
        }
        cam_pan_timer = 0;

        if (cam_x < cam_target_x) cam_x++;
        else if (cam_x > cam_target_x) cam_x--;

        if (cam_y < cam_target_y) cam_y++;
        else if (cam_y > cam_target_y) cam_y--;

        cam_qx = (uint16_t)((uint16_t)cam_x << 8);
        cam_qy = (uint16_t)((uint16_t)cam_y << 8);
        /* Keep the goal with the override position: when the arrival clears
         * cam_override the normal ease must not pull the view back. */
        cam_goal_x = cam_x;
        cam_goal_y = cam_y;
        cam_sync();
        return;
    }

    /* Hysteresis is measured against the goal, not the transient Q4 position,
     * so a direction change during a glide cannot make the view wobble. */
    cam_goal_x = cam_goal_axis(robbo_x, cam_goal_x, 2, 7, cam_max_x());
    cam_goal_y = cam_goal_axis(robbo_y, cam_goal_y, 2, 5, cam_max_y());
    cam_smooth = 1;
}
