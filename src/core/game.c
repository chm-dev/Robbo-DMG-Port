#include <gb/gb.h>
#include <stdint.h>

#include "game.h"
#include "../gen/levels.h"
#include "../gen/tiles.h"
#include "../gb/intro.h"
#include "../gb/render.h"
#include "../gb/sound.h"
#include "../gb/variants.h"

uint16_t bear_step(uint16_t idx, uint8_t state) BANKED;
uint16_t blaster_step(uint16_t bidx, uint8_t extra) BANKED;
void barrier_tick(uint16_t row_lo, uint16_t row_hi, uint8_t animate) BANKED;

/* Retained effects from the previous sound set.  The new sound-port2 set
 * removed EXPLOSION and DESTRUCT, so these keep the old SfxDef rendering.
 * DOOR OPEN now uses the GBC CH3 wave conversion via sfx_play_note().
 *
 * DESTROY is tuned below the sound-port2 preset: pitch_q8 406 drops the
 * attack roughly six semitones (the nearest DMG noise rate from 512),
 * master 2 keeps the attack peak at 5/15, and env 5 with step_frames 3
 * stretches the hit to a little over the Atari DESTRUCT note 10 (~560 ms).
 * The 5-step attack uses attack_env 3, so its rising envelope reaches only
 * the 5/15 peak instead of blipping to full volume before the decay. */
static const SfxDef sfx_destroy   = { 17, 0, 16, 406, 3, 0, 0, 0, 0, 0, 0, 0, 1, 5, 5, 3, 2 };
const SfxDef sfx_explosion = { 16, 0, 16, 16, 4, 0, 0, 0, 0, 0, 0, 0, 1, 4 };

uint8_t map_type[MAP_CELLS];
uint8_t map_extra[MAP_CELLS];
uint8_t map_obj[MAP_CELLS];

uint16_t teleport_dest[MAX_TELEPORTS];
uint8_t level_height;
uint8_t level_screw;
uint8_t level_planet;
uint8_t level_teleport_count;

uint8_t robbo_x;
uint8_t robbo_y;
uint8_t robbo_dir;
uint8_t screws_left;
uint8_t ammo;
uint8_t keys;
volatile uint16_t cam_qx;
volatile uint16_t cam_qy;
volatile uint8_t cam_x;
volatile uint8_t cam_y;
volatile uint8_t cam_goal_x;
volatile uint8_t cam_goal_y;
volatile uint8_t cam_smooth;
volatile uint8_t cam_scx;
volatile uint8_t cam_scy;
uint8_t debug_pad;
uint16_t debug_ticks;
uint8_t hud_dirty;
uint8_t robbo_busy;
uint8_t robbo_no_move;
static uint16_t magnet_field;
uint8_t cam_override;
uint8_t cam_target_x;
uint8_t cam_target_y;
uint8_t cam_pan_timer;
uint8_t anim_frame;
uint8_t anim_slow;
uint8_t robbo_step_timer;
uint8_t level_wall_cell;
uint8_t bonus_bits[BONUS_WORDS];

#define MAX_SLIDING 32
static uint16_t sliding_boxes[MAX_SLIDING];
static uint8_t sliding_count;

#define MAX_BULLETS 96
static uint16_t bullet_cells[MAX_BULLETS];
#define MAX_TURRET_LIST 32
#define MAX_ENEMY_LIST 40
#define MAX_BOMB_LIST 160
#define MAX_EXPLOSION_LIST 496
#define MAX_MAGNET_LIST 16
#define MAX_SPACESHIP_LIST 8
#define MAX_TELEPORT_LIST 24
static uint16_t turret_list[MAX_TURRET_LIST];
static uint16_t enemy_list[MAX_ENEMY_LIST];
static uint16_t bomb_list[MAX_BOMB_LIST];
static uint16_t explosion_list[MAX_EXPLOSION_LIST];
static uint16_t magnet_list[MAX_MAGNET_LIST];
static uint16_t spaceship_list[MAX_SPACESHIP_LIST];
static uint16_t teleport_list[MAX_TELEPORT_LIST];
static uint8_t turret_count;
static uint8_t enemy_count;
static uint8_t bomb_count;
static uint16_t explosion_count;
static uint8_t magnet_count;
static uint8_t spaceship_count;
static uint8_t teleport_count;
static uint8_t bullet_count;
/* Rows containing at least one live barrier cell, one bit per row (0..15 and
 * 16..30).  Filled by collect_actors() and consumed by the banked barrier
 * sweep, so the hot map scan pays only one bit-set per barrier cell. */
static uint16_t barrier_row_lo;
static uint16_t barrier_row_hi;
#define BULLET_LASER_WAIT   1
#define BULLET_LASER_RETURN 2
static uint8_t fire_delay = 0;
static uint8_t explosion_sfx_started = 0;
static uint8_t teleport_phase = 0; /* 0 idle, 1 panning, 2 arriving */
static uint16_t teleport_to = 0;

static uint8_t robbo_dead = 0;
static uint8_t death_timer = 0;
static uint8_t death_wipe_timer = 0;
static uint8_t screen_flash_ticks = 0;
/* Atari NXCV: the finished room is cleared column by column while the display
 * stays on, then the next level is loaded and painted in. */
uint8_t game_transition_active = 0;
/* One-shot marker for game_respawn_level(); consumed by game_load_level(). */
static uint8_t respawn_load = 0;
/* One-shot marker for game_load_level_after_clear(). */
static uint8_t transition_load = 0;
/* Atari LSTE: the planet where the hidden extra life was last collected.  A
 * respawn on that planet suppresses its '+' marker again. */
static uint8_t bonus_taken_level = 0;
uint8_t game_restart_requested = 0;
uint8_t game_level_advance_requested = 0;

#define QUESTION_UNROLLED 0xFF

void spawn_explosion_timer(uint16_t idx, uint8_t timer);
void kill_robbo(void);
static void game_teleport(uint16_t entry_idx);
static void teleport_arrive(uint16_t idx);
static void destroy_teleport(uint16_t idx);

/* Death respawn: the map is reloaded while the display stays on, then the
 * intro repaints the wiped room and pans back to Robbo's start. */
void game_respawn_level(uint8_t level)
{
    respawn_load = 1;
    game_load_level(level);
}

/* Level-complete path: the NXCV clear has already emptied the screen, so the
 * next level can be loaded without turning the display off. */
void game_load_level_after_clear(uint8_t level)
{
    transition_load = 1;
    game_load_level(level);
}

