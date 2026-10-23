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
- `+` (extra life / score bonus) becomes a hidden easter egg: the loader
  converts the cell to empty and records it in `bonus_bits[]`. Stepping on it
  plays `SFX_EXTRA_LIFE` and the last-bolt flash, but awards no life/score.
- `=` (ZAPO force field) stays `CT_LAVA`, which is currently static in this
  port. See the barrier TODO in `AGENTS.md`.
- Teleports are linked to the next cell in the same group (scan order), with
  wrap-around; Robbo starts facing down.

Regenerate the ROM level packs with:

```powershell
python gb/tools/gen_levels.py
```

Pass `--gnu` to regenerate the previous `robboJS`/GNU fixture instead. The ROM
ships the Atari set by default. `gb/tests/fixtures/levels.json` and
`levels.summary.json` remain the legacy GNU fixture used by `gen_tiles.py`'s
preview and the `--gnu` path; they no longer describe the shipped ROM levels.
