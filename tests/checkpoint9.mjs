#!/usr/bin/env node
/*
 * Checkpoint 9: magnet field rules.
 *
 * Source behaviour (robboJS/js/objects/Magnet.js):
 *   - a magnet only affects Robbo when he is in its forward ray
 *   - the ray must contain only empty cells
 *   - the first tick locks Robbo in the field
 *   - following ticks pull Robbo one cell toward the magnet
 *   - reaching the magnet cell/adjacent distance restarts the level
 *
 * Run: node gb/tests/checkpoint9.mjs
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
const CT_WALL = 1;
const CT_MAGNET = 25;
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

function fresh() {
  const gb = loadRom(rom);
  run(gb, 150);
  const core = gb[Object.keys(gb)[0]].gameboy;
  const mem = core.memory;
  const byte = (name) => readMem(gb, S[name], 1)[0];
  return { gb, core, mem, byte };
}

function setCell(mem, x, y, type, extra = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = extra;
  mem[S.map_obj + y * 16 + x] = 0;
}

function clearActors(mem) {
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

function waitFor(ctx, predicate, maxFrames = 800) {
  for (let i = 0; i < maxFrames; i++) {
    if (predicate()) return true;
    ctx.gb.doFrame();
  }
  return false;
}

// --- Capture, input lock, pull, and death at the magnet. ---
{
  const ctx = fresh();
  clearActors(ctx.mem);
  setCell(ctx.mem, 3, 2, CT_EMPTY);
  setCell(ctx.mem, 4, 2, CT_EMPTY);
  setCell(ctx.mem, 5, 2, CT_MAGNET, 2); // pointing left at Robbo

  const captured = waitFor(ctx, () => ctx.byte('robbo_no_move') !== 0, 400);
  check('magnet captures Robbo', captured,
    `noMove=${ctx.byte('robbo_no_move')} pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
  check('capture happens before pulling',
    ctx.byte('robbo_x') === 2, `x=${ctx.byte('robbo_x')}`);

  for (let i = 0; i < 2; i++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(['RIGHT']);
    ctx.gb.doFrame();
  }
  check('captured Robbo ignores movement input',
    ctx.byte('robbo_x') === 2 && ctx.byte('robbo_no_move') !== 0,
    `x=${ctx.byte('robbo_x')} noMove=${ctx.byte('robbo_no_move')}`);

  const pulled = waitFor(ctx, () => ctx.byte('robbo_x') > 2, 400);
  check('magnet pulls Robbo toward itself', pulled,
    `x=${ctx.byte('robbo_x')}`);

  const killed = waitFor(ctx, () => ctx.byte('robbo_busy') !== 0, 500);
  check('magnet kills Robbo at close range', killed,
    `busy=${ctx.byte('robbo_busy')} x=${ctx.byte('robbo_x')}`);

  const reset = waitFor(ctx, () =>
    ctx.byte('robbo_busy') === 0 &&
    ctx.byte('robbo_x') === 2 && ctx.byte('robbo_y') === 2, 800);
  check('magnet death restarts level', reset,
    `busy=${ctx.byte('robbo_busy')} pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- A wall between the magnet and Robbo blocks the field. ---
{
  const ctx = fresh();
  clearActors(ctx.mem);
  setCell(ctx.mem, 3, 2, CT_EMPTY);
  setCell(ctx.mem, 4, 2, CT_WALL);
  setCell(ctx.mem, 5, 2, CT_MAGNET, 2);

  const captured = waitFor(ctx, () => ctx.byte('robbo_no_move') !== 0, 250);
  check('wall blocks magnet field', !captured,
    `noMove=${ctx.byte('robbo_no_move')}`);
}

// --- Robbo must be in front of the magnet, not behind it. ---
{
  const ctx = fresh();
  clearActors(ctx.mem);
  setCell(ctx.mem, 3, 2, CT_EMPTY);
  setCell(ctx.mem, 4, 2, CT_EMPTY);
  setCell(ctx.mem, 5, 2, CT_MAGNET, 0); // pointing away from Robbo

  const captured = waitFor(ctx, () => ctx.byte('robbo_no_move') !== 0, 250);
  check('magnet ignores Robbo behind it', !captured,
    `noMove=${ctx.byte('robbo_no_move')}`);
}

// --- Robbo must be on the magnet's row/column. ---
{
  const ctx = fresh();
  clearActors(ctx.mem);
  setCell(ctx.mem, 3, 3, CT_EMPTY);
  setCell(ctx.mem, 4, 3, CT_EMPTY);
  setCell(ctx.mem, 5, 3, CT_MAGNET, 2);

  const captured = waitFor(ctx, () => ctx.byte('robbo_no_move') !== 0, 250);
  check('magnet ignores Robbo outside its ray', !captured,
    `noMove=${ctx.byte('robbo_no_move')}`);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 9 passed');
process.exit(failures ? 1 : 0);
