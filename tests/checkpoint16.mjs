#!/usr/bin/env node
/*
 * Checkpoint 16: stones and pushable boxes survive gunfire.
 *
 * In the source, Stone and PushableStone are explodable but not demolishable.
 * Robbo's gun therefore cannot destroy them, whether the bullet hits from a
 * distance or the shot is fired point-blank at the neighbouring cell.
 *
 * Run: node gb/tests/checkpoint16.mjs
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
const CT_STONE = 10;
const CT_PUSHABLE = 11;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;
const CT_BULLET = 27;

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

function holdFireRight(frames) {
  for (let i = 0; i < frames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT', 'A']);
    gb.doFrame();
  }
}

clearActors();
const rx = byte('robbo_x');
const ry = byte('robbo_y');

/* Clear the corridor to the right so only the tested object is in the way. */
for (let x = rx + 1; x <= rx + 8; x++) setCell(x, ry, CT_EMPTY);

/* --- Point-blank shot at a stone. --------------------------------------- */
setCell(rx + 1, ry, CT_STONE);
mem[S.ammo] = 9;
holdFireRight(40);
check('point-blank stone survives gunfire', cell(rx + 1, ry) === CT_STONE,
  `cell=${cell(rx + 1, ry)}`);
check('point-blank shot does not move Robbo',
  byte('robbo_x') === rx && byte('robbo_y') === ry,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);

/* --- Point-blank shot at a pushable box. -------------------------------- */
setCell(rx + 1, ry, CT_PUSHABLE);
mem[S.ammo] = 9;
holdFireRight(40);
check('point-blank pushable box survives gunfire',
  cell(rx + 1, ry) === CT_PUSHABLE,
  `cell=${cell(rx + 1, ry)}`);

/* --- Bullet fired from a distance at a stone. --------------------------- */
setCell(rx + 1, ry, CT_EMPTY);
setCell(rx + 5, ry, CT_STONE);
mem[S.ammo] = 9;
holdFireRight(90);
check('distant stone survives a bullet', cell(rx + 5, ry) === CT_STONE,
  `cell=${cell(rx + 5, ry)}`);
check('distant shot consumes ammo', byte('ammo') < 9, `ammo=${byte('ammo')}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 16 passed');
process.exit(failures ? 1 : 0);
