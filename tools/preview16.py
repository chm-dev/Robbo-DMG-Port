#!/usr/bin/env python3
"""Preview original icons32.png artwork at 16x16 (zoomed-in Plan B).

Produces gb/tests/art/contact-sheet-16.png with, per sprite:
  original 32x32 at 2x | 2x2 area downsample | nearest downsample
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "robboJS" / "icons32.png"
OUT = ROOT / "gb" / "tests" / "art"

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
SHADE = {0: 0, 1: 1, 2: 2, 3: 2, 4: 3}
RGB = [(239, 255, 222), (172, 205, 164), (92, 143, 108), (24, 52, 66)]

SPRITES = {
    "Empty": (10, 2),
    "Ground": (4, 2),
    "Stone": (6, 0),
    "Pushable": (8, 1),
    "Door": (9, 0),
    "Spaceship0": (6, 1),
    "Spaceship1": (5, 1),
    "Question": (0, 1),
    "Bomb": (8, 0),
    "Key": (7, 0),
    "Screw": (4, 0),
    "Ammo": (5, 0),
    "TurretR": (5, 4),
    "TurretD": (6, 4),
    "TurretL": (7, 4),
    "TurretU": (8, 4),
    "Teleport0": (0, 4),
    "Teleport1": (1, 4),
    "Explosion0": (0, 7),
    "Explosion1": (1, 7),
    "Explosion2": (2, 7),
    "Explosion3": (3, 7),
    "Bullet0": (0, 3),
    "Bullet1": (1, 3),
    "Bullet2": (2, 3),
    "Bullet3": (3, 3),
    "Mustache0": (3, 1),
    "Mustache1": (4, 1),
    "Butterfly0": (8, 2),
    "Butterfly1": (9, 2),
    "BearCW0": (1, 1),
    "BearCW1": (2, 1),
    "BearCW2": (3, 1),
    "BearCW3": (4, 1),
    "BearCCW0": (6, 2),
    "BearCCW1": (7, 2),
    "BearCCW2": (8, 2),
    "BearCCW3": (9, 2),
    "Lava0": (9, 3),
    "Lava1": (9, 4),
    "Magnet0": (0, 0),
    "Magnet1": (1, 0),
    "HudScrew": (4, 3),
    "HudAmmo": (7, 3),
    "HudKeys": (6, 3),
    "HudLives": (5, 3),
    "HudPlanet": (8, 3),
}
for i in range(8):
    SPRITES[f"Robbo{i}"] = (i, 5)
for letter, (x, y) in zip("OIo-QqPpSsyYzZJji", [
    (2, 0), (7, 6), (5, 2), (7, 1), (3, 0), (9, 1), (9, 5), (8, 5),
    (10, 1), (10, 0), (9, 5), (9, 6), (9, 7), (8, 6), (8, 7), (10, 6), (10, 7),
]):
    SPRITES[f"Wall{letter}"] = (x, y)


def src_index(pixel):
    if pixel in COLOUR_INDEX:
        return COLOUR_INDEX[pixel]
    best, best_d = 0, 1 << 30
    for colour, index in COLOUR_INDEX.items():
        d = sum((pixel[i] - colour[i]) ** 2 for i in range(3))
        if d < best_d:
            best, best_d = index, d
    return best


def crop(image, coord):
    x0 = OFFSET + coord[0] * GRID
    y0 = OFFSET + coord[1] * GRID
    return [[src_index(image.getpixel((x0 + x, y0 + y))) for x in range(CELL)]
            for y in range(CELL)]


def area16(cell):
    out = []
    for by in range(16):
        row = []
        for bx in range(16):
            values = [SHADE[cell[by * 2 + y][bx * 2 + x]] for y in range(2) for x in range(2)]
            avg = sum(values) / 4
            row.append(round(avg))
        out.append(row)
    return out


def nearest16(cell):
    return [[SHADE[cell[y * 2][x * 2]] for x in range(16)] for y in range(16)]


def majority16(cell):
    out = []
    for by in range(16):
        row = []
        for bx in range(16):
            values = [SHADE[cell[by * 2 + y][bx * 2 + x]] for y in range(2) for x in range(2)]
            values.sort()
            row.append(values[1])  # lower median, keeps outlines over fills
        out.append(row)
    return out


def content_crop(cell, pad=2):
    xs, ys = [], []
    for y in range(CELL):
        for x in range(CELL):
            if cell[y][x] != 0:
                xs.append(x); ys.append(y)
    if not xs:
        return cell
    x0, x1 = max(0, min(xs) - pad), min(CELL - 1, max(xs) + pad)
    y0, y1 = max(0, min(ys) - pad), min(CELL - 1, max(ys) + pad)
    side = max(x1 - x0 + 1, y1 - y0 + 1)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    sx, sy = cx - side // 2, cy - side // 2
    return [[cell[sy + y * side // CELL][sx + x * side // CELL]
             if 0 <= sx + x * side // CELL < CELL and 0 <= sy + y * side // CELL < CELL else 0
             for x in range(CELL)] for y in range(CELL)]


def to_image(shades, scale=1):
    im = Image.new("RGB", (16, 16))
    for y in range(16):
        for x in range(16):
            im.putpixel((x, y), RGB[shades[y][x]])
    if scale != 1:
        im = im.resize((16 * scale, 16 * scale), Image.NEAREST)
    return im


def main():
    image = Image.open(SHEET).convert("RGB")
    names = list(SPRITES.keys())
    scale = 3
    cols = 6
    cell_w = 64 * 2 + 16 * scale * 5 + 48
    row_h = 64 + 24
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * row_h + 24), (250, 250, 245))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, name in enumerate(names):
        col, row = i % cols, i // cols
        x0, y0 = col * cell_w, row * row_h + 24
        draw.text((x0, y0 - 14), name, fill=(0, 0, 0), font=font)
        cx, cy = SPRITES[name]
        sx, sy = OFFSET + cx * GRID, OFFSET + cy * GRID
        original = image.crop((sx, sy, sx + CELL, sy + CELL)).resize((64, 64), Image.NEAREST)
        sheet.paste(original, (x0, y0))
        cell = crop(image, SPRITES[name])
        cropped = content_crop(cell) if not name.startswith("Wall") and name != "Empty" else cell
        variants = [("area", area16(cell)), ("near", nearest16(cell)), ("maj", majority16(cell)),
                    ("crop", area16(cropped)), ("cmaj", majority16(cropped))]
        for j, (label, shades) in enumerate(variants):
            vx = x0 + 64 + 12 + j * (16 * scale + 8)
            sheet.paste(to_image(shades, scale), (vx, y0))
            draw.text((vx, y0 + 16 * scale + 1), label, fill=(0, 0, 0), font=font)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT / "contact-sheet-16.png")
    print(f"Wrote {OUT / 'contact-sheet-16.png'}")


if __name__ == "__main__":
    main()
