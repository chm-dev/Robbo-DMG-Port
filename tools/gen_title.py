#!/usr/bin/env python3
"""Generate the DMG title-screen assets.

The layout and behaviour are ported from the GBC title screen
(robbo-gbc/src/menu.c).  The authentic 'RoDDo' logo is the Atari TITLE.ASM
BIGR bitmap that the GBC port reproduces in robbo-gbc/tools/sim_logo.py.
The text uses the authentic Atari I.FNT font from robbo-gbc (see
gb/tools/atari_font.py).

DMG conversion:
  * The GBC rainbow is a temporal hue cycle of COLPF0/1/2.  DMG has no hue,
    so three pre-rendered logo variants rotate the three bevel shades; the
    BG map is switched between them every 8 frames.
  * The GBC palette bands become separate 1bpp font tile sets: bright
    credits, grey controls/instructions, and an inverse heading.

Outputs:
    gb/src/gen/title_data.c
    gb/src/gen/title_data.h
    gb/tests/art/title-dmg.png       (preview)

Run: python gb/tools/gen_title.py
"""
from __future__ import annotations

import string
from pathlib import Path

from PIL import Image

import atari_font
import gen_tiles

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "gb" / "src" / "gen"
ART = ROOT / "gb" / "tests" / "art"

# 56x8 source grid, 0 = background, 1..3 = the three logo shades.
# Derived from the authentic Atari TITLE.ASM BIGR routine through
# robbo-gbc/tools/sim_logo.py and robbo-gbc/src/gen/gfx_tiles.c.
LOGO_GRID = [
    "33221100000000000000000033200000000033200000000000000000",
    "32200220000000211200000032211200000032211200000000211200",
    "22100033000002110230000022100230000022100230000002110230",
    "21100032000021100032000021100032000021100032000021100032",
    "11200320000011200022000011200022000011200022000011200022",
    "12233200000012200021000012200021000012200021000012200021",
    "22300210000022300011000022300011000022300011000022300011",
    "23300012000003322110000023322110000023322110000003322110",
]
LOGO_SX, LOGO_SY = 2, 3                    # source pixels -> DMG pixels
LOGO_TW, LOGO_TH = 14, 3                  # 8x8 tiles

# DMG shades: 0 white, 1 light grey, 2 dark grey, 3 black (BGP = 0xE4).
# Each phase cyclically reassigns the three non-background shades.
LOGO_PHASE_MAPS = [
    {0: 3, 1: 2, 2: 1, 3: 0},
    {0: 3, 1: 1, 2: 0, 3: 2},
    {0: 3, 1: 0, 2: 2, 3: 1},
]

# Character sets needed by the title and start-level menu.  Credits and menu
# headings are bright; controls, typewriter and the delete option are grey;
# only the INSTRUCTIONS heading uses inverse video.
CREDIT_CHARS = string.ascii_uppercase + string.digits + ">?"
GRAY_CHARS = CREDIT_CHARS + ",.:-!+"
INVERSE_CHARS = "".join(dict.fromkeys("INSTRUCTIONS"))

# ---------------------------------------------------------------------------
# Instruction text (English, adapted from robbo-gbc's title)
# ---------------------------------------------------------------------------
# The GBC text says "OVERVIEW: HOLD B" and points at a restart option in its
# pause menu.  This port pans with B + D-PAD and has no restart menu, so the
# control hint is renamed and the restart paragraph is omitted.
WRAP = 20
PARAGRAPHS = [
    "INSTRUCTIONS",
    "",
    "ROBBO FACES A DIFFICULT JOURNEY ACROSS 56 PLANETS TO ESCAPE THE "
    "HOSTILE PLANETARY SYSTEM WHERE HE WAS TRICKED AND IMPRISONED.",
    "",
    "A SMALL CAPSULE AWAITS HIM ON EACH PLANET, READY TO CARRY HIM "
    "TO THE NEXT. UNFORTUNATELY, MOST CAPSULES ARE MISSING PARTS. "
    "ROBBO MUST COLLECT ENOUGH PARTS SCATTERED ACROSS THE PLANET TO "
    "REPAIR THEM.",
    "",
    "THE HOSTILE CREATURES THAT INHABIT THIS SYSTEM WILL TRY TO STOP HIM. "
    "ALONG THE WAY, ROBBO WILL FIND MANY DIFFERENT OBJECTS. DISCOVER "
    "WHAT THEY DO: TRY PUSHING THEM, PICKING THEM UP, OR SHOOTING THEM.",
    "",
    "REMEMBER: EVERY PLANET CAN BE COMPLETED!",
    "",
    "HAVE FUN! - THE AUTHOR",
]


