#!/usr/bin/env node
/*
 * Checkpoint 6: teleport transfer, self-links, orphan fallback and link repair.
 *
 * Teleport cells and the destination table are injected into WRAM next to
 * Robbo; the real levels use the same generated table.
 *
 * Run: node gb/tests/checkpoint6.mjs
 */
import { loadRom, readMem } from '../tools/gb_harness.mjs';
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
const CT_BOMB = 15;
const CT_TELEPORT = 20;
const CT_EXPLOSION = 28;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function fresh() {
  const gb = loadRom(rom);
  const core = gb[Object.keys(gb)[0]].gameboy;
  const mem = core.memory;
  /* Wait out the ENTCV/WFAC spawn intro.  It keeps robbo_busy set, and the
   * teleport trigger below treats robbo_busy as "teleport started". */
  for (let i = 0; i < 700; i++) {
    core.JoyPad = 0xff;
    if (readMem(gb, S.intro_active, 1)[0] === 0 &&
        readMem(gb, S.robbo_busy, 1)[0] === 0) break;
    gb.doFrame();
  }
  return { gb, core, mem, byte: (name) => readMem(gb, S[name], 1)[0] };
}

function setCell(mem, x, y, type, extra = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = extra;
}

function setDest(mem, index, cell) {
  mem[S.teleport_dest + index * 2] = cell & 0xff;
  mem[S.teleport_dest + index * 2 + 1] = cell >> 8;
}

/* Three teleports in one group on row 2: A(3) -> B(7) -> C(10) -> A.
 * B's four neighbours are walled off unless the caller reopens one. */
function setupThreeWayGroup(ctx) {
  const A = 2 * 16 + 3;
  const B = 2 * 16 + 7;
  const C = 2 * 16 + 10;
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);
  setCell(ctx.mem, 7, 2, CT_TELEPORT, 1);
  setCell(ctx.mem, 10, 2, CT_TELEPORT, 2);
  setDest(ctx.mem, 0, B);
  setDest(ctx.mem, 1, C);
  setDest(ctx.mem, 2, A);
  ctx.mem[S.level_teleport_count] = 3;
  setCell(ctx.mem, 6, 2, CT_WALL, 0);
  setCell(ctx.mem, 8, 2, CT_WALL, 0);
  setCell(ctx.mem, 7, 1, CT_WALL, 0);
  setCell(ctx.mem, 7, 3, CT_WALL, 0);
  /* C's right neighbour is the first landing in Robbo's heading. */
  setCell(ctx.mem, 11, 2, CT_EMPTY, 0);
  return { A, B, C };
}

function triggerRight({ gb, core, byte }, maxFrames = 80) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT']);
    gb.doFrame();
    if (byte('robbo_busy')) return true;
  }
  return false;
}

function waitArrival({ gb, byte }, maxFrames = 400) {
  for (let i = 0; i < maxFrames; i++) {
    if (!byte('robbo_busy')) return true;
    gb.doFrame();
  }
  return false;
}

