#!/usr/bin/env node
/*
 * Checkpoint 19: smooth sub-cell camera.
 *
 * The camera keeps the existing 2-cell dead zone but glides in Q4 pixels
 * toward a cell-aligned goal (robbo-gbc's 1/8-distance ease, capped at
 * 3 px/frame).  The VBlank handler is the only writer of SCX/SCY.
 *
 * Covered:
 *   - resting camera is still cell-aligned and identical to the old snap;
 *   - horizontal and vertical glides have intermediates, <=3 px steps and
 *     settle exactly on the target cell;
 *   - the 2-row row-ring margin survives pan eviction/redraw at both ends;
 *   - B-pan restores the exact Q4 position, including mid-glide;
 *   - a level whose Robbo starts low snaps the ring to that row on load.
 *
 * Run: node gb/tests/checkpoint19.mjs
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
const CT_ROBBO = 26;
/* Moving or timed actors; static scenery is left untouched. */
const ACTORS = [15, 18, 20, 21, 22, 23, 25, 27, 28];

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function boot() {
  const gb = loadRom(rom);
  run(gb, 180);
  const core = gb[Object.keys(gb)[0]].gameboy;
  const mem = core.memory;
  const byte = n => readMem(gb, S[n], 1)[0];
  const u16 = n => {
    const b = readMem(gb, S[n], 2);
    return b[0] | (b[1] << 8);
  };
  const clearActors = () => {
    for (let i = 0; i < 16 * 31; i++) {
      if (ACTORS.includes(mem[S.map_type + i])) {
        mem[S.map_type + i] = CT_EMPTY;
        mem[S.map_extra + i] = 0;
        mem[S.map_obj + i] = 0;
      }
    }
  };
  const frame = (keys = null) => {
    core.JoyPad = 0xff;
    if (keys) gb.pressKeys(keys);
    gb.doFrame();
  };
  return { gb, core, mem, byte, u16, clearActors, frame };
}

function clearCell(ctx, x, y) {
  const i = y * 16 + x;
  ctx.mem[S.map_type + i] = CT_EMPTY;
  ctx.mem[S.map_extra + i] = 0;
  ctx.mem[S.map_obj + i] = 0;
}

/* One metatile row of the BG map for a world Y (both 8px halves). */
function tileRow(ctx, worldY) {
  const bg = ctx.core.BGCHRBank1;
  const slot = worldY & 15;
  const row = [];
  for (let t = 0; t < 2; t++) {
    for (let x = 0; x < 32; x++) {
      row.push(bg[((slot * 2 + t) * 32 + x) & 0x7ff]);
    }
  }
  return row.join(',');
}

/* Walk one direction until `done()`; returns the per-frame cam_scx/sc_y. */
function glideUntil(ctx, keys, done, max = 240) {
  const samples = [];
  for (let i = 0; i < max; i++) {
    if (done()) break;
    ctx.frame(keys);
    samples.push([ctx.byte('cam_scx'), ctx.byte('cam_scy')]);
  }
  return samples;
}

/* Wait until the Q4 position stops changing (the 1/8 tail is long), with a
 * generous cap; also collect the per-frame pixel samples. */
function settleStable(ctx, max = 320) {
  const samples = [];
  let lastX = ctx.u16('cam_qx');
  let lastY = ctx.u16('cam_qy');
  let stable = 0;
  for (let i = 0; i < max; i++) {
    ctx.frame();
    samples.push([ctx.byte('cam_scx'), ctx.byte('cam_scy')]);
    const x = ctx.u16('cam_qx');
    const y = ctx.u16('cam_qy');
    if (x === lastX && y === lastY) {
      if (++stable >= 8) break;
    } else {
      stable = 0;
      lastX = x;
      lastY = y;
    }
  }
  return samples;
}

function distinct(values) {
  return new Set(values).size;
}

function maxStep(values) {
  let m = 0;
  for (let i = 1; i < values.length; i++) {
    m = Math.max(m, Math.abs(values[i] - values[i - 1]));
  }
  return m;
}

/* ------------------------------------------------------------------ */
/* 1. Resting camera is cell-aligned and starts at zero.              */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  check('level 1 starts with a snapped camera',
    ctx.byte('cam_x') === 0 && ctx.byte('cam_y') === 0 &&
    ctx.byte('cam_scx') === 0 && ctx.byte('cam_scy') === 0 &&
    ctx.byte('cam_goal_x') === 0 && ctx.byte('cam_goal_y') === 0,
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')} sc=${ctx.byte('cam_scx')},${ctx.byte('cam_scy')}`);
  check('camera ease is enabled in play', ctx.byte('cam_smooth') === 1,
    `smooth=${ctx.byte('cam_smooth')}`);
  check('Q4 camera starts at the cell origin',
    ctx.u16('cam_qx') === 0 && ctx.u16('cam_qy') === 0,
    `q=${ctx.u16('cam_qx')},${ctx.u16('cam_qy')}`);
}

