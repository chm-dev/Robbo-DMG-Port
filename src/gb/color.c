/* Colour support.
 *
 * Two back-ends share this file:
 *
 *   Game Boy Color - per-cell BG palettes (VRAM bank 1 attributes) and the
 *   authentic per-level Atari palettes in BGR555.  The DMG build keeps its
 *   shade-index renderer; every entry point checks color_on and returns
 *   immediately on DMG hardware.
 *
 *   NES - four BG palette slots with 2C02 colour indices.  The NES build
 *   swaps tile pixel indices 0/1 at generation time (see gen_tiles.py), so
 *   pixel index 0 is the background role and the shared backdrop ($3F00) can
 *   be COLB for every gameplay palette.  Slots:
 *       0 normal, 1 walls + teleports, 2 inverse objects, 3 UI.
 *   Cave fill needs no slot: MT_WALL_CAVE is all index 3 (COLPF0) and draws
 *   through the normal palette.
 *
 * Art-role index order (see gb/tools/gen_level_pal.py):
 *   0 = bright (Robbo, bolts), 1 = background, 2 = mid, 3 = dark outlines.
 *   After the NES swap: 0 = background, 1 = bright, 2 = mid, 3 = dark.
 *
 * Bank 10 also holds the generated level palette table.
 */
#pragma bank 10

#include <gbdk/platform.h>
#include "platform_compat.h"
#include <stdint.h>

#include "color.h"

#ifdef NINTENDO_NES
#include "../gen/level_pal_nes.h"
#else
#include "../gen/level_pal.h"
#endif

BANKREF(color_init)

uint8_t color_on;

#ifdef NINTENDO_NES

/* ------------------------------------------------------------------ */
/* NES                                                                 */
/* ------------------------------------------------------------------ */

/* Gameplay palettes in NES entry order: [0..3] normal, [4..7] walls,
 * [8..11] inverse objects.  Entry 0 of every palette is the shared backdrop,
 * so only slot 0's copy is actually programmed. */
static uint8_t nes_pal[12];
static uint8_t nes_backdrop;
static uint8_t nes_flash_on;

/* Title art is not index-swapped, so these ramps keep the CGB role order:
 * 0 = bright .. 3 = dark.  All four slots get the same ramp while the title
 * owns the screen.  Slot 0 entry 0 is the universal backdrop. */
static const uint8_t pal_title_ramp[16] = {
    0x30, 0x10, 0x00, 0x0D,
    0x30, 0x10, 0x00, 0x0D,
    0x30, 0x10, 0x00, 0x0D,
    0x30, 0x10, 0x00, 0x0D
};
/* Ending palettes.  The generated NES tiles carry the Atari character-mode
 * colour indices, and the Atari ending colours are TITLE.ASM CONGR's COLS+6
 * block: COLBK $32, COLPF0 $C8, COLPF1 $0C, COLPF2 $74.  Pixel 1 is COLPF0,
 * 2 is COLPF1 (light grey) and 3 is COLPF2 (blue), so the scene and ground
 * need a single slot; the DMG/CGB builds bake COLBK away and the GBC palette
 * table stores the same four colours shifted, which reads as red ground +
 * green ship.
 *
 * COLBK is the shared backdrop, which has to stay black (the text page and
 * every other screen need it), and the original COLPF0 olive-green is
 * replaced by a brown so the ground reads as soil (a palette-only change:
 * every art index 1 pixel follows).
 *
 * Slot 0 is the scene/ground, slot 2 the text page (white ink, grey hatch,
 * black page). */
#define NES_END_SOIL 0x17       /* COLPF0 role: brown #$17 (203,77,12) */
static const uint8_t pal_ending_nes[12] = {
    0x0D, NES_END_SOIL, 0x3D, 0x12,  /* scene/ground: COLB, COLPF0, COLPF1, COLPF2 */
    0x0D, NES_END_SOIL, 0x3D, 0x12,  /* slot 1 unused: same scene palettes */
    0x0D, 0x30, 0x00, 0x0D           /* text: backdrop, white, grey, black */
};
/* Text-page ease-in.  The DMG fades BGP's four shade indices; the NES pages use
 * entry 1 for the ink and entry 2 for the hatch, and must keep entry 3 black
 * (the solid page tile). */
