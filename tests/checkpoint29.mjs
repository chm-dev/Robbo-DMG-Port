#!/usr/bin/env node
/*
 * Checkpoint 29: CGB normal-palette wall variant (two wall colours per level).
 *
 * Some Atari levels mix the usual inverse-palette wall with the normal-palette
 * wall (Atari glyph $00, GNU 'O' + [additional] state 9): L6, L25, L26, L28 and
 * L37.  The GBC keeps the distinction in the cell state and only swaps the
 * palette, so this port flags the cell in map_extra bit 7 and draws it with the
 * level's normal palette (BG slot 0) instead of the inverse wall palette.  The
 * tile itself, collision and the whole DMG path are unchanged.
 *
 * - Every mixed level (L6 31, L25 42, L26 20, L28 26, L37 20) flags exactly its
 *   Atari `$00` cells; every visible wall in a bound ring row gets the matching
 *   attribute (0 normal, 1 inverse, 2 cave fill).
 * - On screen the two variants differ across the wall's MAIN surface (the
 *   normal variant repaints well over a hundred pixels per cell, not just the
 *   thin contour), and that colour is neither the inverse body nor the floor.
 * - The pause-menu row restore keeps the variant attributes.
 * - DMG mode ignores the flag: color_on stays 0 and both variants use the same
 *   four wall tiles.
 *
 * Run: node gb/tests/checkpoint29.mjs
 */
import { loadRom } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo-debug.gb');

function symbols() {
  const text = fs.readFileSync(path.join(root, 'roms', 'robbo-debug.noi'), 'utf8');
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
    if (m) map[m[1]] = parseInt(m[2], 16);
  }
  return map;
}

const S = symbols();
const MAP_W = 16;
const WALL_EXTRA_NORMAL = 0x80;
const PAL_NORMAL = 0;
const PAL_WALL = 1;
const PAL_CAVE = 2;

/* Normal-palette wall counts in the shipped Atari level set. */
const NORMAL_WALLS = { 6: 31, 25: 42, 26: 20, 28: 26, 37: 20 };

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function makeSession(cgb) {
  const gb = loadRom(rom, undefined, cgb ? { cgb: true } : undefined);
  const core = gb[Object.keys(gb)[0]].gameboy;
  /* Read through the CPU bus, not gb.getMemory(): in CGB mode the raw memory
   * array does not track the switchable WRAM/SVBK mirror, so globals above
   * 0xCFFF read back as 0 there. */
  const u8 = (addr) => core.memoryRead(addr);
  const byte = (name) => u8(S[name]);
  const frame = () => {
    core.JoyPad = 0xff;
    gb.doFrame();
  };

  function warpOnce(keys) {
    const before = byte('level_planet');
    for (let attempt = 0; attempt < 8 && byte('level_planet') === before; attempt++) {
      core.JoyPad = 0xff;
      gb.pressKeys(keys);
      gb.doFrame();
      frame();
      for (let i = 0; i < 20 && byte('level_planet') === before; i++) frame();
    }
    for (let i = 0; i < 10; i++) frame();
  }

  function warpTo(level) {
    let guard = 0;
    while (byte('level_planet') !== level && guard++ < 200) {
      if (byte('level_planet') < level) warpOnce(['SELECT']);
      else warpOnce(['SELECT', 'UP']);
    }
    settle();
  }

  /* Let the intro paint, the entry morph finish and the camera reach a
   * cell-aligned resting position. */
  function settle() {
    for (let i = 0; i < 400; i++) frame();
    for (let i = 0; i < 120 && byte('intro_active'); i++) frame();
    for (let i = 0; i < 240; i++) {
      const scx = byte('cam_scx');
      const scy = byte('cam_scy');
      frame();
      if ((scx & 15) === 0 && (scy & 15) === 0 &&
          byte('cam_scx') === scx && byte('cam_scy') === scy &&
          !byte('intro_active') && !byte('robbo_busy')) break;
    }
  }

  /* BG tile map / attribute byte via the CPU bus (mode 3 reads return 0xFF,
   * so retry until a whole pass is clean). */
  function readMap(bank1) {
    for (let attempt = 0; attempt < 80; attempt++) {
      if (bank1) core.memoryWrite(0xFF4F, 1);
      const bytes = [];
      let bad = false;
      for (let i = 0; i < 32 * 32; i++) {
        const v = core.memoryRead(0x9800 + i);
        if (v === 0xFF) bad = true;
        bytes.push(v);
      }
      if (bank1) core.memoryWrite(0xFF4F, 0);
      if (!bad) return bytes;
      frame();
    }
    throw new Error('could not read VRAM outside mode 3');
  }

  const cellTile = (map, x, y) =>
    map[((y & 15) * 2) * 32 + ((x & 15) * 2)];
  const cellQuad = (map, x, y) => {
    const ty = (y & 15) * 2;
    const tx = (x & 15) * 2;
    return [map[ty * 32 + tx], map[ty * 32 + tx + 1],
      map[(ty + 1) * 32 + tx], map[(ty + 1) * 32 + tx + 1]];
  };

  function tap(key, frames = 6) {
    for (let i = 0; i < frames; i++) {
      core.JoyPad = 0xff;
      gb.pressKeys([key]);
      gb.doFrame();
    }
    core.JoyPad = 0xff;
    for (let i = 0; i < 24; i++) frame();
  }

  /* Wait for the camera to reach a cell-aligned resting position.  The Q4 ease
   * needs ~150 frames for a long move, so allow plenty; a relocated Robbo is
   * kept alive by clearThreats(). */
  function waitCameraSettle(max = 420) {
    for (let i = 0; i < 6; i++) frame();
    let stable = 0;
    let prev = null;
    for (let i = 0; i < max; i++) {
      frame();
      const key = `${byte('cam_scx')},${byte('cam_scy')}`;
      const aligned = (byte('cam_scx') & 15) === 0 &&
        (byte('cam_scy') & 15) === 0;
      if (key === prev && aligned) {
        if (++stable >= 3) return true;
      } else {
        stable = 0;
        prev = key;
      }
    }
    return false;
  }

  return { gb, core, byte, u8, frame, warpTo, settle, waitCameraSettle,
    readMap, cellTile, cellQuad, tap };
}

