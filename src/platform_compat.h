/*
 * Robbo - platform compatibility layer
 *
 * The gameplay code is shared between the Game Boy (DMG/CGB) and NES builds.
 * <gbdk/platform.h> selects the native API for the target; this header
 * contains the few small shims that the shared files need.
 *
 * On NES the window macros now drive the top-HUD scanline split and the HUD
 * lives in the second nametable.  The APU/display-register stubs remain
 * placeholders until their porting phases.  The GB definitions must remain
 * byte-for-byte equivalent to the old direct register use.
 */
#ifndef PLATFORM_COMPAT_H
#define PLATFORM_COMPAT_H

#include <gbdk/platform.h>
#include <stdint.h>

/* ------------------------------------------------------------------ */
/* Game Boy                                                            */
/* ------------------------------------------------------------------ */
#ifndef NINTENDO_NES

#define PLATFORM_ENTROPY()      ((uint8_t)DIV_REG)
#define PLATFORM_WAIT_VBL()     do { VBL_DONE = 0; while (!VBL_DONE) {} } while (0)
#define PLATFORM_SAVE_RAM       ((volatile uint8_t *)0xA000)
#define PLATFORM_RAM_INIT()     do { } while (0)

/* The existing GB code uses the MBC5 fast path explicitly. */
#define PLATFORM_SWITCH_ROM(b)  SWITCH_ROM_MBC5(b)

/* ------------------------------------------------------------------ */
/* NES                                                                 */
/* ------------------------------------------------------------------ */
#else

/* NES has no hardware Window layer.  The HUD is stationary in the second
 * nametable; the playfield ring lives in nametable 0 and wraps vertically at
 * 240 px, so a 15-metarow ring covers the 13-row view plus one prefetch row.
 * SHOW_WIN/HIDE_WIN enable or disable the HUD scanline split for the title,
 * ending and gameplay.  set_win_tiles() keeps the shared pause/ending code
 * working by drawing into the playfield nametable. */
extern uint8_t nes_hud_enabled;
extern uint8_t nes_pan_dir;
#define SHOW_WIN                        do { nes_hud_enabled = 1; } while (0)
#define HIDE_WIN                        do { nes_hud_enabled = 0; } while (0)
#define move_win(x, y)                  ((void)(x), (void)(y))
#define set_win_tiles(x, y, w, h, buf)  set_bkg_tiles((x), (y), (w), (h), (buf))

/* HUD in nametable 1 (0x2400): 4 tile rows, with the two status rows in the
 * middle so CRT top overscan cannot clip them.  nes_hud_write() takes a 32x2
 * tile buffer and places it at rows 1..2; nes_hud_fill() clears rows 0..3. */
void nes_hud_fill(void);
void nes_hud_write(const uint8_t *tiles);
void nes_hud_attrs(uint8_t pal);

/* GB-only display registers.  The NES back-end in phase 2/3 will replace the
 * meaningful ones (scroll/attributes/palettes); these stubs keep the shared
 * UI files compiling in the meantime. */
extern volatile uint8_t nes_compat_cpu;
extern volatile uint8_t nes_compat_bgp;
extern volatile uint8_t nes_compat_obp0;
extern volatile uint8_t nes_compat_obp1;
extern volatile uint8_t nes_compat_lcdc;
extern volatile uint8_t nes_compat_stat;
extern volatile uint8_t nes_compat_wx;
extern volatile uint8_t nes_compat_wy;
extern volatile uint8_t nes_compat_dma;
extern volatile uint8_t nes_compat_vbk;

#define BGP_REG         nes_compat_bgp
#define OBP0_REG        nes_compat_obp0
#define OBP1_REG        nes_compat_obp1
#define LCDC_REG        nes_compat_lcdc
#define STAT_REG        nes_compat_stat
#define WX_REG          nes_compat_wx
#define WY_REG          nes_compat_wy
#define DMA_REG         nes_compat_dma
#define VBK_REG         nes_compat_vbk

#define VBK_TILES       0u
#define VBK_ATTRIBUTES  1u

#define LCDCF_ON        0u
#define LCDCF_WINON     0u
#define LCDCF_WIN9C00   0u
#define LCDCF_BG8000    0u
#define LCDCF_BGON      0u

/* CGB detection: the NES is never a CGB.  Keep _cpu a runtime value so the
 * shared colour code still contains both paths (and stays warning-free). */
#define _cpu            nes_compat_cpu
#define CGB_TYPE        1u

/* The APU back-end is phase 5.  These aliases give sound.c a stable set of
 * addresses while it is still written against the GB register names. */
extern volatile uint8_t nes_compat_apu[32];
#define NR10_REG        nes_compat_apu[0]
#define NR11_REG        nes_compat_apu[1]
#define NR12_REG        nes_compat_apu[2]
#define NR13_REG        nes_compat_apu[3]
#define NR14_REG        nes_compat_apu[4]
#define NR21_REG        nes_compat_apu[5]
#define NR22_REG        nes_compat_apu[6]
#define NR23_REG        nes_compat_apu[7]
#define NR24_REG        nes_compat_apu[8]
#define NR30_REG        nes_compat_apu[9]
#define NR31_REG        nes_compat_apu[10]
#define NR32_REG        nes_compat_apu[11]
#define NR33_REG        nes_compat_apu[12]
#define NR34_REG        nes_compat_apu[13]
#define NR41_REG        nes_compat_apu[14]
#define NR42_REG        nes_compat_apu[15]
#define NR43_REG        nes_compat_apu[16]
#define NR44_REG        nes_compat_apu[17]
#define NR50_REG        nes_compat_apu[18]
#define NR51_REG        nes_compat_apu[19]
#define NR52_REG        nes_compat_apu[20]

/* Entropy: the NES has no DIV register.  sys_time is the frame counter the
 * GBDK NES runtime maintains in its VBlank handler. */
#define PLATFORM_ENTROPY()      ((uint8_t)sys_time)

/* GBDK NES installs a fake VBL handler; vsync() also flushes the shadow
 * attribute/transfer buffers, so it is the correct frame gate. */
#define PLATFORM_WAIT_VBL()     vsync()

/* Persistent save record: top 16 bytes of the battery-backed 8 KiB PRG-RAM.
 * The linker script has already checked that BSS never reaches this page. */
#define PLATFORM_SAVE_RAM       ((volatile uint8_t *)0x7FF0)

#define PLATFORM_RAM_INIT()     platform_ram_init()

/* GBDK NES uses the generic UNROM-style SWITCH_ROM macro. */
#define PLATFORM_SWITCH_ROM(b)  SWITCH_ROM(b)
#define SWITCH_ROM_MBC5(b)      SWITCH_ROM(b)
#define SWITCH_ROM_MBC1(b)      SWITCH_ROM(b)

void platform_ram_init(void);

#endif /* NINTENDO_NES */

#endif /* PLATFORM_COMPAT_H */