static const uint8_t pal_ending_ink[6]   = { 0x0D, 0x00, 0x10, 0x30, 0x30, 0x30 };
static const uint8_t pal_ending_hatch[6] = { 0x0D, 0x0D, 0x0D, 0x0D, 0x00, 0x10 };
/* HUD/pause text.  The bar and glyph backgrounds are solid black (art
 * index 3); the glyph ink is art index 1 (white) on the swapped gameplay
 * tiles.  Entry 0 is unused and never programmed for slot 3. */
static const uint8_t pal_ui_nes[4] = { 0x0D, 0x30, 0x00, 0x0D };
/* NES title palettes.  Slot 0 is the animated Atari logo: black plus the
 * three current logo colours.  Slot 1 is bright text (white ink, blue rules),
 * slot 2 is the grey instruction window, slot 3 is the bright menu/inverse
 * palette.  On the NES every slot's entry 0 is the shared backdrop, so all
 * four copies are black. */
static const uint8_t title_pal_nes[4][16] = {
    { 0x0F, 0x12, 0x04, 0x18,  0x0F, 0x30, 0x12, 0x0F,
      0x0F, 0x00, 0x12, 0x0F,  0x0F, 0x30, 0x12, 0x0F },
    { 0x0F, 0x04, 0x18, 0x12,  0x0F, 0x30, 0x12, 0x0F,
      0x0F, 0x00, 0x12, 0x0F,  0x0F, 0x30, 0x12, 0x0F },
    { 0x0F, 0x18, 0x12, 0x04,  0x0F, 0x30, 0x12, 0x0F,
      0x0F, 0x00, 0x12, 0x0F,  0x0F, 0x30, 0x12, 0x0F },
    { 0x0F, 0x12, 0x18, 0x04,  0x0F, 0x30, 0x12, 0x0F,
      0x0F, 0x00, 0x12, 0x0F,  0x0F, 0x30, 0x12, 0x0F }
};
/* Sprite entries: 0 is transparent, 1 = dark, 2 = light, 3 = white. */
static const uint8_t pal_sprite_nes[16] = {
    0x0D, 0x00, 0x10, 0x30,
    0x0D, 0x00, 0x10, 0x30,
    0x0D, 0x00, 0x10, 0x30,
    0x0D, 0x00, 0x10, 0x30
};

void color_init(void) BANKED
{
    /* The NES always has colour; the attribute path is always active. */
    color_on = 1;
    /* Boot into the title ramp until a level installs its own palettes. */
    set_bkg_palette(0, 4, pal_title_ramp);
    set_sprite_palette(0, 4, pal_sprite_nes);
}

/* Reinstall the boot ramp (black, grey, light grey, white) for callers that
 * still use the CGB slot numbers; the NES title itself installs its final map
 * through color_title_nes(). */
void color_title_dim_palette(void) BANKED
{
    if (!color_on) return;
    set_bkg_palette(0, 4, pal_title_ramp);
    set_sprite_palette(0, 4, pal_sprite_nes);
}

/* NES title screen: four real BG slots (animated logo, bright text, grey
 * instruction window, bright menu).  Called once on title entry and again
 * whenever the logo's colour phase advances. */
void color_title_nes(uint8_t logo_phase) BANKED
{
    if (!color_on) return;
    set_bkg_palette(0, 4, title_pal_nes[logo_phase & 3]);
}

void color_level_pal(uint8_t level) BANKED
{
    const uint8_t *src;
    uint8_t i;

    if (!color_on) return;
    if (level < 1) level = 1;
    if (level > LEVEL_PAL_NES_COUNT) level = LEVEL_PAL_NES_COUNT;

    src = level_pal_nes[level - 1];
    for (i = 0; i < 4; i++) {
        nes_pal[i] = src[i];
        nes_pal[4 + i] = src[4 + i];
    }
    /* Inverse objects (crates, doors), derived from the wall entries:
     * background role = COLB, bright = wall detail, mid = COL3,
     * dark = the generated object body (normally COLPF0, recoloured by the
     * generator when COLPF0 would merge into the floor or wall surface). */
    nes_pal[8] = src[4];
    nes_pal[9] = src[7];
    nes_pal[10] = src[6];
    nes_pal[11] = src[8];

    nes_backdrop = src[0];
    nes_flash_on = 0;

    /* Slots 0..2 are contiguous: normal, walls (+ teleports), objects. */
    set_bkg_palette(0, 3, nes_pal);
    set_bkg_palette(COLOR_PAL_UI, 1, pal_ui_nes);
}

