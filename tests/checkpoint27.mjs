#!/usr/bin/env node
/*
 * Checkpoint 27: release/debug ROM split.
 *
 * - Both ROMs are produced with the same MBC5 + 128 KiB RAM header.
 * - roms/robbo.gb (release) ignores Select: no level warp, and holding it
 *   neither freezes gameplay logic nor movement.  The START+SELECT ending
 *   preview is compiled out as well.
 * - roms/robbo-debug.gb (debug, -DDEBUG_STATE) warps to the next planet on
 *   Select and keeps the START+SELECT ending preview.
 *
 * Run: node gb/tests/checkpoint27.mjs
 */
import { loadRom, readMem, holdKey, run } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const romDir = path.join(root, 'roms');
const releaseRom = path.join(romDir, 'robbo.gb');
const debugRom = path.join(romDir, 'robbo-debug.gb');

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function symbols(noiName) {
  const text = fs.readFileSync(path.join(romDir, noiName), 'utf8');
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
    if (m) map[m[1]] = parseInt(m[2], 16);
  }
  return map;
}

function header(file) {
  const bytes = fs.readFileSync(file);
  return {
    cgb: bytes[0x143],
    cart: bytes[0x147],
    ram: bytes[0x149],
    size: bytes.length,
  };
}

for (const [label, file] of [['release', releaseRom], ['debug', debugRom]]) {
  check(`${label} ROM exists`, fs.existsSync(file), file);
  if (!fs.existsSync(file)) continue;
  const h = header(file);
  check(`${label} ROM is CGB-compatible`, h.cgb === 0x80, `0x143=${h.cgb}`);
  check(`${label} ROM is MBC5+RAM`, h.cart === 0x1b, `0x147=${h.cart}`);
  check(`${label} ROM declares 128 KiB RAM`, h.ram === 0x04, `0x149=${h.ram}`);
  check(`${label} ROM is 16 banks`, h.size === 0x40000, `${h.size} bytes`);
}

/* The main loop can miss VBlanks during a level load, so hold/poll instead of
 * assuming one frame per iteration.  Stops as soon as level_planet changes. */
function warpOnce(gb, byte, keys = ['SELECT']) {
  const core = gb[Object.keys(gb)[0]].gameboy;
  const before = byte('level_planet');
  for (let attempt = 0; attempt < 8 && byte('level_planet') === before; attempt++) {
    core.JoyPad = 0xff;
    gb.pressKeys(keys);
    gb.doFrame();
    core.JoyPad = 0xff;
    gb.doFrame();
    for (let i = 0; i < 20 && byte('level_planet') === before; i++) gb.doFrame();
  }
  for (let i = 0; i < 10; i++) gb.doFrame();
  return byte('level_planet') !== before;
}

/* ------------------------------------------------------------------ */
/* Release ROM: Select must be completely inert.                       */
/* ------------------------------------------------------------------ */
{
  const gb = loadRom(releaseRom);
  const S = symbols('robbo.noi');
  const byte = (name) => readMem(gb, S[name], 1)[0];

  run(gb, 120);
  check('release starts on planet 1', byte('level_planet') === 1,
    `level=${byte('level_planet')}`);

  const tapped = [];
  for (let i = 0; i < 3; i++) {
    holdKey(gb, 'SELECT', 2);
    run(gb, 30);
    tapped.push(byte('level_planet'));
  }
  check('release Select does not warp', tapped.every(v => v === 1), `levels=${tapped}`);

  /* Level 1 starts Robbo at (2,2) with open space to the left.  Holding
   * Select used to gate the whole input/logic block; the release ROM must
   * ignore it and keep moving. */
  const startX = byte('robbo_x');
  holdKey(gb, ['SELECT', 'LEFT'], 30);
  check('release Select does not freeze movement', byte('robbo_x') < startX,
    `x=${byte('robbo_x')} start=${startX}`);
  check('release still on planet 1 after Select+LEFT', byte('level_planet') === 1,
    `level=${byte('level_planet')}`);

  /* START+SELECT is a debug-only test hook; the release ROM must not jump to
   * the ending.  START keeps its normal pause-menu behavior. */
  holdKey(gb, ['START', 'SELECT'], 2);
  run(gb, 30);
  check('release START+SELECT does not preview the ending', byte('ending_active') === 0,
    `active=${byte('ending_active')}`);
}

/* ------------------------------------------------------------------ */
/* Debug ROM: Select warps.                                            */
/* ------------------------------------------------------------------ */
{
  const gb = loadRom(debugRom);
  const S = symbols('robbo-debug.noi');
  const byte = (name) => readMem(gb, S[name], 1)[0];

  run(gb, 120);
  check('debug starts on planet 1', byte('level_planet') === 1,
    `level=${byte('level_planet')}`);
  check('debug Select warps to planet 2', warpOnce(gb, byte),
    `level=${byte('level_planet')}`);
}

console.log(failures ? `\n${failures} check(s) failed` : '\nall checks passed');
process.exit(failures ? 1 : 0);