/* ------------------------------------------------------------------ */
/* 2. Horizontal glide across the right dead-zone edge.               */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  ctx.clearActors();
  for (let x = 3; x < 12; x++) clearCell(ctx, x, 2);

  const before = [];
  let goalSeen = false;
  for (let i = 0; i < 200 && !goalSeen; i++) {
    before.push(ctx.byte('cam_scx'));
    ctx.frame(['RIGHT']);
    goalSeen = ctx.byte('cam_goal_x') === 1;
  }
  check('walking right moves the camera goal by one cell', goalSeen,
    `goal=${ctx.byte('cam_goal_x')} x=${ctx.byte('robbo_x')}`);

  const samples = settleStable(ctx).map(s => s[0]);
  const all = before.slice(-4).concat(samples);
  const mids = samples.filter(v => v > 0 && v < 16);
  check('horizontal glide has sub-cell intermediates', distinct(mids) >= 3,
    `values=${[...new Set(samples)].slice(0, 20).join(',')}`);
  check('horizontal glide never jumps a whole cell', maxStep(all) <= 3,
    `maxStep=${maxStep(all)}`);
  check('horizontal glide settles exactly one cell over',
    samples[samples.length - 1] === 16 && ctx.byte('cam_x') === 1 &&
    ctx.u16('cam_qx') === 256,
    `scx=${samples[samples.length - 1]} cam_x=${ctx.byte('cam_x')} q=${ctx.u16('cam_qx')}`);
}

/* ------------------------------------------------------------------ */
/* 3. Vertical glide down and then back up (the top-edge ring case).  */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  ctx.clearActors();
  for (let y = 3; y <= 12; y++) clearCell(ctx, 2, y);

  let goalSeen = false;
  for (let i = 0; i < 240 && !goalSeen; i++) {
    ctx.frame(['DOWN']);
    goalSeen = ctx.byte('cam_goal_y') === 1;
  }
  check('walking down moves the camera goal by one cell', goalSeen,
    `goal=${ctx.byte('cam_goal_y')} y=${ctx.byte('robbo_y')}`);

  const downSamples = settleStable(ctx);
  const downY = downSamples.map(s => s[1]);
  const downMids = downY.filter(v => v > 0 && v < 16);
  check('down glide has sub-cell intermediates', distinct(downMids) >= 3,
    `values=${[...new Set(downY)].slice(0, 20).join(',')}`);
  check('down glide never jumps a whole cell', maxStep(downY) <= 3,
    `maxStep=${maxStep(downY)}`);
  check('down glide settles exactly one cell over',
    downY[downY.length - 1] === 16 && ctx.byte('cam_y') === 1 &&
    ctx.u16('cam_qy') === 256,
    `scy=${downY[downY.length - 1]} cam_y=${ctx.byte('cam_y')} q=${ctx.u16('cam_qy')}`);

  let backSeen = false;
  for (let i = 0; i < 240 && !backSeen; i++) {
    ctx.frame(['UP']);
    backSeen = ctx.byte('cam_goal_y') === 0 && ctx.byte('robbo_y') <= 2;
  }
  check('walking back up returns the camera goal', backSeen,
    `goal=${ctx.byte('cam_goal_y')} y=${ctx.byte('robbo_y')}`);

  const upSamples = settleStable(ctx);
  const upY = upSamples.map(s => s[1]);
  const upMids = upY.filter(v => v > 0 && v < 16);
  check('up glide (top edge) has sub-cell intermediates', distinct(upMids) >= 3,
    `values=${[...new Set(upY)].slice(0, 20).join(',')}`);
  check('up glide never jumps a whole cell', maxStep(upY) <= 3,
    `maxStep=${maxStep(upY)}`);
  check('up glide settles exactly on the start cell',
    upY[upY.length - 1] === 0 && ctx.byte('cam_y') === 0 &&
    ctx.u16('cam_qy') === 0,
    `scy=${upY[upY.length - 1]} cam_y=${ctx.byte('cam_y')} q=${ctx.u16('cam_qy')}`);
}

/* ------------------------------------------------------------------ */
/* 4. Row ring: evict/redraw at both map ends via B-pan.              */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  ctx.clearActors();

  const holdB = (dir, frames) => {
    for (let i = 0; i < frames; i++) ctx.frame(['B', dir]);
  };
  const releaseB = () => {
    for (let i = 0; i < 240; i++) ctx.frame();
  };

  /* First round trip also flushes the actor clears out of the ring. */
  holdB('DOWN', 260);
  const bottomY = ctx.byte('cam_y');
  holdB('DOWN', 60); /* ensure the clamp is reached */
  const bottomRows = [];
  for (let y = 21; y <= 30; y++) bottomRows.push(tileRow(ctx, y));
  releaseB();
  const topRef = [];
  for (let y = 0; y <= 9; y++) topRef.push(tileRow(ctx, y));

  check('B+Down reaches the bottom clamp', bottomY === 23,
    `cam_y=${bottomY}`);
  check('release restores the top view', ctx.byte('cam_y') === 0,
    `cam_y=${ctx.byte('cam_y')}`);

  /* Second round trip: every evicted row must be rebuilt identically. */
  holdB('DOWN', 320);
  const bottomRows2 = [];
  for (let y = 21; y <= 30; y++) bottomRows2.push(tileRow(ctx, y));
  releaseB();
  const topRows2 = [];
  for (let y = 0; y <= 9; y++) topRows2.push(tileRow(ctx, y));

  check('bottom rows survive eviction/redraw',
    bottomRows.join('|') === bottomRows2.join('|'),
    `rows=${bottomRows2.length}`);
  check('top rows survive eviction/redraw',
    topRef.join('|') === topRows2.join('|'),
    `rows=${topRows2.length}`);
}