void game_load_level(uint8_t level)
{
    uint16_t i;
    uint8_t x, y;
    uint16_t entry_qx = 0;
    uint16_t entry_qy = 0;
    uint8_t from_death = respawn_load;
    uint8_t from_transition = transition_load;

    respawn_load = 0;
    transition_load = 0;

    if (level == 0) level = 1;
    if (level > LEVEL_COUNT) level = LEVEL_COUNT;

    if (from_death || from_transition) {
        /* Keep the view where the previous level ended: PLA1 leaves DLSA at
         * the exit, and only SETU (a fresh boot/level load) writes SCRN.  The
         * snapshot is atomic because the VBlank ISR may update half of the
         * Q4 pair. */
        __critical {
            entry_qx = cam_qx;
            entry_qy = cam_qy;
        }
    }

    /* Freeze the VBlank ease while the level is rebuilt; the intro starts it
     * again after the playfield has been painted. */
    cam_smooth = 0;

    load_level_data(level);

    /* One wall texture per four-level block, loaded from the full sheet.  A
     * respawn is the same planet, so the dynamic metatile is already resident;
     * an after-clear transition defers it to the intro's first VBlank slice.
     * Both keep bulk VRAM writes out of the display-on load. */
    level_wall_cell = wall_rotation_cells[(uint8_t)((level - 1) >> 2)];
    render_set_level_palette(level);
    {
        uint8_t bg = render_level_background();
        uint8_t mask = 0;
        /* Projectiles: white on a dark gray floor, darker on a white floor. */
        if (bg == 0 || bg == 2) mask |= VAR_BULLETS_ALT;
        if (bg == 3) mask |= VAR_BADDIES_BRIGHT;
        /* A fresh/debug load runs with the display off.  Respawn/transition
         * keep it on, so the intro uploads the variants in VBlank slices. */
        variants_request(mask, (uint8_t)(!from_death && !from_transition));
    }
    if (!from_death && !from_transition) {
        render_set_wall_style(level_wall_cell);
    }

    for (i = 0; i < BONUS_WORDS; i++) {
        bonus_bits[i] = 0;
    }
    for (i = 0; i < MAP_CELLS; i++) {
        map_obj[i] = 0;
        if (map_type[i] == CT_EXTRA_LIFE) {
            /* Invisible easter egg: empty for every actor, but Robbo's entry
             * triggers the bonus.  Scan the full array, including rows past
             * the current height (some Atari bonuses sit on the bottom row).
             * Atari LSTE keeps it consumed when the same planet is reloaded
             * after a death; only a different planet re-arms it. */
            if (bonus_taken_level != level) {
                bonus_bits[i >> 3] |= (uint8_t)(1u << (i & 7));
            }
            map_type[i] = CT_EMPTY;
            map_extra[i] = 0;
        }
    }

    robbo_x = 2;
    robbo_y = 2;
    robbo_dir = 1;
    for (y = 0; y < level_height; y++) {
        for (x = 0; x < MAP_W; x++) {
            uint16_t idx = y * MAP_W + x;
            if (map_type[idx] == CT_ROBBO) {
                robbo_x = x;
                robbo_y = y;
                robbo_dir = map_extra[idx] & 3;
            } else if (map_type[idx] == CT_QUESTION) {
                map_extra[idx] = QUESTION_UNROLLED;
            }
        }
    }

    screws_left = level_screw;
    ammo = 0;
    keys = 0;
    sliding_count = 0;
    bullet_count = 0;
    fire_delay = 0;
    explosion_sfx_started = 0;
    robbo_busy = 0;
    robbo_no_move = 0;
    magnet_field = 0;
    teleport_phase = 0;
    teleport_to = 0;
    cam_override = 0;
    cam_pan_timer = 0;
    robbo_dead = 0;
    death_timer = 0;
    death_wipe_timer = 0;
    game_restart_requested = 0;
    game_level_advance_requested = 0;
    screen_flash_ticks = 0;
    game_transition_active = 0;
    anim_frame = 0;
    anim_slow = 0;
    robbo_step_timer = 0;
    render_flash_set(0);

    /* render_camera_snap() publishes the start-centered goal used by the end
     * of the intro's pan.  A fresh boot/debug load starts at the top-left of
     * the cave (Atari SETU writes SCRN into DLSA); a death respawn and a
     * level-complete transition start at the camera position where the
     * previous view ended (PLA1 leaves DLSA untouched). */
    render_camera_snap();
    if (from_death || from_transition) {
        render_camera_set_q(entry_qx, entry_qy);
        hud_dirty = 1;
    } else {
        render_camera_set_q(0, 0);
        render_apply_camera();
        /* The display is off for a new level, so the HUD can be published now;
         * the intro will paint the playfield in from an empty map. */
        render_hud();
        hud_dirty = 0;
    }
    cam_smooth = 0;

    /* Fill the legacy SFX conversion cache while the display is off: the
     * first explosion or destroyed tile must not pay those divisions
     * mid-gameplay.  Re-loading a level is nearly free because the memo
     * entries are already present. */
    sfx_prewarm_def(&sfx_explosion);
    sfx_prewarm_def(&sfx_destroy);

    /* The entry jingle now plays from the intro once the camera has settled
     * on the spawn cell (Atari WFAC), not at the instant the map is loaded. */
    if (from_death) {
        intro_begin(INTRO_MODE_RESPAWN);
    } else if (from_transition) {
        intro_begin(INTRO_MODE_AFTER_CLEAR);
    } else {
        intro_begin(INTRO_MODE_NEW);
    }
}

uint8_t is_demolishable(uint8_t type)
{
    /* Matches the JS objects that define demolishable: true.  Keys, screws,
     * doors and stones are explodable but not demolishable, so a sliding box
     * stops against them. */
    switch (type) {
        case CT_GROUND:
        case CT_AMMO:
        case CT_BOMB:
        case CT_QUESTION:
        case CT_BEAR:
        case CT_BUTTERFLY:
        case CT_MUSTACHE:
        case CT_BARRIER:
            return 1;
        default:
            return 0;
    }
}

static uint8_t is_explodable(uint8_t type)
{
    switch (type) {
        case CT_GROUND:
        case CT_STONE:
        case CT_PUSHABLE:
        case CT_DOOR:
        case CT_QUESTION:
        case CT_BOMB:
        case CT_KEY:
        case CT_SCREW:
        case CT_TURRET:
        case CT_AMMO:
        case CT_TELEPORT:
        case CT_MUSTACHE:
        case CT_BUTTERFLY:
        case CT_BEAR:
        case CT_LAVA:
        case CT_EXTRA_LIFE:
        case CT_BARRIER:
            return 1;
        default:
            return 0;
    }
}

static uint16_t rng_state = 0xACE1u;

static uint8_t next_rand8(void)
{
    rng_state ^= (uint16_t)(rng_state << 7);
    rng_state ^= (uint16_t)(rng_state >> 9);
    rng_state ^= (uint16_t)(rng_state << 8);
    return (uint8_t)(rng_state & 0xFF);
}

/* Question payloads are rolled on first hit rather than kept from the level
 * data.  Mix in the DIV/frame counters so repeated hits do not reuse the same
 * short xorshift sequence. */
static uint8_t random_question_payload(void)
{
    rng_state ^= (uint16_t)DIV_REG;
    rng_state ^= (uint16_t)((uint16_t)debug_ticks * 0x9E37u);
    if (rng_state == 0) rng_state = 0xACE1u;
    return (uint8_t)(next_rand8() % 11);
}

static void add_sliding(uint16_t idx)
{
    uint8_t i;
    if (sliding_count >= MAX_SLIDING) return;
    for (i = 0; i < sliding_count; i++) {
        if (sliding_boxes[i] == idx) return;
    }
    sliding_boxes[sliding_count++] = idx;
}

static void remove_sliding(uint8_t i)
{
    sliding_boxes[i] = sliding_boxes[--sliding_count];
}

static void refresh_spaceships(void)
{
    uint8_t x, y;
    for (y = 0; y < level_height; y++) {
        for (x = 0; x < MAP_W; x++) {
            if (map_type[y * MAP_W + x] == CT_SPACESHIP) {
                render_cell(x, y);
            }
        }
    }
}

static void move_robbo_to(uint8_t nx, uint8_t ny, uint8_t dir)
{
    uint16_t old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
    uint16_t new_idx = (uint16_t)ny * MAP_W + nx;

    map_type[old_idx] = CT_EMPTY;
    map_extra[old_idx] = 0;
    map_type[new_idx] = CT_ROBBO;
    map_extra[new_idx] = dir;

    /* GBC rule: the walk frame is `moving ? 1 : 0`, not a persistent flip.
     * Show it for the first half of the move-repeat period, then return to
     * the neutral frame when the timer expires in game_frame(). */
    robbo_step_timer = ROBBO_STEP_ANIM_FRAMES;

    render_cell(robbo_x, robbo_y);
    robbo_x = nx;
    robbo_y = ny;
    robbo_dir = dir;
    render_cell(robbo_x, robbo_y);
}