/* Last-bolt flash: on NES the background role is pixel index 0, which is the
 * shared backdrop, so a single backdrop write flashes every palette. */
void color_flash(uint8_t on) BANKED
{
    if (!color_on) return;
    if (on) {
        nes_flash_on = 1;
        set_bkg_palette_entry(0, 0,
                              (nes_backdrop == 0x30 || nes_backdrop == 0x20)
                                  ? 0x0D : 0x30);
    } else {
        if (!nes_flash_on) return;
        nes_flash_on = 0;
        set_bkg_palette_entry(0, 0, nes_backdrop);
    }
}

/* Fill a rectangle of BG attributes.  NES attributes are one palette per
 * 16x16 pixel cell, so rectangles are rounded outwards to cell boundaries.
 * The argument is the raw NES slot (0..3) on this target: gameplay slots come
 * from render_cell_palette() and the title/ending use their own fixed map. */
void color_fill_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                      uint8_t pal) BANKED
{
    uint8_t cx, cy, cx0, cy0, cx1, cy1;

    if (!color_on || w == 0 || h == 0) return;
    cx0 = (uint8_t)(x >> 1);
    cy0 = (uint8_t)(y >> 1);
    cx1 = (uint8_t)((x + w - 1) >> 1);
    cy1 = (uint8_t)((y + h - 1) >> 1);
    if (cx1 > 15) cx1 = 15;
    if (cy1 > 14) cy1 = 14;
    pal &= 3;
    for (cy = cy0; cy <= cy1; cy++) {
        for (cx = cx0; cx <= cx1; cx++) {
            set_bkg_attribute_xy_nes16x16(cx, cy, pal);
        }
    }
}

/* On NES set_win_tiles() maps to the playfield nametable, so the window
 * attribute helper is the same as the BG one. */
void color_fill_win_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                          uint8_t pal) BANKED
{
    color_fill_attrs(x, y, w, h, pal);
}

/* Ending scene: the GBC scene/ground/text palettes in NES colour indices.
 * Sprites keep the grey ramp (the DMG ending draws Robbo with OBP0 = 0x18). */
void color_ending_scene(void) BANKED
{
    if (!color_on) return;
    set_bkg_palette(0, 3, pal_ending_nes);
    set_sprite_palette(0, 4, pal_sprite_nes);
}

/* Text-page fade step 0..5 (see pal_ending_ink/hatch). */
void color_ending_text_fade(uint8_t step) BANKED
{
    uint8_t pal[4];

    if (!color_on) return;
    if (step > 5) step = 5;
    pal[0] = 0x0D;
    pal[1] = pal_ending_ink[step];
    pal[2] = pal_ending_hatch[step];
    pal[3] = 0x0D;
    set_bkg_palette(2, 1, pal);
}

#else /* !NINTENDO_NES */

/* ------------------------------------------------------------------ */
/* Game Boy / Game Boy Color                                           */
/* ------------------------------------------------------------------ */

/* Current level palettes in art-index order, kept so the last-bolt flash can
 * swap the background entry and restore it without re-reading the table. */
static uint16_t pal_cur[12];
/* Inverse-object palette (crates/doors): the GBC draws these with the
 * inverse palette's body (= COL3) and its dark detail is COLPF0. */
static uint16_t pal_obj[4];
/* Teleport blink palette (see color_level_pal). */
static uint16_t pal_tp[4];

