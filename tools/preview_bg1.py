#!/usr/bin/env python3
"""Preview the 16x16 Robbo sheet with the DMG background one shade darker.

Run from the repository root:
    python gb/tools/preview_bg1.py

This is a preview-only tool.  It does not regenerate the game tileset.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "gb" / "tools"))
import gen_tiles  # noqa: E402

SRC = ROOT / "tiles.png"
LEVELS = ROOT / "gb" / "tests" / "fixtures" / "levels.json"

# Canonical DMG shade preview (BGP 0xE4):
# 0 = white, 1 = light grey (background), 2 = dark grey, 3 = black.
PALETTE = [
    (255, 255, 255),
    (170, 170, 170),
    (85, 85, 85),
    (0, 0, 0),
]

# New contrast order: background is shade 1, while Robbo/projectiles and
# yellow details are the brightest shade 0.  Blue stays dark and black is the
# outline colour.
SRC_TO_SHADE = {
    (0, 0, 0, 0): 1,        # transparent -> game background
    (254, 254, 2, 255): 0,  # yellow -> white
    (2, 194, 2, 255): 2,    # green -> dark detail
    (28, 39, 131, 255): 2,  # blue -> dark
    (16, 16, 16, 255): 3,   # black -> outline
}
OPAQUE_SRC = [
    (254, 254, 2, 255),
    (2, 194, 2, 255),
    (28, 39, 131, 255),
    (16, 16, 16, 255),
]


def snap(pixel):
    if pixel[3] == 0:
        return (0, 0, 0, 0)
    return min(
        OPAQUE_SRC,
        key=lambda p: sum((p[i] - pixel[i]) ** 2 for i in range(3)),
    )


def cell_image(sheet: Image.Image, coord: tuple[int, int]) -> Image.Image:
    """Return a 16x16 image using the preview DMG palette."""
    x0 = 1 + coord[0] * 17
    y0 = 1 + coord[1] * 17
    out = Image.new("RGB", (16, 16))
    for y in range(16):
        for x in range(16):
            shade = SRC_TO_SHADE[snap(sheet.getpixel((x0 + x, y0 + y)))]
            out.putpixel((x, y), PALETTE[shade])
    return out


def preview_sheet(sheet: Image.Image) -> None:
    scale = 4
    out = Image.new("RGB", (sheet.width * scale, sheet.height * scale), PALETTE[1])
    draw = ImageDraw.Draw(out)
    # Grid lines are black in the source sheet.
    for y in range(sheet.height):
        for x in range(sheet.width):
            p = sheet.getpixel((x, y))
            shade = SRC_TO_SHADE[snap(p)] if p[3] else 3 if (x % 17 == 0 or y % 17 == 0) else 1
            out.paste(PALETTE[shade], (x * scale, y * scale, (x + 1) * scale, (y + 1) * scale))
    out.save(ROOT / "preview_gray_sheet.png")
    print("Wrote preview_gray_sheet.png")


def preview_sprites(sheet: Image.Image) -> None:
    names = [
        ("ROBBO_2", "Robbo"),
        ("BULLET_0", "Projectile H"),
        ("BULLET_1", "Projectile V"),
        ("TELEPORT_0", "Teleport"),
        ("KEY", "Key"),
        ("BOMB", "Bomb"),
        ("WALL", "Wall"),
        ("GROUND", "Ground"),
    ]
    scale = 8
    pad = 12
    label_h = 14
    cell_w = 16 * scale
    out = Image.new(
        "RGB",
        (len(names) * (cell_w + pad) + pad, cell_w + label_h + pad * 2),
        PALETTE[1],
    )
    draw = ImageDraw.Draw(out)
    for i, (name, label) in enumerate(names):
        x = pad + i * (cell_w + pad)
        image = cell_image(sheet, gen_tiles.SPRITES[name]).resize(
            (cell_w, cell_w), Image.Resampling.NEAREST
        )
        out.paste(image, (x, pad))
        draw.text((x, pad + cell_w + 2), label, fill=PALETTE[3])
    out.save(ROOT / "preview_gray_sprites.png")
    print("Wrote preview_gray_sprites.png")


def preview_level(sheet: Image.Image) -> None:
    data = json.loads(LEVELS.read_text(encoding="utf-8"))
    level = data["levels"][0]
    rows = level["map"].split("\n")
    screen = Image.new("RGB", (160, 144), PALETTE[1])
    for y, row in enumerate(rows[:9]):
        for x, glyph in enumerate(row[:10]):
            name = gen_tiles.GLYPH_MT.get(glyph, "EMPTY")
            coord = gen_tiles.SPRITES.get(name, gen_tiles.SPRITES["EMPTY"])
            image = cell_image(sheet, coord)
            screen.paste(image, (x * 16, y * 16))
    screen = screen.resize((640, 576), Image.Resampling.NEAREST)
    screen.save(ROOT / "preview_gray_level1.png")
    print("Wrote preview_gray_level1.png")


def main() -> None:
    sheet = Image.open(SRC).convert("RGBA")
    preview_sheet(sheet)
    preview_sprites(sheet)
    preview_level(sheet)


if __name__ == "__main__":
    main()