static void collect_bonus(uint16_t idx)
{
    bonus_bits[idx >> 3] &= (uint8_t)~(1u << (idx & 7));
    /* Atari LSTE: remember the planet so ENTCV does not draw the '+' again
     * after a death on this same level. */
    bonus_taken_level = level_planet;
    /* Easter egg: the hidden extra-life cell uses the last-bolt flash and the
     * extra-life jingle, but awards nothing. */
    screen_flash_ticks = 1;
    render_flash_set(1);
    sfx_play_note(SFX_EXTRA_LIFE);
}

static const int8_t tp_dx[4] = { 1, 0, -1, 0 };
static const int8_t tp_dy[4] = { 0, 1, 0, -1 };

#define TELEPORT_NONE 0xFFFF

static uint16_t teleport_scan(uint16_t base, uint8_t *pdir)
{
    uint8_t i;
    uint8_t dir = *pdir;
    uint8_t bx = base % MAP_W;
    uint8_t by = base / MAP_W;

    for (i = 0; i < 4; i++) {
        int16_t nx = (int16_t)bx + tp_dx[dir];
        int16_t ny = (int16_t)by + tp_dy[dir];
        if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
            uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
            if (map_type[nidx] == CT_EMPTY) {
                *pdir = dir;
                return nidx;
            }
        }
        dir ^= (uint8_t)(3 - (i & 1));
    }

    *pdir = dir;
    return TELEPORT_NONE;
}

static uint16_t teleport_find_next(uint16_t entry_idx, uint16_t dest_idx)
{
    uint8_t dir = robbo_dir;
    uint16_t candidate;

    /* Search around the linked destination teleport. */
    candidate = teleport_scan(dest_idx, &dir);
    if (candidate != TELEPORT_NONE && map_type[dest_idx] == CT_TELEPORT) {
        robbo_dir = dir;
        return candidate;
    }

    /* Orphan link or blocked destination: fall back to the entry teleport. */
    candidate = teleport_scan(entry_idx, &dir);
    robbo_dir = dir;
    return candidate;
}

static void game_teleport(uint16_t entry_idx)
{
    uint16_t dest_idx;
    uint16_t to;
    uint16_t old_idx;
    uint8_t table_idx;

    if (robbo_busy) return;

    table_idx = map_extra[entry_idx];
    if (table_idx >= level_teleport_count) return;
    dest_idx = teleport_dest[table_idx];

    to = teleport_find_next(entry_idx, dest_idx);
    if (to == TELEPORT_NONE) return;

    old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
    robbo_busy = 1;
    teleport_phase = 1;
    teleport_to = to;

    map_type[old_idx] = CT_EXPLOSION;
    map_extra[old_idx] = 2;
    render_cell(robbo_x, robbo_y);

    /* Move the camera to the arrival area before Robbo reappears. */
    {
        uint8_t tx = to % MAP_W;
        uint8_t ty = to / MAP_W;
        uint8_t max_x = MAP_W - VIEW_COLS;
        uint8_t max_y = (level_height > VIEW_ROWS) ? (level_height - VIEW_ROWS) : 0;

        cam_target_x = (tx > VIEW_CENTER_X) ? (uint8_t)(tx - VIEW_CENTER_X) : 0;
        cam_target_y = (ty > VIEW_CENTER_Y) ? (uint8_t)(ty - VIEW_CENTER_Y) : 0;
        if (cam_target_x > max_x) cam_target_x = max_x;
        if (cam_target_y > max_y) cam_target_y = max_y;
        cam_override = 1;
        cam_pan_timer = 0;
    }

    sfx_play_note(SFX_TELEPORT);
}

void game_teleport_camera_ready(void)
{
    if (teleport_phase != 1) return;
    if (cam_x != cam_target_x || cam_y != cam_target_y) return;

    teleport_phase = 2;

    map_type[teleport_to] = CT_EXPLOSION;
    map_extra[teleport_to] = (uint8_t)((12 << 3) | 2);
    render_cell(teleport_to % MAP_W, teleport_to / MAP_W);
}

static void teleport_arrive(uint16_t idx)
{
    teleport_phase = 0;
    cam_override = 0;
    robbo_x = idx % MAP_W;
    robbo_y = idx / MAP_W;
    map_type[idx] = CT_ROBBO;
    map_extra[idx] = robbo_dir;
    robbo_busy = 0;
    robbo_no_move = 0;
    magnet_field = 0;
    render_cell(robbo_x, robbo_y);
}

static void destroy_teleport(uint16_t idx)
{
    uint16_t i;
    uint8_t table_idx = map_extra[idx];
    uint16_t new_dest;

    if (table_idx >= level_teleport_count) {
        spawn_explosion_timer(idx, 3);
        return;
    }

    new_dest = teleport_dest[table_idx];

    /* Retarget teleports that linked to this cell. */
    for (i = 0; i < MAP_CELLS; i++) {
        if (map_type[i] == CT_TELEPORT) {
            if (teleport_dest[map_extra[i]] == idx) {
                teleport_dest[map_extra[i]] = new_dest;
            }
        }
    }

    spawn_explosion_timer(idx, 3);
}

uint8_t game_try_move(uint8_t dir)
{
    uint8_t nx = robbo_x;
    uint8_t ny = robbo_y;
    uint8_t target;
    uint16_t old_idx;
    uint16_t new_idx;

    if (robbo_busy || robbo_no_move) return 0;

    if (dir == 0) {
        nx++;
    } else if (dir == 1) {
        ny++;
    } else if (dir == 2) {
        if (nx > 0) nx--;
    } else {
        if (ny > 0) ny--;
    }

    old_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
    robbo_dir = dir;
    map_extra[old_idx] = dir;  /* face the direction even when blocked */

    if (nx >= MAP_W || ny >= level_height) {
        render_cell(robbo_x, robbo_y);
        return 0;
    }

    new_idx = (uint16_t)ny * MAP_W + nx;
    target = map_type[new_idx];

    if (target == CT_TELEPORT) {
        game_teleport(new_idx);
        return 0;
    }

    if (target == CT_EMPTY) {
        if (bonus_bits[new_idx >> 3] & (uint8_t)(1u << (new_idx & 7))) {
            collect_bonus(new_idx);
        }
        move_robbo_to(nx, ny, dir);
        return 1;
    }

    if (target == CT_SCREW) {
        /* controller.set('screw', ...) clamps at zero: a bolt from a question
         * is not added to the level total when it appears, so collecting it
         * still takes one off the HUD counter. */
        uint8_t was_last = (screws_left == 1);
        if (screws_left > 0) screws_left--;
        map_type[new_idx] = CT_EMPTY;
        map_extra[new_idx] = 0;
        hud_dirty = 1;
        if (was_last) {
            screen_flash_ticks = 1;
            render_flash_set(1);
            refresh_spaceships();
        }
        move_robbo_to(nx, ny, dir);
        /* The last bolt uses the GBC capsule-open jingle. */
        sfx_play_note(was_last ? SFX_LAST_BOLT : SFX_BOLT);
        return 1;
    }

    if (target == CT_AMMO) {
        ammo += 9;
        if (ammo > 99) ammo = 99;
        map_type[new_idx] = CT_EMPTY;
        map_extra[new_idx] = 0;
        hud_dirty = 1;
        move_robbo_to(nx, ny, dir);
        sfx_play_note(SFX_AMMO);
        return 1;
    }

    if (target == CT_EXTRA_LIFE) {
        /* Fallback for directly injected bonus cells; level loading normally
         * converts them to empty + bonus_bits. */
        map_type[new_idx] = CT_EMPTY;
        map_extra[new_idx] = 0;
        collect_bonus(new_idx);
        move_robbo_to(nx, ny, dir);
        return 1;
    }

    if (target == CT_KEY) {
        keys++;
        if (keys > 99) keys = 99;
        map_type[new_idx] = CT_EMPTY;
        map_extra[new_idx] = 0;
        hud_dirty = 1;
        move_robbo_to(nx, ny, dir);
        sfx_play_note(SFX_KEY);
        return 1;
    }

    if (target == CT_DOOR) {
        if (keys > 0) {
            keys--;
            map_type[new_idx] = CT_EMPTY;
            map_extra[new_idx] = 0;
            hud_dirty = 1;
            render_cell(nx, ny);
            sfx_play_note(SFX_DOOR);
        }
        /* Door.eat() returns false: Robbo stays put for this tick. */
        render_cell(robbo_x, robbo_y);
        return 0;
    }

    if (target == CT_SPACESHIP) {
        if (screws_left == 0 || (map_extra[new_idx] & 1)) {
            uint16_t robbo_idx = (uint16_t)robbo_y * MAP_W + robbo_x;
            map_type[robbo_idx] = CT_EMPTY;
            map_extra[robbo_idx] = 0;
            render_cell(robbo_x, robbo_y);
            robbo_busy = 1;
            game_transition_active = 1;
            intro_clear_begin();
            sfx_play_note(SFX_LEVEL_END);
            return 0;
        }
        /* Inactive capsule is movable: fall through to the push block. */
    }

    if (target == CT_STONE || target == CT_PUSHABLE ||
        target == CT_SPACESHIP || target == CT_BOMB || target == CT_QUESTION) {
        uint8_t bx = nx;
        uint8_t by = ny;
        uint8_t moved_extra = map_extra[new_idx];
        uint16_t beyond_idx;

        if (dir == 0) bx++;
        else if (dir == 1) by++;
        else if (dir == 2) { if (bx > 0) bx--; }
        else { if (by > 0) by--; }

        if (bx >= MAP_W || by >= level_height) {
            render_cell(robbo_x, robbo_y);
            return 0;
        }

        beyond_idx = (uint16_t)by * MAP_W + bx;
        if (map_type[beyond_idx] != CT_EMPTY) {
            render_cell(robbo_x, robbo_y);
            return 0;
        }

        map_type[beyond_idx] = target;
        if (target == CT_PUSHABLE) {
            map_extra[beyond_idx] = dir | 4;
        } else {
            map_extra[beyond_idx] = moved_extra;
        }
        map_type[new_idx] = CT_EMPTY;
        map_extra[new_idx] = 0;

        render_cell(bx, by);
        render_cell(nx, ny);
        if (target == CT_PUSHABLE) add_sliding(beyond_idx);
        move_robbo_to(nx, ny, dir);
        sfx_play_note(SFX_PUSH);
        return 1;
    }

    render_cell(robbo_x, robbo_y);
    return 0;
}

