#!/usr/bin/env node
/*
 * Checkpoint 24: L49 ZAPO barrier and DZ3 blaster.
 *
 * - `=` loads as CT_BARRIER (not the old static lava tile).
 * - A player shot destroys one segment and the gap travels along the row.
 * - A blaster turret (bullet type 2) leaves an explosion trail and the head
 *   advances through empty cells.
 *
 * Run: node gb/tests/checkpoint24.mjs
 */
import { loadRom, run, readMem, holdKey } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo.gb');

function symbols() {
  const text = fs.readFileSync(path.join(root, 'roms', 'robbo.noi'), 'utf8');
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
    if (m) map[m[1]] = parseInt(m[2], 16);
  }
  return map;
}

const S = symbols();
const CT_EMPTY = 0;
const CT_TURRET = 18;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;
const CT_BARRIER = 30;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
run(gb, 200);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const cells = () => readMem(gb, S.map_type, 16 * 31);
const setCell = (x, y, type, extra = 0) => {
  const i = y * 16 + x;
  mem[S.map_type + i] = type;
  mem[S.map_extra + i] = extra;
  mem[S.map_obj + i] = 0;
};

/* Warp using SELECT, polling level_planet because the main loop can miss
 * VBlanks during a load. */
function warpOnce(keys) {
  const before = byte('level_planet');
  for (let attempt = 0; attempt < 8 && byte('level_planet') === before; attempt++) {
    core.JoyPad = 0xff;
    gb.pressKeys(keys);
    gb.doFrame();
    core.JoyPad = 0xff;
    gb.doFrame();
    for (let i = 0; i < 20 && byte('level_planet') === before; i++) gb.doFrame();
  }
  for (let i = 0; i < 10; i++) gb.doFrame();
  for (let i = 0; i < 20 && byte('screws_left') !== byte('level_screw'); i++) gb.doFrame();
}
function warpTo(level) {
  let guard = 0;
  while (byte('level_planet') !== level && guard++ < 200) {
    if (byte('level_planet') < level) warpOnce(['SELECT']);
    else warpOnce(['SELECT', 'UP']);
  }
  for (let i = 0; i < 240 && byte('intro_active'); i++) gb.doFrame();
  for (let i = 0; i < 20; i++) gb.doFrame();
}

warpTo(49);
check('L49 loaded', byte('level_planet') === 49, `level=${byte('level_planet')}`);

function barrierCount() {
  const c = cells();
  let n = 0;
  for (let x = 1; x <= 14; x++) if (c[6 * 16 + x] === CT_BARRIER) n++;
  return n;
}
function barrierGaps() {
  const c = cells();
  const gaps = [];
  for (let x = 1; x <= 14; x++) if (c[6 * 16 + x] !== CT_BARRIER) gaps.push(x);
  return gaps;
}

check('L49 barrier row loads', barrierCount() === 14, `count=${barrierCount()}`);

/* Barrier tiles animate between the two F.FNT frames.  Read the generated
 * metatile table so this keeps working if tile allocation moves. */
function barrierTileIds() {
  const text = fs.readFileSync(path.join(root, 'gb/src/gen/tiles.c'), 'utf8');
  const found = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*\/\*\s*\d+\s+(\w+)\s*\*\//);
    if (m) found[m[5]] = [Number(m[1]), Number(m[2]), Number(m[3]), Number(m[4])];
  }
  return found;
}
const barrierTiles = barrierTileIds();
const frame0 = barrierTiles.BARRIER_0[0];
const frame1 = barrierTiles.BARRIER_1[0];
let sawFrame0 = false;
let sawFrame1 = false;
for (let f = 0; f < 40 && !(sawFrame0 && sawFrame1); f++) {
  gb.doFrame();
  const bg = Array.from(core.BGCHRBank1);
  if (bg.includes(frame0)) sawFrame0 = true;
  if (bg.includes(frame1)) sawFrame1 = true;
}
check('barrier alternates animation frames', sawFrame0 && sawFrame1,
  `frames=${frame0}/${frame1}`);

/* Keep only the barrier test; L49's turrets would otherwise shoot Robbo.
 * Select is the debug-warp key, so only clear the object types. */
for (let i = 0; i < 16 * 31; i++) {
  const t = mem[S.map_type + i];
  if (t === CT_TURRET || t === CT_BULLET || t === CT_EXPLOSION) {
    mem[S.map_type + i] = CT_EMPTY;
    mem[S.map_extra + i] = 0;
    mem[S.map_obj + i] = 0;
  }
}

