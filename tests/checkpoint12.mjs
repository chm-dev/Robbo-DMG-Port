#!/usr/bin/env node
/*
 * Checkpoint 12: free camera pan with B.
 *
 * Hold B and use the d-pad to pan; release B to restore the view that was
 * active when B was pressed.
 *
 * Run: node gb/tests/checkpoint12.mjs
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
const ACTORS = [18, 21, 22, 23, 27];

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function fresh() {
  const gb = loadRom(rom);
  run(gb, 180);
  const core = gb[Object.keys(gb)[0]].gameboy;
  const mem = core.memory;
  for (let i = 0; i < 16 * 31; i++) {
    if (ACTORS.includes(mem[S.map_type + i])) {
      mem[S.map_type + i] = CT_EMPTY;
      mem[S.map_extra + i] = 0;
      mem[S.map_obj + i] = 0;
    }
  }
  return { gb, core, mem, byte: (name) => readMem(gb, S[name], 1)[0] };
}

function hold(ctx, keys, frames) {
  for (let i = 0; i < frames; i++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(keys);
    ctx.gb.doFrame();
  }
}

function release(ctx, frames = 10) {
  for (let i = 0; i < frames; i++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.doFrame();
  }
}

{
  const ctx = fresh();
  const saved = [ctx.byte('cam_x'), ctx.byte('cam_y')];
  hold(ctx, ['B', 'RIGHT'], 80);
  check('B+Right pans right', ctx.byte('cam_x') > saved[0],
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')}`);
  check('panning does not move Robbo', ctx.byte('robbo_x') === 2,
    `x=${ctx.byte('robbo_x')}`);

  hold(ctx, ['B', 'RIGHT'], 240);
  check('horizontal pan is clamped', ctx.byte('cam_x') <= 6,
    `cam_x=${ctx.byte('cam_x')}`);

  release(ctx);
  check('release restores horizontal view',
    ctx.byte('cam_x') === saved[0] && ctx.byte('cam_y') === saved[1],
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')}`);
}

{
  const ctx = fresh();
  const savedY = ctx.byte('cam_y');
  hold(ctx, ['B', 'DOWN'], 80);
  check('B+Down pans down', ctx.byte('cam_y') > savedY,
    `cam_y=${ctx.byte('cam_y')}`);
  release(ctx);
  check('release restores vertical view', ctx.byte('cam_y') === savedY,
    `cam_y=${ctx.byte('cam_y')}`);
}

{
  const ctx = fresh();
  const saved = [ctx.byte('cam_x'), ctx.byte('cam_y')];
  hold(ctx, ['B'], 40);
  check('B without direction holds the view',
    ctx.byte('cam_x') === saved[0] && ctx.byte('cam_y') === saved[1],
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')}`);
  release(ctx);
  check('B release restores unchanged view',
    ctx.byte('cam_x') === saved[0] && ctx.byte('cam_y') === saved[1]);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 12 passed');
process.exit(failures ? 1 : 0);
