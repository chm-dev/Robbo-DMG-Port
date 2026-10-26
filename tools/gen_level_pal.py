#!/usr/bin/env python3
"""Emit the per-level CGB palettes for the DMG port's colour mode.

Source:   robbo-gbc/src/atari_pal.c  (GENERATED on the GBC side from the
          authentic Atari d2/C*.txt colour registers through Altirra's
          Default PAL palette; see robbo-gbc/AGENTS.md).
Output:   gb/src/gen/level_pal.c / level_pal.h   (bank 10, CGB BGR555)
          gb/src/gen/level_pal_nes.c / level_pal_nes.h
                                              (bank 10, NES $00..$3F)

The NES table is derived from the same BGR555 roles, converted to NES
colour indices with a grey-aware, contrast-constrained quantiser (the 2C02
has no mid-grey, and several Atari palettes put a grey wall/background next
to a dark blue/green), then reordered for the NES build's swapped tile
indices: entry 0 = background (shared backdrop), 1 = bright, 2 = mid,
3 = dark.  Only the normal and wall palettes are stored; the inverse object
palette is a reorder of the wall entries and is built at load time by
color.c.

The GBC table stores two 4-colour palettes per level in Atari order:

    [0..3] normal  = COLB, COLPF0, COLPF1, COLPF2
    [4..7] inverse = COLB, COLPF0, COLPF1, COL3   (walls)

This port's artwork has four fixed shade roles, so the palette is reordered
to the art's index order:

    index 0 = bright (Robbo, bolts, highlights)  -> COLPF2
    index 1 = background / transparent           -> COLB
    index 2 = mid    (machinery, wall body)      -> COLPF1
    index 3 = dark   (outlines)                  -> COLPF0
                                                 (COL3 in the wall palette)

The cave-fill palette is not stored: it is solid COLPF0, which is art index 3
of the normal palette, built at load time.

Run from the repository root:
    python gb/tools/gen_level_pal.py
"""
from __future__ import annotations

import math
import re
from functools import lru_cache
from pathlib import Path

from PIL import Image

import tileset

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "robbo-gbc" / "src" / "atari_pal.c"
SHEET_PNG = ROOT / "tiles_dmg.png"
OUT_C = ROOT / "gb" / "src" / "gen" / "level_pal.c"
OUT_H = ROOT / "gb" / "src" / "gen" / "level_pal.h"
OUT_NES_C = ROOT / "gb" / "src" / "gen" / "level_pal_nes.c"
OUT_NES_H = ROOT / "gb" / "src" / "gen" / "level_pal_nes.h"

ROW = re.compile(
    r"\{(0x[0-9A-Fa-f]{4})\s*,\s*(0x[0-9A-Fa-f]{4})\s*,\s*"
    r"(0x[0-9A-Fa-f]{4})\s*,\s*(0x[0-9A-Fa-f]{4})\s*,\s*"
    r"(0x[0-9A-Fa-f]{4})\s*,\s*(0x[0-9A-Fa-f]{4})\s*,\s*"
    r"(0x[0-9A-Fa-f]{4})\s*,\s*(0x[0-9A-Fa-f]{4})\s*\}"
)


# Wall art roles: role 3 is the mortar/grid on every wall style except the
# first one (levels 1-4), where it is a decorative edge that must keep COLPF1.
# The grid entry is forced to black on all other levels (5-56).
WALL_FIRST_STYLE_LEVELS = 4


