#!/usr/bin/env node
/*
 * Checkpoint 25: in-game pause menu overlay.
 *
 * - START opens a compact 15x9 BG overlay in the middle of the playfield;
 *   the HUD window stays visible at the bottom.
 * - The menu has WARP TO <level>, RESTART and EXIT TO MENU.  The warp level
 *   defaults to the current planet.
 * - Up/down moves the cursor; left/right changes the warp level on WARP.
 * - Only A activates an item.  START or B closes the menu and resumes.
 * - Closing rebuilds the covered playfield tiles exactly.
 * - WARP loads the selected planet, RESTART runs the normal death/respawn
 *   sequence on the same planet, and EXIT returns to the title.
 *
 * Run: node gb/tests/checkpoint25.mjs
 */
import { loadRom, readMem, holdKey, tapKey } from '../tools/gb_harness.mjs';
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
const CT_EXPLOSION = 28;

/* Valid external-RAM record with saved highest level = level. */
function makeSave(level) {
  const ram = new Uint8Array(0x20000);
  ram[0] = 0x52; ram[1] = 0x42; ram[2] = 0x42; ram[3] = 0x4f;
  ram[4] = 1;
  ram[5] = level;
  ram[6] = level ^ 1 ^ 0x3c;
  ram[7] = 0xa5;
  return ram;
}
/* Keep in sync with gb/src/gb/screens.c. */
const MENU_W = 15;
const MENU_H = 9;
const MENU_SCREEN_X = 24;
const MENU_SCREEN_Y = 20;
const PAUSE_STATE_CLOSED = 0;
const PAUSE_STATE_READY = 2;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

/* The pause warp range is 1..saved level now, so start with a level-2 save
 * and use the title menu to begin on level 1. */
const gb = loadRom(rom, makeSave(2), { skipTitle: true });
const core = gb[Object.keys(gb)[0]].gameboy;
const byte = (name) => readMem(gb, S[name], 1)[0];
const lcdc = () => readMem(gb, 0xFF40, 1)[0];

/* font_tiles lives in bank 0; map tile ids back to characters so the menu
 * layout can be asserted without hard-coding generated tile numbers. */
const font = readMem(gb, S.font_tiles, 128);
const hudBg = byte('hud_bg_tile');
function tileChar(tile) {
  for (let i = 0; i < 128; i++) {
    if (font[i] === tile) return String.fromCharCode(i);
  }
  return tile === hudBg ? ' ' : '?';
}
function bgTile(x, y) {
  return core.BGCHRBank1[y * 32 + x];
}
function winTile(x, y) {
  return core.BGCHRBank1[0x400 + y * 32 + x];
}
function menuRow(row) {
  let out = '';
  for (let x = 0; x < MENU_W; x++) {
    out += tileChar(bgTile(byte('pause_menu_bg_x') + x,
                           byte('pause_menu_bg_y') + row));
  }
  return out;
}
function captureMenuRect() {
  const bx = byte('pause_menu_bg_x');
  const by = byte('pause_menu_bg_y');
  const out = [];
  for (let y = 0; y < MENU_H; y++) {
    for (let x = 0; x < MENU_W; x++) out.push(bgTile(bx + x, by + y));
  }
  return out;
}
function sameMenuRect(snapshot) {
  const now = captureMenuRect();
  if (now.length !== snapshot.length) return false;
  for (let i = 0; i < now.length; i++) {
    if (now[i] !== snapshot[i]) return false;
  }
  return true;
}

function waitFor(fn, max) {
  for (let i = 0; i < max; i++) {
    if (fn()) return true;
    gb.doFrame();
  }
  return fn();
}

function waitForTitle() {
  core.JoyPad = 0xff;
  for (let i = 0; i < 200; i++) {
    if ((lcdc() & 0x80) === 0) break;
    gb.doFrame();
  }
  for (let i = 0; i < 300; i++) {
    const l = lcdc();
    if ((l & 0x80) && (l & 0x01) && !(l & 0x20)) break;
    gb.doFrame();
  }
}

function levelSettled(level) {
  return byte('level_planet') === level &&
    byte('intro_active') === 0 &&
    byte('robbo_busy') === 0 &&
    byte('screws_left') === byte('level_screw') &&
    (lcdc() & 0x80) !== 0 &&
    core.windowY === 128;
}

function waitLevel(level) {
  return waitFor(() => levelSettled(level), 1600);
}

function waitLevelAfterLoad(level) {
  if (!waitFor(() => byte('intro_active') === 1, 1600)) return false;
  return waitFor(() => levelSettled(level), 1600);
}

function menuReady() {
  return byte('pause_menu_state') === PAUSE_STATE_READY;
}

function openMenu() {
  holdKey(gb, 'START', 6);
  return waitFor(menuReady, 80);
}