void spawn_explosion_timer(uint16_t idx, uint8_t timer)
{
    map_type[idx] = CT_EXPLOSION;
    map_extra[idx] = timer;
    render_cell(idx % MAP_W, idx / MAP_W);
}

static void spawn_explosion(uint16_t idx)
{
    spawn_explosion_timer(idx, 3);
}

static void spawn_payload_explosion_timer(uint16_t idx, uint8_t payload, uint8_t timer)
{
    map_type[idx] = CT_EXPLOSION;
    map_extra[idx] = (uint8_t)(((payload + 1) << 3) | timer);
    render_cell(idx % MAP_W, idx / MAP_W);
}

static void spawn_payload_explosion(uint16_t idx, uint8_t payload)
{
    spawn_payload_explosion_timer(idx, payload, 3);
}

/* Question.randomCfg payload order from robboJS/js/objects/Question.js. */
static uint8_t question_payload(uint16_t idx)
{
    uint8_t payload = map_extra[idx];

    if (payload == QUESTION_UNROLLED) {
        payload = random_question_payload();
        map_extra[idx] = payload;
    }
    return payload;
}

static void spawn_question_payload(uint16_t idx, uint8_t payload)
{
    uint8_t x = idx % MAP_W;
    uint8_t y = idx / MAP_W;
    uint8_t type = CT_EMPTY;
    uint8_t extra = 0;

    switch (payload) {
        case 0:  /* another Question: roll when it is hit */
            type = CT_QUESTION;
            extra = QUESTION_UNROLLED;
            break;
        case 1:  /* Spaceship from question */
            type = CT_SPACESHIP;
            extra = 1;
            break;
        case 2:  type = CT_STONE; break;
        case 3:  type = CT_GROUND; break;
        case 4:
            /* Screw.js only counts bolts while the level is loading; a bolt
             * revealed by a question is a bonus, so the HUD counter is not
             * increased here.  Collecting it decrements the counter. */
            type = CT_SCREW;
            break;
        case 5:  type = CT_KEY; break;
        case 6:  type = CT_AMMO; break;
        case 7:  /* Turret: random direction, gun, rotatable */
            type = CT_TURRET;
            extra = (uint8_t)((next_rand8() & 3) | 0x80);
            break;
        case 8:  type = CT_EMPTY; break;
        case 9:  type = CT_BOMB; break;
        case 10: type = CT_BUTTERFLY; break;
        default: type = CT_EMPTY; break;
    }

    map_type[idx] = type;
    map_extra[idx] = extra;
    render_cell(x, y);
}

void demolish_cell(uint16_t idx)
{
    uint8_t type = map_type[idx];

    if (type == CT_BOMB) {
        if (map_extra[idx] == 0) {
            map_extra[idx] = 2;  /* two logic ticks of fuse */
            render_cell(idx % MAP_W, idx / MAP_W);
        }
        return;
    }

    /* Every non-bomb demolition shows the perish animation, so it also uses
     * the retained DESTROY voice.  Bombs stay silent here: their fuse ends
     * with the retained explosion in bomb_explode().  Callers only invoke
     * this for demolishable cells. */
    if (type == CT_QUESTION) {
        spawn_payload_explosion(idx, question_payload(idx));
    } else if (is_demolishable(type)) {
        spawn_explosion(idx);
    }

    sfx_play_def(&sfx_destroy);
}

void blast_cell(uint16_t idx, uint8_t timer)
{
    uint8_t type = map_type[idx];

    if (type == CT_ROBBO) {
        kill_robbo();
        return;
    }

    if (type == CT_TELEPORT) {
        destroy_teleport(idx);
        return;
    }

    if (type == CT_BOMB) {
        if (map_extra[idx] == 0) {
            map_extra[idx] = 2;
            render_cell(idx % MAP_W, idx / MAP_W);
        }
        return;
    }

    if (type == CT_QUESTION) {
        spawn_payload_explosion_timer(idx, question_payload(idx), timer);
        return;
    }

    if (type == CT_EMPTY || type == CT_EXPLOSION) {
        spawn_explosion_timer(idx, timer);
        return;
    }

    if (is_explodable(type)) {
        spawn_explosion_timer(idx, timer);
    }
}

/* Barrier/ZAPO sweep hit lives in barrier.c (bank 14), where the wave needs
 * it; its destruction helpers are exported above. */

/* A chain can detonate several bombs in the same logic tick. Restarting the
 * effect repeatedly within that tick only replays step 0, so coalesce it to
 * one restart. A later tick still restarts, keeping every new blast audible. */
static void play_explosion_sfx(void)
{
    if (explosion_sfx_started) return;
    explosion_sfx_started = 1;
    sfx_restart_def(&sfx_explosion);
}

/* Bomb.exploding(): a 3x3 blast, with neighbouring bombs chained. */
static void bomb_explode(uint16_t idx)
{
    static const uint8_t blast_timer[9] = {
        5, 4, 5,
        4, 3, 2,
        5, 4, 5
    };
    uint8_t x = idx % MAP_W;
    uint8_t y = idx / MAP_W;
    int8_t dy, dx;

    spawn_explosion_timer(idx, 3);

    for (dy = -1; dy <= 1; dy++) {
        for (dx = -1; dx <= 1; dx++) {
            int16_t nx, ny;
            uint16_t nidx;
            uint8_t timer;
            if (dx == 0 && dy == 0) continue;
            nx = (int16_t)x + dx;
            ny = (int16_t)y + dy;
            if (nx < 0 || ny < 0 || nx >= MAP_W || ny >= level_height) continue;
            nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
            timer = blast_timer[(dy + 1) * 3 + (dx + 1)];
            blast_cell(nidx, timer);
        }
    }

    play_explosion_sfx();
}