/* Fixed palettes: UI (HUD/title/pause), title logo, ending scene. */
static const uint16_t pal_ui[4]   = { 0x7FFF, 0x56B5, 0x294A, 0x0000 };
/* Inactive title-menu options: darker than the normal UI grey. */
static const uint16_t pal_title_dim[4] = { 0x7FFF, 0x35AD, 0x294A, 0x0000 };
static const uint16_t pal_logo[4] = { 0x7FFF, 0x03FF, 0x029F, 0x0000 };
static const uint16_t pal_ending[4] = { 0x0000, 0x35AD, 0x6B5A, 0x7FFF };
/* Sprite entries (0 is transparent): 1 = dark, 2 = light, 3 = white. */
static const uint16_t pal_sprite[4] = { 0x0000, 0x35AD, 0x7FFF, 0x7FFF };
/* Title rules: the GBC title uses a dark-red rule band (RPAL = 0x040A). */
static const uint16_t pal_rule[4] = { 0x7FFF, 0x040A, 0x294A, 0x0000 };

void color_init(void) BANKED
{
    /* _cpu is set by the GBDK runtime from the boot ROM's A register. */
    color_on = (uint8_t)(_cpu == CGB_TYPE);
    if (!color_on) return;

    set_bkg_palette(COLOR_PAL_UI, 1, (const palette_color_t *)pal_ui);
    set_bkg_palette(COLOR_PAL_LOGO, 1, (const palette_color_t *)pal_logo);
    set_bkg_palette(COLOR_PAL_ENDING, 1, (const palette_color_t *)pal_ending);
    set_bkg_palette(COLOR_PAL_RULE, 1, (const palette_color_t *)pal_rule);
    set_sprite_palette(0, 1, (const palette_color_t *)pal_sprite);
}

/* The title uses a darker inactive-option grey than the regular UI palette.
 * Slot 6 is unused during the title and is restored by color_level_pal().
 * Slots 4 and 7 hold the logo and rule palettes; gameplay reuses slot 4 for
 * the teleport palette, so reinstall them whenever the title opens. */
void color_title_dim_palette(void) BANKED
{
    if (!color_on) return;
    set_bkg_palette(COLOR_PAL_TITLE_DIM, 1,
                    (const palette_color_t *)pal_title_dim);
    set_bkg_palette(COLOR_PAL_LOGO, 1, (const palette_color_t *)pal_logo);
    set_bkg_palette(COLOR_PAL_RULE, 1, (const palette_color_t *)pal_rule);
}

void color_level_pal(uint8_t level) BANKED
{
    const uint16_t *src;
    uint8_t i;

    if (!color_on) return;
    if (level < 1) level = 1;
    if (level > LEVEL_PAL_COUNT) level = LEVEL_PAL_COUNT;

    src = level_pal_data[level - 1];
    for (i = 0; i < 4; i++) {
        pal_cur[i] = src[i];
        pal_cur[4 + i] = src[4 + i];
        /* Cave fill is solid COLPF0 = art index 3 of the normal palette. */
        pal_cur[8 + i] = src[3];
    }
    /* Inverse objects (crates, doors): body (role 3) = COLPF0, highlight
     * (role 2) = COL3, keyhole (role 0) = COLPF1. */
    pal_obj[0] = src[7];
    pal_obj[1] = src[5];
    pal_obj[2] = src[6];
    pal_obj[3] = src[4];

    /* Palettes 0..2 are contiguous: normal, walls, cave fill. */
    set_bkg_palette(0, 3, (const palette_color_t *)pal_cur);
    set_bkg_palette(COLOR_PAL_OBJ, 1, (const palette_color_t *)pal_obj);

    /* Teleports keep a stable palette so the wall grid colour (black on the
     * brick styles) never changes their blink.  Slot 4 is title-only. */
    pal_tp[0] = src[3];      /* COLPF0 */
    pal_tp[1] = src[1];      /* COLB   */
    pal_tp[2] = src[6];      /* COL3   */
    pal_tp[3] = src[2];      /* COLPF1 */
    set_bkg_palette(COLOR_PAL_TP, 1, (const palette_color_t *)pal_tp);
}

/* Last-bolt flash: the DMG build swaps the background shade (BGP 0xE0).
 * On CGB the same effect rewrites palette entry 1 (the background role) of
 * the two playfield palettes. */