function closeMenuWith(key) {
  holdKey(gb, key, 6);
  return waitFor(() => byte('pause_menu_state') === PAUSE_STATE_CLOSED, 80);
}

function levelDigits() {
  return menuRow(3).slice(11, 13);
}

/* Menu input needs a longer hold and a release gap than gameplay taps:
 * serverboy can miss short input edges across frame boundaries. */
function menuPress(key) {
  holdKey(gb, key, 6);
  runFrames(6);
}

/* ------------------------------------------------------------------ */
/* Boot and layout                                                     */
/* ------------------------------------------------------------------ */

/* With save=2 the title opens its start-level menu.  Lower it to 1 and
 * begin there so the original warp/restart/exit checks still apply. */
waitForTitle();
runFrames(40);
holdKey(gb, 'START', 6);
runFrames(15);
holdKey(gb, 'LEFT', 6);
runFrames(10);
holdKey(gb, 'A', 6);

check('level 1 settles before the pause test', waitLevel(1), `level=${byte('level_planet')}`);
const camX = byte('cam_scx');
const camY = byte('cam_scy');
const expectBx = (camX + MENU_SCREEN_X) >> 3;
const expectBy = (camY + MENU_SCREEN_Y) >> 3;

check('HUD window is at the bottom in gameplay', core.windowY === 128,
  `y=${core.windowY}`);
const hudBefore = [];
for (let x = 0; x < 20; x++) hudBefore.push(winTile(x, 0));
/* Snapshot the tiles the panel will cover and the tiles just outside it, so
 * closing can be checked against the real playfield. */
const menuBefore = [];
for (let y = 0; y < MENU_H; y++) {
  for (let x = 0; x < MENU_W; x++) {
    menuBefore.push(bgTile(expectBx + x, expectBy + y));
  }
}
const outsideBefore = {
  left: bgTile(expectBx - 1, expectBy + 3),
  right: bgTile(expectBx + MENU_W, expectBy + 3),
  bottom: bgTile(expectBx + 3, expectBy + MENU_H),
};

check('START opens the pause menu', openMenu(),
  `state=${byte('pause_menu_state')}`);
check('menu is a compact BG overlay',
  byte('pause_menu_bg_x') === expectBx && byte('pause_menu_bg_y') === expectBy,
  `bg=${byte('pause_menu_bg_x')},${byte('pause_menu_bg_y')} expected=${expectBx},${expectBy}`);

const menuScreenX = byte('pause_menu_bg_x') * 8 - camX;
const menuScreenY = byte('pause_menu_bg_y') * 8 - camY;
check('menu does not span the full width',
  menuScreenX > 0 && menuScreenX + MENU_W * 8 < 160,
  `x=${menuScreenX}..${menuScreenX + MENU_W * 8}`);
check('menu ends above the HUD', menuScreenY > 0 &&
  menuScreenY + MENU_H * 8 <= 128,
  `y=${menuScreenY}..${menuScreenY + MENU_H * 8}`);
check('HUD stays visible while paused',
  core.windowY === 128 && core.gfxWindowDisplay === true,
  `y=${core.windowY} display=${core.gfxWindowDisplay}`);
let hudSame = true;
for (let x = 0; x < 20; x++) {
  if (winTile(x, 0) !== hudBefore[x]) hudSame = false;
}
check('pause does not disturb the HUD window', hudSame);

check('menu has no rule dashes', !menuRow(0).includes('-') &&
  !menuRow(8).includes('-'), `${JSON.stringify(menuRow(0))}`);
check('menu title is PAUSED', menuRow(1).includes('PAUSED'), menuRow(1));
check('WARP row defaults to the current level',
  menuRow(3) === `> WARP TO <${levelDigits()}> ` &&
  levelDigits() === `0${byte('level_planet')}`,
  menuRow(3));
check('RESTART row is present', menuRow(5) === '  RESTART      ', menuRow(5));
check('EXIT row says EXIT TO MENU', menuRow(7) === '  EXIT TO MENU ', menuRow(7));
check('menu has right-side padding', menuRow(3).endsWith(' ') &&
  menuRow(7).endsWith(' ') && menuRow(8) === ' '.repeat(MENU_W),
  `${JSON.stringify(menuRow(7))} / ${JSON.stringify(menuRow(8))}`);

/* The tiles just outside the panel must still be playfield, not menu. */
const outsideAfter = {
  left: bgTile(expectBx - 1, expectBy + 3),
  right: bgTile(expectBx + MENU_W, expectBy + 3),
  bottom: bgTile(expectBx + 3, expectBy + MENU_H),
};
check('menu leaves the surrounding playfield intact',
  outsideAfter.left === outsideBefore.left &&
  outsideAfter.right === outsideBefore.right &&
  outsideAfter.bottom === outsideBefore.bottom,
  `left=${outsideAfter.left}/${outsideBefore.left}`);

