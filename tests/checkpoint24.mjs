#!/usr/bin/env node
/*
 * Checkpoint 24: palette-dependent object tile variants.
 *
 * - Level 2 (dark gray floor): projectiles use the alternate (white) tile.
 * - Level 3 (black floor): baddies use the brighter tile.
 * - Level 4 (white floor): projectiles use the alternate (darker) tile.
 * - Level 1 and non-matching levels keep the base tiles.
 *
 * The transition checks exercise the VBlank-chunked upload used while the
 * display stays on during a level-complete intro.
 *
 * Run: node gb/tests/checkpoint24.mjs
 */
import { loadRom, run, readMem } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo.gb');
const romBytes = fs.readFileSync(rom);

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
const CT_SPACESHIP = 13;
const MAP_CELLS = 16 * 31;
const BULLET_TILE = 78;
const BADDIE_TILE = 86;
const BEAR_TILE = 134;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

/* .noi addresses for banked symbols encode bank * 0x10000 + CPU address. */
function fileOffset(addr) {
  const bank = Math.floor(addr / 0x10000);
  const cpu = addr & 0xffff;
  return bank === 0 ? cpu : bank * 0x4000 + (cpu - 0x4000);
}
function symbolBytes(name, offset, length) {
  const start = fileOffset(S[name]) + offset;
  return Array.from(romBytes.subarray(start, start + length));
}
function same(a, b) {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

const gb = loadRom(rom);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const bgp = () => readMem(gb, 0xFF47, 1)[0];
const vramTile = (n) => readMem(gb, 0x8000 + n * 16, 16);
const isBase = (tile) =>
  same(vramTile(tile), symbolBytes('tileset_data', tile * 16, 16));
const isVariant = (symbol, tile, base) =>
  same(vramTile(tile), symbolBytes(symbol, (tile - base) * 16, 16));

function setCell(x, y, type, ex = 0) {
  mem[S.map_type + y * 16 + x] = type;
  mem[S.map_extra + y * 16 + x] = ex;
  mem[S.map_obj + y * 16 + x] = 0;
}
function clearActors() {
  for (let i = 0; i < MAP_CELLS; i++) {
    const type = mem[S.map_type + i];
    if (type === 18 || type === 21 || type === 22 || type === 23 || type === 27 ||
        type === 15 || type === 28) {
      mem[S.map_type + i] = CT_EMPTY;
      mem[S.map_extra + i] = 0;
      mem[S.map_obj + i] = 0;
    }
  }
}
function frame() {
  core.JoyPad = 0xff;
  gb.doFrame();
}
function waitFor(predicate, maxFrames = 800) {
  for (let i = 0; i < maxFrames; i++) {
    if (predicate()) return true;
    frame();
  }
  return false;
}

/* Complete the current level by opening a capsule next to Robbo. */
function advance() {
  clearActors();
  const x = byte('robbo_x');
  const y = byte('robbo_y');
  const dir = x < 15 ? 1 : -1;
  const key = dir > 0 ? 'RIGHT' : 'LEFT';
  setCell(x + dir, y, CT_SPACESHIP, 0);
  mem[S.screws_left] = 0;

  let started = false;
  for (let i = 0; i < 400; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys([key]);
    gb.doFrame();
    if (byte('game_transition_active')) { started = true; break; }
  }
  core.JoyPad = 0xff;
  if (!started) return false;

  while (byte('game_transition_active')) frame();
  const target = byte('level_planet') + 1;
  if (!waitFor(() => byte('level_planet') === target, 300)) return false;
  if (!waitFor(() => byte('intro_active') !== 0, 400)) return false;
  return waitFor(() => byte('intro_active') === 0 && byte('robbo_busy') === 0, 1200);
}

waitFor(() => byte('intro_active') === 0 && byte('robbo_busy') === 0, 400);

check('L1 palette normal', bgp() === 0xE4, `bgp=0x${bgp().toString(16)}`);
check('L1 projectiles base', isBase(BULLET_TILE));
check('L1 baddies base', isBase(BADDIE_TILE));
check('L1 bears base', isBase(BEAR_TILE));

check('advanced to L2', advance() && byte('level_planet') === 2,
  `level=${byte('level_planet')}`);
check('L2 palette dark gray', bgp() === 0xC9, `bgp=0x${bgp().toString(16)}`);
check('L2 projectiles alternate (white)',
  isVariant('bullet_variant_tiles', BULLET_TILE, BULLET_TILE));
check('L2 baddies base', isBase(BADDIE_TILE));

check('advanced to L3', advance() && byte('level_planet') === 3,
  `level=${byte('level_planet')}`);
check('L3 palette black', bgp() === 0x9C, `bgp=0x${bgp().toString(16)}`);
check('L3 projectiles base', isBase(BULLET_TILE));
check('L3 baddies brighter',
  isVariant('baddie_variant_tiles', BADDIE_TILE, BADDIE_TILE));
check('L3 bat/butterfly brighter',
  isVariant('baddie_variant_tiles', 94, BADDIE_TILE));
check('L3 bears brighter',
  isVariant('bear_variant_tiles', BEAR_TILE, BEAR_TILE));
check('L3 bear second frame brighter',
  isVariant('bear_variant_tiles', 142, BEAR_TILE));

check('advanced to L4', advance() && byte('level_planet') === 4,
  `level=${byte('level_planet')}`);
check('L4 palette white', bgp() === 0xE1, `bgp=0x${bgp().toString(16)}`);
check('L4 projectiles alternate (darker)',
  isVariant('bullet_variant_tiles', BULLET_TILE, BULLET_TILE));
check('L4 baddies base', isBase(BADDIE_TILE));
check('L4 bears base', isBase(BEAR_TILE));

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 24 passed');
process.exit(failures ? 1 : 0);
