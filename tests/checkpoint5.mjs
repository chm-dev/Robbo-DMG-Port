#!/usr/bin/env node
/*
 * Checkpoint 5: key pickup and door opening.
 *
 * Run: node gb/tests/checkpoint5.mjs
 */
import { loadRom, run, readMem, savePng } from '../tools/gb_harness.mjs';
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
const cell = (x, y) => mem[S.map_type + y * 16 + x];
const extra = (x, y) => mem[S.map_extra + y * 16 + x];

const CT_EMPTY = 0;
const CT_DOOR = 12;
const CT_KEY = 16;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function setCell(x, y, type, ex = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = ex;
}

function holdUntil(predicate, maxFrames = 200) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT']);
    gb.doFrame();
    if (predicate()) return true;
  }
  return false;
}

run(gb, 150);

// Door with no key must block and stay.
mem[S.keys] = 0;
setCell(3, 2, CT_DOOR, 0);
for (let i = 0; i < 40; i++) {
  core.JoyPad = 0xff;
  gb.pressKeys(['RIGHT']);
  gb.doFrame();
}
check('locked door blocks Robbo', byte('robbo_x') === 2, `x=${byte('robbo_x')}`);
check('locked door remains', cell(3, 2) === CT_DOOR, `type=${cell(3, 2)}`);
check('no key was consumed', byte('keys') === 0, `keys=${byte('keys')}`);

// Replace the door with a key and collect it.
setCell(3, 2, CT_KEY, 0);
const gotKey = holdUntil(() => byte('keys') === 1, 80);
check('key collected', gotKey && byte('keys') === 1, `keys=${byte('keys')}`);
check('Robbo entered key cell', byte('robbo_x') === 3, `x=${byte('robbo_x')}`);
check('key removed', cell(3, 2) === 26, `type=${cell(3, 2)}`);
savePng(gb.getScreen(), path.join(out, 'cp5-key.png'));

// Put a door in front; collision opens it, consumes one key, and Robbo stays.
setCell(4, 2, CT_DOOR, 0);
const opened = holdUntil(() => byte('keys') === 0, 80);
check('door opened with key', opened && byte('keys') === 0, `keys=${byte('keys')}`);
check('door cell cleared', cell(4, 2) === CT_EMPTY, `type=${cell(4, 2)}`);
check('Robbo stays put while opening', byte('robbo_x') === 3, `x=${byte('robbo_x')}`);

// Next movement enters the opened doorway.
const entered = holdUntil(() => byte('robbo_x') === 4, 80);
check('Robbo can enter opened doorway', entered, `x=${byte('robbo_x')}`);
savePng(gb.getScreen(), path.join(out, 'cp5-door.png'));

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 5 passed');
process.exit(failures ? 1 : 0);
