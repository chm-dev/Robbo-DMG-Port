#!/usr/bin/env node
/*
 * Checkpoint 2 regression test: bolt pickup, stone push, pushable box slide.
 *
 * Run: node gb/tests/checkpoint2.mjs
 */
import { loadRom, run, readMem, savePng, holdKey, tapKey } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = path.join(root, 'gb', 'tests', 'screenshots');
const gb = loadRom(path.join(root, 'roms', 'robbo.gb'));

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
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const row = (name, y) => Array.from(readMem(gb, S[name] + y * 16, 16));
const CT_PUSHABLE = 11;
const CT_STONE = 10;
const CT_ROBBO = 26;

function clearTurretsAndBullets() {
  for (let i = 0; i < 16 * 31; i++) {
    if (mem[S.map_type + i] === 18 || mem[S.map_type + i] === 27) {
      mem[S.map_type + i] = 0;
      mem[S.map_extra + i] = 0;
    }
  }
}

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

run(gb, 150);

// --- Level 5: walk to the bolt at (10,2) and collect it. ---
for (let i = 0; i < 10 && byte('level_planet') !== 5; i++) tapKey(gb, 'SELECT', 80);
for (let i = 0; i < 40 && byte('screws_left') !== byte('level_screw'); i++) gb.doFrame();
clearTurretsAndBullets();
check('warp to level 5', byte('level_planet') === 5, `level=${byte('level_planet')}`);

let guard = 0;
while (byte('robbo_x') > 10 && guard++ < 30) holdKey(gb, 'LEFT', 8);
while (byte('robbo_x') < 10 && guard++ < 60) holdKey(gb, 'RIGHT', 8);
check('aligned with bolt', byte('robbo_x') === 10, `x=${byte('robbo_x')}`);

const screwsBefore = byte('screws_left');
for (let i = 0; i < 10 && byte('robbo_y') === 1; i++) holdKey(gb, 'DOWN', 20);
const screwsAfter = byte('screws_left');
check('bolt collected', screwsAfter === screwsBefore - 1,
  `${screwsBefore} -> ${screwsAfter}`);
check('Robbo entered bolt cell', byte('robbo_y') === 2 && byte('robbo_x') === 10,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
savePng(gb.getScreen(), path.join(out, 'cp2-bolt.png'));

// --- Level 30: push a stone one cell, then push a sliding box. ---
for (let i = 0; i < 20 && byte('level_planet') !== 30; i++) {
  tapKey(gb, ['SELECT', 'A'], 50);
}
for (let i = 0; i < 40 && byte('screws_left') !== byte('level_screw'); i++) gb.doFrame();
clearTurretsAndBullets();
check('warp to level 30', byte('level_planet') === 30, `level=${byte('level_planet')}`);

holdKey(gb, 'RIGHT', 40);
guard = 0;
while (byte('robbo_x') < 5 && guard++ < 20) holdKey(gb, 'RIGHT', 12);
check('stone pushed one cell', row('map_type', 2)[6] === CT_STONE,
  `row2[6]=${row('map_type', 2)[6]}`);
check('Robbo behind stone', row('map_type', 2)[5] === CT_ROBBO && byte('robbo_x') === 5,
  `row2[5]=${row('map_type', 2)[5]} x=${byte('robbo_x')}`);

holdKey(gb, 'UP', 16);
guard = 0;
while (byte('robbo_y') > 1 && guard++ < 20) holdKey(gb, 'UP', 16);
check('moved up to box row', byte('robbo_y') === 1, `y=${byte('robbo_y')}`);

guard = 0;
while (byte('robbo_x') < 6 && guard++ < 20) holdKey(gb, 'RIGHT', 8);
check('aligned to push box', byte('robbo_x') === 6 && byte('robbo_y') === 1,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);

holdKey(gb, 'RIGHT', 24);
guard = 0;
while (!(byte('robbo_x') >= 7 && row('map_type', 1)[byte('robbo_x') + 1] === CT_PUSHABLE) && guard++ < 20) {
  holdKey(gb, 'RIGHT', 12);
}
const rx = byte('robbo_x');
check('box moved from its start cell', rx >= 7, `x=${rx}`);
check('box is directly ahead of Robbo', row('map_type', 1)[rx + 1] === CT_PUSHABLE,
  `row1[${rx + 1}]=${row('map_type', 1)[rx + 1]}`);

for (let i = 0; i < 600; i++) gb.doFrame();
check('box slid to the wall', row('map_type', 1)[14] === CT_PUSHABLE,
  `row1[14]=${row('map_type', 1)[14]}`);
check('box stopped moving', (row('map_extra', 1)[14] & 4) === 0,
  `extra=${row('map_extra', 1)[14]}`);
savePng(gb.getScreen(), path.join(out, 'cp2-boxes.png'));

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 2 passed');
process.exit(failures ? 1 : 0);
