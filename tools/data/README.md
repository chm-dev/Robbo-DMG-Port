# Atari level data

`atari_levels.dat` is the 56-level authentic Atari Robbo level set used by the
GBC port, in the GNU Robbo `.dat` format consumed by `gb/tools/gen_levels.py`.

Provenance:

- Source designs: `lkavalon-atari/robbo/d2/C1.txt`, `C2.txt`, `C3.txt`.
- Converted with `robbo-gbc/tools/convert_atari_levels.py` (Atari ATASCII ->
  GNU glyphs + `[additional]` parameters), then normalized to this file.
- Verified against `robbo-gbc`'s pinned submodule commit
  `6c9ef22a8ec0e677f038624bae6e541ce616d6d0`; current upstream `main` produces
  identical level content.

DMG mapping applied by `gb/tools/gen_levels.py`:

- Visible walls use one source wall texture per four-level block, selected by
  the 14-entry `tileset.WALL_ROTATION` order. The tile is loaded from the full
  sheet at level load, so all 14 styles fit in active VRAM. Atari glyph `-`
  (0x13) is the fixed black cave fill (`MT_WALL_CAVE`).
- Five levels (L6, L25, L26, L28, L37) mix two colour variants of the same wall
  shape: the usual inverse-palette wall and the normal-palette wall (Atari glyph
  `$00`, carried here as GNU `O` plus an `[additional]` record whose first value
  is 9). `gen_levels.py` sets `map_extra` bit 7 for those cells; the renderer
  keys on it only in CGB mode (BG palette slot 0, the level's normal palette)
  and the DMG path is unchanged - see `AGENTS.md`.
- `+` (extra life / score bonus) becomes a hidden easter egg: the loader
  converts the cell to empty and records it in `bonus_bits[]`. Stepping on it
  plays `SFX_EXTRA_LIFE` and the last-bolt flash, but awards no life/score.
- `=` (ZAPO force field) becomes `CT_BARRIER`. It is a destructible horizontal
  field that sweeps one cell per logic tick and wraps inside its wall-to-wall
  run, so a shot gap travels along the row. The two authentic F.FNT animation
  frames alternate every other tick.
- Teleports are linked to the next cell in the same group (scan order), with
  wrap-around; Robbo starts facing down. At runtime the destination search
  walks the whole group: a member whose landing is blocked is skipped for the
  next free member, and a fully blocked group (including a lone self-link such
  as L7) teleports Robbo in place, matching GNU Robbo's fallback.

Regenerate the ROM level packs with:

```powershell
python gb/tools/gen_levels.py
```

Pass `--gnu` to regenerate the previous `robboJS`/GNU fixture instead. The ROM
ships the Atari set by default. `gb/tests/fixtures/levels.json` and
`levels.summary.json` remain the legacy GNU fixture used by `gen_tiles.py`'s
preview and the `--gnu` path; they no longer describe the shipped ROM levels.

# Ending tile sheet

`ending_tiles.dat` is the 640-byte (40 × 8×8, 2bpp) scene sheet used by the
Atari/GBC ending, extracted verbatim from
`robbo-gbc/src/gen/gfx_tiles.c` (`ending_tiles[640]`). The two message pages in
`gb/tools/gen_ending.py` are copied from `robbo-gbc/src/ending.c`.

DMG mapping applied by `gb/tools/gen_ending.py`:

- The scene runs with `BGP = 0x1B` (index 0 → black, 1 → dark, 2 → light,
  3 → white). Palette-0 tiles keep the source indices; palette-1 tiles (ground
  and the ship's inverse-colour flash) map source index 3 (Atari PF3 orange)
  to shade 2.
- The sprite copy keeps the raw 2bpp indices; `OBP0 = 0x18` renders 1 → dark,
  2 → light, 3 → white and index 0 is transparent.
- Sprite tiles are loaded at VRAM 128..167 so they do not overwrite the
  background scene tiles (DMG BG and sprites share one 256-tile bank).
