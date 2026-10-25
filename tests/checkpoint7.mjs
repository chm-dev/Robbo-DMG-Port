#!/usr/bin/env node
/*
 * Checkpoint 7: turret (cannon) logic.
 *
 * Covers firing, bullet owner/type, turret movement/rotation and the enemy
 * projectile -> Robbo death/restart path. Turrets from the level are cleared
 * first so the injected test cannon is the only actor.
 *
 * Run: node gb/tests/checkpoint7.mjs
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
const CT_TURRET = 18;
const CT_BULLET = 27;
const CT_EXPLOSION = 28;

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

function countType(mem, type) {
  let n = 0;
  for (let i = 0; i < 16 * 31; i++) if (mem[S.map_type + i] === type) n++;
  return n;
}

function clearTurretsAndBullets(mem) {
  for (let i = 0; i < 16 * 31; i++) {
    if (mem[S.map_type + i] === CT_TURRET || mem[S.map_type + i] === CT_BULLET) {
      mem[S.map_type + i] = CT_EMPTY;
      mem[S.map_extra + i] = 0;
      mem[S.map_obj + i] = 0;
    }
  }
}

function scanBullets(mem, wantOwner = null) {
  const out = [];
  for (let i = 0; i < 16 * 31; i++) {
    if (mem[S.map_type + i] === CT_BULLET) {
      const extra = mem[S.map_extra + i];
      const owner = (extra >> 4) & 1;
      if (wantOwner === null || owner === wantOwner) {
        out.push({ x: i % 16, y: Math.floor(i / 16), extra, owner, type: (extra >> 2) & 3 });
      }
    }
  }
  return out;
}

function waitFor(ctx, predicate, maxFrames = 3000) {
  for (let i = 0; i < maxFrames; i++) {
    if (predicate(i)) return true;
    ctx.gb.doFrame();
  }
  return false;
}

// --- Gun turret fires at Robbo; enemy bullet kills and restarts. ---
{
  const ctx = fresh();
  clearTurretsAndBullets(ctx.mem);
  setCell(ctx.mem, 3, 2, CT_EMPTY, 0);
  setCell(ctx.mem, 4, 2, CT_TURRET, 2);  // facing left, gun

  let sawEnemyBullet = false;
  const fired = waitFor(ctx, () => {
    if (scanBullets(ctx.mem, 1).length) sawEnemyBullet = true;
    return sawEnemyBullet || ctx.byte('robbo_busy');
  });
  check('turret fires', fired, `busy=${ctx.byte('robbo_busy')}`);
  check('turret bullet belongs to enemy', sawEnemyBullet ||
    scanBullets(ctx.mem, 1).length > 0);
  check('turret bullet hit Robbo', waitFor(ctx, () => ctx.byte('robbo_busy'), 3000),
    `busy=${ctx.byte('robbo_busy')}`);

  /* game_restart_requested is an internal one-frame pulse that the main loop
   * consumes before the frame ends, so a frame-stepping harness cannot observe
   * it.  Check the observable Atari ZYTY wipe instead: after the death delay
   * every non-wall cell becomes an explosion before the level reloads. */
  let peakExplosions = 0;
  const sawWipe = waitFor(ctx, () => {
    const n = countType(ctx.mem, CT_EXPLOSION);
    if (n > peakExplosions) peakExplosions = n;
    return n > 20;
  }, 1000);
  check('death starts the room wipe', sawWipe,
    `explosions=${peakExplosions}`);
  /* The restart now runs the level-entry intro: repaint, then pan back to the
   * start and materialize Robbo.  Poll instead of assuming a fixed delay. */
  check('level restarted after death',
    waitFor(ctx, () => ctx.byte('robbo_busy') === 0 &&
      ctx.byte('level_planet') === 1 &&
      ctx.byte('robbo_x') === 2 && ctx.byte('robbo_y') === 2, 800),
    `busy=${ctx.byte('robbo_busy')} level=${ctx.byte('level_planet')} pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- Movable turret steps one cell every other tick. ---
{
  const ctx = fresh();
  clearTurretsAndBullets(ctx.mem);
  setCell(ctx.mem, 3, 2, CT_TURRET, 0x40);  // movable, move right, gun
  setCell(ctx.mem, 4, 2, CT_EMPTY, 0);
  let sawAt3 = false, sawAt4 = false;
  for (let i = 0; i < 1200; i++) {
    ctx.gb.doFrame();
    if (ctx.mem[S.map_type + 2 * 16 + 3] === CT_TURRET) sawAt3 = true;
    if (ctx.mem[S.map_type + 2 * 16 + 4] === CT_TURRET) sawAt4 = true;
    if (sawAt3 && sawAt4) break;
  }
  check('movable turret moves', sawAt3 && sawAt4,
    `x3=${sawAt3} x4=${sawAt4}`);
}

// --- Rotatable turret changes direction. ---
{
  const ctx = fresh();
  clearTurretsAndBullets(ctx.mem);
  setCell(ctx.mem, 1, 1, CT_TURRET, 0x80);  // rotatable, facing right
  let changed = false;
  for (let i = 0; i < 2500; i++) {
    ctx.gb.doFrame();
    if ((ctx.mem[S.map_extra + 1 * 16 + 1] & 3) !== 0) {
      changed = true;
      break;
    }
  }
  check('rotatable turret changes direction', changed,
    `dir=${ctx.mem[S.map_extra + 1 * 16 + 1] & 3}`);
}

// --- Bullet type is carried from the turret config. ---
for (const [name, type] of [['laser', 1], ['antimatter', 2]]) {
  const ctx = fresh();
  clearTurretsAndBullets(ctx.mem);
  setCell(ctx.mem, 1, 1, CT_TURRET, (type << 4));  // facing right, selected type
  let seen = null;
  for (let i = 0; i < 3000; i++) {
    ctx.gb.doFrame();
    const bullets = scanBullets(ctx.mem, 1);
    if (bullets.length) {
      seen = bullets[0];
      break;
    }
  }
  check(`${name} bullet type`, seen !== null && seen.type === type,
    seen ? `type=${seen.type}` : 'no bullet');
}

// --- Laser beam extends and retracts instead of moving as a single tile. ---
{
  const ctx = fresh();
  clearTurretsAndBullets(ctx.mem);
  setCell(ctx.mem, 1, 1, CT_TURRET, (1 << 4));  // laser, facing right
  let maxSegments = 0;
  let extended = false;
  let retracted = false;
  for (let i = 0; i < 4000; i++) {
    ctx.gb.doFrame();
    let segments = 0;
    for (let x = 0; x < 16; x++) {
      if (ctx.mem[S.map_type + 1 * 16 + x] === CT_BULLET) segments++;
    }
    if (segments > maxSegments) maxSegments = segments;
    if (segments > 1) extended = true;
    if (extended && segments === 0) {
      retracted = true;
      break;
    }
  }
  check('laser beam extends', extended, `max=${maxSegments}`);
  check('laser beam retracts', retracted, `max=${maxSegments}`);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 7 passed');
process.exit(failures ? 1 : 0);
