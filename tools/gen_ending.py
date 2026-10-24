#!/usr/bin/env python3
"""Generate the DMG ending-screen assets.

Ported from the GBC ending (robbo-gbc/src/ending.c, robbo-gbc/src/gen/gfx_tiles.c,
docs/outro.md).  The scene geometry, animation poses and message text are the
authentic Atari TITLE.ASM CONGR outro as implemented by the GBC port.

DMG conversion:
  * The GBC scene palettes (COLB/PF0/PF1/PF2 and the inverse PF3 ground) become
    baked DMG shade indices: source 0 -> 3 (black), 1 -> 2 (dark), 2 -> 1
    (light), 3 -> 0 (white).  Ground/ship-flash tiles use PF3 for index 3,
    which becomes shade 1, so the flash is white <-> light grey.
  * Robbo is drawn with sprites (the only sprites in this port).  Tile indices
    stay raw and OBP0 = 0x18 maps them to the same shades as the background.
  * The text page uses the authentic I.FNT glyphs.  The animated hatch is one
    dynamically rewritten tile (shade 1); the message cells are opaque tiles
    (white ink on black) and the heading band uses an inverse set.
  * The window-based wipe becomes a 4-step shade band under BGP = 0xE4.

Outputs:
    gb/src/gen/ending_data.c
    gb/src/gen/ending_data.h
    gb/tests/art/ending-scene.png
    gb/tests/art/ending-text-0.png
    gb/tests/art/ending-text-1.png

Run: python gb/tools/gen_ending.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

import atari_font
import gen_tiles

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "gb" / "src" / "gen"
ART = ROOT / "gb" / "tests" / "art"
DATA = ROOT / "gb" / "tools" / "data" / "ending_tiles.dat"

# Scene geometry (same 20x18 grid as the GBC ending).
GROUND_ROW = 16
FEET_ROW = 14
SHIP_COL = 8
STARS = [
    (0, 0), (16, 0), (10, 1), (18, 1), (10, 2), (15, 3), (17, 4), (3, 4),
    (11, 8), (15, 8), (3, 9), (7, 10), (5, 2), (8, 5), (0, 6), (1, 12),
    (16, 12),
]
PATTERN_ROWS = [0x4B, 0x96, 0x2D, 0x5A, 0xB4, 0x69, 0xD2, 0xA5]

# Source tile slots in ending_tiles[] (40 tiles).
END_STAR = 0
END_SHIPL = 4
END_SHIPR = 8
END_WALK1 = 12
END_STAND = 16
END_GROUND = 20
END_WAVE1 = 24
END_WAVE2 = 28
END_WALK2 = 32
END_STAND2 = 36

# Message pages: robbo-gbc/src/ending.c message[2][18][21], 20 columns each.
MESSAGE = [
    [
        "~~~~~~~~~~~~~~~~~~~~",
        "~                  ~",
        "~                  ~",
        "~    WELL DONE!    ~",
        "~                  ~",
        "~ROBBO HAS ESCAPED ~",
        "~   THE HOSTILE    ~",
        "~PLANETARY SYSTEM. ~",
        "~                  ~",
        "~ THE PLANS STORED ~",
        "~IN HIS MEMORY ARE ~",
        "~OF GREAT VALUE TO ~",
        "~      EARTH!      ~",
        "~                  ~",
        "~                  ~",
        "~START TO CONTINUE ~",
        "~                  ~",
        "~~~~~~~~~~~~~~~~~~~~",
    ],
    [
        "~~~~~~~~~~~~~~~~~~~~",
        "~                  ~",
        "~YOU HAVE COMPLETED~",
        "~ OUR FIRST GAME.  ~",
        "~IF YOU ENJOYED IT,~",
        "~ LOOK OUT FOR OUR ~",
        "~  NEXT RELEASES.  ~",
        "~                  ~",
        "~    REMEMBER:     ~",
        "~  THE BEST GAMES  ~",
        "~    COME FROM     ~",
        "~     AVALON!      ~",
        "~                  ~",
        "~                  ~",
        "~                  ~",
        "~   PRESS START    ~",
        "~                  ~",
        "~~~~~~~~~~~~~~~~~~~~",
    ],
]

# Heading rows are drawn inverse within their margins (GBC ending.c).
HEADINGS = [(3, 5, 15), (11, 6, 13)]

# GBC palette -> DMG shade index.  The ending scene runs with BGP = 0x1B, so
# index 0..3 render black, dark, light, white.  Keeping the source indices for
# the scene makes the COLB sky index 0: sprite priority then lets the ship cover
# Robbo while leaving him visible over the sky (as on the GBC).
BG_PAL0 = {0: 0, 1: 1, 2: 2, 3: 3}
BG_PAL1 = {0: 0, 1: 1, 2: 2, 3: 2}   # PF3 (orange ground) -> light grey


def read_source_tiles() -> list[tuple[int, ...]]:
    raw = DATA.read_bytes()
    assert len(raw) == 40 * 16, f"{DATA} must hold 40 8x8 tiles"
    tiles = []
    for i in range(40):
        data = raw[i * 16:(i + 1) * 16]
        pixels = []
        for row in range(8):
            lo, hi = data[row * 2], data[row * 2 + 1]
            for col in range(8):
                bit = 7 - col
                pixels.append(((lo >> bit) & 1) | (((hi >> bit) & 1) << 1))
        tiles.append(tuple(pixels))
    return tiles


def tile_bytes(shades: list[list[int]]) -> bytes:
    return gen_tiles.to_tile_bytes(shades)


def shade_tile(pixels: tuple[int, ...], mapping: dict[int, int]) -> bytes:
    shades = [[mapping[pixels[y * 8 + x]] for x in range(8)] for y in range(8)]
    return tile_bytes(shades)


def font_tile(rows: list[str], fg: int, bg: int) -> bytes:
    tile = [[bg] * 8 for _ in range(8)]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                tile[y][x] = fg
    return tile_bytes(tile)


def glyph(ch: str) -> list[str]:
    if ch in atari_font.FONT8:
        return atari_font.FONT8[ch]
    return atari_font.SPECIALS[ch]


def pattern_tile(bits: list[int]) -> bytes:
    tile = [[1 if (bits[y] >> (7 - x)) & 1 else 3 for x in range(8)] for y in range(8)]
    return tile_bytes(tile)


def main() -> None:
    src = read_source_tiles()

    tiles: list[bytes] = []
    # 0..39: background scene tiles.
    for i, pixels in enumerate(src):
        mapping = BG_PAL1 if END_GROUND <= i < END_GROUND + 4 else BG_PAL0
        tiles.append(shade_tile(pixels, mapping))
    assert len(tiles) <= 128, "the sprite layer starts at tile 128"

    shipl_flash = len(tiles)
    for i in range(END_SHIPL, END_SHIPL + 4):
        tiles.append(shade_tile(src[i], BG_PAL1))
    shipr_flash = len(tiles)
    for i in range(END_SHIPR, END_SHIPR + 4):
        tiles.append(shade_tile(src[i], BG_PAL1))

    chars = sorted({ch for page in MESSAGE for row in page for ch in row if ch != "~"})
    font_normal = len(tiles)
    table_normal = [0xFF] * 128
    for ch in chars:
        table_normal[ord(ch)] = len(tiles)
        tiles.append(font_tile(glyph(ch), 0, 3))
    font_inverse = len(tiles)
    table_inverse = [0xFF] * 128
    for ch in chars:
        # The inverse heading band is solid white; its spaces must be white too.
        table_inverse[ord(ch)] = len(tiles)
        tiles.append(font_tile(glyph(ch), 3, 0))

    blank = len(tiles)
    tiles.append(tile_bytes([[0] * 8 for _ in range(8)]))
    black = len(tiles)
    tiles.append(tile_bytes([[3] * 8 for _ in range(8)]))
    pattern = len(tiles)
    tiles.append(pattern_tile(PATTERN_ROWS))
    wipe = len(tiles)
    band = [0, 0, 1, 1, 2, 2, 3, 3]
    tiles.append(tile_bytes([band] * 8))

    GEN.mkdir(parents=True, exist_ok=True)
    with open(GEN / "ending_data.h", "w", encoding="utf-8") as h:
        h.write("/* Generated by gb/tools/gen_ending.py - do not edit. */\n")
        h.write("#ifndef ENDING_DATA_H\n#define ENDING_DATA_H\n\n")
        h.write("#include <stdint.h>\n\n")
        h.write(f"#define ENDING_GROUND_ROW {GROUND_ROW}\n")
        h.write(f"#define ENDING_FEET_ROW {FEET_ROW}\n")
        h.write(f"#define ENDING_SHIP_COL {SHIP_COL}\n")
        h.write(f"#define ENDING_STAR {END_STAR}\n")
        h.write(f"#define ENDING_SHIPL {END_SHIPL}\n")
        h.write(f"#define ENDING_SHIPR {END_SHIPR}\n")
        h.write(f"#define ENDING_WALK1 {END_WALK1}\n")
        h.write(f"#define ENDING_STAND {END_STAND}\n")
        h.write(f"#define ENDING_GROUND {END_GROUND}\n")
        h.write(f"#define ENDING_WAVE1 {END_WAVE1}\n")
        h.write(f"#define ENDING_WAVE2 {END_WAVE2}\n")
        h.write(f"#define ENDING_WALK2 {END_WALK2}\n")
        h.write(f"#define ENDING_STAND2 {END_STAND2}\n")
        h.write(f"#define ENDING_SHIPL_FLASH {shipl_flash}\n")
        h.write(f"#define ENDING_SHIPR_FLASH {shipr_flash}\n")
        h.write(f"#define ENDING_FONT {font_normal}\n")
        h.write(f"#define ENDING_FONT_INVERSE {font_inverse}\n")
        h.write(f"#define ENDING_GLYPH_COUNT {len(chars)}\n")
        h.write(f"#define ENDING_BLANK_TILE {blank}\n")
        h.write(f"#define ENDING_BLACK_TILE {black}\n")
        h.write(f"#define ENDING_PATTERN_TILE {pattern}\n")
        h.write(f"#define ENDING_WIPE_TILE {wipe}\n")
        h.write(f"#define ENDING_TILE_COUNT {len(tiles)}\n")
        h.write(f"#define ENDING_SPRITE_BASE 128\n")
        h.write(f"#define ENDING_SPRITE_TILES 40\n")
        h.write(f"#define ENDING_MSG_COLS 20\n")
        h.write(f"#define ENDING_MSG_ROWS 18\n")
        for page, (row, x0, x1) in enumerate(HEADINGS):
            h.write(f"#define ENDING_HEAD_ROW_{page} {row}\n")
            h.write(f"#define ENDING_HEAD_X0_{page} {x0}\n")
            h.write(f"#define ENDING_HEAD_X1_{page} {x1}\n")
        h.write("\n")
        h.write("extern const uint8_t ending_tiles[ENDING_TILE_COUNT * 16];\n")
        h.write("extern const uint8_t ending_sprite_tiles[ENDING_SPRITE_TILES * 16];\n")
        h.write("extern const uint8_t ending_font[128];\n")
        h.write("extern const uint8_t ending_font_inverse[128];\n")
        h.write("extern const uint8_t ending_stars[17][2];\n")
        h.write("extern const uint8_t ending_pattern_rows[8];\n")
        h.write("extern const char ending_message[2][ENDING_MSG_ROWS][ENDING_MSG_COLS + 1];\n\n")
        h.write("#endif\n")

    with open(GEN / "ending_data.c", "w", encoding="utf-8") as c:
        c.write("/* Generated by gb/tools/gen_ending.py - do not edit. */\n")
        c.write("#pragma bank 12\n\n")
        c.write("#include <stdint.h>\n#include \"ending_data.h\"\n\n")
        c.write("/* Background tiles: 0..39 scene, ship flash, font, hatch/blank/wipe. */\n")
        c.write(f"const uint8_t ending_tiles[{len(tiles) * 16}] = {{\n")
        for i, tile in enumerate(tiles):
            c.write(f"  /* {i:3d} */ " + ",".join(f"0x{b:02X}" for b in tile) + ",\n")
        c.write("};\n\n")

        c.write("/* Raw 2bpp source tiles for the sprite layer (OBP0 = 0x18). */\n")
        c.write(f"const uint8_t ending_sprite_tiles[{len(src) * 16}] = {{\n")
        for i, pixels in enumerate(src):
            tile = tile_bytes([list(pixels[y * 8:(y + 1) * 8]) for y in range(8)])
            c.write(f"  /* {i:3d} */ " + ",".join(f"0x{b:02X}" for b in tile) + ",\n")
        c.write("};\n\n")

        for name, table in (("normal", table_normal), ("inverse", table_inverse)):
            c.write(f"const uint8_t ending_font{'_inverse' if name == 'inverse' else ''}[128] = {{\n")
            for i in range(0, 128, 16):
                c.write("  " + ", ".join(f"0x{v:02X}" for v in table[i:i + 16]) + ",\n")
            c.write("};\n\n")

        c.write("const uint8_t ending_stars[17][2] = {\n")
        for x, y in STARS:
            c.write(f"  {{{x},{y}}},\n")
        c.write("};\n\n")

        c.write("const uint8_t ending_pattern_rows[8] = {\n  ")
        c.write(", ".join(f"0x{v:02X}" for v in PATTERN_ROWS))
        c.write("\n};\n\n")

        c.write("const char ending_message[2][18][21] = {\n")
        for page in MESSAGE:
            c.write("  {\n")
            for row in page:
                assert len(row) == 20, repr(row)
                c.write(f'    "{row}",\n')
            c.write("  },\n")
        c.write("};\n")

    # ------------------------------------------------------------------
    # Preview
    # ------------------------------------------------------------------
    scale = 4

    def cell_tile(page: int, x: int, y: int) -> int:
        ch = MESSAGE[page][y][x]
        if ch == "~":
            return pattern
        row, x0, x1 = HEADINGS[page]
        table = table_inverse if y == row and x0 <= x < x1 else table_normal
        return table[ord(ch)] if table[ord(ch)] != 0xFF else blank

    def render_text(page: int) -> Image.Image:
        out = Image.new("RGB", (160, 144), gen_tiles.RGB[3])
        p = out.load()
        for y in range(18):
            for x in range(20):
                idx = cell_tile(page, x, y)
                data = tiles[idx]
                for row in range(8):
                    lo, hi = data[row * 2], data[row * 2 + 1]
                    for col in range(8):
                        bit = 7 - col
                        v = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                        p[x * 8 + col, y * 8 + row] = gen_tiles.RGB[v]
        return out

    def render_scene() -> Image.Image:
        out = Image.new("RGB", (160, 144), gen_tiles.RGB[3])
        p = out.load()
        scene_shade = {0: 3, 1: 2, 2: 1, 3: 0}   # BGP = 0x1B

        def bg(x: int, y: int, idx: int) -> None:
            data = tiles[idx]
            for row in range(8):
                lo, hi = data[row * 2], data[row * 2 + 1]
                for col in range(8):
                    bit = 7 - col
                    v = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                    p[x * 8 + col, y * 8 + row] = gen_tiles.RGB[scene_shade[v]]

        def spr(x: int, y: int, idx: int) -> None:
            raw = src[idx]
            for row in range(8):
                for col in range(8):
                    value = raw[row * 8 + col]
                    if value == 0:
                        continue
                    p[x + col, y + row] = gen_tiles.RGB[{1: 2, 2: 1, 3: 0}[value]]

        for y in range(18):
            for x in range(20):
                bg(x, y, blank)
        for x, y in STARS:
            bg(x, y, 1)
        for x in range(0, 20, 2):
            for dy in range(2):
                for dx in range(2):
                    bg(x + dx, GROUND_ROW + dy, END_GROUND + dy * 2 + dx)
        for dy in range(2):
            for dx in range(4):
                bg(SHIP_COL + dx, 12 + dy,
                   (END_SHIPL if dx < 2 else END_SHIPR) + dy * 2 + (dx & 1))
        for i in range(4):
            sx = 108 + (8 if i & 1 else 0)
            sy = FEET_ROW * 8 + (8 if i & 2 else 0)
            spr(sx, sy, END_WAVE1 + i)
        return out

    ART.mkdir(parents=True, exist_ok=True)
    render_scene().resize((160 * scale, 144 * scale), Image.NEAREST).save(
        ART / "ending-scene.png")
    render_text(0).resize((160 * scale, 144 * scale), Image.NEAREST).save(
        ART / "ending-text-0.png")
    render_text(1).resize((160 * scale, 144 * scale), Image.NEAREST).save(
        ART / "ending-text-1.png")

    print(f"Ending BG tiles: {len(tiles)} / 256")
    print(f"Ending sprite tiles: {len(src)} / 256")
    print(f"Glyphs: {len(chars)} per style ({len(chars) * 2} tiles)")
    print(f"Wrote {GEN / 'ending_data.c'}, {GEN / 'ending_data.h'} and 3 previews")


if __name__ == "__main__":
    main()