/* Wall map for the current level: 'N' normal variant, '#' inverse, '-' cave. */
function wallGrid(s) {
  const h = s.byte('level_height');
  const rows = [];
  for (let y = 0; y < h; y++) {
    let line = '';
    for (let x = 0; x < MAP_W; x++) {
      const t = s.u8(S.map_type + y * MAP_W + x);
      const e = s.u8(S.map_extra + y * MAP_W + x);
      if (t < 1 || t > 8) line += '.';
      else if (t === 6) line += '-';
      else line += (e & WALL_EXTRA_NORMAL) ? 'N' : '#';
    }
    rows.push(line);
  }
  return rows;
}

function countFlags(s) {
  const grid = wallGrid(s);
  let n = 0;
  for (const line of grid) n += (line.match(/N/g) || []).length;
  return n;
}

/* Verify every bound row's wall attribute byte against the level data. */
function checkWallAttrs(s, label) {
  const h = s.byte('level_height');
  const attr = s.readMap(true);
  const grid = wallGrid(s);
  let checked = 0;
  let bad = 0;
  let caveChecked = 0;
  let caveBad = 0;
  for (let y = 0; y < h; y++) {
    const ring = y & 15;
    if (s.u8(S.map_row_level + ring) !== y) continue;
    for (let x = 0; x < MAP_W; x++) {
      const ch = grid[y][x];
      const a = s.cellTile(attr, x, y);
      const q = s.cellQuad(attr, x, y);
      if (ch === 'N') {
        checked++;
        if (a !== PAL_NORMAL || q.some((v) => v !== PAL_NORMAL)) bad++;
      } else if (ch === '#') {
        checked++;
        if (a !== PAL_WALL || q.some((v) => v !== PAL_WALL)) bad++;
      } else if (ch === '-') {
        caveChecked++;
        if (a !== PAL_CAVE || q.some((v) => v !== PAL_CAVE)) caveBad++;
      }
    }
  }
  check(`${label}: every bound visible wall has the right CGB attribute`,
    checked > 0 && bad === 0, `cells=${checked} bad=${bad}`);
  if (caveChecked) {
    check(`${label}: cave fill keeps the solid COLPF0 palette`,
      caveBad === 0, `cells=${caveChecked} bad=${caveBad}`);
  }
  return checked;
}

/* Screen position of a map cell, or null when it is outside the 160x128
 * playfield.  The BG ring is 16 metatile rows (256 px) so the row must be
 * taken modulo 16 and the camera offset wrapped, exactly like the hardware. */
function screenPos(s, mapX, mapY) {
  const ringY = (mapY & 15) * 16;
  const dy = (ringY - s.byte('cam_scy') + 256) & 0xff;
  const sx = (mapX * 16 - s.byte('cam_scx') + 256) & 0xff;
  if (dy + 16 > 128 || sx + 16 > 160) return null;
  return { sx, sy: dy };
}