/* Point-blank shot at the barrier: no projectile is created, but the segment
 * is demolished and the two-frame field animation starts. */
mem[S.robbo_x] = 2;
mem[S.robbo_y] = 5;
mem[S.robbo_dir] = 1;
mem[S.robbo_busy] = 0;
mem[S.robbo_no_move] = 0;
mem[S.ammo] = 9;
mem[S.fire_delay] = 0;
holdKey(gb, ['A', 'DOWN'], 8);
gb.doFrame();
check('barrier shot consumes ammo', byte('ammo') === 8, `ammo=${byte('ammo')}`);
check('barrier shot opens a gap', barrierCount() < 14, `count=${barrierCount()}`);

/* The gap is one cell wide and travels west, wrapping at the row edges. */
const gapsSeen = new Set(barrierGaps());
let badCount = false;
for (let f = 0; f < 90; f++) {
  gb.doFrame();
  if (f % 6 === 0) {
    if (barrierCount() !== 13) badCount = true;
    for (const x of barrierGaps()) gapsSeen.add(x);
  }
}
check('barrier gap stays one cell wide', !badCount, `count=${barrierCount()}`);
check('barrier gap moves along the row', gapsSeen.size >= 2,
  `positions=${Array.from(gapsSeen).sort((a, b) => a - b).join(',')}`);

/* DZ3 blaster turret: type 2 leaves a trail and advances through empty cells. */
for (let i = 0; i < 16 * 31; i++) {
  const t = mem[S.map_type + i];
  if (t === CT_TURRET || t === CT_BULLET || t === CT_EXPLOSION) {
    mem[S.map_type + i] = CT_EMPTY;
    mem[S.map_extra + i] = 0;
    mem[S.map_obj + i] = 0;
  }
}
setCell(1, 1, CT_TURRET, 0x20);  /* facing right, bullet type 2 */

let head = null;
for (let f = 0; f < 3000 && !head; f++) {
  gb.doFrame();
  for (let i = 0; i < 16 * 31; i++) {
    if (mem[S.map_type + i] === CT_BULLET &&
        ((mem[S.map_extra + i] >> 2) & 3) === 2) {
      head = { x: i % 16, y: Math.floor(i / 16) };
      break;
    }
  }
}
check('blaster turret fires a type-2 projectile', head !== null,
  head ? `at=${head.x},${head.y}` : 'none');

if (head) {
  const startX = head.x;
  let moved = false;
  let trail = false;
  for (let f = 0; f < 30 && !(moved && trail); f++) {
    gb.doFrame();
    for (let i = 0; i < 16 * 31; i++) {
      if (mem[S.map_type + i] === CT_BULLET &&
          ((mem[S.map_extra + i] >> 2) & 3) === 2 &&
          Math.floor(i / 16) === 1 && (i % 16) > startX) moved = true;
      if (mem[S.map_type + i] === CT_EXPLOSION) trail = true;
    }
  }
  check('blaster head advances', moved, `start=${startX}`);
  check('blaster leaves an explosion trail', trail);
}

/* Palette variants: L49 has the normal floor (no projectile swap), L50 is
 * the dark-floor palette (VAR_BULLETS_ALT).  Both the bullet metatiles and
 * the separate blaster head range must actually change in VRAM. */
const tilesH = fs.readFileSync(path.join(root, 'gb/src/gen/tiles.h'), 'utf8');
const define = (name) => Number(tilesH.match(new RegExp(`#define ${name} (\\d+)`))[1]);
const bulletBase = define('BULLET_VARIANT_BASE');
const bulletCount = define('BULLET_VARIANT_COUNT');
const blasterBase = define('BLASTER_VARIANT_BASE');
const blasterCount = define('BLASTER_VARIANT_COUNT');
const readTiles = (base, count) => readMem(gb, 0x8000 + base * 16, count * 16);
const beforeBullet = readTiles(bulletBase, bulletCount);
const beforeBlaster = readTiles(blasterBase, blasterCount);
warpTo(50);
const afterBullet = readTiles(bulletBase, bulletCount);
const afterBlaster = readTiles(blasterBase, blasterCount);
const changed = (a, b) => a.some((v, i) => v !== b[i]);
check('bullet palette variant still swaps', changed(beforeBullet, afterBullet));
check('blaster palette variant swaps with bullets',
  changed(beforeBlaster, afterBlaster));

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 24 passed');
process.exit(failures ? 1 : 0);