# Standard 2C02 RGB palette, FCEUX's default set (6-bit values; P64 expands a
# 6-bit channel to 8 bits the same way FCEUX does).  Several entries are
# duplicates/blacks, which is normal for the hardware palette.
NES_PALETTE_6BIT = [
    (0x1D, 0x1D, 0x1D), (0x09, 0x06, 0x23), (0x00, 0x00, 0x2A), (0x11, 0x00, 0x27),
    (0x23, 0x00, 0x1D), (0x2A, 0x00, 0x04), (0x29, 0x00, 0x00), (0x1F, 0x02, 0x00),
    (0x10, 0x0B, 0x00), (0x00, 0x11, 0x00), (0x00, 0x14, 0x00), (0x00, 0x0F, 0x05),
    (0x06, 0x0F, 0x17), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0x2F, 0x2F, 0x2F), (0x00, 0x1C, 0x3B), (0x08, 0x0E, 0x3B), (0x20, 0x00, 0x3C),
    (0x2F, 0x00, 0x2F), (0x39, 0x00, 0x16), (0x36, 0x0A, 0x00), (0x32, 0x13, 0x03),
    (0x22, 0x1C, 0x00), (0x00, 0x25, 0x00), (0x00, 0x2A, 0x00), (0x00, 0x24, 0x0E),
    (0x00, 0x20, 0x22), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0x3F, 0x3F, 0x3F), (0x0F, 0x2F, 0x3F), (0x17, 0x25, 0x3F), (0x33, 0x22, 0x3F),
    (0x3D, 0x1E, 0x3F), (0x3F, 0x1D, 0x2D), (0x3F, 0x1D, 0x18), (0x3F, 0x26, 0x0E),
    (0x3C, 0x2F, 0x0F), (0x20, 0x34, 0x04), (0x13, 0x37, 0x12), (0x16, 0x3E, 0x26),
    (0x00, 0x3A, 0x36), (0x1E, 0x1E, 0x1E), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0x3F, 0x3F, 0x3F), (0x2A, 0x39, 0x3F), (0x31, 0x35, 0x3F), (0x35, 0x32, 0x3F),
    (0x3F, 0x31, 0x3F), (0x3F, 0x31, 0x36), (0x3F, 0x2F, 0x2C), (0x3F, 0x36, 0x2A),
    (0x3F, 0x39, 0x28), (0x38, 0x3F, 0x28), (0x2A, 0x3C, 0x2F), (0x2C, 0x3F, 0x33),
    (0x27, 0x3F, 0x3C), (0x31, 0x31, 0x31), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
]


def p64(v: int) -> int:
    """Expand a 6-bit NES channel to 8 bits (FCEUX's P64)."""
    return (v << 2) | ((v >> 4) & 3)


NES_RGB = [tuple(p64(c) for c in entry) for entry in NES_PALETTE_6BIT]


def bgr555_to_rgb(value: int) -> tuple[int, int, int]:
    r = value & 0x1F
    g = (value >> 5) & 0x1F
    b = (value >> 10) & 0x1F
    return (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2)


def _luma(rgb: tuple[int, int, int]) -> float:
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


# NES grey ramp, deduplicated by RGB.  The 2C02 has no mid-grey between black
# and ~117, which is why a naive RGB match sends greys to dark blue/green.
_NEUTRALS: list[tuple[int, tuple[int, int, int], float]] = []
_seen_rgb: set[tuple[int, int, int]] = set()
for _i, _rgb in enumerate(NES_RGB):
    if max(_rgb) - min(_rgb) <= 2 and _rgb not in _seen_rgb:
        _NEUTRALS.append((_i, _rgb, _luma(_rgb)))
        _seen_rgb.add(_rgb)


def _rgb_dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return math.sqrt(2 * dr * dr + 4 * dg * dg + 3 * db * db)


def _is_neutral(rgb: tuple[int, int, int]) -> bool:
    return max(rgb) - min(rgb) <= 24


def _gray_snap(rgb: tuple[int, int, int]) -> int:
    """Quantise a low-chroma source to the NES grey ramp.

    Pure black stays black; any other grey is lifted to a visible grey so it
    cannot collapse into a dark blue/green (the L2/L3/L6 background bug).
    """
    l = _luma(rgb)
    pool = [t for t in _NEUTRALS if t[2] > 10] if l > 8 else _NEUTRALS
    # Bias slightly brighter: NES has a wide gap between 49 and 117.
    return min(pool, key=lambda t: (abs(t[2] - l) + (20 if t[2] < l else 0), t[0]))[0]


def _nes_candidates(rgb: tuple[int, int, int]) -> list[int]:
    """Closest NES entries for a source colour, neutrals always available."""
    if _is_neutral(rgb):
        return [t[0] for t in _NEUTRALS]
    seen: dict[tuple[int, int, int], int] = {}
    for i, c in enumerate(NES_RGB):
        seen.setdefault(c, i)
    out = sorted(seen.values(), key=lambda i: _rgb_dist(rgb, NES_RGB[i]))
    for t in _NEUTRALS:
        if t[0] not in out:
            out.append(t[0])
    return out


def _contrast(a: int, b: int, need: int | str = 25) -> bool:
    ca, cb = NES_RGB[a], NES_RGB[b]
    dy = abs(_luma(ca) - _luma(cb))
    d = math.sqrt(sum((ca[i] - cb[i]) ** 2 for i in range(3)))
    if need == "blink":
        # The teleport's middle block must change visibly, not just a hint.
        return dy >= 45 and d >= 50
    return dy >= need or (dy >= 12 and d >= 90)


