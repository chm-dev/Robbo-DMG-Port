/*
 * Robbo - platform compatibility layer (NES-only implementation)
 *
 * The NES build links the gameplay data/BSS into the cartridge PRG-RAM at
 * $6000-$7FEF.  The GBDK NES crt0 only copies initialised data into _DATA; it
 * does not clear _BSS.  On a battery-backed cartridge that memory contains
 * whatever the previous session left there, so clear it before main() uses
 * any global.
 *
 * bss_start/bss_size are defined by the linker from s__BSS/l__BSS (see
 * build.ps1).  The persistent save record at $7FF0-$7FFF sits above the
 * checked BSS end and is intentionally left untouched.
 */
#include "platform_compat.h"

#ifdef NINTENDO_NES

volatile uint8_t nes_compat_cpu;
volatile uint8_t nes_compat_bgp;
volatile uint8_t nes_compat_obp0;
volatile uint8_t nes_compat_obp1;
volatile uint8_t nes_compat_lcdc;
volatile uint8_t nes_compat_stat;
volatile uint8_t nes_compat_wx;
volatile uint8_t nes_compat_wy;
volatile uint8_t nes_compat_dma;
volatile uint8_t nes_compat_vbk;
volatile uint8_t nes_compat_apu[32];

/* Linker symbols (see the -Wl-g flags in gb/tools/build.ps1).  The value of
 * bss_size is the byte count, so its address is the number we want. */
extern uint8_t bss_start;
extern uint8_t bss_size;

void platform_ram_init(void)
{
    uint8_t *p = &bss_start;
    uint16_t n = (uint16_t)&bss_size;

    while (n) {
        *p++ = 0;
        n--;
    }
}

void platform_palette_init(void)
{
    /* Universal NES backdrop is index 0; the four grayscale entries keep the
     * shared game visible while the real per-level palettes are still to be
     * generated (phase 3).  All four BG slots get the same ramp because the
     * current attribute path still writes CGB bytes. */
    static const palette_color_t bg[16] = {
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30
    };
    static const palette_color_t spr[16] = {
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30,
        0x0F, 0x00, 0x10, 0x30
    };

    set_bkg_palette(0, 4, bg);
    set_sprite_palette(0, 4, spr);
}

#endif /* NINTENDO_NES */