/* Colour histogram of one 16x16 screen cell, or null when off screen. */
function cellColors(s, mapX, mapY) {
  const pos = screenPos(s, mapX, mapY);
  if (!pos) return null;
  const px = s.gb.getScreen();
  const counts = new Map();
  for (let y = pos.sy; y < pos.sy + 16; y++) {
    for (let x = pos.sx; x < pos.sx + 16; x++) {
      const o = (y * 160 + x) * 4;
      const key = `${px[o]},${px[o + 1]},${px[o + 2]}`;
      counts.set(key, (counts.get(key) || 0) + 1);
    }
  }
  return counts;
}

function mostCommon(counts) {
  return Array.from(counts.entries()).sort((a, b) => b[1] - a[1])[0][0];
}

/* Most common playfield colour: the level floor (the HUD rows are excluded). */
function screenFloor(s) {
  const px = s.gb.getScreen();
  const counts = new Map();
  for (let y = 0; y < 128; y++) {
    for (let x = 0; x < 160; x++) {
      const o = (y * 160 + x) * 4;
      const key = `${px[o]},${px[o + 1]},${px[o + 2]}`;
      counts.set(key, (counts.get(key) || 0) + 1);
    }
  }
  return mostCommon(counts);
}

/* Wall body colour: the most common colour that is neither the level floor
 * nor the wall's black trim.  Returns null when the cell is off screen. */
function bodyColor(counts, floorKey) {
  if (!counts) return null;
  const rest = Array.from(counts.entries())
    .filter(([k]) => k !== floorKey && k !== '0,0,0')
    .sort((a, b) => b[1] - a[1]);
  return rest.length ? { key: rest[0][0], count: rest[0][1] } : null;
}

/* First fully visible cell of the given wall glyph ('N' normal, '#' inverse). */
function findScreenCell(s, glyph) {
  const grid = wallGrid(s);
  for (let y = 0; y < grid.length; y++) {
    if (s.u8(S.map_row_level + (y & 15)) !== y) continue;
    for (let x = 0; x < MAP_W; x++) {
      if (grid[y][x] !== glyph) continue;
      const pos = screenPos(s, x, y);
      if (pos) return { x, y, sx: pos.sx, sy: pos.sy };
    }
  }
  return null;
}

function findMapCell(s, glyph) {
  const grid = wallGrid(s);
  for (let y = 0; y < grid.length; y++) {
    const x = grid[y].indexOf(glyph);
    if (x >= 0) return { x, y };
  }
  return null;
}

/* Hostile/self-triggering cells that would kill or move a parked Robbo. */
const THREAT_TYPES = new Set([15, 18, 21, 22, 23, 24, 25, 30]);

/* Clear hazards around a parking cell so a relocated Robbo survives the few
 * frames the camera needs to arrive. */
function clearThreats(s, cx, cy) {
  const h = s.byte('level_height');
  for (let y = cy - 3; y <= cy + 3; y++) {
    for (let x = cx - 4; x <= cx + 4; x++) {
      if (x < 0 || x >= MAP_W || y < 0 || y >= h) continue;
      const i = y * MAP_W + x;
      if (!THREAT_TYPES.has(s.u8(S.map_type + i))) continue;
      s.core.memoryWrite(S.map_type + i, 0);
      s.core.memoryWrite(S.map_extra + i, 0);
    }
  }
}

/* Park Robbo a few cells from a map cell so the camera brings it on screen. */
function viewCell(s, target) {
  const h = s.byte('level_height');
  const cands = [];
  for (let dy = -3; dy <= 3; dy++) {
    for (let dx = -5; dx <= 5; dx++) {
      if (dx === 0 && dy === 0) continue;
      cands.push([dx, dy, dx * dx + dy * dy]);
    }
  }
  cands.sort((a, b) => a[2] - b[2]);
  let tries = 0;
  for (const [dx, dy] of cands) {
    if (tries >= 12) break;
    const x = target.x + dx;
    const y = target.y + dy;
    if (x < 0 || x >= MAP_W || y < 0 || y >= h) continue;
    const t = s.u8(S.map_type + y * MAP_W + x);
    /* Only park on plain floor: hazards/teleports would kill or move him and
     * the camera would return to the level start. */
    if (t !== 0 && t !== 9) continue;  /* CT_EMPTY / CT_GROUND */
    tries++;
    clearThreats(s, x, y);
    const old = s.byte('robbo_y') * MAP_W + s.byte('robbo_x');
    const idx = y * MAP_W + x;
    if (old !== idx) {
      s.core.memoryWrite(S.map_type + old, 0);
      s.core.memoryWrite(S.map_extra + old, 0);
    }
    s.core.memoryWrite(S.map_type + idx, 26);  /* CT_ROBBO */
    s.core.memoryWrite(S.map_extra + idx, 1);
    s.core.memoryWrite(S.robbo_x, x);
    s.core.memoryWrite(S.robbo_y, y);
    s.core.memoryWrite(S.robbo_dir, 1);
    s.waitCameraSettle();
    if (s.byte('robbo_x') !== x || s.byte('robbo_y') !== y) continue;
    if (findScreenCell(s, wallGrid(s)[target.y][target.x])) return true;
  }
  return false;
}