/* ------------------------------------------------------------------ */
/* Navigation, level selection, and Start/B close                       */
/* ------------------------------------------------------------------ */

menuPress('DOWN');
check('down selects RESTART', menuRow(5).startsWith('>') && !menuRow(3).startsWith('>'),
  menuRow(5));
menuPress('DOWN');
check('down selects EXIT TO MENU', menuRow(7).startsWith('>'), menuRow(7));
menuPress('DOWN');
check('down wraps back to WARP', menuRow(3).startsWith('>'), menuRow(3));

menuPress('RIGHT');
check('right raises the warp level', levelDigits() === '02', levelDigits());
menuPress('LEFT');
check('left lowers the warp level', levelDigits() === '01', levelDigits());
menuPress('LEFT');
check('warp level clamps at 1', levelDigits() === '01', levelDigits());

/* START must only close/resume, never activate the selected WARP item. */
menuPress('RIGHT');
check('warp row is ready on 02', levelDigits() === '02', levelDigits());
check('START closes the menu', closeMenuWith('START'),
  `state=${byte('pause_menu_state')}`);
check('START does not warp', byte('level_planet') === 1,
  `level=${byte('level_planet')}`);
runFrames(4);
check('closing restores the playfield tiles', sameMenuRect(menuBefore));
check('HUD remains at the bottom after closing', core.windowY === 128,
  `y=${core.windowY}`);

/* ------------------------------------------------------------------ */
/* A activates: warp, restart, exit                                    */
/* ------------------------------------------------------------------ */

check('menu reopens with the current level', openMenu() && levelDigits() === '01',
  menuRow(3));
menuPress('RIGHT');
check('warp level is ready on 02', levelDigits() === '02', levelDigits());
menuPress('A');
check('A warps to level 2', waitLevelAfterLoad(2), `level=${byte('level_planet')}`);
check('warp closes the menu', byte('pause_menu_state') === PAUSE_STATE_CLOSED,
  `state=${byte('pause_menu_state')}`);
check('warp restores the HUD window', core.windowY === 128 && core.gfxWindowDisplay,
  `y=${core.windowY} display=${core.gfxWindowDisplay}`);

check('reopened menu defaults to the new current level',
  openMenu() && levelDigits() === '02', menuRow(3));
menuPress('DOWN');
const robboX = byte('robbo_x');
const robboY = byte('robbo_y');
menuPress('A');
check('A RESTART restores then kills Robbo',
  waitFor(() => byte('pause_menu_state') === PAUSE_STATE_CLOSED &&
    byte('robbo_busy') === 1, 80),
  `state=${byte('pause_menu_state')} busy=${byte('robbo_busy')}`);
check('RESTART closed the menu before the death sequence',
  readMem(gb, S.map_type + robboY * 16 + robboX, 1)[0] === CT_EXPLOSION,
  `busy=${byte('robbo_busy')}`);

check('RESTART respawns on the same planet', waitLevelAfterLoad(2),
  `level=${byte('level_planet')}`);
check('restart restores the level counters',
  byte('screws_left') === byte('level_screw'),
  `left=${byte('screws_left')} declared=${byte('level_screw')}`);

check('menu opens after restart', openMenu(), `state=${byte('pause_menu_state')}`);
check('B closes the menu like START', closeMenuWith('B'),
  `state=${byte('pause_menu_state')}`);
check('B does not warp or restart', byte('level_planet') === 2 &&
  byte('robbo_busy') === 0, `level=${byte('level_planet')}`);

check('menu opens for EXIT TO MENU', openMenu(), `state=${byte('pause_menu_state')}`);
menuPress('DOWN');
menuPress('DOWN');
check('EXIT TO MENU is selected', menuRow(7).startsWith('>'), menuRow(7));
menuPress('A');
const title = waitFor(() =>
  (lcdc() & 0x80) !== 0 && (lcdc() & 0x01) !== 0 && (lcdc() & 0x20) === 0, 900);
check('A EXIT TO MENU returns to the title', title,
  `LCDC=0x${lcdc().toString(16)}`);
check('title hides the pause menu', byte('pause_menu_state') === PAUSE_STATE_CLOSED,
  `state=${byte('pause_menu_state')}`);

holdKey(gb, 'START', 6);
runFrames(15);
holdKey(gb, 'LEFT', 6);
runFrames(10);
holdKey(gb, 'A', 6);
check('title starts level 1 again',
  waitFor(() => (lcdc() & 0x20) !== 0, 500) && waitLevelAfterLoad(1),
  `level=${byte('level_planet')}`);

console.log(failures === 0 ? 'Checkpoint 25 passed' : `Checkpoint 25 FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);

function runFrames(n) {
  for (let i = 0; i < n; i++) gb.doFrame();
}