/* ------------------------------------------------------------------ */
/* 5. B-pan restores the exact Q4 position, including mid-glide.      */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  ctx.clearActors();
  for (let x = 3; x < 12; x++) clearCell(ctx, x, 2);

  let midGlide = false;
  for (let i = 0; i < 240 && !midGlide; i++) {
    ctx.frame(['RIGHT']);
    const sx = ctx.byte('cam_scx');
    midGlide = ctx.byte('cam_goal_x') === 1 && sx > 0 && sx < 16;
  }
  check('caught the camera mid-glide', midGlide,
    `scx=${ctx.byte('cam_scx')} goal=${ctx.byte('cam_goal_x')}`);

  /* Freeze on B, then pan down and release. */
  for (let i = 0; i < 3; i++) ctx.frame(['B']);
  const frozenX = ctx.byte('cam_scx');
  const frozenY = ctx.byte('cam_scy');
  const frozenQx = ctx.u16('cam_qx');
  const frozenQy = ctx.u16('cam_qy');
  check('B freezes the glide', ctx.byte('cam_smooth') === 0,
    `smooth=${ctx.byte('cam_smooth')} scx=${frozenX}`);

  for (let i = 0; i < 40; i++) ctx.frame(['B', 'DOWN']);
  for (let i = 0; i < 4; i++) ctx.frame();
  check('pan release restores the exact horizontal Q4 position',
    ctx.byte('cam_scx') === frozenX && ctx.u16('cam_qx') === frozenQx,
    `scx=${ctx.byte('cam_scx')} want=${frozenX} q=${ctx.u16('cam_qx')} want=${frozenQx}`);
  check('pan release restores the exact vertical Q4 position',
    ctx.byte('cam_scy') === frozenY && ctx.u16('cam_qy') === frozenQy,
    `scy=${ctx.byte('cam_scy')} want=${frozenY} q=${ctx.u16('cam_qy')} want=${frozenQy}`);
}

/* ------------------------------------------------------------------ */
/* 6. Level starting with Robbo low: load-time snap and ring start.   */
/* ------------------------------------------------------------------ */
{
  const ctx = boot();
  const neutral = (() => {
    const bg = ctx.core.BGCHRBank1;
    const y = ctx.byte('robbo_y');
    const x = ctx.byte('robbo_x');
    return bg[(((y & 15) * 2) * 32 + x * 2) & 0x7ff];
  })();

  function warpOnce() {
    const before = ctx.byte('level_planet');
    for (let attempt = 0; attempt < 8 && ctx.byte('level_planet') === before; attempt++) {
      ctx.core.JoyPad = 0xff;
      ctx.gb.pressKeys(['SELECT']);
      ctx.gb.doFrame();
      ctx.core.JoyPad = 0xff;
      ctx.gb.doFrame();
      for (let i = 0; i < 20 && ctx.byte('level_planet') === before; i++) ctx.gb.doFrame();
    }
    for (let i = 0; i < 10; i++) ctx.gb.doFrame();
    for (let i = 0; i < 20 && ctx.byte('screws_left') !== ctx.byte('level_screw'); i++) {
      ctx.gb.doFrame();
    }
  }

  /* Level 4 has Robbo at (4,20), so the snapped camera base is 15. */
  for (let i = 0; i < 3; i++) warpOnce();
  for (let i = 0; i < 120; i++) ctx.gb.doFrame();
  check('warped to level 4', ctx.byte('level_planet') === 4,
    `level=${ctx.byte('level_planet')}`);
  check('low-start level snaps to the correct camera row',
    ctx.byte('robbo_y') === 20 && ctx.byte('cam_y') === 15 &&
    ctx.byte('cam_goal_y') === 15,
    `robbo_y=${ctx.byte('robbo_y')} cam_y=${ctx.byte('cam_y')} goal=${ctx.byte('cam_goal_y')}`);
  check('low-start level applies the wrapped pixel scroll',
    ctx.byte('cam_scy') === ((15 * 16) & 0xff),
    `scy=${ctx.byte('cam_scy')}`);

  const bg = ctx.core.BGCHRBank1;
  const tile = bg[(((20 & 15) * 2) * 32 + 4 * 2) & 0x7ff];
  check('low-start ring contains Robbo at his row',
    tile === neutral && ctx.byte('robbo_x') === 4,
    `tile=${tile} neutral=${neutral} robbo=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 19 passed');
process.exit(failures ? 1 : 0);
