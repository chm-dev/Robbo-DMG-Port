#!/usr/bin/env node
/*
 * Checkpoint 18: Atari/GBC level pack, four-level wall styles, and the
 * extra-life bonus.
 *
 * - Every level 1..56 loads with one Robbo, one capsule and the declared
 *   screw count.
 * - Visible walls use one texture per four-level block; cave fill is slot 5.
 * - Level 55 carries all 23 Atari turrets (the old 16-entry list truncated it).
 * - Walking onto a `+` bonus removes it, changes no counters, and plays
 *   SFX_EXTRA_LIFE.
 *
 * Run: node gb/tests/checkpoint18.mjs
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
const CT_SPACESHIP = 13;
const CT_BOMB = 15;
const CT_SCREW = 17;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;
const CT_ROBBO = 26;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;
const CT_EXTRA_LIFE = 29;

/* Generated wall encoding: visible = WALL_0 + slot1, cave = WALL_0 + slot5. */
const WALL_VISIBLE = 2;
const WALL_CAVE = 6;

/* A few authentic Atari screw counts, including the 0-screw levels. */
const ATARI_SCREWS = { 1: 9, 23: 0, 27: 6, 48: 0, 51: 9, 55: 14 };

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
const core = gb[Object.keys(gb)[0]].gameboy;
const byte = (name) => readMem(gb, S[name], 1)[0];
const cells = () => readMem(gb, S.map_type, 16 * 31);
const count = (values, type) => values.filter(v => v === type).length;
const wallRotation = readMem(gb, S.wall_rotation_cells, 14);

/* The main loop can miss VBlanks while a level loads, so hold/poll rather
 * than assuming one frame per iteration.  Stop as soon as level_planet
 * changes, before gameplay ticks can alter the board. */
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
  /* game_load_level writes level_planet before copying the 496-cell arrays
   * and only sets screws_left after the map scan.  A slow main-loop iteration
   * needs ~9 frames here; wait for the counter to match, with a floor. */
  for (let i = 0; i < 10; i++) gb.doFrame();
  for (let i = 0; i < 20 && byte('screws_left') !== byte('level_screw'); i++) {
    gb.doFrame();
  }
  return byte('level_planet');
}

function reloadLevel1() {
  if (byte('level_planet') === 1) warpOnce(['SELECT']);
  warpOnce(['SELECT', 'B']);
}

function warpTo(level) {
  let guard = 0;
  while (byte('level_planet') !== level && guard++ < 200) {
    if (byte('level_planet') < level) warpOnce(['SELECT']);
    else warpOnce(['SELECT', 'UP']);
  }
}

run(gb, 150);
reloadLevel1();
check('reloaded level 1', byte('level_planet') === 1, `level=${byte('level_planet')}`);

for (let level = 1; level <= 56; level++) {
  if (level > 1) warpTo(level);
  check(`L${level} loaded`, byte('level_planet') === level,
    `level=${byte('level_planet')}`);
  if (byte('level_planet') !== level) break;

  const map = cells();
  const screw = byte('level_screw');
  check(`L${level} height 31`, byte('level_height') === 31,
    `h=${byte('level_height')}`);
  check(`L${level} one Robbo`, count(map, CT_ROBBO) === 1,
    `robbo=${count(map, CT_ROBBO)}`);
  check(`L${level} one capsule`, count(map, CT_SPACESHIP) === 1,
    `capsules=${count(map, CT_SPACESHIP)}`);
  check(`L${level} screw count`, count(map, CT_SCREW) === screw,
    `map=${count(map, CT_SCREW)} declared=${screw}`);
  check(`L${level} extra life hidden`, count(map, CT_EXTRA_LIFE) === 0,
    `visible=${count(map, CT_EXTRA_LIFE)}`);
  if (level === 4) {
    const bonusIdx = 15 * 16 + 7;
    const marked = core.memory[S.bonus_bits + (bonusIdx >> 3)] &
      (1 << (bonusIdx & 7));
    check('L4 extra life marker present', marked !== 0,
      `bits=${core.memory[S.bonus_bits + (bonusIdx >> 3)]}`);
  }
  check(`L${level} screws_left loaded`, byte('screws_left') === screw,
    `left=${byte('screws_left')} declared=${screw}`);
  if (ATARI_SCREWS[level] !== undefined) {
    check(`L${level} authentic screw count`, screw === ATARI_SCREWS[level],
      `declared=${screw} expected=${ATARI_SCREWS[level]}`);
  }

  const expectedCell = wallRotation[(level - 1) >> 2];
  check(`L${level} wall rotation`, byte('level_wall_cell') === expectedCell,
    `cell=${byte('level_wall_cell')} expected=${expectedCell}`);

  let wallOk = true;
  let visible = 0;
  for (const type of map) {
    if (type >= 1 && type <= 8) {
      if (type === WALL_CAVE) continue;
      visible++;
      if (type !== WALL_VISIBLE) wallOk = false;
    }
  }
  check(`L${level} wall map`, wallOk && visible > 0,
    `visible=${visible}`);
}

