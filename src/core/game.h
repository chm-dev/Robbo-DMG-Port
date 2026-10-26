/*
 * Core game data model shared by the engine, generated level packs and the
 * renderer.
 */
#ifndef GAME_H
#define GAME_H

#include <stdint.h>

#define MAP_W 16
#define MAP_H 31
#define MAP_CELLS (MAP_W * MAP_H)
#define VIEW_COLS 10
#define VIEW_ROWS 8
/* View cell Robbo occupies when the camera can center him.  Both view
 * dimensions are even, so this picks the top-left of the two middle cells
 * (column 4 of 0..9, row 3 of 0..7). */
#define VIEW_CENTER_X ((VIEW_COLS - 1) / 2)
#define VIEW_CENTER_Y ((VIEW_ROWS - 1) / 2)
#define MAX_TELEPORTS 64
#define BONUS_WORDS ((MAP_CELLS + 7) / 8)

/* Actor list capacities.  The lists are filled by the banked collect_actors()
 * once per logic tick and consumed by the per-type loops in game_tick. */
#define MAX_TURRET_LIST 32
#define MAX_ENEMY_LIST 40
#define MAX_BOMB_LIST 160
#define MAX_EXPLOSION_LIST 496
#define MAX_MAGNET_LIST 16
#define MAX_SPACESHIP_LIST 8
#define MAX_TELEPORT_LIST 24

/* Cell type ids.  Generated level packs and the renderer depend on these
 * values; walls occupy 1..8 and encode their texture slot. */
enum {
    CT_EMPTY = 0,
    CT_WALL_0 = 1,
    CT_WALL_1 = 2,
    CT_WALL_2 = 3,
    CT_WALL_3 = 4,
    CT_WALL_4 = 5,
    CT_WALL_5 = 6,
    CT_WALL_6 = 7,
    CT_WALL_7 = 8,
    CT_GROUND = 9,
    CT_STONE = 10,
    CT_PUSHABLE = 11,
    CT_DOOR = 12,
    CT_SPACESHIP = 13,
    CT_QUESTION = 14,
    CT_BOMB = 15,
    CT_KEY = 16,
    CT_SCREW = 17,
    CT_TURRET = 18,
    CT_AMMO = 19,
    CT_TELEPORT = 20,
    CT_MUSTACHE = 21,
    CT_BUTTERFLY = 22,
    CT_BEAR = 23,
    CT_LAVA = 24,
    CT_MAGNET = 25,
    CT_ROBBO = 26,
    CT_BULLET = 27,
    CT_EXPLOSION = 28,
    CT_EXTRA_LIFE = 29,
    CT_BARRIER = 30,
};

#define IS_WALL(t) ((t) >= CT_WALL_0 && (t) <= CT_WALL_7)
#define WALL_SLOT(t) ((t) - CT_WALL_0)

/* WRAM state.  map_type is authoritative for collision; map_obj holds the
 * object-pool index plus one (0 = no object). */
extern uint8_t map_type[MAP_CELLS];
extern uint8_t map_extra[MAP_CELLS];
extern uint8_t map_obj[MAP_CELLS];

/* Per-type actor lists and counts, rebuilt each logic tick by the banked
 * collect_actors().  Stale entries are tolerated: consumers re-check map_type
 * before acting. */
extern uint16_t turret_list[MAX_TURRET_LIST];
extern uint16_t enemy_list[MAX_ENEMY_LIST];
extern uint16_t bomb_list[MAX_BOMB_LIST];
extern uint16_t explosion_list[MAX_EXPLOSION_LIST];
extern uint16_t magnet_list[MAX_MAGNET_LIST];
extern uint16_t spaceship_list[MAX_SPACESHIP_LIST];
extern uint16_t teleport_list[MAX_TELEPORT_LIST];
extern uint8_t turret_count;
extern uint8_t enemy_count;
extern uint8_t bomb_count;
extern uint16_t explosion_count;
extern uint8_t magnet_count;
extern uint8_t spaceship_count;
extern uint8_t teleport_count;
/* One bit per map row containing at least one live barrier cell. */
extern uint16_t barrier_row_lo;
extern uint16_t barrier_row_hi;

extern uint16_t teleport_dest[MAX_TELEPORTS];
extern uint8_t level_height;
extern uint8_t level_screw;
extern uint8_t level_planet;
extern uint8_t level_teleport_count;
/* Source-sheet cell index for the current four-level wall style. */
extern uint8_t level_wall_cell;
/* Hidden extra-life easter-egg cells; their map_type is converted to empty. */
extern uint8_t bonus_bits[BONUS_WORDS];