static uint8_t bullet_make_extra(uint8_t dir, uint8_t type, uint8_t owner)
{
    return (uint8_t)((dir & 3) | ((type & 3) << 2) | ((owner & 1) << 4));
}

static uint8_t add_bullet(uint16_t idx, uint8_t dir, uint8_t type, uint8_t owner)
{
    if (bullet_count >= MAX_BULLETS) return 0;
    map_type[idx] = CT_BULLET;
    map_extra[idx] = bullet_make_extra(dir, type, owner);
    render_cell(idx % MAP_W, idx / MAP_W);
    bullet_cells[bullet_count++] = idx;
    return 1;
}

static void remove_bullet_at(uint8_t i)
{
    bullet_cells[i] = bullet_cells[--bullet_count];
}

static uint8_t player_bullet_active(void)
{
    uint8_t i;
    for (i = 0; i < bullet_count; i++) {
        uint16_t idx = bullet_cells[i];
        if (map_type[idx] == CT_BULLET && ((map_extra[idx] >> 4) & 1) == 0) {
            return 1;
        }
    }
    return 0;
}

/* Source restart(): after Robbo's own explosion has played, every map cell
 * that is neither Empty nor Walls is replaced by an Explosion.  The level is
 * reloaded six ticks later, so this is a visual wipe rather than loot or
 * bomb-chain logic.  Ground, teleports, the spaceship and live actors are all
 * consumed just like in the original.  The explosion effect restarts once for
 * the whole wipe; re-triggering it per cell would just restart it again. */
static void destroy_all_items(void)
{
    uint16_t idx;

    for (idx = 0; idx < MAP_CELLS; idx++) {
        uint8_t type = map_type[idx];

        if (type != CT_EMPTY && !IS_WALL(type)) {
            map_obj[idx] = 0;
            spawn_explosion_timer(idx, (uint8_t)(2 + (next_rand8() & 1)));
        }
    }

    play_explosion_sfx();
}

void kill_robbo(void)
{
    uint16_t idx;

    if (robbo_dead) return;

    robbo_dead = 1;
    robbo_busy = 1;
    /* Atari WYBC waits 48 jiffies before the room-wide explosion.  The logic
     * tick is 6 frames, so 8 ticks is 48 frames on the DMG. */
    death_timer = 8;
    death_wipe_timer = 0;

    idx = (uint16_t)robbo_y * MAP_W + robbo_x;
    map_type[idx] = CT_EXPLOSION;
    map_extra[idx] = 2;
    render_cell(robbo_x, robbo_y);
    sfx_play_def(&sfx_destroy);
}

static void turret_fire(uint16_t idx, uint8_t dir, uint8_t btype)
{
    uint8_t x = idx % MAP_W;
    uint8_t y = idx / MAP_W;
    uint8_t nx = x;
    uint8_t ny = y;
    uint8_t target;
    uint16_t nidx;

    if (dir == 0) nx++;
    else if (dir == 1) ny++;
    else if (dir == 2) { if (nx > 0) nx--; }
    else { if (ny > 0) ny--; }

    if (nx >= MAP_W || ny >= level_height) return;
    nidx = (uint16_t)ny * MAP_W + nx;
    target = map_type[nidx];

    if (target == CT_EMPTY) {
        add_bullet(nidx, dir, btype, 1);
    } else if (target == CT_ROBBO) {
        kill_robbo();
    } else if (is_demolishable(target)) {
        demolish_cell(nidx);
    }
}

#define TURRET_MOVED 1
#define TURRET_SHOT  2
#define TURRET_PROC  4

static void turret_tick(void)
{
    uint8_t i;
    uint16_t eidx;

    for (i = 0; i < turret_count; i++) {
        uint8_t extra, dir, mdir, btype, movable, rotatable, state, was_shot;
        uint16_t idx;

        eidx = turret_list[i];
        if (map_type[eidx] != CT_TURRET) continue;
        state = map_obj[eidx];

        extra = map_extra[eidx];
        dir = extra & 3;
        mdir = (extra >> 2) & 3;
        btype = (extra >> 4) & 3;
        movable = extra & 0x40;
        rotatable = extra & 0x80;
        was_shot = state & TURRET_SHOT;
        state &= (uint8_t)~TURRET_SHOT;
        idx = eidx;

        if (movable && !(state & TURRET_MOVED)) {
            uint8_t nx = eidx % MAP_W;
            uint8_t ny = eidx / MAP_W;

            if (mdir == 0) nx++;
            else if (mdir == 1) ny++;
            else if (mdir == 2) { if (nx > 0) nx--; }
            else { if (ny > 0) ny--; }

            if (nx < MAP_W && ny < level_height &&
                map_type[(uint16_t)ny * MAP_W + nx] == CT_EMPTY) {
                uint16_t nidx = (uint16_t)ny * MAP_W + nx;
                map_type[nidx] = CT_TURRET;
                map_extra[nidx] = extra;
                map_obj[nidx] = state | TURRET_MOVED;
                map_type[eidx] = CT_EMPTY;
                map_extra[eidx] = 0;
                map_obj[eidx] = 0;
                render_cell(eidx % MAP_W, eidx / MAP_W);
                render_cell(nx, ny);
                idx = nidx;
            } else {
                mdir = (mdir + 2) & 3;
                extra = (uint8_t)((extra & ~0x0C) | (mdir << 2));
                map_extra[eidx] = extra;
            }
            state |= TURRET_MOVED;
        } else {
            state &= (uint8_t)~TURRET_MOVED;
        }

        if (rotatable && (next_rand8() & 15) == 0) {
            int8_t delta = (int8_t)(next_rand8() % 3) - 1;
            dir = (uint8_t)((dir + delta + 4) & 3);
            extra = (uint8_t)((extra & ~3) | dir);
            map_extra[idx] = extra;
            render_cell(idx % MAP_W, idx / MAP_W);
        } else if ((next_rand8() % 12) == 0 && !was_shot) {
            state |= TURRET_SHOT;
            turret_fire(idx, dir, btype);
        }

        map_obj[idx] = state;
    }
}

#define ENEMY_PROC 0x80
#define BFLY_VALID 1
#define MUST_INNER_SKIP 1
#define MUST_JUST_SHOT 2

static void enemy_try_kill_at(uint8_t x, uint8_t y)
{
    uint8_t dx, dy;

    if (robbo_dead) return;
    if (map_type[(uint16_t)robbo_y * MAP_W + robbo_x] != CT_ROBBO) return;

    dx = (robbo_x > x) ? (robbo_x - x) : (x - robbo_x);
    dy = (robbo_y > y) ? (robbo_y - y) : (y - robbo_y);
    if (dx + dy == 1) {
        kill_robbo();
    }
}

static void enemy_check_kills(void)
{
    uint16_t idx;
    for (idx = 0; idx < MAP_CELLS; idx++) {
        uint8_t type = map_type[idx];
        if (type == CT_BEAR || type == CT_BUTTERFLY || type == CT_MUSTACHE) {
            enemy_try_kill_at(idx % MAP_W, idx / MAP_W);
        }
    }
}

static uint8_t dirs_contains(const uint8_t *dirs, uint8_t count, uint8_t dir)
{
    uint8_t i;
    for (i = 0; i < count; i++) {
        if (dirs[i] == dir) return 1;
    }
    return 0;
}