/* Body colour of one wall variant, moving the view only when needed. */
function sampleWall(s, glyph, floorKey) {
  let cell = findScreenCell(s, glyph);
  if (!cell) {
    const target = findMapCell(s, glyph);
    if (!target || !viewCell(s, target)) return null;
    cell = findScreenCell(s, glyph);
  }
  return cell ? bodyColor(cellColors(s, cell.x, cell.y), floorKey) : null;
}

/* --- CGB: every level that mixes both variants. --------------------- */
const cgb = makeSession(true);
check('CGB boot has colour enabled', cgb.byte('color_on') === 1);

/* Boot starts on level 1, which has no normal-palette walls. */
cgb.settle();
check('L1 has no normal-palette walls', countFlags(cgb) === 0);
checkWallAttrs(cgb, 'L1');

for (const level of [6, 25, 26, 28, 37]) {
  cgb.warpTo(level);
  check(`L${level} loaded`, cgb.byte('level_planet') === level,
    `level=${cgb.byte('level_planet')}`);
  const n = countFlags(cgb);
  check(`L${level} flags exactly ${NORMAL_WALLS[level]} normal-palette walls`,
    n === NORMAL_WALLS[level], `count=${n}`);
  checkWallAttrs(cgb, `L${level}`);

  /* The whole wall switches palette, so the wall's MAIN surface changes, not
   * just the few contour pixels (the original bug report). */
  const floorKey = screenFloor(cgb);
  const normalBody = sampleWall(cgb, 'N', floorKey);
  const inverseBody = sampleWall(cgb, '#', floorKey);
  check(`L${level} normal wall body differs from the floor`,
    !!normalBody && normalBody.key !== floorKey,
    `normal=${normalBody && normalBody.key} floor=${floorKey}`);
  check(`L${level} normal and inverse walls paint different body colours`,
    !!normalBody && !!inverseBody && normalBody.key !== inverseBody.key,
    `normal=${normalBody && normalBody.key} inverse=${inverseBody && inverseBody.key}`);
  check(`L${level} normal wall repaints its main surface, not just the contour`,
    !!normalBody && normalBody.count >= 100,
    `body=${normalBody && normalBody.key} px=${normalBody && normalBody.count}`);

  if (level === 25) {
    /* The pause overlay rebuilds the covered cells from the level data when it
     * closes; those rows must keep the normal-wall attribute. */
    cgb.tap('START');
    for (let i = 0; i < 120 && !cgb.byte('pause_menu_state'); i++) cgb.frame();
    check('L25 pause menu opened', cgb.byte('pause_menu_state') !== 0);
    cgb.tap('START');
    for (let i = 0; i < 120 && cgb.byte('pause_menu_state'); i++) cgb.frame();
    check('L25 pause menu closed', cgb.byte('pause_menu_state') === 0);
    checkWallAttrs(cgb, 'L25 after pause menu');
  }
}

/* --- DMG: the flag is inert; both variants use the same wall tiles. - */
const dmg = makeSession(false);
check('DMG boot has colour disabled', dmg.byte('color_on') === 0);
dmg.warpTo(25);
check('DMG L25 loaded', dmg.byte('level_planet') === 25);
const dmgGrid = wallGrid(dmg);
check('DMG L25 still tags 42 normal-palette wall cells',
  dmgGrid.join('').split('N').length - 1 === NORMAL_WALLS[25]);
const dmgTiles = dmg.readMap(false);
const normalTiles = dmg.cellQuad(dmgTiles, 5, 6);
const inverseTiles = dmg.cellQuad(dmgTiles, 5, 0);
check('DMG draws both wall variants with the same four tiles',
  normalTiles.join(',') === inverseTiles.join(','),
  `normal=${normalTiles} inverse=${inverseTiles}`);
check('DMG wall cells are not empty tiles',
  new Set(normalTiles).size === 4, `tiles=${normalTiles}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 29 passed');
process.exit(failures ? 1 : 0);
