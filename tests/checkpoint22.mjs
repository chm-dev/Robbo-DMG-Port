#!/usr/bin/env node
/*
 * Checkpoint 22: Atari/GBC ending sequence.
 *
 * - START+SELECT enters the ending from normal gameplay (debug test hook).
 * - The scene uses the starfield/ground tiles, the 0x1B scene palette and the
 *   sprite layer for Robbo (the port's only sprite user).
 * - The first message page fades in, keeps the animated pattern border and
 *   draws the authentic I.FNT glyphs.
 * - START advances to the second page; START again runs the closing window
 *   wipe and returns to the title, where START begins level 1.
 * - Completing the last planet takes the same ending path.
 *
 * Run: node gb/tests/checkpoint22.mjs
 */
import { loadRom, run, readMem, holdKey, tapKey } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo.gb');

function symbols() {
  const text = fs.readFileSync(path.join(root, 'roms', 'robbo.noi'), 'utf8');
  const map = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)$/);
    if (m) map[m[1]] = parseInt(m[2], 16);
  }
  return map;
}

const S = symbols();
const header = fs.readFileSync(path.join(root, 'gb', 'src', 'gen', 'ending_data.h'), 'utf8');
const E = {};
for (const m of header.matchAll(/#define (ENDING_[A-Z0-9_]+) (\d+)/g)) {
  E[m[1]] = Number(m[2]);
}

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const byte = (gb, name) => readMem(gb, S[name], 1)[0];
const lcdc = (gb) => readMem(gb, 0xFF40, 1)[0];
const bgp = (gb) => readMem(gb, 0xFF47, 1)[0];
const oam = (gb, i) => ({
  y: readMem(gb, 0xFE00 + i * 4, 1)[0],
  x: readMem(gb, 0xFE00 + i * 4 + 1, 1)[0],
  tile: readMem(gb, 0xFE00 + i * 4 + 2, 1)[0],
});

function coreOf(gb) {
  return gb[Object.keys(gb)[0]].gameboy;
}

/* BG map at 0x9800, window map at 0x9C00 (LCDC selects both). */
function tileAt(gb, x, y) {
  return coreOf(gb).BGCHRBank1[y * 32 + x];
}
function winAt(gb, x, y) {
  return coreOf(gb).BGCHRBank1[0x400 + y * 32 + x];
}

function waitFor(gb, fn, max) {
  for (let i = 0; i < max; i++) {
    if (fn()) return true;
    gb.doFrame();
  }
  return fn();
}

function waitBgp(gb, value, max) {
  return waitFor(gb, () => bgp(gb) === value, max);
}

function glyphTile(v) {
  return v >= E.ENDING_FONT && v < E.ENDING_FONT + E.ENDING_GLYPH_COUNT;
}

/* ------------------------------------------------------------------ */
/* Debug chord and scene                                               */
/* ------------------------------------------------------------------ */

const gb = loadRom(rom);
holdKey(gb, ['START', 'SELECT'], 2);
run(gb, 4);

check('START+SELECT starts the ending', byte(gb, 'ending_active') === 1,
  `active=${byte(gb, 'ending_active')}`);
check('ending starts on message page 0', byte(gb, 'ending_page') === 0,
  `page=${byte(gb, 'ending_page')}`);
check('scene uses the 0x1B palette', bgp(gb) === 0x1B,
  `BGP=0x${bgp(gb).toString(16)}`);
check('ending enables the sprite layer',
  waitFor(gb, () => (lcdc(gb) & 0x02) !== 0, 80),
  `LCDC=0x${lcdc(gb).toString(16)}`);
check('ending hides the HUD window', (lcdc(gb) & 0x20) === 0,
  `LCDC=0x${lcdc(gb).toString(16)}`);

/* Let draw_scene finish before inspecting the map. */
run(gb, 4);
check('starfield uses the star tile', tileAt(gb, 0, 0) === E.ENDING_STAR + 1,
  `tile=${tileAt(gb, 0, 0)}`);
check('sky uses the blank tile', tileAt(gb, 1, 0) === E.ENDING_BLANK_TILE,
  `tile=${tileAt(gb, 1, 0)}`);
check('ground row uses the ground tile',
  tileAt(gb, 0, E.ENDING_GROUND_ROW) === E.ENDING_GROUND,
  `tile=${tileAt(gb, 0, E.ENDING_GROUND_ROW)}`);

/* Sample Robbo while he walks in: the OAM x must take several values. */
const xs = new Set();
let robboY = 0;
for (let i = 0; i < 420; i++) {
  gb.doFrame();
  if ((i % 8) === 0) {
    const o = oam(gb, 0);
    if (o.y === 128 && o.x > 0) {
      xs.add(o.x);
      robboY = o.y;
    }
  }
}
check('Robbo sprite is on the ground row', robboY === 128, `y=${robboY}`);
check('Robbo sprite walks toward the ship', xs.size >= 4 && Math.max(...xs) > Math.min(...xs),
  `x=${[...xs].slice(0, 6).join(',')}...`);
check('Robbo uses the sprite tile block', oam(gb, 0).tile >= E.ENDING_SPRITE_BASE,
  `tile=${oam(gb, 0).tile}`);

/* ------------------------------------------------------------------ */
/* Message pages                                                       */
/* ------------------------------------------------------------------ */

check('first message page fades in', waitBgp(gb, 0xC4, 3200),
  `BGP=0x${bgp(gb).toString(16)}`);
check('still on page 0', byte(gb, 'ending_page') === 0,
  `page=${byte(gb, 'ending_page')}`);
check('text page hides sprites', (lcdc(gb) & 0x02) === 0,
  `LCDC=0x${lcdc(gb).toString(16)}`);

/* Let the random reveal fill every cell before checking the layout. */
run(gb, 320);
check('pattern border is drawn', tileAt(gb, 0, 0) === E.ENDING_PATTERN_TILE,
  `tile=${tileAt(gb, 0, 0)}`);
check('message glyphs are drawn', glyphTile(tileAt(gb, 1, 5)),
  `tile=${tileAt(gb, 1, 5)}, font=${E.ENDING_FONT}..${E.ENDING_FONT + E.ENDING_GLYPH_COUNT - 1}`);

holdKey(gb, 'START', 8);
check('START advances to page 1',
  waitFor(gb, () => byte(gb, 'ending_page') === 1, 200),
  `page=${byte(gb, 'ending_page')}`);
check('second message page fades in', waitBgp(gb, 0xC4, 400),
  `BGP=0x${bgp(gb).toString(16)}`);
run(gb, 320);
check('page 1 glyphs are drawn', glyphTile(tileAt(gb, 1, 2)),
  `tile=${tileAt(gb, 1, 2)}`);

holdKey(gb, 'START', 8);

let sawWipe = false;
let returned = false;
for (let i = 0; i < 1200; i++) {
  if ((lcdc(gb) & 0x20) && winAt(gb, 0, 0) === E.ENDING_WIPE_TILE) sawWipe = true;
  if (byte(gb, 'ending_active') === 0) {
    returned = true;
    break;
  }
  gb.doFrame();
}
check('closing wipe uses the window band', sawWipe);
check('ending returns after the wipe', returned,
  `active=${byte(gb, 'ending_active')}`);

run(gb, 200);
check('title hides the HUD window after the ending', (lcdc(gb) & 0x20) === 0,
  `LCDC=0x${lcdc(gb).toString(16)}`);
tapKey(gb, 'START', 8);
check('title START begins level 1',
  waitFor(gb, () => (lcdc(gb) & 0x20) !== 0, 400),
  `LCDC=0x${lcdc(gb).toString(16)}`);
check('ending restart loads level 1', byte(gb, 'level_planet') === 1,
  `level=${byte(gb, 'level_planet')}`);

/* ------------------------------------------------------------------ */
/* Last-planet path                                                    */
/* ------------------------------------------------------------------ */

const gbLast = loadRom(rom);
const coreLast = coreOf(gbLast);
coreLast.memory[S.level_planet] = 56;
coreLast.memory[S.game_level_advance_requested] = 1;
run(gbLast, 10);
check('finishing the last planet starts the ending',
  byte(gbLast, 'ending_active') === 1,
  `active=${byte(gbLast, 'ending_active')} level=${byte(gbLast, 'level_planet')}`);

console.log(failures === 0 ? 'Checkpoint 22 passed' : `Checkpoint 22 FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);
