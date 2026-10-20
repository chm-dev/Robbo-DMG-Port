#!/usr/bin/env node
/*
 * Checkpoint 4: bombs and question blocks.
 *
 * The ROM is exercised with cells injected into WRAM next to Robbo so the test
 * does not depend on navigating a level. This is a harness-only shortcut; the
 * real levels load the same cells from banked data.
 *
 * Run: node gb/tests/checkpoint4.mjs
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
const CT_BOMB = 15;
const CT_QUESTION = 14;
const CT_AMMO = 19;
const CT_EXPLOSION = 28;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function setCell(x, y, type, ex = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = ex;
}

function pressRightFire(maxFrames = 20) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT', 'A']);
    gb.doFrame();
  }
}

function waitFor(predicate, maxFrames = 300) {
  for (let i = 0; i < maxFrames; i++) {
    if (predicate()) return true;
    gb.doFrame();
  }
  return false;
}

function holdUntil(key, predicate, maxFrames = 200) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys([key]);
    gb.doFrame();
    if (predicate()) return true;
  }
  return false;
}

run(gb, 150);

// --- Bomb: shoot it, check the staggered 3x3 blast. ---
mem[S.ammo] = 9;
setCell(3, 2, CT_BOMB, 0);
pressRightFire(12);
check('bomb fuse started', cell(3, 2) === CT_BOMB && extra(3, 2) !== 0,
  `type=${cell(3, 2)} extra=${extra(3, 2)}`);
check('shot did not move Robbo', byte('robbo_x') === 2, `x=${byte('robbo_x')}`);

const exploded = waitFor(() => cell(3, 2) === CT_EXPLOSION, 200);
check('bomb exploded', exploded, `type=${cell(3, 2)}`);
if (exploded) {
  let explosionCount = 0;
  const timers = [];
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const x = 3 + dx, y = 2 + dy;
      if (x < 0 || y < 0 || x >= 16 || y >= 31) continue;
      if (cell(x, y) === CT_EXPLOSION) {
        explosionCount++;
        timers.push(extra(x, y) & 7);
      }
    }
  }
  check('3x3 blast covers the area', explosionCount >= 7, `cells=${explosionCount}`);
  const distinct = new Set(timers);
  check('blast animation is staggered', distinct.size >= 3,
    `timers=${timers.join(',')}`);
  savePng(gb.getScreen(), path.join(out, 'cp4-bomb.png'));
}

// --- Question: shoot it, then wait for its ammo payload. ---
run(gb, 40);
mem[S.ammo] = 9;
setCell(3, 2, CT_QUESTION, 6);  // randomCfg[6] = Ammo
pressRightFire(12);
check('question is exploding', cell(3, 2) === CT_EXPLOSION,
  `type=${cell(3, 2)} extra=${extra(3, 2)}`);
const revealed = waitFor(() => cell(3, 2) === CT_AMMO, 300);
check('question revealed ammo payload', revealed, `type=${cell(3, 2)}`);
check('ammo payload has no extra state', extra(3, 2) === 0, `extra=${extra(3, 2)}`);

// --- Pushable bomb and question. ---
run(gb, 40);
mem[S.ammo] = 9;
setCell(4, 2, CT_EMPTY, 0);
setCell(3, 2, CT_BOMB, 0);
const pushedBomb = holdUntil('RIGHT', () => byte('robbo_x') === 3, 120);
check('bomb can be pushed', pushedBomb && cell(4, 2) === CT_BOMB,
  `robbo=${byte('robbo_x')} type(4,2)=${cell(4, 2)}`);

// Reset Robbo to the left of the target cell, then test question pushing.
holdUntil('LEFT', () => byte('robbo_x') === 2, 120);
setCell(4, 2, CT_EMPTY, 0);
setCell(3, 2, CT_QUESTION, 6);
const pushedQuestion = holdUntil('RIGHT', () => byte('robbo_x') === 3, 120);
check('question can be pushed', pushedQuestion && cell(4, 2) === CT_QUESTION,
  `robbo=${byte('robbo_x')} type(4,2)=${cell(4, 2)}`);
check('pushed question keeps its payload', extra(4, 2) === 6, `extra=${extra(4, 2)}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 4 passed');
process.exit(failures ? 1 : 0);
