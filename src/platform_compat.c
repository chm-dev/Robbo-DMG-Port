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

#include "gen/tiles.h"

/* HUD scanline split enable.  The title/ending clear it; gameplay sets it. */
uint8_t nes_hud_enabled = 1;
/* Pan/teleport direction hint for the playfield ring prefetch:
 * 0 = follow the camera goal, 1 = down, 3 = up. */
uint8_t nes_pan_dir = 0;

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

/* ------------------------------------------------------------------ */
/* HUD in nametable 1                                                  */
/* ------------------------------------------------------------------ */
/* set_vram_byte() takes the PPU address as a pointer.  Consecutive writes
 * are merged into 32-byte stripes by the GBDK VRAM buffer, so a whole row
 * costs one transfer. */
static void nes_nt1_write(uint16_t addr, const uint8_t *src, uint8_t count)
{
    while (count--) {
        set_vram_byte((uint8_t *)addr, *src++);
        addr++;
    }
}

void nes_hud_fill(void)
{
    uint8_t row;
    uint8_t i;

    /* Four rows: padding above/below the two status rows. */
    for (row = 0; row < 4; row++) {
        for (i = 0; i < 32; i++) {
            set_vram_byte((uint8_t *)(0x2400u + (uint16_t)(row << 5) + i),
                          hud_bg_tile);
        }
    }
    nes_hud_attrs(0);
}

void nes_hud_write(const uint8_t *tiles)
{
    nes_nt1_write(0x2420u, tiles, 32);
    nes_nt1_write(0x2440u, tiles + 32, 32);
}

void nes_hud_attrs(uint8_t pal)
{
    uint8_t packed = (uint8_t)(pal | (pal << 2) | (pal << 4) | (pal << 6));
    uint8_t i;

    for (i = 0; i < 8; i++) {
        set_vram_byte((uint8_t *)(0x27C0u + i), packed);
    }
}

#endif /* NINTENDO_NES */