static uint16_t butterfly_step(uint16_t idx, uint8_t state)
{
    uint8_t extra = map_extra[idx];
    uint8_t dir = extra & 3;
    uint8_t dirs[4];
    uint8_t count = 0;
    uint8_t last;
    uint8_t x = idx % MAP_W;
    uint8_t y = idx / MAP_W;
    int16_t nx, ny;

    if (robbo_x < x) dirs[count++] = 2;
    if (robbo_x > x) dirs[count++] = 0;
    if (robbo_y < y) dirs[count++] = 3;
    if (robbo_y > y) dirs[count++] = 1;

    if (count == 0) {
        map_obj[idx] = state;
        return idx;
    }

    last = (state & BFLY_VALID) ? dir : 0xFF;

    if (((next_rand8() & 1) == 0) && last != 0xFF && dirs_contains(dirs, count, last)) {
        dir = last;
    } else if ((next_rand8() % 6) == 0) {
        dir = dirs[0];
        while (dirs_contains(dirs, count, dir)) {
            dir = next_rand8() & 3;
        }
    } else {
        dir = dirs[next_rand8() % count];
    }

    nx = (int16_t)x + tp_dx[dir];
    ny = (int16_t)y + tp_dy[dir];
    if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
        uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
        if (map_type[nidx] == CT_EMPTY) {
            map_type[nidx] = CT_BUTTERFLY;
            map_extra[nidx] = (uint8_t)((extra & ~3) | dir);
            map_obj[nidx] = (uint8_t)(state | BFLY_VALID);
            map_type[idx] = CT_EMPTY;
            map_extra[idx] = 0;
            map_obj[idx] = 0;
            render_cell(x, y);
            render_cell((uint8_t)nx, (uint8_t)ny);
            return nidx;
        }
    }

    state &= (uint8_t)~BFLY_VALID;
    map_obj[idx] = state;
    return idx;
}

static uint16_t mustache_step(uint16_t idx, uint8_t state)
{
    uint8_t extra = map_extra[idx];
    uint8_t dir = extra & 3;
    uint8_t was_shot = state & MUST_JUST_SHOT;
    uint8_t x = idx % MAP_W;
    uint8_t y = idx / MAP_W;
    uint16_t cur = idx;

    state &= (uint8_t)~MUST_JUST_SHOT;

    enemy_try_kill_at(x, y);
    if (robbo_dead) {
        map_obj[idx] = state;
        return idx;
    }

    if (state & MUST_INNER_SKIP) {
        state &= (uint8_t)~MUST_INNER_SKIP;
    } else {
        int16_t nx = (int16_t)x + tp_dx[dir];
        int16_t ny = (int16_t)y + tp_dy[dir];
        if (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height &&
            map_type[(uint16_t)ny * MAP_W + (uint8_t)nx] == CT_EMPTY) {
            uint16_t nidx = (uint16_t)ny * MAP_W + (uint8_t)nx;
            map_type[nidx] = CT_MUSTACHE;
            map_extra[nidx] = extra;
            map_obj[nidx] = state;
            map_type[idx] = CT_EMPTY;
            map_extra[idx] = 0;
            map_obj[idx] = 0;
            render_cell(x, y);
            render_cell((uint8_t)nx, (uint8_t)ny);
            cur = nidx;
            x = (uint8_t)nx;
            y = (uint8_t)ny;
        } else {
            dir = (dir + 2) & 3;
            extra = (uint8_t)((extra & ~3) | dir);
            map_extra[idx] = extra;
            state |= MUST_INNER_SKIP;
        }
    }

    if ((extra & 4) && ((next_rand8() & 7) == 0) && !was_shot) {
        state |= MUST_JUST_SHOT;
        turret_fire(cur, 1, 0);  /* mustaches shoot downward */
    }

    map_obj[cur] = state;
    return cur;
}

/* Category lookup for collect_actors(): 0 = not tracked, else which list.
 * A table probe beats the 7-way type compare chain in the per-tick scan;
 * walls/ground/empty (the bulk of the map) exit the loop body in two loads. */
#define CAT_NONE 0
#define CAT_TURRET 1
#define CAT_ENEMY 2
#define CAT_BOMB 3
#define CAT_EXPLOSION 4
#define CAT_MAGNET 5
#define CAT_SPACESHIP 6
#define CAT_TELEPORT 7
#define CAT_BARRIER 8
static const uint8_t type_cat[31] = {
    CAT_NONE,       /* CT_EMPTY */
    CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE, CAT_NONE,
    CAT_NONE,       /* CT_GROUND */
    CAT_NONE,       /* CT_STONE */
    CAT_NONE,       /* CT_PUSHABLE */
    CAT_NONE,       /* CT_DOOR */
    CAT_SPACESHIP,  /* CT_SPACESHIP */
    CAT_NONE,       /* CT_QUESTION */
    CAT_BOMB,       /* CT_BOMB */
    CAT_NONE,       /* CT_KEY */
    CAT_NONE,       /* CT_SCREW */
    CAT_TURRET,     /* CT_TURRET */
    CAT_NONE,       /* CT_AMMO */
    CAT_TELEPORT,   /* CT_TELEPORT */
    CAT_ENEMY,      /* CT_MUSTACHE */
    CAT_ENEMY,      /* CT_BUTTERFLY */
    CAT_ENEMY,      /* CT_BEAR */
    CAT_NONE,       /* CT_LAVA */
    CAT_MAGNET,     /* CT_MAGNET */
    CAT_NONE,       /* CT_ROBBO */
    CAT_NONE,       /* CT_BULLET */
    CAT_EXPLOSION,  /* CT_EXPLOSION */
    CAT_NONE,       /* CT_EXTRA_LIFE */
    CAT_BARRIER,    /* CT_BARRIER */
};

static void collect_actors(void)
{
    const uint8_t *p = map_type;
    const uint8_t *end = map_type + MAP_CELLS;

    turret_count = 0;
    enemy_count = 0;
    bomb_count = 0;
    explosion_count = 0;
    magnet_count = 0;
    spaceship_count = 0;
    teleport_count = 0;
    barrier_row_lo = 0;
    barrier_row_hi = 0;

    while (p != end) {
        uint8_t cat = type_cat[*p++];

        if (cat == CAT_NONE) continue;
        {
            uint16_t idx = (uint16_t)(p - map_type) - 1;
            switch (cat) {
        case CAT_TURRET:
            if (turret_count < MAX_TURRET_LIST) turret_list[turret_count++] = idx;
            break;
        case CAT_ENEMY:
            if (enemy_count < MAX_ENEMY_LIST) enemy_list[enemy_count++] = idx;
            break;
        case CAT_BOMB:
            if (bomb_count < MAX_BOMB_LIST) bomb_list[bomb_count++] = idx;
            break;
        case CAT_EXPLOSION:
            if (explosion_count < MAX_EXPLOSION_LIST) explosion_list[explosion_count++] = idx;
            break;
        case CAT_MAGNET:
            if (magnet_count < MAX_MAGNET_LIST) magnet_list[magnet_count++] = idx;
            break;
        case CAT_SPACESHIP:
            if (spaceship_count < MAX_SPACESHIP_LIST) spaceship_list[spaceship_count++] = idx;
            break;
        case CAT_BARRIER:
            if (idx < 256) barrier_row_lo |= (uint16_t)(1u << (idx >> 4));
            else barrier_row_hi |= (uint16_t)(1u << ((idx >> 4) - 16));
            break;
        default:    /* CAT_TELEPORT */
            if (teleport_count < MAX_TELEPORT_LIST) teleport_list[teleport_count++] = idx;
            break;
            }
        }
    }
}

static void enemy_tick(void)
{
    uint8_t i;
    uint16_t idx;

    if (robbo_dead) return;

    for (i = 0; i < enemy_count; i++) {
        uint8_t state;
        uint8_t type;
        uint16_t cur;

        idx = enemy_list[i];
        type = map_type[idx];
        if (type != CT_BEAR && type != CT_BUTTERFLY && type != CT_MUSTACHE) continue;

        state = map_obj[idx];
        if (type == CT_BEAR) {
            cur = bear_step(idx, state);
        } else if (type == CT_BUTTERFLY) {
            cur = butterfly_step(idx, state);
        } else {
            cur = mustache_step(idx, state);
        }

        if (cur < MAP_CELLS) {
            render_cell(cur % MAP_W, cur / MAP_W);
            enemy_try_kill_at(cur % MAP_W, cur / MAP_W);
        }
    }
}

