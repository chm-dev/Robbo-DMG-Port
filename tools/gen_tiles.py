#!/usr/bin/env python3
"""Generate the zoomed-in 16x16 Robbo tileset from the original 32x32 artwork.

Each game cell is a 16x16 metatile made of four 8x8 GB tiles.  All 8x8 tile
quadrants are deduplicated, which keeps the whole set inside the DMG's 256-tile
VRAM budget.

Outputs:
    gb/tests/art/contact-sheet-16.png
    gb/tests/art/level1-mock-16.png
    gb/src/gen/tiles.c
    gb/src/gen/tiles.h

Run: python gb/tools/gen_tiles.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "robboJS" / "icons32.png"
LEVELS = ROOT / "gb" / "tests" / "fixtures" / "levels.json"
ART = ROOT / "gb" / "tests" / "art"
GEN = ROOT / "gb" / "src" / "gen"

GRID = 34
CELL = 32
OFFSET = 2

COLOUR_INDEX = {
    (0, 0, 0): 0,
    (254, 254, 2): 1,
    (2, 194, 2): 2,
    (28, 39, 131): 3,
    (16, 16, 16): 4,
}
# semantic source index -> DMG shade.  This matches the GB Studio prototype:
# background is dark (shade 2), yellow highlights are lightest (0), green/blue
# become light green (1), and black outlines are darkest (3).
SHADE = {0: 2, 1: 0, 2: 1, 3: 1, 4: 3}
RGB = [(239, 255, 222), (172, 205, 164), (92, 143, 108), (24, 52, 66)]

# Source coords from robboJS/js/sprites.js.  Order here is the metatile order.
SPRITES: dict[str, tuple[int, int]] = {
    "EMPTY": (10, 2),
    "GROUND": (4, 2),
    "STONE": (6, 0),
    "PUSHABLE": (8, 1),
    "DOOR": (9, 0),
    "SPACESHIP_0": (6, 1),
    "SPACESHIP_1": (5, 1),
    "QUESTION": (0, 1),
    "BOMB": (8, 0),
    "KEY": (7, 0),
    "SCREW": (4, 0),
    "AMMO": (5, 0),
    "TURRET_R": (5, 4),
    "TURRET_D": (6, 4),
    "TURRET_L": (7, 4),
    "TURRET_U": (8, 4),
    "TELEPORT_0": (0, 4),
    "EXPLOSION_0": (0, 7),
    "EXPLOSION_1": (1, 7),
    "EXPLOSION_2": (2, 7),
    "EXPLOSION_3": (3, 7),
    "BULLET_0": (0, 3),
    "BULLET_1": (1, 3),
    "BULLET_2": (2, 3),
    "BULLET_3": (3, 3),
    "MUSTACHE_0": (3, 1),
    "MUSTACHE_1": (4, 1),
    "BUTTERFLY_0": (8, 2),
    "BUTTERFLY_1": (9, 2),
    "LAVA_0": (9, 3),
    "LAVA_1": (9, 4),
    "MAGNET_0": (0, 0),
    "MAGNET_1": (1, 0),
    "HUD_SCREW": (4, 3),
    "HUD_AMMO": (7, 3),
    "HUD_KEY": (6, 3),
    "HUD_LIVES": (5, 3),
    "HUD_PLANET": (8, 3),
}
for i, coord in enumerate([
    (1, 1), (2, 1),
    (6, 2), (7, 2),
]):
    SPRITES[f"BEAR_{i}"] = coord
for i in range(8):
    SPRITES[f"ROBBO_{i}"] = (i, 5)

WALL_GLYPHS = "OIo-QqPpSsyYzZJji"
WALL_SLOT = {
    "Q": 0, "O": 1, "I": 2, "o": 3, "y": 4, "-": 5, "q": 6, "P": 7,
    "p": 0, "S": 1, "s": 2, "Y": 3, "z": 4, "Z": 5, "J": 6, "j": 7, "i": 0,
}

# Exact 16x16 bevel block from the GB Studio prototype.
WALL_16 = [[0] * 16]
WALL_16.append([0, 0] + [1] * 13 + [2])
for _ in range(12):
    WALL_16.append([0] + [1] * 14 + [2])
WALL_16.append([2] + [1] * 13 + [2, 2])
WALL_16.append([2] * 16)

CUSTOM_16 = {
    "EMPTY": [[2] * 16 for _ in range(16)],
    "WALL": WALL_16,
}

# Full-cell textures keep their framing; objects are cropped to their pixels so
# they read at 16x16.
NO_CROP = {"GROUND", "LAVA_0", "LAVA_1", "TELEPORT_0"}


def src_index(pixel: tuple[int, int, int]) -> int:
    if pixel in COLOUR_INDEX:
        return COLOUR_INDEX[pixel]
    best, best_d = 0, 1 << 30
    for colour, index in COLOUR_INDEX.items():
        d = sum((pixel[i] - colour[i]) ** 2 for i in range(3))
        if d < best_d:
            best, best_d = index, d
    return best


def crop_source(image: Image.Image, coord: tuple[int, int]) -> list[list[int]]:
    x0 = OFFSET + coord[0] * GRID
    y0 = OFFSET + coord[1] * GRID
    return [[src_index(image.getpixel((x0 + x, y0 + y))) for x in range(CELL)]
            for y in range(CELL)]


def content_crop(cell: list[list[int]], pad: int = 2) -> list[list[int]]:
    xs, ys = [], []
    for y in range(CELL):
        for x in range(CELL):
            if cell[y][x] != 0:
                xs.append(x)
                ys.append(y)
    if not xs:
        return cell
    x0, x1 = max(0, min(xs) - pad), min(CELL - 1, max(xs) + pad)
    y0, y1 = max(0, min(ys) - pad), min(CELL - 1, max(ys) + pad)
    side = max(x1 - x0 + 1, y1 - y0 + 1)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    sx, sy = cx - side // 2, cy - side // 2
    out = []
    for y in range(CELL):
        row = []
        src_y = sy + y * side // CELL
        for x in range(CELL):
            src_x = sx + x * side // CELL
            row.append(cell[src_y][src_x] if 0 <= src_x < CELL and 0 <= src_y < CELL else 0)
        out.append(row)
    return out


def majority16(cell: list[list[int]]) -> list[list[int]]:
    out = []
    for by in range(16):
        row = []
        for bx in range(16):
            values = sorted(SHADE[cell[by * 2 + y][bx * 2 + x]] for y in range(2) for x in range(2))
            row.append(values[1])
        out.append(row)
    return out


def outline16(shades: list[list[int]]) -> list[list[int]]:
    """Add a 1px dark outline around the silhouette (original art has almost
    no outline on Robbo, which disappears against the light background)."""
    mask = [[shades[y][x] != 0 for x in range(16)] for y in range(16)]
    out = [row[:] for row in shades]
    for y in range(16):
        for x in range(16):
            if shades[y][x] != 0:
                continue
            neighbours = (
                (y > 0 and mask[y - 1][x]) or (y < 15 and mask[y + 1][x]) or
                (x > 0 and mask[y][x - 1]) or (x < 15 and mask[y][x + 1])
            )
            if neighbours:
                out[y][x] = 3
    return out


def sprite16(image: Image.Image, name: str) -> list[list[int]]:
    if name in CUSTOM_16:
        return CUSTOM_16[name]
    cell = crop_source(image, SPRITES[name])
    return majority16(cell)


# 5x7 text font (same glyphs as before), used for title/pause/end screens.
FONT = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
    ":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
}


def glyph8(rows: list[str]) -> list[list[int]]:
    mapping = {".": 2, ":": 1, "+": 1, "#": 0}
    out = []
    for row in rows:
        out.append([2] + [mapping[ch] for ch in row] + [2, 2])
    out.append([2] * 8)
    return out


def digit16(ch: str) -> tuple[list[list[int]], list[list[int]]]:
    """8x16 digit: 5x7 glyph scaled 2x vertically, centred in one tile column."""
    glyph = FONT[ch]
    # 7 rows -> 14 rows, plus one blank row above/below.
    pixels = []
    for row in glyph:
        pixels.append(row)
        pixels.append(row)
    grid = [[2] * 8 for _ in range(16)]
    for y in range(14):
        for x in range(5):
            if pixels[y][x] == "#":
                grid[y + 1][x + 1] = 0
    top = grid[:8]
    bottom = grid[8:]
    return top, bottom


def to_tile_bytes(shades: list[list[int]]) -> bytes:
    out = bytearray()
    for y in range(8):
        low = high = 0
        for x in range(8):
            shade = shades[y][x]
            bit = 1 << (7 - x)
            if shade & 1:
                low |= bit
            if shade & 2:
                high |= bit
        out.extend((low, high))
    return bytes(out)


class TilePool:
    def __init__(self):
        self.data: list[bytes] = []
        self.index: dict[bytes, int] = {}
        self.names: list[str] = []

    def add(self, shades: list[list[int]], name: str) -> int:
        data = to_tile_bytes(shades)
        if data in self.index:
            return self.index[data]
        if len(self.data) >= 256:
            raise RuntimeError(f"Tile budget exceeded at {name}")
        idx = len(self.data)
        self.data.append(data)
        self.index[data] = idx
        self.names.append(name)
        return idx


def quadrants(tile16: list[list[int]]) -> list[list[list[int]]]:
    return [
        [row[0:8] for row in tile16[0:8]],
        [row[8:16] for row in tile16[0:8]],
        [row[0:8] for row in tile16[8:16]],
        [row[8:16] for row in tile16[8:16]],
    ]


def tile_image(shades: list[list[int]], scale: int = 1) -> Image.Image:
    im = Image.new("RGB", (8, 8))
    for y in range(8):
        for x in range(8):
            im.putpixel((x, y), RGB[shades[y][x]])
    if scale != 1:
        im = im.resize((8 * scale, 8 * scale), Image.NEAREST)
    return im


def build_contact_sheet(metatiles: dict[str, list[list[int]]]) -> None:
    scale = 3
    cols = 8
    cell_w = 16 * scale + 12
    row_h = 16 * scale + 20
    rows = (len(metatiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w + 8, rows * row_h + 20), (250, 250, 245))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, (name, shades) in enumerate(metatiles.items()):
        x = 8 + (i % cols) * cell_w
        y = 20 + (i // cols) * row_h
        im = Image.new("RGB", (16, 16))
        for yy in range(16):
            for xx in range(16):
                im.putpixel((xx, yy), RGB[shades[yy][xx]])
        im = im.resize((16 * scale, 16 * scale), Image.NEAREST)
        sheet.paste(im, (x, y))
        draw.text((x, y + 16 * scale + 2), name, fill=(0, 0, 0), font=font)
    ART.mkdir(parents=True, exist_ok=True)
    sheet.save(ART / "contact-sheet-16.png")


GLYPH_MT = {
    ".": "EMPTY", " ": "EMPTY", "H": "GROUND", "#": "STONE", "~": "PUSHABLE",
    "D": "DOOR", "!": "SPACESHIP_0", "?": "QUESTION", "b": "BOMB", "%": "KEY",
    "T": "SCREW", "x": "SCREW", "}": "TURRET_R", "'": "AMMO", "&": "TELEPORT_0",
    "^": "MUSTACHE_0", "V": "BUTTERFLY_0", "@": "BEAR_0", "*": "BEAR_2",
    "M": "MAGNET_0", "=": "LAVA_0", "R": "ROBBO_2",
}
for glyph, slot in WALL_SLOT.items():
    GLYPH_MT[glyph] = "WALL"


def build_mock(metatiles: dict[str, list[list[int]]]) -> None:
    data = json.loads(LEVELS.read_text(encoding="utf-8"))
    level = data["levels"][0]
    rows = level["map"].split("\n")
    screen = Image.new("RGB", (160, 144), RGB[2])
    for y in range(9):
        if y >= len(rows):
            break
        for x in range(10):
            glyph = rows[y][x]
            name = GLYPH_MT.get(glyph, "EMPTY")
            shades = metatiles[name]
            for yy in range(16):
                for xx in range(16):
                    screen.putpixel((x * 16 + xx, y * 16 + yy), RGB[shades[yy][xx]])
    screen = screen.resize((640, 576), Image.NEAREST)
    screen.save(ART / "level1-mock-16.png")

    proto = ART / "prototype.png"
    if proto.exists():
        left = Image.open(proto).convert("RGB").resize((640, 576), Image.NEAREST)
        compare = Image.new("RGB", (1288, 576), (255, 255, 255))
        compare.paste(left, (0, 0))
        compare.paste(screen, (648, 0))
        compare.save(ART / "prototype-compare-16.png")


def emit(metatiles: dict[str, list[list[int]]], pool: TilePool,
         digit_tiles: dict[str, tuple[int, int]], font_tiles: dict[str, int]) -> None:
    GEN.mkdir(parents=True, exist_ok=True)
    mt_names = list(metatiles.keys())
    mt_index = {name: i for i, name in enumerate(mt_names)}

    lines = [
        "/* Generated by gb/tools/gen_tiles.py - do not edit. */",
        "#include <stdint.h>",
        '#include "tiles.h"',
        "",
        f"const uint8_t tileset_count = {len(pool.data)};",
        "",
        f"const uint8_t metatile_tiles[{len(mt_names) * 4}] = {{",
    ]
    for name in mt_names:
        quads = quadrants(metatiles[name])
        vals = []
        for q in quads:
            data = to_tile_bytes(q)
            vals.append(pool.index[data])
        lines.append(f"    {vals[0]}, {vals[1]}, {vals[2]}, {vals[3]},  /* {mt_index[name]} {name} */")
    lines.append("};")
    lines.append("")
    lines.append(f"const uint8_t metatile_count = {len(mt_names)};")
    lines.append("")
    lines.append("const uint8_t digit_tiles[10][2] = {")
    for d in range(10):
        top, bottom = digit_tiles[str(d)]
        lines.append(f"    {{ {top}, {bottom} }},  /* {d} */")
    lines.append("};")
    lines.append("")
    font_lookup = [0xFF] * 128
    for char, idx in font_tiles.items():
        font_lookup[ord(char)] = idx
    lines.append("const uint8_t font_tiles[128] = {")
    for i in range(0, 128, 16):
        lines.append("    " + ", ".join(f"0x{v:02X}" for v in font_lookup[i:i + 16]) + ",")
    lines.append("};")
    lines.append("")

    (GEN / "tiles.c").write_text("\n".join(lines) + "\n", encoding="utf-8")

    bank_lines = [
        "/* Generated by gb/tools/gen_tiles.py - do not edit. */",
        "#pragma bank 1",
        "",
        "#include <stdint.h>",
        '#include "tiles.h"',
        "",
        f"const uint8_t tileset_data[{len(pool.data) * 16}] = {{",
    ]
    for i, data in enumerate(pool.data):
        bank_lines.append("    " + ", ".join(f"0x{b:02X}" for b in data) + f",  /* {i} {pool.names[i]} */")
    bank_lines.append("};")
    bank_lines.append("")
    (GEN / "tiles_bank.c").write_text("\n".join(bank_lines) + "\n", encoding="utf-8")

    hlines = [
        "/* Generated by gb/tools/gen_tiles.py - do not edit. */",
        "#ifndef TILES_H",
        "#define TILES_H",
        "",
        "#include <stdint.h>",
        "",
        f"#define TILESET_COUNT {len(pool.data)}",
        f"#define METATILE_COUNT {len(mt_names)}",
        "",
    ]
    for i, name in enumerate(mt_names):
        hlines.append(f"#define MT_{name} {i}")
    hlines += [
        "",
        "extern const uint8_t tileset_data[];",
        "extern const uint8_t tileset_count;",
        "extern const uint8_t metatile_tiles[];",
        "extern const uint8_t metatile_count;",
        "extern const uint8_t digit_tiles[10][2];",
        "extern const uint8_t font_tiles[128];",
        "",
        "#endif",
    ]
    (GEN / "tiles.h").write_text("\n".join(hlines) + "\n", encoding="utf-8")


def main() -> None:
    image = Image.open(SHEET).convert("RGB")
    metatiles: dict[str, list[list[int]]] = {}
    for name in CUSTOM_16:
        metatiles[name] = CUSTOM_16[name]
    for name in SPRITES:
        metatiles[name] = sprite16(image, name)

    pool = TilePool()
    # Add metatile quadrants first so the tile indices are ordered by sprite.
    for name in metatiles:
        for q in quadrants(metatiles[name]):
            pool.add(q, f"{name}.q")

    digit_tiles: dict[str, tuple[int, int]] = {}
    for d in range(10):
        top, bottom = digit16(str(d))
        digit_tiles[str(d)] = (pool.add(top, f"digit{d}.top"), pool.add(bottom, f"digit{d}.bottom"))

    font_tiles: dict[str, int] = {}
    for char, rows in FONT.items():
        font_tiles[char] = pool.add(glyph8(rows), f"font.{ord(char):02X}")

    build_contact_sheet(metatiles)
    build_mock(metatiles)
    emit(metatiles, pool, digit_tiles, font_tiles)

    print(f"Metatiles: {len(metatiles)}")
    print(f"Unique 8x8 tiles: {len(pool.data)} / 256")
    print(f"Wrote {ART / 'contact-sheet-16.png'}")
    print(f"Wrote {ART / 'level1-mock-16.png'}")
    print(f"Wrote {GEN / 'tiles.c'}, tiles_bank.c and tiles.h")


if __name__ == "__main__":
    main()
