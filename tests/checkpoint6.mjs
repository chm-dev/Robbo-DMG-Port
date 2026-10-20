#!/usr/bin/env node
/*
 * Checkpoint 6: teleport transfer, self-links, orphan fallback and link repair.
 *
 * Teleport cells and the destination table are injected into WRAM next to
 * Robbo; the real levels use the same generated table.
 *
 * Run: node gb/tests/checkpoint6.mjs
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
  run(gb, 150);
  const core = gb[Object.keys(gb)[0]].gameboy;
  const mem = core.memory;
  const byte = (name) => readMem(gb, S[name], 1)[0];
  return { gb, core, mem, byte };
}

function setCell(mem, x, y, type, extra = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = extra;
}

function setDest(mem, index, cell) {
  mem[S.teleport_dest + index * 2] = cell & 0xff;
  mem[S.teleport_dest + index * 2 + 1] = cell >> 8;
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

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 6 passed');
process.exit(failures ? 1 : 0);
