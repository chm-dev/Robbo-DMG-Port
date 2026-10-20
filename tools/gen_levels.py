#!/usr/bin/env python3
"""Generate banked C level packs from gb/tests/fixtures/levels.json.

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
from pathlib import Path

import tileset

ROOT = Path(__file__).resolve().parents[2]
LEVELS = ROOT / "gb" / "tests" / "fixtures" / "levels.json"
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
}

BULLET_TYPE = {"gun": 0, "laser": 1, "antimatter": 2}


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
    if t in ("Magnet", "Lava"):
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


def format_bytes(values: list[int], indent: str = "    ") -> str:
    lines = []
    for i in range(0, len(values), 16):
        lines.append(indent + ", ".join(str(v) for v in values[i:i + 16]) + ",")
    return "\n".join(lines)


def main() -> None:
    data = json.loads(LEVELS.read_text(encoding="utf-8"))
    levels = data["levels"]
    assert len(levels) == 56

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