@lru_cache(maxsize=1)
def _wall_usage() -> tuple[tuple[int, int, int, int], ...]:
    """Pixel count per art role for each four-level wall style.

    Derived from the same tiles_dmg.png sheet the tile generator uses, so a
    changed wall glyph automatically updates the contrast weights.
    """
    shades = {
        (255, 255, 255): 0,
        (170, 170, 170): 1,
        (85, 85, 85): 2,
        (0, 0, 0): 3,
    }
    if not SHEET_PNG.exists():
        raise SystemExit(f"missing {SHEET_PNG}; run convert_tiles_dmg.py first")
    image = Image.open(SHEET_PNG).convert("RGB")
    out = []
    for col, row in tileset.WALL_ROTATION:
        x0 = 1 + col * 17
        y0 = 1 + row * 17
        counts = [0, 0, 0, 0]
        for y in range(16):
            for x in range(16):
                rgb = image.getpixel((x0 + x, y0 + y))
                if rgb not in shades:
                    rgb = min(shades, key=lambda c: sum((rgb[i] - c[i]) ** 2
                                                        for i in range(3)))
                counts[shades[rgb]] += 1
        out.append(tuple(counts))
    return tuple(out)


# Roles: 0 bg, 1 normal bright, 2 normal mid, 3 normal dark (cave/outline),
# 4 wall highlight, 5 wall body, 6 wall detail.
# The third field is the minimum luma separation; "blink" is the teleport pair.
_BASE_CONSTRAINTS = (
    (0, 1, 25), (0, 2, 25), (0, 3, 35),
    (3, 1, 25), (3, 2, 25),
    (0, 5, 25), (3, 5, 25), (4, 5, "blink"),
)


def _solve_nes_roles(level: int,
                     normal: list[str],
                     wall: list[str]) -> tuple[list[int], list[int]]:
    """Pick NES entries for one level's normal + wall palettes.

    Starts from a grey-aware nearest match, then repairs pairs that would
    visually collapse.  Roles are weighted by their art usage (and the
    teleport blink), so the least visible role is changed first.
    """
    style = (level - 1) // 4
    usage_counts = _wall_usage()[style]
    constraints = list(_BASE_CONSTRAINTS)
    # When the wall highlight is the style's main surface (styles 25-28 and
    # 37-40), it must also stand out from the floor.  It may equal the cave
    # fill (both are COLPF0) - that is the authentic wall-in-cave look; the
    # body/detail lines carry the structure there.
    if usage_counts[0] > 100:
        constraints.append((0, 4, 25))
    usage = [1000, 100, 80, 500,
             usage_counts[0] + 128, usage_counts[2] + 128,
             usage_counts[3] + 24]
    src = [bgr555_to_rgb(int(v, 16)) for v in (
        normal[1], normal[0], normal[2], normal[3],
        wall[0], wall[2], wall[3])]
    current = [
        _gray_snap(rgb) if _is_neutral(rgb)
        else min(range(64), key=lambda i: _rgb_dist(rgb, NES_RGB[i]))
        for rgb in src
    ]
    candidates = [_nes_candidates(rgb) for rgb in src]

    def cost(role: int, candidate: int) -> float:
        return (_rgb_dist(src[role], NES_RGB[candidate]) *
                (1 + usage[role] / 200))

    for _ in range(8):
        changed = False
        for a, b, need in constraints:
            if _contrast(current[a], current[b], need):
                continue
            best = None
            for role in (a, b):
                if role == 0:          # the shared backdrop is fixed
                    continue
                for candidate in candidates[role][:24]:
                    if candidate == current[role]:
                        continue
                    trial = list(current)
                    trial[role] = candidate
                    remaining = sum(
                        1 for x, y, req in constraints
                        if not _contrast(trial[x], trial[y], req))
                    delta = cost(role, candidate) - cost(role, current[role])
                    score = (remaining, delta)
                    if best is None or score < best[0]:
                        best = (score, role, candidate)
            if best is not None:
                current[best[1]] = best[2]
                changed = True
        if not changed:
            break

    bad = [(a, b) for a, b, need in constraints
           if not _contrast(current[a], current[b], need)]
    if bad:
        raise SystemExit(f"level {level}: no contrast-safe NES palette for {bad}")

    return ([current[0], current[1], current[2], current[3]],
            [current[0], current[4], current[5], current[6]])



