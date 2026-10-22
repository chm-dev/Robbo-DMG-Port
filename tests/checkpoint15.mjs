#!/usr/bin/env node
/*
 * Checkpoint 15: inactive capsule behaviour.
 *
 * The original Spaceship is a movable object: while bolts remain it can be
 * pushed like a stone, and it uses the closed sprite.  Once open it is eaten
 * (level complete) instead of pushed.
 *
 * Run: node gb/tests/checkpoint15.mjs
 */
import { loadRom, run, readMem } from '../tools/gb_harness.mjs';
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
const CT_ROBBO = 26;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function setCell(mem, x, y, type, extra = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = extra;
  mem[S.map_obj + y * 16 + x] = 0;
}

const gb = loadRom(rom);
run(gb, 150);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const cell = (x, y) => mem[S.map_type + y * 16 + x];

/* Closed-frame tile id from the generated metatile table in bank 0. */
const tilesHeader = fs.readFileSync(path.join(root, 'gb', 'src', 'gen', 'tiles.h'), 'utf8');
const mtSpaceship0 = Number(tilesHeader.match(/#define\s+MT_SPACESHIP_0\s+(\d+)/)[1]);
const romBytes = fs.readFileSync(rom);
const closedTile = romBytes[S.metatile_tiles + mtSpaceship0 * 4];

/* Capsule at (3,2), empty cells beyond it; bolts still remain. */
mem[S.screws_left] = 5;
setCell(mem, 3, 2, CT_SPACESHIP, 0);
setCell(mem, 4, 2, CT_EMPTY, 0);
setCell(mem, 5, 2, CT_EMPTY, 0);

function holdRightUntil(predicate, maxFrames = 300) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT']);
    gb.doFrame();
    if (predicate()) return true;
  }
  return false;
}

const pushed = holdRightUntil(() => byte('robbo_x') === 3);
check('inactive capsule can be pushed', pushed &&
  cell(4, 2) === CT_SPACESHIP && cell(3, 2) === CT_ROBBO,
  `robbo=${byte('robbo_x')},${byte('robbo_y')} cells=${cell(3, 2)},${cell(4, 2)}`);
check('pushed capsule keeps its state', mem[S.map_extra + 2 * 16 + 4] === 0,
  `extra=${mem[S.map_extra + 2 * 16 + 4]}`);

/* Closed capsule must hold the MT_SPACESHIP_0 frame while bolts remain. */
const bgmap = core.BGCHRBank1;
const addr = (0x9800 + 4 * 32 + 4 * 2) & 0x7ff;
let arrived = false;
for (let i = 0; i < 300; i++) {
  gb.doFrame();
  if (bgmap[addr] === closedTile) {
    arrived = true;
    break;
  }
}
check('inactive capsule uses the closed frame', arrived,
  `tile=${bgmap[addr]} expected=${closedTile}`);

let stable = arrived;
let tile = bgmap[addr];
for (let i = 0; i < 120 && stable; i++) {
  gb.doFrame();
  if (bgmap[addr] !== tile) stable = false;
}
check('inactive capsule stays on the closed frame', stable,
  `tile=${bgmap[addr]} expected=${closedTile}`);

/* Opening the capsule starts its two-frame animation. */
mem[S.screws_left] = 0;
const seen = new Set();
for (let i = 0; i < 600; i++) {
  gb.doFrame();
  seen.add(bgmap[addr]);
}
check('open capsule animates between two frames', seen.size === 2,
  `tiles=${[...seen].join(',')}`);
check('closed frame is part of the open animation', seen.has(closedTile),
  `tiles=${[...seen].join(',')}`);

/* Entering an open capsule finishes the level instead of pushing it. */
let entered = false;
for (let i = 0; i < 200; i++) {
  core.JoyPad = 0xff;
  gb.pressKeys(['RIGHT']);
  gb.doFrame();
  if (byte('robbo_busy')) {
    entered = true;
    break;
  }
}
check('open capsule is entered, not pushed',
  entered && byte('robbo_x') === 3 && cell(4, 2) === CT_SPACESHIP,
  `busy=${byte('robbo_busy')} robbo=${byte('robbo_x')},${byte('robbo_y')} cell=${cell(4, 2)}`);

let advanced = false;
for (let i = 0; i < 800; i++) {
  gb.doFrame();
  if (byte('level_planet') === 2) {
    advanced = true;
    break;
  }
}
check('entering the capsule finishes the level', advanced,
  `level=${byte('level_planet')}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 15 passed');
process.exit(failures ? 1 : 0);
