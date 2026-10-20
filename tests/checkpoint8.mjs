#!/usr/bin/env node
/*
 * Checkpoint 8: a bomb blast kills Robbo.
 *
 * Regression test for the 3x3 bomb blast missing CT_ROBBO.
 *
 * Run: node gb/tests/checkpoint8.mjs
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
const CT_BOMB = 15;
const CT_BULLET = 27;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;

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
  for (let i = 0; i < 16 * 31; i++) {
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
    gb.doFrame();
  }
  return false;
}

// Keep the test isolated from level turrets/enemies.
clearActors();
mem[S.ammo] = 9;

// Robbo starts at (2,2); place a bomb directly to his right and ignite it.
setCell(3, 2, CT_BOMB, 0);
for (let i = 0; i < 12; i++) {
  core.JoyPad = 0xff;
  gb.pressKeys(['RIGHT', 'A']);
  gb.doFrame();
}

const killed = waitFor(() => byte('robbo_busy') !== 0);
check('bomb blast kills Robbo', killed,
  `busy=${byte('robbo_busy')} bomb=${cell(3, 2)}`);

const restarted = waitFor(() =>
  byte('robbo_busy') === 0 &&
  byte('robbo_x') === 2 && byte('robbo_y') === 2, 800);
check('death sequence restarts the level', restarted,
  `busy=${byte('robbo_busy')} level=${byte('level_planet')} pos=${byte('robbo_x')},${byte('robbo_y')}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 8 passed');
process.exit(failures ? 1 : 0);