def art_palettes(v: list[str], level: int) -> tuple[list[str], list[str]]:
    """Map Atari-order values to this port's art-index order.

    Walls: the GBC/Atari wall glyph draws its body with pixel value 3 (COL3)
    and its detail with value 2 (COLPF1); this port's wall metatile uses
    role 2 for the body and role 3 for the detail, so the two are crossed.
    """
    normal = [v[3], v[0], v[2], v[1]]          # COLPF2, COLB, COLPF1, COLPF0
    detail = v[2] if level <= WALL_FIRST_STYLE_LEVELS else "0x0000"
    wall = [v[1], v[0], v[7], detail]          # COLPF0, COLB, COL3, detail
    return normal, wall


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    rows = ROW.findall(text)
    if len(rows) != 56:
        raise SystemExit(f"expected 56 palettes in {SRC}, found {len(rows)}")

    lines = [
        "/* GENERATED by gb/tools/gen_level_pal.py - do not edit.",
        " *",
        " * Per-level Atari palettes in CGB BGR555 format, reordered to this",
        " * port's art-role indices.  Values come from robbo-gbc/src/atari_pal.c",
        " * (generated there from the authentic Atari colour registers through",
        " * Altirra's Default PAL palette - see robbo-gbc/AGENTS.md).",
        " *",
        " * [0..3] normal : COLPF2, COLB, COLPF1, COLPF0",
        " * [4..7] walls  : COLPF0, COLB, COL3, COLPF1",
        " */",
        "#pragma bank 10",
        "",
        '#include <stdint.h>',
        '#include "level_pal.h"',
        "",
        "const uint16_t level_pal_data[LEVEL_PAL_COUNT][8] = {",
    ]
    nes_rows: list[tuple[list[int], list[int]]] = []
    for i, row in enumerate(rows, start=1):
        normal, wall = art_palettes(row, i)
        entry = ", ".join(normal + wall)
        lines.append(f"  {{{entry}}}, /* {i} */")
        nes_rows.append(_solve_nes_roles(i, normal, wall))
    lines += ["};", ""]
    OUT_C.write_text("\n".join(lines), encoding="utf-8")

    OUT_H.write_text(
        "/* GENERATED by gb/tools/gen_level_pal.py - do not edit. */\n"
        "#ifndef GB_GEN_LEVEL_PAL_H\n"
        "#define GB_GEN_LEVEL_PAL_H\n"
        "\n"
        "#include <stdint.h>\n"
        "\n"
        "#define LEVEL_PAL_COUNT 56\n"
        "\n"
        "/* [level-1][0..3]=normal, [4..7]=walls, both in art-index order. */\n"
        "extern const uint16_t level_pal_data[LEVEL_PAL_COUNT][8];\n"
        "\n"
        "#endif\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT_C.relative_to(ROOT)} and {OUT_H.relative_to(ROOT)}")

    nes_lines = [
        "/* GENERATED by gb/tools/gen_level_pal.py - do not edit.",
        " *",
        " * Per-level NES BG palettes (2C02 colour indices $00..$3F).",
        " * Derived from the CGB BGR555 table above and reordered for the NES",
        " * build's swapped tile indices:",
        " *   entry 0 = background / shared backdrop (COLB)",
        " *   entry 1 = bright (COLPF2), 2 = mid (COLPF1), 3 = dark (COLPF0)",
        " * Walls: entry 1 = COLPF0, 2 = COL3, 3 = wall detail (black after L4).",
        " * The table is contrast-repaired: low-chroma sources stay grey (the",
        " * 2C02 has no mid-grey, so a plain nearest match sends them to dark",
        " * blue/green), and wall body/background/cave, baddie outline/floor and",
        " * the teleport blink pair are forced to stay distinguishable.",
        " * The inverse object palette is derived from the wall entries at load",
        " * time by color.c.",
        " */",
        "#pragma bank 10",
        "",
        "#include <stdint.h>",
        "#include <gbdk/platform.h>",
        "#ifdef NINTENDO_NES",
        '#include "level_pal_nes.h"',
        "",
        "const uint8_t level_pal_nes[LEVEL_PAL_NES_COUNT][8] = {",
    ]
    for i, (normal, wall) in enumerate(nes_rows, start=1):
        entry = ", ".join(f"0x{v:02X}" for v in normal + wall)
        nes_lines.append(f"  {{{entry}}}, /* {i} */")
    nes_lines += ["};", "#endif", ""]
    OUT_NES_C.write_text("\n".join(nes_lines), encoding="utf-8")

    OUT_NES_H.write_text(
        "/* GENERATED by gb/tools/gen_level_pal.py - do not edit. */\n"
        "#ifndef GB_GEN_LEVEL_PAL_NES_H\n"
        "#define GB_GEN_LEVEL_PAL_NES_H\n"
        "\n"
        "#include <stdint.h>\n"
        "\n"
        "#define LEVEL_PAL_NES_COUNT 56\n"
        "\n"
        "/* [level-1][0..3]=normal, [4..7]=walls, NES entries in swapped-art order. */\n"
        "extern const uint8_t level_pal_nes[LEVEL_PAL_NES_COUNT][8];\n"
        "\n"
        "#endif\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT_NES_C.relative_to(ROOT)} and {OUT_NES_H.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
