#!/usr/bin/env python3
"""Convert the native 16x16 tiles.png sheet to DMG shade indices.

Mapping:
    transparent -> shade 1 (game background)
    yellow      -> shade 0 (Robbo main, projectiles, highlights)
    green       -> shade 2 (Robbo secondary details)
    blue        -> shade 2 (walls and machinery)
    black       -> shade 3 (outlines)

Run from the repository root:
    python gb/tools/convert_tiles_dmg.py

Writes:
    tiles_dmg.png
    tiles_dmg_preview.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tiles.png"
OUT = ROOT / "tiles_dmg.png"
PREVIEW = ROOT / "tiles_dmg_preview.png"

YELLOW = (254, 254, 2, 255)
GREEN = (2, 194, 2, 255)
BLUE = (28, 39, 131, 255)
BLACK = (16, 16, 16, 255)

OPAQUE = [YELLOW, GREEN, BLUE, BLACK]
SHADE = {
    (0, 0, 0, 0): 1,
    YELLOW: 0,
    GREEN: 2,
    BLUE: 2,
    BLACK: 3,
}
PALETTE = [
    255, 255, 255,
    170, 170, 170,
    85, 85, 85,
    0, 0, 0,
]


def snap(pixel):
    if pixel[3] == 0:
        return (0, 0, 0, 0)
    return min(
        OPAQUE,
        key=lambda p: sum((p[i] - pixel[i]) ** 2 for i in range(3)),
    )


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    out = Image.new("P", src.size)
    out.putpalette(PALETTE + [0, 0, 0] * 252)
    src_px = src.load()
    out_px = out.load()
    for y in range(src.height):
        for x in range(src.width):
            out_px[x, y] = SHADE[snap(src_px[x, y])]
    out.save(OUT, optimize=True)
    out.resize(
        (src.width * 4, src.height * 4), Image.Resampling.NEAREST
    ).save(PREVIEW, optimize=True)
    print(f"Wrote {OUT}")
    print(f"Wrote {PREVIEW}")


if __name__ == "__main__":
    main()
