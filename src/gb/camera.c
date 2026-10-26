/*
 * Smooth camera target and position helpers.
 *
 * The camera position lives in Q4 (1/16 px).  Main publishes a cell-aligned
 * goal that keeps Robbo on the view's center cell, clamped at the map edges;
 * the VBlank handler in render.c eases the Q4 position toward it (see
 * cam_ease_step).  Keeping this code out of bank 0 pays for that VBlank
 * handler.
 *
 * Q4 layout: one cell = 16 px = 256 Q4, so cell = q >> 8 and px = q >> 4.
 */
#pragma bank 15

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "render.h"
#include "../core/game.h"

/* Cell origin that puts `robbo` on the view's center cell.  Near the map
 * edges the goal clamps, so Robbo moves off-center instead of showing
 * outside the level. */
static uint8_t cam_center_goal(uint8_t robbo, uint8_t center, uint8_t max)
{
    uint8_t goal = (robbo > center) ? (uint8_t)(robbo - center) : 0;
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
    cam_goal_x = cam_center_goal(robbo_x, VIEW_CENTER_X, cam_max_x());
    cam_goal_y = cam_center_goal(robbo_y, VIEW_CENTER_Y, cam_max_y());
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

    /* Center Robbo every frame.  The VBlank ease turns the per-cell goal
     * changes into the smooth glide while the camera is not at a map edge. */
    cam_goal_x = cam_center_goal(robbo_x, VIEW_CENTER_X, cam_max_x());
    cam_goal_y = cam_center_goal(robbo_y, VIEW_CENTER_Y, cam_max_y());
    cam_smooth = 1;
}
