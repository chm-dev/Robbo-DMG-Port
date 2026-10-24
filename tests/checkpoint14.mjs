#!/usr/bin/env node
/*
 * Checkpoint 14: Robbo's death destroys every non-wall item.
 *
 * Source controller.restart() replaces every map cell that is neither Empty
 * nor Walls with an Explosion before reloading the level.  This test kills
 * Robbo with a bomb and verifies the wipe, wall survival, and the reload.
 *
 * Run: node gb/tests/checkpoint14.mjs
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
const CT_WALL_3 = 4;
const CT_GROUND = 9;
const CT_BOMB = 15;
const CT_KEY = 16;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;
const MAP_CELLS = 16 * 31;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
run(gb, 150);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const cell = (x, y) => mem[S.map_type + y * 16 + x];

function setCell(x, y, type, ex = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = ex;
  mem[S.map_obj + y * 16 + x] = 0;
}

function clearActors() {
  for (let i = 0; i < MAP_CELLS; i++) {
    const type = mem[S.map_type + i];
    if (type === CT_TURRET || type === CT_MUSTACHE || type === CT_BUTTERFLY ||
        type === CT_BEAR || type === CT_BULLET) {
      mem[S.map_type + i] = CT_EMPTY;
      mem[S.map_extra + i] = 0;
      mem[S.map_obj + i] = 0;
    }
  }
}

function waitFor(predicate, maxFrames = 800) {
  for (let i = 0; i < maxFrames; i++) {
    if (predicate()) return true;
    core.JoyPad = 0xff;
    gb.doFrame();
  }
  return false;
}

clearActors();

/* Put a bomb next to Robbo, plus distant non-wall markers and a wall. */
const rx = byte('robbo_x');
const ry = byte('robbo_y');
setCell(rx + 1, ry, CT_BOMB, 1);
setCell(8, 1, CT_KEY, 0);
setCell(7, 1, CT_GROUND, 0);
setCell(6, 1, CT_WALL_3, 0);

const killed = waitFor(() => byte('robbo_busy') !== 0, 300);
check('bomb kills Robbo', killed,
  `busy=${byte('robbo_busy')} pos=${byte('robbo_x')},${byte('robbo_y')}`);

/* The Atari WYBC/WHIL sequence waits 48 frames (eight 6-frame logic ticks)
 * after the death explosion before wiping.  The wipe itself can straddle a
 * VBlank, so wait until every non-wall item has become an explosion rather
 * than sampling a partially processed map. */
function nonWallSurvivors() {
  let survivors = 0;
  for (let i = 0; i < MAP_CELLS; i++) {
    const type = mem[S.map_type + i];
    const isWall = type >= 1 && type <= 8;
    if (!isWall && type !== CT_EMPTY && type !== CT_EXPLOSION) survivors++;
  }
  return survivors;
}

const wiped = waitFor(() =>
  cell(8, 1) === CT_EXPLOSION && nonWallSurvivors() === 0, 300);
check('death turns items into explosions', wiped,
  `key=${cell(8, 1)} ground=${cell(7, 1)} survivors=${nonWallSurvivors()}`);

if (wiped) {
  check('every non-wall item is destroyed', nonWallSurvivors() === 0,
    `survivors=${nonWallSurvivors()}`);
  check('walls survive the death wipe', cell(6, 1) === CT_WALL_3,
    `wall=${cell(6, 1)}`);
  check('ground is consumed too', cell(7, 1) === CT_EXPLOSION,
    `ground=${cell(7, 1)}`);
  check('level waits before reloading', byte('robbo_busy') !== 0,
    `busy=${byte('robbo_busy')} request=${byte('game_restart_requested')}`);
}

const restarted = waitFor(() =>
  byte('robbo_busy') === 0 &&
  byte('robbo_x') === 2 && byte('robbo_y') === 2, 600);
check('level reloads after the wipe', restarted,
  `busy=${byte('robbo_busy')} level=${byte('level_planet')} ` +
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 14 passed');
process.exit(failures ? 1 : 0);