extern uint8_t robbo_x;
extern uint8_t robbo_y;
extern uint8_t robbo_dir;
extern uint8_t screws_left;
extern uint8_t ammo;
extern uint8_t keys;
/* Smooth camera.  cam_qx/cam_qy are Q4 (1/16 px) absolute positions, kept by
 * the VBlank handler while cam_smooth is set.  cam_x/cam_y are the derived
 * cell origin used by the row ring, the teleport check and the tests.
 * cam_goal_x/y are the centered target in cells; cam_scx/scy are the pixel
 * scroll values applied to SCX/SCY. */
extern volatile uint16_t cam_qx;
extern volatile uint16_t cam_qy;
extern volatile uint8_t cam_x;
extern volatile uint8_t cam_y;
extern volatile uint8_t cam_goal_x;
extern volatile uint8_t cam_goal_y;
extern volatile uint8_t cam_smooth;
extern volatile uint8_t cam_scx;
extern volatile uint8_t cam_scy;
extern uint8_t debug_pad;
extern uint16_t debug_ticks;
extern uint8_t hud_dirty;
extern uint8_t robbo_busy;
extern uint8_t robbo_no_move;
extern uint8_t game_restart_requested;
extern uint8_t game_level_advance_requested;
extern uint8_t cam_override;
extern uint8_t anim_frame;
/* Toggles every other logic tick; drives bullets, the capsule and teleports. */
extern uint8_t anim_slow;
/* Split-tick phase counter: 0 idle, 1..4 the phase game_tick_step() runs next.
 * The main loop arms a tick by writing 1, then calls game_tick_step() once per
 * frame to amortize the tick over several frames. */
extern uint8_t tick_phase;
/* Frames left in the current step.  The walk pose is shown while this is
 * non-zero; when it expires Robbo redraws in the neutral frame.  Mirrors the
 * GBC renderer's `robbo.moved > 0 ? walk : neutral` rule. */
#define ROBBO_STEP_ANIM_FRAMES 3
extern uint8_t robbo_step_timer;
extern uint8_t cam_target_x;
extern uint8_t cam_target_y;
extern uint8_t cam_pan_timer;

void game_load_level(uint8_t level);
/* Reload the current planet after a death.  Unlike game_load_level() this
 * keeps the display on and leaves the wiped screen in place so the intro can
 * repaint it and pan from the death view back to Robbo's start. */
void game_respawn_level(uint8_t level);
/* Load the next level after the NXCV column-clear.  The screen is already
 * empty, so no display-off/bulk draw is needed. */
void game_load_level_after_clear(uint8_t level);
/* Set while the level-complete clear is running.  Main drives it with
 * intro_clear_tick() and then requests the level advance. */
extern uint8_t game_transition_active;
void game_tick_step(void);
/* Rebuild the per-type actor lists by scanning the map once.  Banked to keep
 * bank 0's budget; called once per logic tick. */
void collect_actors(void) BANKED;
/* One per rendered frame: advances frame-rate animation timers. */
void game_frame(void);
uint8_t game_try_move(uint8_t dir);
uint8_t game_fire(void);
void game_face(uint8_t dir);
void game_check_enemies(void);
void game_teleport_camera_ready(void);
/* Resolve the landing cell for a teleport.  Walks the whole linked group in
 * scan order (bank 14), so a blocked destination skips to the next member and
 * a fully blocked group teleports in place. */
uint16_t game_teleport_find_next(uint16_t entry_idx, uint16_t dest_idx) BANKED;
/* Barrier/ZAPO sweep helper: destroy/consume whatever the moving field is
 * about to cover.  Lives in bank 0 because the destruction helpers are static
 * here; the barrier wave itself is banked (barrier.c). */
void game_barrier_hit(uint16_t idx) BANKED;
/* Shared destruction helpers (bank 0); banked object code calls these. */
uint8_t is_demolishable(uint8_t type);
void demolish_cell(uint16_t idx);
void blast_cell(uint16_t idx, uint8_t timer);
void kill_robbo(void);
/* Start/refresh an explosion animation in one cell.  Shared with the banked
 * projectile code, which leaves its fading trail behind. */
void spawn_explosion_timer(uint16_t idx, uint8_t timer);

#endif /* GAME_H */
