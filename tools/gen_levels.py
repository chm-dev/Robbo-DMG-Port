#!/usr/bin/env python3
"""Generate banked C level packs from the Atari/GBC set by default.

The default source is gb/tools/data/atari_levels.dat.  Pass --gnu to use the
legacy gb/tests/fixtures/levels.json (robboJS/GNU original) instead.

Each level pack contains:
    - one byte per cell: cell type (walls encode their texture slot)
    - one byte per cell: packed extra state (turret config, bear dir, ...)
    - a small uint16 table of teleport destination cell indices

The banked loader copy these into WRAM and returns.  Bank 0 then builds the
object pool and renderer state.  This keeps cross-bank pointers out of the
engine.

Run: python gb/tools/gen_levels.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import tileset

ROOT = Path(__file__).resolve().parents[2]
LEVELS = ROOT / "gb" / "tests" / "fixtures" / "levels.json"
ATARI_LEVELS = ROOT / "gb" / "tools" / "data" / "atari_levels.dat"
GEN = ROOT / "gb" / "src" / "gen"

MAP_W = 16
MAP_H = 31
CELLS = MAP_W * MAP_H
LEVELS_PER_BANK = 8

# Cell type ids.  Keep in sync with gb/src/core/game.h.
EMPTY = 0
WALL_0 = 1
GROUND = 9
STONE = 10
PUSHABLE = 11
DOOR = 12
SPACESHIP = 13
QUESTION = 14
BOMB = 15
KEY = 16
SCREW = 17
TURRET = 18
AMMO = 19
TELEPORT = 20
MUSTACHE = 21
BUTTERFLY = 22
BEAR = 23
LAVA = 24
MAGNET = 25
ROBBO = 26
EXTRA_LIFE = 29
BARRIER = 30

TYPE_ID = {
    "Empty": EMPTY,
    "Ground": GROUND,
    "Stone": STONE,
    "PushableStone": PUSHABLE,
    "Door": DOOR,
    "Spaceship": SPACESHIP,
    "Question": QUESTION,
    "Bomb": BOMB,
    "Key": KEY,
    "Screw": SCREW,
    "Turrel": TURRET,
    "Ammo": AMMO,
    "Teleport": TELEPORT,
    "Mustache": MUSTACHE,
    "Butterfly": BUTTERFLY,
    "Bear": BEAR,
    "Lava": LAVA,
    "Magnet": MAGNET,
    "Robbo": ROBBO,
    "ExtraLife": EXTRA_LIFE,
    "Barrier": BARRIER,
}

BULLET_TYPE = {"gun": 0, "laser": 1, "antimatter": 2}
BULLET_NAME = {v: k for k, v in BULLET_TYPE.items()}

# Wall style is selected at level load from the 14-cell rotation table in
# tiles.h.  Level data only needs to distinguish visible walls (slot 1) from
# the fixed black cave fill (slot 5).
#
# Some Atari levels mix two colour variants of the same wall shape: the usual
# inverse-palette wall and the normal-palette wall (Atari glyph $00, written as
# GNU 'O' plus an [additional] record whose first value is 9).  GNU/GBC keep the
# distinction in the cell state, so it is carried here in map_extra:
#   bit 7 = visible wall drawn with the level's *normal* palette (CGB only).
# The Atari loader appends it as the 4th field of a "Walls" cell; the legacy
# --gnu fixture keeps its 3-field ["Walls", slot, glyph] shape.
WALL_NORMAL_BIT = 0x80


def pack_extra(cell: list, teleports: list[int]) -> int:
    t = cell[0]
    if t == "Turrel":
        # [type, direction, moveDirection, bulletType, movable, rotatable]
        value = (
            (cell[1] & 3)
            | ((cell[2] & 3) << 2)
            | ((BULLET_TYPE.get(cell[3], 0) & 3) << 4)
            | ((1 if cell[4] else 0) << 6)
            | ((1 if cell[5] else 0) << 7)
        )
        return value
    if t == "Mustache":
        return (cell[1] & 3) | ((1 if cell[2] else 0) << 2)
    if t == "Bear":
        return (cell[1] & 3) | ((1 if cell[2] else 0) << 2)
    if t in ("Magnet", "Lava", "Barrier"):
        return cell[1] & 3
    if t == "Question":
        return cell[1] & 15
    if t == "Spaceship":
        return 1 if cell[1] else 0
    if t == "Robbo":
        return cell[1] & 3
    if t == "Teleport":
        dest = cell[2] * MAP_W + cell[1]
        if dest not in teleports:
            teleports.append(dest)
        return teleports.index(dest)
    return 0


GLYPH_TYPE = {
    "H": "Ground", "#": "Stone", "~": "PushableStone", "D": "Door",
    "!": "Spaceship", "?": "Question", "b": "Bomb", "%": "Key",
    "T": "Screw", "'": "Ammo", "V": "Butterfly", ".": "Empty",
}


def _pad(values: list[int], count: int) -> list[int]:
    return (list(values) + [0] * count)[:count]


def load_atari_levels(path: Path = ATARI_LEVELS) -> list[dict]:
    """Read the GBC-compatible Atari .dat and return canonical level records.

    The source was produced by robbo-gbc/tools/convert_atari_levels.py from
    lkavalon-atari robbo/d2/C1-C3.txt.  Level data only distinguishes visible
    walls from cave fill; the four-level wall texture is applied at level load
    from wall_rotation_cells[] in the generated tiles.h.
    """
    text = path.read_text(encoding="latin-1").splitlines()
    raw: dict[int, dict] = {}
    cur = None
    mode = None
    i = 0
    while i < len(text):
        line = text[i]
        if line == "[level]":
            cur = {"rows": [], "add": []}
            raw[int(text[i + 1])] = cur
            i += 2
            mode = None
            continue
        if line == "[data]":
            mode = "data"
            i += 1
            continue
        if line == "[additional]":
            i += 1
            count = int(text[i])
            i += 1
            for _ in range(count):
                p = text[i].split(".")
                cur["add"].append(
                    (int(p[0]), int(p[1]), p[2], [int(v) for v in p[3:]])
                )
                i += 1
            mode = None
            continue
        if line.startswith("["):
            mode = None
            i += 1
            continue
        if mode == "data" and line:
            cur["rows"].append(line)
        i += 1

    levels = []
    for number in sorted(raw):
        lv = raw[number]
        rows = lv["rows"]
        if len(rows) != MAP_H or any(len(r) != MAP_W for r in rows):
            raise SystemExit(f"Level {number}: expected {MAP_W}x{MAP_H}")
        addmap = {(x, y): vals for (x, y, _ch, vals) in lv["add"]}

        groups: dict[int, list[tuple[int, int]]] = {}
        for y in range(MAP_H):
            for x in range(MAP_W):
                if rows[y][x] == "&":
                    vals = addmap.get((x, y))
                    if not vals:
                        raise SystemExit(f"Level {number}: unlinked teleport at {x},{y}")
                    groups.setdefault(vals[0], []).append((x, y))
        dest: dict[tuple[int, int], tuple[int, int]] = {}
        for cells in groups.values():
            for k, (x, y) in enumerate(cells):
                dest[(x, y)] = cells[(k + 1) % len(cells)]

        cells = []
        for y in range(MAP_H):
            row = []
            for x in range(MAP_W):
                ch = rows[y][x]
                vals = addmap.get((x, y), [])
                if ch in tileset.WALL_GLYPHS:
                    normal = 1 if (vals and vals[0] == 9) else 0
                    row.append(["Walls", 0, "-" if ch == "-" else "O", normal])
                elif ch == "R":
                    row.append(["Robbo", 1, 0, 0])
                elif ch == "&":
                    dx, dy = dest[(x, y)]
                    row.append(["Teleport", dx, dy])
                elif ch == "+":
                    row.append(["ExtraLife"])
                elif ch == "}":
                    v = _pad(vals, 5)
                    row.append([
                        "Turrel", v[0] & 3, v[1] & 3,
                        BULLET_NAME.get(v[2] & 3, "gun"), v[3] & 1, v[4] & 1,
                    ])
                elif ch == "^":
                    v = _pad(vals, 3)
                    row.append(["Mustache", v[0] & 3, v[2] & 1])
                elif ch in "@*":
                    v = _pad(vals, 1)
                    row.append(["Bear", v[0] & 3, 1 if ch == "*" else 0])
                elif ch == "M":
                    v = _pad(vals, 1)
                    row.append(["Magnet", v[0] & 3])
                elif ch == "=":
                    v = _pad(vals, 1)
                    row.append(["Barrier", v[0] & 3])
                elif ch == "!":
                    row.append(["Spaceship", 0])
                elif ch == "?":
                    row.append(["Question", 0])
                elif ch in GLYPH_TYPE:
                    row.append([GLYPH_TYPE[ch]])
                else:
                    raise SystemExit(
                        f"Level {number}: unknown glyph {ch!r} at {x},{y}"
                    )
            cells.append(row)

        flat = "".join(rows)
        if flat.count("R") != 1 or flat.count("!") != 1:
            raise SystemExit(f"Level {number}: expected one Robbo and one capsule")
        levels.append({
            "number": number,
            "canonical": {
                "width": MAP_W,
                "height": MAP_H,
                "screw": sum(r.count("T") for r in rows),
                "cells": cells,
            },
        })

    if len(levels) != 56:
        raise SystemExit(f"Expected 56 Atari levels, found {len(levels)}")
    return levels


def format_bytes(values: list[int], indent: str = "    ") -> str:
    lines = []
    for i in range(0, len(values), 16):
        lines.append(indent + ", ".join(str(v) for v in values[i:i + 16]) + ",")
    return "\n".join(lines)


def main() -> None:
    # The ROM ships the authentic Atari/GBC set by default.  Pass --gnu to
    # regenerate the previous robboJS/GNU fixture instead.
    if "--gnu" in sys.argv[1:]:
        data = json.loads(LEVELS.read_text(encoding="utf-8"))
        levels = data["levels"]
        source = "robboJS/GNU levels.json"
    else:
        levels = load_atari_levels()
        source = "Atari/GBC levels (gb/tools/data/atari_levels.dat)"
    assert len(levels) == 56
    print(f"Source: {source}")

    GEN.mkdir(parents=True, exist_ok=True)

    declarations = []
    switch_cases = []
    packs_by_bank: dict[int, list[str]] = {}

    for level in levels:
        number = level["number"]
        canonical = level["canonical"]
        height = canonical["height"]
        assert height in (30, 31)
        assert canonical["width"] == 16

        map_bytes = [EMPTY] * CELLS
        extra_bytes = [0] * CELLS
        teleports: list[int] = []

        for y in range(height):
            for x in range(MAP_W):
                cell = canonical["cells"][y][x]
                idx = y * MAP_W + x
                t = cell[0]
                if t == "Walls":
                    slot = tileset.WALL_SLOT[cell[2]]
                    map_bytes[idx] = WALL_0 + slot
                else:
                    map_bytes[idx] = TYPE_ID[t]
                extra_bytes[idx] = pack_extra(cell, teleports)
                # Legacy (--gnu) wall cells are ["Walls", slot, glyph]; only the
                # Atari loader appends the normal-palette flag as a 4th field.
                if t == "Walls" and len(cell) > 3 and cell[3]:
                    extra_bytes[idx] |= WALL_NORMAL_BIT

        if len(teleports) > 64:
            raise SystemExit(f"Level {number}: {len(teleports)} teleport destinations (>64)")

        bank = 1 + (number - 1) // LEVELS_PER_BANK
        decl = f"void load_level_{number:02d}(void) BANKED;"
        declarations.append(decl)
        switch_cases.append(f"        case {number}: load_level_{number:02d}(); break;")

        body = []
        body.append(f"/* Level {number}: {height} rows, {canonical['screw']} screws, {len(teleports)} teleport links */")
        body.append(f"static const uint8_t l{number:02d}_map[{CELLS}] = {{")
        body.append(format_bytes(map_bytes))
        body.append("};")
        body.append("")
        body.append(f"static const uint8_t l{number:02d}_extra[{CELLS}] = {{")
        body.append(format_bytes(extra_bytes))
        body.append("};")
        body.append("")
        body.append(f"static const uint16_t l{number:02d}_tp[{len(teleports) if teleports else 1}] = {{")
        if teleports:
            body.append("    " + ", ".join(str(v) for v in teleports) + ",")
        else:
            body.append("    0,")
        body.append("};")
        body.append("")
        body.append(f"void load_level_{number:02d}(void) BANKED")
        body.append("{")
        body.append("    uint16_t i;")
        body.append(f"    level_height = {height};")
        body.append(f"    level_screw = {canonical['screw']};")
        body.append(f"    level_planet = {number};")
        body.append(f"    level_teleport_count = {len(teleports)};")
        body.append(f"    for (i = 0; i < {CELLS}; i++) {{")
        body.append(f"        map_type[i] = l{number:02d}_map[i];")
        body.append(f"        map_extra[i] = l{number:02d}_extra[i];")
        body.append("    }")
        body.append(f"    for (i = 0; i < {len(teleports) if teleports else 1}; i++)")
        body.append(f"        teleport_dest[i] = l{number:02d}_tp[i];")
        body.append("}")
        body.append("")

        packs_by_bank.setdefault(bank, []).append("\n".join(body))

    # levels.h
    hlines = [
        "/* Generated by gb/tools/gen_levels.py - do not edit. */",
        "#ifndef LEVELS_H",
        "#define LEVELS_H",
        "",
        "#include <stdint.h>",
        "#include <gbdk/platform.h>",
        "",
        "#define LEVEL_COUNT 56",
        "",
        "void load_level_data(uint8_t level);",
        "",
    ]
    hlines += declarations
    hlines += ["", "#endif"]
    (GEN / "levels.h").write_text("\n".join(hlines) + "\n", encoding="utf-8")

    # level_index.c
    index_lines = [
        "/* Generated by gb/tools/gen_levels.py - do not edit. */",
        '#include "levels.h"',
        "",
        "void load_level_data(uint8_t level)",
        "{",
        "    switch (level) {",
    ]
    index_lines += switch_cases
    index_lines += [
        "        default: break;",
        "    }",
        "}",
        "",
    ]
    (GEN / "level_index.c").write_text("\n".join(index_lines), encoding="utf-8")

    # one file per bank
    for bank, packs in sorted(packs_by_bank.items()):
        lines = [
            "/* Generated by gb/tools/gen_levels.py - do not edit. */",
            f"#pragma bank {bank}",
            "",
            "#include <gbdk/platform.h>",
            "#include <stdint.h>",
            '#include "levels.h"',
            '#include "../core/game.h"',
            "",
        ]
        lines.append("\n".join(packs))
        (GEN / f"levels_bank{bank}.c").write_text("\n".join(lines), encoding="utf-8")

    print(f"Generated {len(levels)} levels across {len(packs_by_bank)} banks")
    total = sum(len(Path(GEN / f'levels_bank{b}.c').read_text()) for b in packs_by_bank)
    print(f"Bank source size: {total} bytes")


if __name__ == "__main__":
    main()
