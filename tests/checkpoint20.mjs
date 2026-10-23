#!/usr/bin/env node
/*
 * Checkpoint 20: projectile deaths and destroyed-tile audio.
 *
 * A projectile that destroys a demolishable cell must vanish without its own
 * perish animation; only the destroyed cell explodes.  Every non-bomb
 * demolition that shows the perish animation must also start the retained
 * DESTROY effect instead of the short SHOT IMPACT tick.
 *
 * Run: node gb/tests/checkpoint20.mjs
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
const CT_GROUND = 9;
const CT_QUESTION = 14;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;
const CT_TURRET = 18;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function fresh() {
  const gb = loadRom(rom);
  const core = gb[Object.keys(gb)[0]].gameboy;
  return { gb, core, mem: core.memory, byte: (name) => readMem(gb, S[name], 1)[0] };
}

function leftSamples(gb) {
  const buf = gb.getAudio();
  const out = [];
  if (!buf) return out;
  for (let i = 0; i < buf.length; i += 2) out.push(buf[i] + 1);
  return out;
}

function peak(samples) {
  let p = 0;
  for (const s of samples) {
    const a = Math.abs(s);
    if (a > p) p = a;
  }
  return p;
}

function setCell(ctx, x, y, type, ex = 0) {
  ctx.mem[S.map_type + y * 16 + x] = type;
  ctx.mem[S.map_extra + y * 16 + x] = ex;
  ctx.mem[S.map_obj + y * 16 + x] = 0;
}

/* Run past the boot fanfare and clear moving shooters so the only sound in the
 * measurement window is the event under test. */
function quietLevel() {
  const ctx = fresh();
  run(ctx.gb, 420);
  for (let i = 0; i < 16 * 31; i++) {
    const type = ctx.mem[S.map_type + i];
    if (type === CT_TURRET || type === CT_MUSTACHE || type === CT_BUTTERFLY ||
        type === CT_BEAR || type === CT_BULLET) {
      ctx.mem[S.map_type + i] = CT_EMPTY;
      ctx.mem[S.map_extra + i] = 0;
      ctx.mem[S.map_obj + i] = 0;
    }
  }
  for (let x = 3; x <= 9; x++) setCell(ctx, x, 2, CT_EMPTY);
  return ctx;
}

/* Fire one shot to the right.  Collect one audio buffer per frame and record
 * the frame where the target cell first becomes an explosion. */
function fireAt(ctx, targetX, targetType) {
  const ry = 2;
  const frames = [];
  let hit = -1;
  let previousAtHit = -1;
  let previousExploded = false;

  setCell(ctx, targetX, ry, targetType);
  ctx.mem[S.ammo] = 9;

  /* Hold the shot until the loop observes the ammo decrement.  The main loop
   * can miss a VBlank and skip a one-frame press. */
  let f = 0;
  while (f < 20 && ctx.mem[S.ammo] === 9) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(['RIGHT', 'A']);
    ctx.gb.doFrame();
    frames.push(leftSamples(ctx.gb));
    f++;
  }

  for (; f < 180; f++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.doFrame();
    frames.push(leftSamples(ctx.gb));

    if (hit < 0 && ctx.mem[S.map_type + ry * 16 + targetX] === CT_EXPLOSION) {
      hit = f;
      previousAtHit = ctx.mem[S.map_type + ry * 16 + targetX - 1];
    }
    if (hit >= 0 && f <= hit + 6 &&
        ctx.mem[S.map_type + ry * 16 + targetX - 1] === CT_EXPLOSION) {
      previousExploded = true;
    }
    /* Keep 30 frames after the hit: DESTROY runs for 32 frames, while the
     * old SHOT IMPACT tick is silent after 10. */
    if (hit >= 0 && f >= hit + 30) break;
  }

  return { frames, hit, ry, previousAtHit, previousExploded };
}

/* --- Ground shot: only the destroyed tile perishes, with DESTROY audio. --- */
{
  const ctx = quietLevel();
  const rx = ctx.byte('robbo_x');
  const targetX = rx + 6;
  const shot = fireAt(ctx, targetX, CT_GROUND);

  check('ground tile is destroyed on impact', shot.hit >= 0, `hit=${shot.hit}`);

  if (shot.hit >= 0) {
    const target = ctx.mem[S.map_type + shot.ry * 16 + targetX];
    check('destroyed tile shows the perish animation', target === CT_EXPLOSION,
      `cell=${target}`);
    check('projectile cell is empty on impact', shot.previousAtHit === CT_EMPTY,
      `previous=${shot.previousAtHit}`);
    check('projectile never shows a perish animation', !shot.previousExploded);

    const tail = shot.frames.slice(shot.hit + 20, shot.hit + 28).flat();
    check('destroyed tile plays the destroy sound', peak(tail) > 0.01,
      `peak=${peak(tail).toFixed(3)}`);
  }
}

/* --- Question shot: same rule, payload still spawns. --------------------- */
{
  const ctx = quietLevel();
  const rx = ctx.byte('robbo_x');
  const targetX = rx + 6;
  const shot = fireAt(ctx, targetX, CT_QUESTION);

  check('question is destroyed on impact', shot.hit >= 0, `hit=${shot.hit}`);

  if (shot.hit >= 0) {
    check('question projectile cell is empty on impact',
      shot.previousAtHit === CT_EMPTY, `previous=${shot.previousAtHit}`);
    check('question projectile never perishes', !shot.previousExploded);

    const tail = shot.frames.slice(shot.hit + 20, shot.hit + 28).flat();
    check('question plays the destroy sound', peak(tail) > 0.01,
      `peak=${peak(tail).toFixed(3)}`);
  }
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 20 passed');
process.exit(failures ? 1 : 0);