// --- Normal pair: A at (3,2) links to B at (7,2), arrive at (8,2). ---
{
  const ctx = fresh();
  const A = 2 * 16 + 3;
  const B = 2 * 16 + 7;
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);
  setCell(ctx.mem, 7, 2, CT_TELEPORT, 1);
  /* The Atari level 1 layout has a wall at (8,2); clear it so the arrival
   * search has the same open cell the test expects. */
  setCell(ctx.mem, 8, 2, CT_EMPTY, 0);
  setDest(ctx.mem, 0, B);
  setDest(ctx.mem, 1, A);
  ctx.mem[S.level_teleport_count] = 2;

  check('teleport starts', triggerRight(ctx), `busy=${ctx.byte('robbo_busy')}`);
  check('old cell becomes an effect',
    ctx.mem[S.map_type + 2 * 16 + 2] === CT_EXPLOSION,
    `type=${ctx.mem[S.map_type + 2 * 16 + 2]}`);
  check('camera target is at the destination',
    ctx.byte('cam_target_x') === 4 && ctx.byte('cam_target_y') === 0,
    `target=${ctx.byte('cam_target_x')},${ctx.byte('cam_target_y')}`);
  check('arrival completes', waitArrival(ctx), `busy=${ctx.byte('robbo_busy')}`);
  check('arrived beside linked teleport',
    ctx.byte('robbo_x') === 8 && ctx.byte('robbo_y') === 2,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
  check('camera moved to destination before arrival',
    ctx.byte('cam_x') === 4 && ctx.byte('cam_y') === 0,
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')}`);
  for (let i = 0; i < 30; i++) ctx.gb.doFrame();
  check('camera holds the arrival view (no snap-back drift)',
    ctx.byte('cam_x') === 4 && ctx.byte('cam_y') === 0 &&
    ctx.byte('cam_goal_x') === 4 && ctx.byte('cam_goal_y') === 0,
    `cam=${ctx.byte('cam_x')},${ctx.byte('cam_y')} goal=${ctx.byte('cam_goal_x')},${ctx.byte('cam_goal_y')}`);
  check('arrival cell is Robbo',
    ctx.mem[S.map_type + 2 * 16 + 8] === 26,
    `type=${ctx.mem[S.map_type + 2 * 16 + 8]}`);
  check('old cell is empty',
    ctx.mem[S.map_type + 2 * 16 + 2] === CT_EMPTY,
    `type=${ctx.mem[S.map_type + 2 * 16 + 2]}`);
  check('teleport cells remain',
    ctx.mem[S.map_type + A] === CT_TELEPORT && ctx.mem[S.map_type + B] === CT_TELEPORT,
    `A=${ctx.mem[S.map_type + A]} B=${ctx.mem[S.map_type + B]}`);
}

// --- Self-link: a lone teleport sends Robbo to an adjacent empty cell. ---
{
  const ctx = fresh();
  const A = 2 * 16 + 3;
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);
  setDest(ctx.mem, 0, A);
  ctx.mem[S.level_teleport_count] = 1;

  check('self-link teleport starts', triggerRight(ctx));
  check('self-link arrival completes', waitArrival(ctx));
  check('self-link finds an adjacent empty cell',
    ctx.byte('robbo_x') === 3 && ctx.byte('robbo_y') === 1,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- Self-link with no free neighbour (Atari L7): teleport in place. ---
{
  const ctx = fresh();
  const A = 2 * 16 + 3;
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);
  setDest(ctx.mem, 0, A);
  ctx.mem[S.level_teleport_count] = 1;
  /* The only non-wall neighbour is the cell Robbo came from. */
  setCell(ctx.mem, 4, 2, CT_WALL, 0);
  setCell(ctx.mem, 3, 1, CT_WALL, 0);
  setCell(ctx.mem, 3, 3, CT_WALL, 0);

  check('isolated self-link teleport starts', triggerRight(ctx),
    `busy=${ctx.byte('robbo_busy')}`);
  check('isolated self-link arrival completes', waitArrival(ctx));
  check('isolated self-link teleports in place',
    ctx.byte('robbo_x') === 2 && ctx.byte('robbo_y') === 2,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
  check('isolated self-link keeps the teleport cell',
    ctx.mem[S.map_type + A] === CT_TELEPORT,
    `type=${ctx.mem[S.map_type + A]}`);
}

// --- Blocked destination: skip to the next teleport of the group. ---
{
  const ctx = fresh();
  setupThreeWayGroup(ctx);
  check('blocked-destination teleport starts', triggerRight(ctx),
    `busy=${ctx.byte('robbo_busy')}`);
  check('blocked-destination arrival completes', waitArrival(ctx));
  check('blocked destination skips to the next group member',
    ctx.byte('robbo_x') === 11 && ctx.byte('robbo_y') === 2,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- Once the primary destination is free it takes priority again. ---
{
  const ctx = fresh();
  setupThreeWayGroup(ctx);
  setCell(ctx.mem, 8, 2, CT_EMPTY, 0);
  check('freed-destination teleport starts', triggerRight(ctx),
    `busy=${ctx.byte('robbo_busy')}`);
  check('freed-destination arrival completes', waitArrival(ctx));
  check('primary destination is used once it is free',
    ctx.byte('robbo_x') === 8 && ctx.byte('robbo_y') === 2,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- Orphan destination: fall back to the entry teleport. ---
{
  const ctx = fresh();
  const A = 2 * 16 + 3;
  const orphan = 3 * 16 + 6;  // empty, not a teleport
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);
  setDest(ctx.mem, 0, orphan);
  ctx.mem[S.level_teleport_count] = 1;

  check('orphan-link teleport starts', triggerRight(ctx));
  check('orphan-link arrival completes', waitArrival(ctx));
  check('orphan link falls back to entry side',
    ctx.byte('robbo_x') === 3 && ctx.byte('robbo_y') === 1,
    `pos=${ctx.byte('robbo_x')},${ctx.byte('robbo_y')}`);
}

// --- Destroying a teleport retargets teleports that linked to it. ---
{
  const ctx = fresh();
  const A = 2 * 16 + 3;
  const B = 2 * 16 + 7;
  const C = 2 * 16 + 10;
  setCell(ctx.mem, 3, 2, CT_TELEPORT, 0);   // links to B
  setCell(ctx.mem, 7, 2, CT_TELEPORT, 0);   // self-ish
  setCell(ctx.mem, 10, 2, CT_TELEPORT, 1);  // links to A
  setDest(ctx.mem, 0, B);
  setDest(ctx.mem, 1, A);
  ctx.mem[S.level_teleport_count] = 2;

  // Bomb directly above Robbo; its 3x3 blast catches A at (3,2).
  setCell(ctx.mem, 2, 1, CT_BOMB, 0);
  ctx.mem[S.ammo] = 9;
  for (let i = 0; i < 20; i++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(['UP', 'A']);
    ctx.gb.doFrame();
  }
  for (let i = 0; i < 200; i++) {
    if (ctx.mem[S.map_type + A] === CT_EXPLOSION ||
        ctx.mem[S.map_type + A] === CT_EMPTY) break;
    ctx.gb.doFrame();
  }
  check('blast destroyed teleport A',
    ctx.mem[S.map_type + A] !== CT_TELEPORT,
    `type=${ctx.mem[S.map_type + A]}`);
  check('teleport C was retargeted to B',
    readMem(ctx.gb, S.teleport_dest + 1 * 2, 1)[0] === (B & 0xff) &&
    readMem(ctx.gb, S.teleport_dest + 1 * 2 + 1, 1)[0] === (B >> 8),
    `dest=${readMem(ctx.gb, S.teleport_dest + 1 * 2, 2).join(',')}`);
}

// --- Teleport frames swap every other logic tick, not every tick. ---
{
  const ctx = fresh();
  const bgmap = ctx.core.BGCHRBank1;
  // Use the first real level-1 teleport; the Atari layout has one at (6,2).
  let tx = 0;
  while (tx < 16 && ctx.mem[S.map_type + 2 * 16 + tx] !== CT_TELEPORT) tx++;
  const addr = (0x9800 + 4 * 32 + tx * 2) & 0x7ff;
  let tile = bgmap[addr];
  let slow = ctx.byte('anim_slow');
  let tileChanges = 0;
  let slowChanges = 0;
  const seen = new Set([tile]);

  for (let i = 0; i < 600; i++) {
    ctx.gb.doFrame();
    if (bgmap[addr] !== tile) {
      tile = bgmap[addr];
      tileChanges++;
      seen.add(tile);
    }
    const nextSlow = ctx.byte('anim_slow');
    if (nextSlow !== slow) {
      slow = nextSlow;
      slowChanges++;
    }
  }

  check('teleport animates between two frames', seen.size === 2,
    `tiles=${[...seen].join(',')}`);
  check('teleport swaps at the half-rate clock',
    slowChanges >= 4 && Math.abs(tileChanges - slowChanges) <= 1,
    `tileChanges=${tileChanges} slowChanges=${slowChanges}`);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 6 passed');
process.exit(failures ? 1 : 0);