static void magnet_tick(void)
{
    uint8_t i;

    if (robbo_dead || robbo_busy) return;

    for (i = 0; i < magnet_count; i++) {
        uint16_t midx = magnet_list[i];
        uint16_t field = (uint16_t)(midx + 1);
        uint8_t dir;
        int8_t dx, dy;
        int8_t sx, sy;
        int16_t nx, ny;
        uint8_t distance = 0;
        uint8_t found = 0;

        if (map_type[midx] != CT_MAGNET) continue;
        if (magnet_field && magnet_field != field) continue;

        dir = map_extra[midx] & 3;
        dx = tp_dx[dir];
        dy = tp_dy[dir];

        sx = (robbo_x > midx % MAP_W) ? 1 : (robbo_x < midx % MAP_W ? -1 : 0);
        sy = (robbo_y > midx / MAP_W) ? 1 : (robbo_y < midx / MAP_W ? -1 : 0);
        if (sx != dx || sy != dy) continue;

        nx = (int16_t)(midx % MAP_W) + dx;
        ny = (int16_t)(midx / MAP_W) + dy;
        while (nx >= 0 && ny >= 0 && nx < MAP_W && ny < level_height) {
            uint16_t cell = (uint16_t)ny * MAP_W + (uint8_t)nx;
            uint8_t type = map_type[cell];

            if (type == CT_ROBBO) {
                found = 1;
                break;
            }
            if (type != CT_EMPTY) break;
            nx += dx;
            ny += dy;
            distance++;
        }
        if (!found) continue;

        if (!robbo_no_move) {
            robbo_no_move = 1;
            magnet_field = field;
            sfx_play_note(SFX_MAGNET);
            return;
        }

        if (distance == 0) {
            kill_robbo();
            return;
        }

        /* Pull Robbo one cell towards the magnet. */
        {
            int16_t tx = (int16_t)robbo_x - dx;
            int16_t ty = (int16_t)robbo_y - dy;
            if (tx >= 0 && ty >= 0 && tx < MAP_W && ty < level_height &&
                map_type[(uint16_t)ty * MAP_W + (uint8_t)tx] == CT_EMPTY) {
                move_robbo_to((uint8_t)tx, (uint8_t)ty, robbo_dir);
            }
        }
    }
}

static void animate_static_objects(void)
{
    uint8_t i;

    for (i = 0; i < teleport_count; i++) {
        uint16_t idx = teleport_list[i];
        if (map_type[idx] == CT_TELEPORT) {
            render_cell(idx % MAP_W, idx / MAP_W);
        }
    }

    for (i = 0; i < spaceship_count; i++) {
        uint16_t idx = spaceship_list[i];
        if (map_type[idx] == CT_SPACESHIP &&
            (screws_left == 0 || (map_extra[idx] & 1))) {
            render_cell(idx % MAP_W, idx / MAP_W);
        }
    }

    /* Barricades use the second F.FNT animation frame (glyph $1E's S.FNT
     * +64 variant); barrier_tick handles the dirty marks in bank 14. */
}

void game_check_enemies(void)
{
    enemy_check_kills();
}

void game_face(uint8_t dir)
{
    if (dir > 3 || robbo_busy || robbo_no_move) return;
    robbo_dir = dir;
    map_extra[(uint16_t)robbo_y * MAP_W + robbo_x] = dir;
    render_cell(robbo_x, robbo_y);
}

/* game_info.md: only one player projectile may exist at a time. */
uint8_t game_fire(void)
{
    uint8_t nx = robbo_x;
    uint8_t ny = robbo_y;
    uint8_t target;
    uint16_t idx;

    if (player_bullet_active()) return 0;
    if (ammo == 0) return 0;
    if (fire_delay != 0) return 0;
    if (robbo_busy || robbo_no_move) return 0;

    if (robbo_dir == 0) nx++;
    else if (robbo_dir == 1) ny++;
    else if (robbo_dir == 2) { if (nx > 0) nx--; }
    else { if (ny > 0) ny--; }

    if (nx >= MAP_W || ny >= level_height) return 0;

    idx = (uint16_t)ny * MAP_W + nx;
    target = map_type[idx];

    if (target == CT_EMPTY) {
        if (!add_bullet(idx, robbo_dir, 0, 0)) return 0;
        ammo--;
        hud_dirty = 1;
        fire_delay = 2;
        sfx_play_note(SFX_SHOT);
        return 1;
    }

    /* Point-blank shot at a destructible cell: no projectile is created. */
    if (is_demolishable(target)) {
        if (target == CT_BOMB && map_extra[idx] != 0) return 0;
        ammo--;
        hud_dirty = 1;
        fire_delay = 2;
        sfx_play_note(SFX_SHOT);
        demolish_cell(idx);  /* replaces the shot with hit/destroy sound */
        return 1;
    }

    /* Stones and pushable boxes are explodable but not demolishable: a
     * point-blank shot must leave them intact, just like a bullet fired from
     * farther away.  The original fire() returns false for these cells. */
    return 0;
}

void game_frame(void)
{
    if (robbo_step_timer) {
        robbo_step_timer--;
        if (robbo_step_timer == 0) {
            /* Redraw once so the neutral (standing) frame replaces the walk
             * pose; the dirty bitmap flushes it at the next VBlank. */
            render_cell(robbo_x, robbo_y);
        }
    }
}

