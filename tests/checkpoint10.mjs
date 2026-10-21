#!/usr/bin/env node
/*
 * Checkpoint 10: last-screw background flash.
 *
 * The flash must whiten the background shade (shade 1), not the wall shade.
 *
 * Run: node gb/tests/checkpoint10.mjs
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
const BGP = 0xFF47;
const CT_EMPTY = 0;
const CT_SCREW = 17;
const ACTOR_TYPES = [18, 21, 22, 23, 27];

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
run(gb, 150);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;

for (let i = 0; i < 16 * 31; i++) {
  if (ACTOR_TYPES.includes(mem[S.map_type + i])) {
    mem[S.map_type + i] = CT_EMPTY;
    mem[S.map_extra + i] = 0;
    mem[S.map_obj + i] = 0;
  }
}

// Put the last screw directly to Robbo's right.
mem[S.map_type + 2 * 16 + 3] = CT_SCREW;
mem[S.map_extra + 2 * 16 + 3] = 0;
mem[S.map_obj + 2 * 16 + 3] = 0;
mem[S.screws_left] = 1;

let flashBgp = null;
for (let i = 0; i < 40; i++) {
  core.JoyPad = 0xff;
  gb.pressKeys(['RIGHT']);
  gb.doFrame();
  const bgp = readMem(gb, BGP, 1)[0];
  if (bgp !== 0xE4) {
    flashBgp = bgp;
    break;
  }
}
check('last screw starts flash', flashBgp !== null,
  flashBgp === null ? 'no BGP change' : '');
check('flash whitens the background shade only', flashBgp === 0xE0,
  flashBgp === null ? 'no flash' : `BGP=0x${flashBgp.toString(16)}`);

let restored = false;
for (let i = 0; i < 40; i++) {
  gb.doFrame();
  if (readMem(gb, BGP, 1)[0] === 0xE4) {
    restored = true;
    break;
  }
}
check('flash restores palette', restored);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 10 passed');
process.exit(failures ? 1 : 0);