void color_flash(uint8_t on) BANKED
{
    static uint16_t pal_flash[8];
    uint16_t flash;
    uint8_t i;

    if (!color_on) return;
    if (!on) {
        set_bkg_palette(0, 2, (const palette_color_t *)pal_cur);
        return;
    }

    flash = (pal_cur[1] == 0x7FFF) ? 0x0000 : 0x7FFF;
    for (i = 0; i < 4; i++) {
        pal_flash[i] = pal_cur[i];
        pal_flash[4 + i] = pal_cur[4 + i];
    }
    pal_flash[1] = flash;
    pal_flash[5] = flash;
    set_bkg_palette(0, 2, (const palette_color_t *)pal_flash);
}

/* Fill a rectangle of BG attributes (VRAM bank 1).  Used by the title,
 * ending and level-entry paths; the gameplay row/cell writers set attributes
 * inline in render.c. */
void color_fill_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                      uint8_t pal) BANKED
{
    uint8_t buf[32];
    uint8_t i;

    if (!color_on) return;
    if (w > 32) w = 32;
    for (i = 0; i < w; i++) buf[i] = pal;
    for (i = 0; i < h; i++) {
        VBK_REG = VBK_ATTRIBUTES;
        set_bkg_tiles(x, (uint8_t)(y + i), w, 1, buf);
        VBK_REG = VBK_TILES;
    }
}

void color_fill_win_attrs(uint8_t x, uint8_t y, uint8_t w, uint8_t h,
                          uint8_t pal) BANKED
{
    uint8_t buf[32];
    uint8_t i;

    if (!color_on) return;
    if (w > 32) w = 32;
    for (i = 0; i < w; i++) buf[i] = pal;
    for (i = 0; i < h; i++) {
        VBK_REG = VBK_ATTRIBUTES;
        set_win_tiles(x, (uint8_t)(y + i), w, 1, buf);
        VBK_REG = VBK_TILES;
    }
}

/* Publish one metatile row's attributes: 32 palette bytes (2 per cell) are
 * duplicated into the two 8x8 tile rows of the ring. */
void color_row_attr(uint8_t map_row, const uint8_t *pals) BANKED
{
    static uint8_t buf[64];
    uint8_t i;

    if (!color_on) return;
    for (i = 0; i < 32; i++) {
        buf[i] = pals[i];
        buf[32 + i] = pals[i];
    }
    set_bkg_attributes(0, (uint8_t)(map_row * 2), 32, 2, buf);
}

void color_cell_attr(uint8_t tx, uint8_t ty, uint8_t pal) BANKED
{
    uint8_t a[4];

    a[0] = a[1] = a[2] = a[3] = pal;
    set_bkg_attributes(tx, ty, 2, 2, a);
}

void color_hud_attr(void) BANKED
{
    uint8_t buf[40];
    uint8_t i;

    for (i = 0; i < 40; i++) buf[i] = COLOR_PAL_UI;
    VBK_REG = VBK_ATTRIBUTES;
    set_win_tiles(0, 0, 20, 2, buf);
    VBK_REG = VBK_TILES;
}

/* Ending scene palettes, taken from the GBC ending data (see
 * robbo-gbc/src/gen/gfx_tiles.h: END_COLOR_*).
 *
 *   BG 0 (scene)   = COLB, PF0, PF1, PF2
 *   BG 1 (ground)  = COLB, PF0, PF1, PF3
 *   sprite 0       = the normal scene palette (Robbo uses the raw indices)
 *
 * The ground and ship-flash tiles are uploaded from the raw-index copy
 * (ending_ground_cgb / ending_scene_cgb) when running in colour, so the DMG
 * shade bake does not collapse the PF1/PF3 split. */
static const uint16_t pal_end_scene[4] = { 0x0000, 0x1C0E, 0x028E, 0x6739 };
static const uint16_t pal_end_ground[4] = { 0x0000, 0x1C0E, 0x028E, 0x6504 };

void color_ending_scene(void) BANKED
{
    if (!color_on) return;
    set_bkg_palette(0, 1, (const palette_color_t *)pal_end_scene);
    set_bkg_palette(1, 1, (const palette_color_t *)pal_end_ground);
    set_sprite_palette(0, 1, (const palette_color_t *)pal_end_scene);
}

#endif /* NINTENDO_NES */