/* Spot checks for the authentic Atari data, not just generic validation. */
warpTo(55);
check('L55 loaded for turret check', byte('level_planet') === 55,
  `level=${byte('level_planet')}`);
check('L55 has all 23 turrets', count(cells(), CT_TURRET) === 23,
  `turrets=${count(cells(), CT_TURRET)}`);

/* Extra-life pickup and sound. */
reloadLevel1();
for (let i = 0; i < 16 * 31; i++) {
  if (core.memory[S.map_type + i] === CT_TURRET ||
      core.memory[S.map_type + i] === 27 ||
      core.memory[S.map_type + i] === 21 ||
      core.memory[S.map_type + i] === 22 ||
      core.memory[S.map_type + i] === 23) {
    core.memory[S.map_type + i] = CT_EMPTY;
    core.memory[S.map_extra + i] = 0;
    core.memory[S.map_obj + i] = 0;
  }
}
for (let i = 0; i < 400; i++) gb.doFrame();

const mem = core.memory;
const bonusIdx = 2 * 16 + 3;
mem[S.map_type + bonusIdx] = CT_EMPTY;
mem[S.map_extra + bonusIdx] = 0;
mem[S.map_obj + bonusIdx] = 0;
mem[S.bonus_bits + (bonusIdx >> 3)] |= (1 << (bonusIdx & 7));
const screwsBefore = byte('screws_left');
const ammoBefore = byte('ammo');
const keysBefore = byte('keys');

function leftSamples() {
  const buf = gb.getAudio();
  const out = [];
  if (!buf) return out;
  for (let i = 0; i < buf.length; i += 2) out.push(Math.abs(buf[i] + 1));
  return out;
}
function capture(frames, keys = null) {
  const samples = [];
  let flash = false;
  for (let i = 0; i < frames; i++) {
    core.JoyPad = 0xff;
    if (keys) gb.pressKeys(keys);
    gb.doFrame();
    if (mem[0xFF47] === 0xE0) flash = true;
    samples.push(...leftSamples());
  }
  core.JoyPad = 0xff;
  return { samples, flash };
}
function peak(samples) {
  let p = 0;
  for (const s of samples) if (s > p) p = s;
  return p;
}

const silence = peak(capture(6).samples);
const pickup = capture(40, ['RIGHT']);
check('extra life is audible', peak(pickup.samples) > 0.005,
  `silence=${silence.toFixed(3)} pickup=${peak(pickup.samples).toFixed(3)}`);
check('extra life flashes like the last bolt', pickup.flash);
check('extra life was collected', byte('robbo_x') === 3 &&
  mem[S.map_type + bonusIdx] === CT_ROBBO,
  `x=${byte('robbo_x')} cell=${mem[S.map_type + bonusIdx]}`);
check('extra life marker cleared',
  (mem[S.bonus_bits + (bonusIdx >> 3)] & (1 << (bonusIdx & 7))) === 0,
  `bits=${mem[S.bonus_bits + (bonusIdx >> 3)]}`);
check('extra life changes no counters',
  byte('screws_left') === screwsBefore && byte('ammo') === ammoBefore &&
  byte('keys') === keysBefore,
  `screws=${byte('screws_left')} ammo=${byte('ammo')} keys=${byte('keys')}`);

/* Regression for the reported 2x2 bear loops: isolate the specific bear and
 * verify it traverses a real wall-following path, not just four cells. */
function isolatedBearCells(level, bx, by, frames = 600) {
  warpTo(level);
  const target = by * 16 + bx;
  for (let i = 0; i < 16 * 31; i++) {
    const type = core.memory[S.map_type + i];
    if ((type === CT_BEAR && i !== target) ||
        type === CT_TURRET || type === CT_MUSTACHE || type === CT_BUTTERFLY ||
        type === CT_BULLET || type === CT_BOMB || type === CT_EXPLOSION) {
      core.memory[S.map_type + i] = CT_EMPTY;
      core.memory[S.map_extra + i] = 0;
      core.memory[S.map_obj + i] = 0;
    }
  }
  const seen = new Set();
  for (let f = 0; f < frames; f++) {
    gb.doFrame();
    for (let i = 0; i < 16 * 31; i++) {
      if (core.memory[S.map_type + i] === CT_BEAR) {
        seen.add(`${i % 16},${(i / 16) | 0}`);
        break;
      }
    }
  }
  return seen.size;
}

const l4BearCells = isolatedBearCells(4, 9, 10);
check('L4 bear follows the wall path', l4BearCells > 8,
  `cells=${l4BearCells}`);
const l5BearCells = isolatedBearCells(5, 11, 10);
check('L5 bear follows the wall path', l5BearCells > 8,
  `cells=${l5BearCells}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 18 passed');
process.exit(failures ? 1 : 0);