void game_tick(void)
{
    uint8_t i = 0;
    uint16_t ei;
    uint16_t eidx;

    /* A level-complete clear owns the screen; the advance request is handled
     * by main on a frame boundary, so do not run another logic tick. */
    if (game_transition_active || game_level_advance_requested) return;

    if (fire_delay != 0) fire_delay--;
    anim_frame = (anim_frame + 1) & 1;
    /* Bullets, capsule and teleports swap frames every other logic tick. */
    if (anim_frame == 0) anim_slow ^= 1;
    explosion_sfx_started = 0;

    if (robbo_dead) {
        if (death_timer != 0) {
            death_timer--;
            if (death_timer == 0) {
                destroy_all_items();
                death_wipe_timer = 8;
            }
        } else if (death_wipe_timer != 0) {
            death_wipe_timer--;
            if (death_wipe_timer == 0) game_restart_requested = 1;
        }
    }

    if (screen_flash_ticks != 0) {
        screen_flash_ticks--;
        if (screen_flash_ticks == 0) render_flash_set(0);
    }

    /* Clear the per-tick processed bit on all live bullets. */
    for (i = 0; i < bullet_count; i++) {
        uint16_t c = bullet_cells[i];
        if (map_type[c] == CT_BULLET) {
            map_extra[c] &= 0x7F;
        }
    }
    i = 0;

    /* Bullets: player and turret projectiles share one list. */
    while (i < bullet_count) {
        uint16_t bidx = bullet_cells[i];
        uint8_t be, bdir, btype, owner;
        uint8_t bx, by, nbx, nby;
        uint8_t target;
        uint16_t nidx;

        if (map_type[bidx] != CT_BULLET) {
            remove_bullet_at(i);
            continue;
        }

        if (map_extra[bidx] & 0x80) {
            i++;
            continue;
        }
        map_extra[bidx] |= 0x80;

        be = map_extra[bidx];
        bdir = be & 3;
        btype = (be >> 2) & 3;
        owner = (be >> 4) & 1;
        bx = bidx % MAP_W;
        by = bidx / MAP_W;
        nbx = bx;
        nby = by;

        if (bdir == 0) nbx++;
        else if (bdir == 1) nby++;
        else if (bdir == 2) { if (nbx > 0) nbx--; }
        else { if (nby > 0) nby--; }

        if (btype == 1) {
            uint8_t lstate = (be >> 5) & 3;

            if (lstate == BULLET_LASER_WAIT) {
                render_cell(bx, by);
                i++;
                continue;
            }

            if (lstate == BULLET_LASER_RETURN) {
                int16_t px = (int16_t)bx - tp_dx[bdir];
                int16_t py = (int16_t)by - tp_dy[bdir];
                uint16_t pidx;

                map_type[bidx] = CT_EMPTY;
                map_extra[bidx] = 0;
                render_cell(bx, by);

                if (px >= 0 && py >= 0 && px < MAP_W && py < level_height) {
                    pidx = (uint16_t)py * MAP_W + (uint8_t)px;
                    if (map_type[pidx] == CT_BULLET) {
                        uint8_t pe = map_extra[pidx];
                        if (((pe >> 5) & 3) == BULLET_LASER_WAIT &&
                            ((pe >> 4) & 1) == owner &&
                            ((pe >> 2) & 3) == 1) {
                            map_extra[pidx] = (uint8_t)((pe & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
                            remove_bullet_at(i);
                            continue;
                        }
                    }
                }

                spawn_explosion_timer(bidx, 3);
                sfx_play_note(SFX_HIT_WALL);
                remove_bullet_at(i);
                continue;
            }

            /* Laser head: extend one cell per tick, then retract. */
            if (nbx >= MAP_W || nby >= level_height) {
                map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
                sfx_play_note(SFX_HIT_WALL);
                i++;
                continue;
            }

            nidx = (uint16_t)nby * MAP_W + nbx;
            target = map_type[nidx];

            if (target == CT_EMPTY) {
                map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_WAIT << 5) | 0x80);
                if (add_bullet(nidx, bdir, 1, owner)) {
                    map_extra[nidx] |= 0x80;
                } else {
                    map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
                }
                i++;
                continue;
            }

            if (target == CT_ROBBO && owner) {
                kill_robbo();
            } else if (is_demolishable(target)) {
                demolish_cell(nidx);
            } else {
                sfx_play_note(SFX_HIT_WALL);
            }
            map_extra[bidx] = (uint8_t)((be & 0x1F) | (BULLET_LASER_RETURN << 5) | 0x80);
            i++;
            continue;
        }

        if (btype == 2) {
            /* Blaster (Atari DZ3): banked, because its head/trail/consume
             * rules are sizable and have no business in bank 0. */
            uint16_t moved = blaster_step(bidx, be);
            if (moved == 0xFFFF) {
                remove_bullet_at(i);
            } else {
                bullet_cells[i] = moved;
                i++;
            }
            continue;
        }

        if (nbx >= MAP_W || nby >= level_height) {
            sfx_play_note(SFX_HIT_WALL);
            spawn_explosion_timer(bidx, 3);
            remove_bullet_at(i);
            continue;
        }

        nidx = (uint16_t)nby * MAP_W + nbx;
        target = map_type[nidx];

        if (target == CT_EMPTY) {
            map_type[nidx] = CT_BULLET;
            map_extra[nidx] = be;
            map_type[bidx] = CT_EMPTY;
            map_extra[bidx] = 0;
            render_cell(bx, by);
            render_cell(nbx, nby);
            bullet_cells[i] = nidx;
            i++;
        } else if (target == CT_BULLET) {
            /* The moving projectile stops; the projectile already in the cell
             * is processed on its own turn. */
            sfx_play_note(SFX_HIT_WALL);
            spawn_explosion_timer(bidx, 3);
            remove_bullet_at(i);
        } else if (target == CT_ROBBO && owner) {
            kill_robbo();
            spawn_explosion_timer(bidx, 3);
            remove_bullet_at(i);
        } else {
            uint8_t destroyed = 0;

            if (btype == 2 && is_explodable(target)) {
                sfx_play_note(SFX_HIT_WALL);
                blast_cell(nidx, 3);
                if (target != CT_BOMB) {
                    sfx_play_def(&sfx_destroy);
                    destroyed = 1;
                }
            } else if (is_demolishable(target)) {
                demolish_cell(nidx);
                destroyed = 1;
            } else {
                sfx_play_note(SFX_HIT_WALL);
            }

            /* The destroyed cell owns the perish animation; the projectile
             * just vanishes instead of exploding in the neighbouring cell. */
            if (destroyed) {
                map_type[bidx] = CT_EMPTY;
                map_extra[bidx] = 0;
                render_cell(bx, by);
            } else {
                spawn_explosion_timer(bidx, 3);
            }
            remove_bullet_at(i);
        }
    }

    collect_actors();
    if (barrier_row_lo | barrier_row_hi) {
        barrier_tick(barrier_row_lo, barrier_row_hi, (uint8_t)!anim_frame);
    }
    turret_tick();
    enemy_tick();

    /* Bomb fuses.  map_extra 0 = idle; 1..2 = remaining ticks. */
    for (i = 0; i < bomb_count; i++) {
        eidx = bomb_list[i];
        if (map_type[eidx] == CT_BOMB && map_extra[eidx] != 0) {
            map_extra[eidx]--;
            if (map_extra[eidx] == 0) {
                bomb_explode(eidx);
            } else {
                render_cell(eidx % MAP_W, eidx / MAP_W);
            }
        }
    }

    /* Explosion countdown.  Low 3 bits are the timer; high bits hold an
     * optional Question payload to spawn when the explosion clears. */
    for (ei = 0; ei < explosion_count; ei++) {
        eidx = explosion_list[ei];
        if (map_type[eidx] == CT_EXPLOSION) {
            uint8_t timer = map_extra[eidx] & 7;
            uint8_t payload = map_extra[eidx] >> 3;
            if (timer > 0) {
                timer--;
                map_extra[eidx] = (uint8_t)((payload << 3) | timer);
                render_cell(eidx % MAP_W, eidx / MAP_W);
            } else if (payload == 12) {
                teleport_arrive(eidx);
            } else if (payload != 0) {
                spawn_question_payload(eidx, payload - 1);
            } else {
                map_type[eidx] = CT_EMPTY;
                map_extra[eidx] = 0;
                render_cell(eidx % MAP_W, eidx / MAP_W);
            }
        }
    }

    /* `i` still holds the explosion-loop count here; restart it for the
     * sliding list or an active explosion silently skips every box. */
    i = 0;
    while (i < sliding_count) {
        uint16_t idx = sliding_boxes[i];
        uint8_t x, y, nx, ny, dir, target;
        uint16_t nidx;

        if (map_type[idx] != CT_PUSHABLE) {
            remove_sliding(i);
            continue;
        }

        x = idx % MAP_W;
        y = idx / MAP_W;
        dir = map_extra[idx] & 3;
        nx = x;
        ny = y;

        if (dir == 0) nx++;
        else if (dir == 1) ny++;
        else if (dir == 2) { if (nx > 0) nx--; }
        else { if (ny > 0) ny--; }

        if (nx >= MAP_W || ny >= level_height) {
            map_extra[idx] &= (uint8_t)~4;
            render_cell(x, y);
            remove_sliding(i);
            continue;
        }

        nidx = (uint16_t)ny * MAP_W + nx;
        target = map_type[nidx];

        if (target == CT_EMPTY) {
            map_type[nidx] = CT_PUSHABLE;
            map_extra[nidx] = dir | 4;
            map_type[idx] = CT_EMPTY;
            map_extra[idx] = 0;
            render_cell(x, y);
            render_cell(nx, ny);
            sliding_boxes[i] = nidx;
            i++;
        } else {
            /* The original pushable stone destroys a demolishable blocker,
             * then stops in place. */
            if (is_demolishable(target)) {
                demolish_cell(nidx);
            }
            map_extra[idx] &= (uint8_t)~4;
            render_cell(x, y);
            remove_sliding(i);
        }
    }

    animate_static_objects();
    magnet_tick();
}