def wrap(text: str, width: int) -> list[str]:
    lines: list[str] = []
    cur = ""
    for word in text.split():
        while len(word) > width:
            if cur:
                lines.append(cur)
                cur = ""
            lines.append(word[:width])
            word = word[width:]
        if not cur:
            cur = word
        elif len(cur) + 1 + len(word) <= width:
            cur += " " + word
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def build_instructions() -> list[str]:
    lines: list[str] = []
    for para in PARAGRAPHS:
        if para == "":
            if lines and lines[-1] != "":
                lines.append("")
            continue
        lines.extend(wrap(para, WRAP))
    while lines and lines[0] == "":
        lines.pop(0)
    while lines and lines[-1] == "":
        lines.pop()
    if lines and lines[0] == "INSTRUCTIONS":
        lines[0] = " " * ((WRAP - len(lines[0])) // 2) + lines[0]
    for line in lines:
        assert len(line) <= WRAP, repr(line)
    return lines


def tile_bytes(shades: list[list[int]]) -> bytes:
    return gen_tiles.to_tile_bytes(shades)


def font_tile(rows: list[str], fg: int, bg: int) -> bytes:
    tile = [[bg] * 8 for _ in range(8)]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                tile[y][x] = fg
    return tile_bytes(tile)


def logo_tiles(mapping: dict[int, int]) -> list[bytes]:
    out: list[bytes] = []
    for ty in range(LOGO_TH):
        for tx in range(LOGO_TW):
            tile = [[0] * 8 for _ in range(8)]
            for py in range(8):
                sy = (ty * 8 + py) // LOGO_SY
                for px in range(8):
                    sx = (tx * 8 + px) // LOGO_SX
                    tile[py][px] = mapping[int(LOGO_GRID[sy][sx])]
            out.append(tile_bytes(tile))
    return out


def main() -> None:
    instructions = build_instructions()

    tiles: list[bytes] = []
    logo_bases: list[int] = []
    for mapping in LOGO_PHASE_MAPS:
        logo_bases.append(len(tiles))
        tiles.extend(logo_tiles(mapping))

    lookups: dict[str, tuple[int, list[int]]] = {}
    styles = (
        ("white", CREDIT_CHARS, 0, 3),
        ("gray", GRAY_CHARS, 1, 3),
        ("inverse", INVERSE_CHARS, 3, 1),
    )
    for name, chars, fg, bg in styles:
        base = len(tiles)
        table = [0xFF] * 128
        for ch in chars:
            rows = atari_font.FONT8.get(ch) or atari_font.SPECIALS[ch]
            table[ord(ch)] = len(tiles)
            tiles.append(font_tile(rows, fg, bg))
        lookups[name] = (base, table)

    copyright_tile = len(tiles)
    tiles.append(font_tile(atari_font.SPECIALS["©"], 0, 3))
    rule_tile = len(tiles)
    tiles.append(font_tile(atari_font.SPECIALS["rule"], 1, 3))
    caret_tile = len(tiles)
    tiles.append(font_tile(atari_font.SPECIALS["caret"], 1, 3))
    black_tile = len(tiles)
    tiles.append(tile_bytes([[3] * 8 for _ in range(8)]))

    # The start-level menu shows the planet number with the authentic 8x16
    # HUD digits from the game sheet, not the I.FNT title glyphs.
    hud_sheet = Image.open(gen_tiles.SHEET).convert("P")
    hud_digit_base = len(tiles)
    hud_digits: list[tuple[int, int]] = []
    for d in range(10):
        top, bottom = gen_tiles.sheet_digit(hud_sheet, d)
        top_tile = len(tiles)
        tiles.append(tile_bytes(top))
        bottom_tile = len(tiles)
        tiles.append(tile_bytes(bottom))
        hud_digits.append((top_tile, bottom_tile))

    GEN.mkdir(parents=True, exist_ok=True)
    with open(GEN / "title_data.h", "w", encoding="utf-8") as h:
        h.write("/* Generated by gb/tools/gen_title.py - do not edit. */\n")
        h.write("#ifndef TITLE_DATA_H\n#define TITLE_DATA_H\n\n")
        h.write("#include <stdint.h>\n\n")
        h.write(f"#define TITLE_LOGO_TW {LOGO_TW}\n")
        h.write(f"#define TITLE_LOGO_TH {LOGO_TH}\n")
        h.write(f"#define TITLE_LOGO_TILES {LOGO_TW * LOGO_TH}\n")
        for i, base in enumerate(logo_bases):
            h.write(f"#define TITLE_LOGO_{i} {base}\n")
        h.write(f"#define TITLE_FONT_WHITE {lookups['white'][0]}\n")
        h.write(f"#define TITLE_FONT_GRAY {lookups['gray'][0]}\n")
        h.write(f"#define TITLE_FONT_INVERSE {lookups['inverse'][0]}\n")
        h.write(f"#define TITLE_COPYRIGHT_TILE {copyright_tile}\n")
        h.write(f"#define TITLE_RULE_TILE {rule_tile}\n")
        h.write(f"#define TITLE_CARET_TILE {caret_tile}\n")
        h.write(f"#define TITLE_BLACK_TILE {black_tile}\n")
        h.write(f"#define TITLE_HUD_DIGIT_BASE {hud_digit_base}\n")
        h.write(f"#define TITLE_HUD_DIGIT_COUNT {len(hud_digits) * 2}\n")
        h.write(f"#define TITLE_TILE_COUNT {len(tiles)}\n")
        h.write(f"#define TITLE_INSTR_WIDTH {WRAP}\n")
        h.write(f"#define TITLE_INSTR_NLINES {len(instructions)}\n\n")
        h.write("extern const uint8_t title_tiles[TITLE_TILE_COUNT * 16];\n")
        h.write("extern const uint8_t title_font_white[128];\n")
        h.write("extern const uint8_t title_font_gray[128];\n")
        h.write("extern const uint8_t title_font_inverse[128];\n")
        h.write("extern const uint8_t title_hud_digits[10][2];\n")
        h.write("extern const char title_instr[TITLE_INSTR_NLINES][TITLE_INSTR_WIDTH + 1];\n\n")
        h.write("#endif\n")

    with open(GEN / "title_data.c", "w", encoding="utf-8") as c:
        c.write("/* Generated by gb/tools/gen_title.py - do not edit. */\n")
        c.write("#pragma bank 11\n\n")
        c.write("#include <stdint.h>\n#include \"title_data.h\"\n\n")
        c.write(f"const uint8_t title_tiles[{len(tiles) * 16}] = {{\n")
        for i, tile in enumerate(tiles):
            c.write(f"  /* {i:3d} */ " + ",".join(f"0x{b:02X}" for b in tile) + ",\n")
        c.write("};\n\n")
        c.write("const uint8_t title_hud_digits[10][2] = {\n")
        for d, (top, bottom) in enumerate(hud_digits):
            c.write(f"  {{ {top}, {bottom} }},  /* {d} */\n")
        c.write("};\n\n")
        for name in ("white", "gray", "inverse"):
            base, table = lookups[name]
            c.write(f"const uint8_t title_font_{name}[128] = {{\n")
            for i in range(0, 128, 16):
                c.write("  " + ", ".join(f"0x{v:02X}" for v in table[i:i + 16]) + ",\n")
            c.write("};\n\n")
        c.write(f"const char title_instr[{len(instructions)}][{WRAP + 1}] = {{\n")
        for line in instructions:
            c.write(f'  "{line}",\n')
        c.write("};\n")

    # Preview: the title with a filled instruction page (like the GBC screen).
    scale = 4
    image = Image.new("RGB", (160, 144), gen_tiles.RGB[3])
    px = image.load()

    def put_tile(x: int, y: int, idx: int) -> None:
        data = tiles[idx]
        for row in range(8):
            lo, hi = data[row * 2], data[row * 2 + 1]
            for col in range(8):
                bit = 7 - col
                value = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                px[x * 8 + col, y * 8 + row] = gen_tiles.RGB[value]

    def put_text(x: int, y: int, text: str, table: list[int]) -> None:
        for i, ch in enumerate(text):
            where = table[ord(ch)]
            if where != 0xFF:
                put_tile(x + i, y, where)

    for ty in range(LOGO_TH):
        for tx in range(LOGO_TW):
            put_tile(3 + tx, ty, logo_bases[0] + ty * LOGO_TW + tx)

    put_tile(2, 4, copyright_tile)
    put_text(4, 4, "1989 BY AVALON", lookups["white"][1])
    put_text(0, 5, "PROGRAM AND GRAPHICS", lookups["white"][1])
    put_text(4, 6, "JANUSZ PELC", lookups["white"][1])

    put_text(0, 8, "CONTROL:  D-PAD", lookups["gray"][1])
    put_text(0, 9, "FIRE:     A + D-PAD", lookups["gray"][1])
    put_text(0, 10, "PAN:      B + D-PAD", lookups["gray"][1])

    for x in range(20):
        put_tile(x, 11, rule_tile)
        put_tile(x, 17, rule_tile)

    page = ["ROBBO FACES A", "DIFFICULT JOURNEY", "ACROSS 56 PLANETS TO",
            "ESCAPE THE HOSTILE", "PLANETARY SYSTEM"]
    for row, line in enumerate(page):
        put_text(0, 12 + row, line, lookups["gray"][1])

    ART.mkdir(parents=True, exist_ok=True)
    image.resize((160 * scale, 144 * scale), Image.NEAREST).save(ART / "title-dmg.png")

    print(f"Title tiles: {len(tiles)} / 256")
    print(f"Instruction lines: {len(instructions)} (width {WRAP})")
    print(f"Wrote {GEN / 'title_data.c'}, {GEN / 'title_data.h'} and {ART / 'title-dmg.png'}")


if __name__ == "__main__":
    main()
