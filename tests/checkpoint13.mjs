#!/usr/bin/env node
/*
 * Checkpoint 13: bomb/explosion performance guard.
 *
 * Measurement: debug_ticks counts completed main-loop iterations and
 * sys_time counts VBlanks.  A healthy loop finishes one iteration per frame
 * (ratio 1.0); a ratio below 1 means the game runs in slow motion.  These are
 * cycle-deterministic (the emulator always advances the same VBlank count),
 * so the numbers do not depend on host speed.
 *
 * Covered:
 *   - quiet steady state,
 *   - the first-ever explosion (pays the one-time sound step conversion),
 *   - a repeated small chain (steady-state, what players experience),
 *   - an 8x8 worst-case field that must fully detonate and clean up.
 *
 * Run: node gb/tests/checkpoint13.mjs
 */
import { loadRom, run } from '../tools/gb_harness.mjs';
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
const CT_EXPLOSION = 28;
const CT_ROBBO = 26;
const MAP = 16 * 31;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const u16 = (a) => mem[a] | (mem[a + 1] << 8);

function frame() {
  core.JoyPad = 0xff;
  gb.doFrame();
}

function window(framesWanted) {
  const s0 = u16(S.sys_time), t0 = u16(S.debug_ticks);
  for (let i = 0; i < framesWanted; i++) frame();
  const frames = (u16(S.sys_time) - s0) & 0xffff;
  const iters = (u16(S.debug_ticks) - t0) & 0xffff;
  return { frames, iters, ratio: frames ? iters / frames : 0 };
}

/* Inject a w*h bomb field whose top-left corner sits at (x0,y0), light one
 * fuse, run until every bomb/explosion cell is gone.  Returns the measured
 * iteration rate plus the peak number of simultaneous explosion cells. */
function cascade(x0, y0, w, h, maxFrames = 4000) {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      mem[S.map_type + y * 16 + x] = CT_BOMB;
      mem[S.map_extra + y * 16 + x] = 0;
      mem[S.map_obj + y * 16 + x] = 0;
    }
  }
  mem[S.map_extra + y0 * 16 + x0] = 1;

  const s0 = u16(S.sys_time), t0 = u16(S.debug_ticks);
  let peak = 0, cleared = false;
  for (let i = 0; i < maxFrames; i++) {
    frame();
    let alive = 0;
    for (let y = y0; y < y0 + h; y++) {
      for (let x = x0; x < x0 + w; x++) {
        const t = mem[S.map_type + y * 16 + x];
        if (t === CT_BOMB || t === CT_EXPLOSION) alive++;
      }
    }
    if (alive > peak) peak = alive;
    if (alive === 0) { cleared = true; break; }
  }
  const frames = (u16(S.sys_time) - s0) & 0xffff;
  const iters = (u16(S.debug_ticks) - t0) & 0xffff;
  return { frames, iters, ratio: frames ? iters / frames : 0, peak, cleared };
}

function settle(framesWanted = 60) {
  for (let i = 0; i < framesWanted; i++) frame();
}

/* ---- boot, clear the level's own actors, settle ---- */
run(gb, 400);
for (let i = 0; i < MAP; i++) {
  const t = mem[S.map_type + i];
  if ((t >= 18 && t <= 25) || t === 27) {   /* turrets..magnets, bullets */
    mem[S.map_type + i] = CT_EMPTY;
    mem[S.map_extra + i] = 0;
    mem[S.map_obj + i] = 0;
  }
}
settle(60);

const quiet = window(400);
check('quiet loop keeps one iteration per frame',
  quiet.ratio >= 0.80, `ratio=${quiet.ratio.toFixed(3)}`);

/* Small chain near Robbo but outside his blast reach (2x2 at 7,7). */
const cold = cascade(7, 7, 2, 2);
settle(80);
const warm = cascade(7, 7, 2, 2);
settle(80);

check('first-ever small chain completes', cold.cleared,
  `ratio=${cold.ratio.toFixed(3)}`);
check('first-ever small chain stays above 45% speed',
  cold.ratio >= 0.45, `ratio=${cold.ratio.toFixed(3)}`);
check('repeated small chain runs at least 75% speed',
  warm.ratio >= 0.75, `ratio=${warm.ratio.toFixed(3)} (${warm.iters} iterations / ${warm.frames} frames)`);

/* Worst case: 8x8 bomb field across most of the view. */
const stress = cascade(4, 5, 8, 8);
settle(80);
check('8x8 stress chain completes and cleans up',
  stress.cleared && stress.peak > 0, `peak=${stress.peak} cells`);
check('8x8 stress chain stays above 50% speed',
  stress.ratio >= 0.50, `ratio=${stress.ratio.toFixed(3)} (${stress.iters} iterations / ${stress.frames} frames)`);
check('Robbo survived all cascades',
  mem[S.map_type + mem[S.robbo_y] * 16 + mem[S.robbo_x]] === CT_ROBBO,
  `robbo=(${mem[S.robbo_x]},${mem[S.robbo_y]})`);

console.log(`\nquiet ${quiet.ratio.toFixed(3)} | first 2x2 ${cold.ratio.toFixed(3)} | ` +
  `repeat 2x2 ${warm.ratio.toFixed(3)} | 8x8 ${stress.ratio.toFixed(3)} ` +
  `(peak ${stress.peak} cells)`);
console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 13 passed');
process.exit(failures ? 1 : 0);
