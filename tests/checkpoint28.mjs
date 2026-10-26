#!/usr/bin/env node
/*
 * Checkpoint 28: Atari teleport group edge cases.
 *
 * - L7 has one lone self-linked teleport whose only non-wall neighbour is the
 *   cell Robbo enters from.  It must trigger and teleport Robbo in place
 *   (GNU's "protect from freezing the game" branch), not act like a wall.
 * - L12's linked group has one member ringed by bombs.  Entering the previous
 *   member must skip that blocked landing and use the next free member of the
 *   group; once a bomb is cleared the ringed teleport becomes the destination
 *   again (GNU/GBC `find_next_teleport` order).
 *
 * Run: node gb/tests/checkpoint28.mjs
 */
import { loadRom, readMem } from '../tools/gb_harness.mjs';
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
const CT_EMPTY = 0;
const CT_TELEPORT = 20;
const CT_ROBBO = 26;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const frame = () => {
  core.JoyPad = 0xff;
  gb.doFrame();
};

/* The main loop can miss VBlanks while a level loads, so hold/poll rather
 * than assuming one frame per iteration.  Stop as soon as level_planet
 * changes. */
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
  for (let i = 0; i < 20 && byte('screws_left') !== byte('level_screw'); i++) frame();
}

function warpTo(level) {
  let guard = 0;
  while (byte('level_planet') !== level && guard++ < 200) {
    if (byte('level_planet') < level) warpOnce(['SELECT']);
    else warpOnce(['SELECT', 'UP']);
  }
}

function waitIntro(maxFrames = 1400) {
  /* The intro starts a few frames after the level load.  Treat an already
   * finished intro as idle too, so a missed start does not hang the test. */
  let sawIntro = false;
  for (let i = 0; i < maxFrames; i++) {
    if (byte('intro_active')) sawIntro = true;
    if (sawIntro && byte('intro_active') === 0 && byte('robbo_busy') === 0) return true;
    if (!sawIntro && i > 120) break;
    frame();
  }
  return byte('intro_active') === 0 && byte('robbo_busy') === 0;
}

/* Put Robbo on a specific cell without walking there.  The old cell is
 * cleared so the map keeps exactly one CT_ROBBO. */
function placeRobbo(x, y, dir) {
  const old = byte('robbo_y') * 16 + byte('robbo_x');
  const idx = y * 16 + x;
  if (old !== idx) {
    mem[S.map_type + old] = CT_EMPTY;
    mem[S.map_extra + old] = 0;
  }
  mem[S.map_type + idx] = CT_ROBBO;
  mem[S.map_extra + idx] = dir;
  mem[S.robbo_x] = x;
  mem[S.robbo_y] = y;
  mem[S.robbo_dir] = dir;
  frame();
  frame();
}

/* Press the direction until the teleport starts, then wait for the arrival. */
function enterTeleport(key, maxFrames = 1200) {
  let started = false;
  for (let i = 0; i < 120 && !started; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys([key]);
    gb.doFrame();
    started = byte('robbo_busy') !== 0;
  }
  if (!started) return false;
  for (let i = 0; i < maxFrames; i++) {
    if (!byte('robbo_busy')) return true;
    frame();
  }
  return false;
}

/* --- L7: lone self-linked teleport with no free neighbour. --- */
warpTo(7);
check('L7 loaded', byte('level_planet') === 7, `level=${byte('level_planet')}`);
check('L7 intro finished', waitIntro());
check('L7 has one self-linked teleport',
  byte('level_teleport_count') === 1 &&
  mem[S.map_type + 1 * 16 + 5] === CT_TELEPORT &&
  readMem(gb, S.teleport_dest, 2)[0] === 1 * 16 + 5 &&
  readMem(gb, S.teleport_dest, 2)[1] === 0,
  `count=${byte('level_teleport_count')} dest=${readMem(gb, S.teleport_dest, 2).join(',')}`);

placeRobbo(6, 1, 2);  /* only entrance: stand east of (5,1) facing west */
check('L7 lone self-link teleport triggers', enterTeleport('LEFT'));
check('L7 lone self-link teleports in place',
  byte('robbo_x') === 6 && byte('robbo_y') === 1,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
check('L7 teleport cell survives the in-place transfer',
  mem[S.map_type + 1 * 16 + 5] === CT_TELEPORT,
  `type=${mem[S.map_type + 1 * 16 + 5]}`);

/* --- L12: group member ringed by bombs is skipped, then used. --- */
warpTo(12);
check('L12 loaded', byte('level_planet') === 12, `level=${byte('level_planet')}`);
check('L12 intro finished', waitIntro());
check('L12 keeps all five teleport links', byte('level_teleport_count') === 5,
  `count=${byte('level_teleport_count')}`);

placeRobbo(2, 22, 2);  /* west of the (1,22) teleport, facing west */
check('L12 blocked ring member is skipped',
  enterTeleport('LEFT') &&
  byte('robbo_x') === 13 && byte('robbo_y') === 20,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);

/* Open the bomb on the ringed teleport's east side. */
mem[S.map_type + 28 * 16 + 8] = CT_EMPTY;
mem[S.map_extra + 28 * 16 + 8] = 0;
placeRobbo(2, 22, 2);
check('L12 ringed member is reachable after clearing a bomb',
  enterTeleport('LEFT') &&
  byte('robbo_x') === 8 && byte('robbo_y') === 28,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 28 passed');
process.exit(failures ? 1 : 0);
