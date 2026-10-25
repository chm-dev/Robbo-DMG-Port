#!/usr/bin/env node
/*
 * Checkpoint 26: external-RAM save and title start-level menu.
 *
 * - The ROM advertises MBC5+RAM with a 128 KiB RAM bank set.
 * - A fresh cart has no save; START begins level 1 and does not write one.
 * - Progressing to a new level stores the highest level (level 1 alone never
 *   creates a save), and replaying from a lower level never downgrades it.
 * - The title START/A menu stops the typewriter, shows the HUD-font level
 *   digits, lowers with Left/Right, and offers DELETE SAVE GAME.
 * - Deleting asks for confirmation, erases the record, returns to the normal
 *   scrolling title, and the next START/A begins level 1.
 * - The pause-menu warp range is clamped to 1..saved level.
 *
 * Run: node gb/tests/checkpoint26.mjs
 */
import { loadRom, readMem, holdKey } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo.gb');
const titleDataC = path.join(root, 'gb', 'src', 'gen', 'title_data.c');
const titleDataH = path.join(root, 'gb', 'src', 'gen', 'title_data.h');

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
const T = {};
for (const m of fs.readFileSync(titleDataH, 'utf8')
  .matchAll(/#define (TITLE_[A-Z0-9_]+) (\d+)/g)) {
  T[m[1]] = Number(m[2]);
}

const titleC = fs.readFileSync(titleDataC, 'utf8');
function parseByteArray(name) {
  const re = new RegExp(`const uint8_t ${name}\\[[^\\]]*\\] = \\{([\\s\\S]*?)\\};`);
  const m = titleC.match(re);
  if (!m) throw new Error(`missing ${name}`);
  return [...m[1].matchAll(/0x([0-9A-Fa-f]{2})/g)].map(x => parseInt(x[1], 16));
}
const whiteFont = parseByteArray('title_font_white');
const grayFont = parseByteArray('title_font_gray');
const hudDigits = [...titleC.match(
  /const uint8_t title_hud_digits\[10\]\[2\] = \{([\s\S]*?)\};/)
  [1].matchAll(/\{\s*(\d+)\s*,\s*(\d+)\s*\}/g)]
  .map(m => [Number(m[1]), Number(m[2])]);

const charByTile = new Map();
for (const font of [whiteFont, grayFont]) {
  for (let i = 0; i < 128; i++) {
    if (font[i] !== 0xFF) charByTile.set(font[i], String.fromCharCode(i));
  }
}
const digitTiles = new Set(hudDigits.flat());
const whiteChevron = whiteFont['>'.charCodeAt(0)];

const PAUSE_STATE_READY = 2;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function makeSave(level) {
  const ram = new Uint8Array(0x20000);
  ram[0] = 0x52; ram[1] = 0x42; ram[2] = 0x42; ram[3] = 0x4f;
  ram[4] = 1;
  ram[5] = level;
  ram[6] = level ^ 1 ^ 0x3c;
  ram[7] = 0xa5;
  return ram;
}

function validSaveLevel(core) {
  const r = core.MBCRam;
  if (!r || r.length < 8) return 0;
  if (r[0] !== 0x52 || r[1] !== 0x42 || r[2] !== 0x42 || r[3] !== 0x4f ||
      r[4] !== 1 || r[7] !== 0xa5) return 0;
  if (r[5] < 1 || r[5] > 56 || r[6] !== (r[5] ^ 1 ^ 0x3c)) return 0;
  return r[5];
}

function coreOf(gb) {
  return gb[Object.keys(gb)[0]].gameboy;
}

function lcdc(gb) {
  return readMem(gb, 0xFF40, 1)[0];
}

function runFrames(gb, n) {
  for (let i = 0; i < n; i++) gb.doFrame();
}

function waitFor(gb, fn, max) {
  for (let i = 0; i < max; i++) {
    if (fn()) return true;
    gb.doFrame();
  }
  return fn();
}

function waitForTitle(gb) {
  const core = coreOf(gb);
  core.JoyPad = 0xff;
  for (let i = 0; i < 200; i++) {
    if ((lcdc(gb) & 0x80) === 0) break;
    gb.doFrame();
  }
  for (let i = 0; i < 300; i++) {
    const l = lcdc(gb);
    if ((l & 0x80) && (l & 0x01) && !(l & 0x20)) break;
    gb.doFrame();
  }
}

function levelSettled(gb, core, level) {
  return readMem(gb, S.level_planet, 1)[0] === level &&
    readMem(gb, S.intro_active, 1)[0] === 0 &&
    readMem(gb, S.robbo_busy, 1)[0] === 0 &&
    readMem(gb, S.screws_left, 1)[0] === readMem(gb, S.level_screw, 1)[0] &&
    (lcdc(gb) & 0x80) !== 0 &&
    core.windowY === 128;
}

function waitLevel(gb, core, level) {
  return waitFor(gb, () => levelSettled(gb, core, level), 1800);
}

function waitNewLevel(gb, core, level) {
  if (!waitFor(gb, () => readMem(gb, S.intro_active, 1)[0] === 1, 1800)) return false;
  return waitLevel(gb, core, level);
}

function waitGameStart(gb, core, level) {
  return waitNewLevel(gb, core, level) && (lcdc(gb) & 0x20) !== 0;
}

function titleTile(core, x, y) {
  return core.BGCHRBank1[y * 32 + x];
}

function titleRow(core, y) {
  let out = '';
  for (let x = 0; x < 20; x++) {
    const tile = titleTile(core, x, y);
    if (tile === T.TITLE_BLACK_TILE) out += ' ';
    else if (charByTile.has(tile)) out += charByTile.get(tile);
    else if (digitTiles.has(tile)) out += '#';
    else out += '?';
  }
  return out;
}

function titleMenuReady(core) {
  return titleRow(core, 12).includes('STARTING LEVEL') &&
    titleRow(core, 16).includes('DELETE SAVE GAME');
}

function titleLevelDigits(core) {
  const tens = titleTile(core, 9, 13);
  const ones = titleTile(core, 10, 13);
  for (let d = 0; d < 10; d++) {
    if (tens === hudDigits[d][0]) {
      for (let o = 0; o < 10; o++) {
        if (ones === hudDigits[o][0]) return `${d}${o}`;
      }
    }
  }
  return '??';
}

function waitTitleMenu(gb, core) {
  return waitFor(gb, () => titleMenuReady(core), 120);
}

function waitTitleConfirm(gb, core) {
  return waitFor(gb, () =>
    titleRow(core, 12).includes('DELETE SAVE GAME?') &&
    titleRow(core, 14).includes('A YES'), 120);
}

/* ------------------------------------------------------------------ */
/* Cartridge header and fresh boot                                     */
/* ------------------------------------------------------------------ */

const romImage = fs.readFileSync(rom);
check('ROM header is MBC5+RAM', romImage[0x147] === 0x1B,
  `0x${romImage[0x147].toString(16)}`);
check('ROM header advertises 128 KiB RAM', romImage[0x149] === 0x04,
  `0x${romImage[0x149].toString(16)}`);

const fresh = loadRom(rom, undefined, { skipTitle: true });
const freshCore = coreOf(fresh);
waitForTitle(fresh);
runFrames(fresh, 40);
check('fresh cart has no valid save', validSaveLevel(freshCore) === 0,
  `level=${validSaveLevel(freshCore)}`);
holdKey(fresh, 'START', 6);
check('fresh START starts level 1 directly',
  waitGameStart(fresh, freshCore, 1), `level=${readMem(fresh, S.level_planet, 1)[0]}`);
check('starting level 1 does not create a save',
  validSaveLevel(freshCore) === 0, `level=${validSaveLevel(freshCore)}`);

/* ------------------------------------------------------------------ */
/* Saving on progression                                               */
/* ------------------------------------------------------------------ */

freshCore.memory[S.game_level_advance_requested] = 1;
check('advancing 1 -> 2 saves level 2',
  waitNewLevel(fresh, freshCore, 2) && validSaveLevel(freshCore) === 2,
  `level=${readMem(fresh, S.level_planet, 1)[0]} save=${validSaveLevel(freshCore)}`);

freshCore.memory[S.game_level_advance_requested] = 1;
check('advancing 2 -> 3 saves level 3',
  waitNewLevel(fresh, freshCore, 3) && validSaveLevel(freshCore) === 3,
  `level=${readMem(fresh, S.level_planet, 1)[0]} save=${validSaveLevel(freshCore)}`);

/* Pause warp must be clamped to the saved highest level. */
const font = readMem(fresh, S.font_tiles, 128);
const hudBg = readMem(fresh, S.hud_bg_tile, 1)[0];
function gameTileChar(tile) {
  for (let i = 0; i < 128; i++) {
    if (font[i] === tile) return String.fromCharCode(i);
  }
  return tile === hudBg ? ' ' : '?';
}
function pauseMenuRow(row) {
  const bx = readMem(fresh, S.pause_menu_bg_x, 1)[0];
  const by = readMem(fresh, S.pause_menu_bg_y, 1)[0];
  let out = '';
  for (let x = 0; x < 15; x++) out += gameTileChar(
    freshCore.BGCHRBank1[(by + row) * 32 + bx + x]);
  return out;
}
function openPause() {
  holdKey(fresh, 'START', 6);
  return waitFor(fresh, () =>
    readMem(fresh, S.pause_menu_state, 1)[0] === PAUSE_STATE_READY, 80);
}
function pausePress(key) {
  holdKey(fresh, key, 6);
  runFrames(fresh, 6);
}
function warpDigits() {
  return pauseMenuRow(3).slice(11, 13);
}

check('pause menu opens at level 3', openPause(), pauseMenuRow(3));
check('warp defaults to level 3', warpDigits() === '03', warpDigits());
pausePress('RIGHT');
check('warp cannot rise above the saved level', warpDigits() === '03', warpDigits());
pausePress('LEFT');
check('warp can go down to level 2', warpDigits() === '02', warpDigits());
pausePress('LEFT');
check('warp can go down to level 1', warpDigits() === '01', warpDigits());
pausePress('A');
check('warp to 1 loads level 1', waitNewLevel(fresh, freshCore, 1),
  `level=${readMem(fresh, S.level_planet, 1)[0]}`);
check('warping does not lower the save', validSaveLevel(freshCore) === 3,
  `save=${validSaveLevel(freshCore)}`);

check('pause reopens at level 1', openPause(), pauseMenuRow(3));
pausePress('RIGHT');
pausePress('RIGHT');
check('warp can return up to saved level 3', warpDigits() === '03', warpDigits());
pausePress('RIGHT');
check('warp stays at saved level 3', warpDigits() === '03', warpDigits());
pausePress('B');
waitFor(fresh, () => readMem(fresh, S.pause_menu_state, 1)[0] === 0, 80);

/* ------------------------------------------------------------------ */
/* Persistence and the title start-level menu                          */
/* ------------------------------------------------------------------ */

const persisted = Uint8Array.from(freshCore.MBCRam);
const gb = loadRom(rom, persisted, { skipTitle: true });
const core = coreOf(gb);
waitForTitle(gb);
runFrames(gb, 40);

holdKey(gb, 'START', 6);
check('START with a save opens the start-level menu', waitTitleMenu(gb, core),
  `row12=${JSON.stringify(titleRow(core, 12))}`);
check('scrolling instructions are gone', titleRow(core, 13).includes('##') &&
  !titleRow(core, 12).includes('ROBBO'), titleRow(core, 12));
check('saved level 3 is shown with HUD digits', titleLevelDigits(core) === '03',
  titleLevelDigits(core));
check('starting level heading is marked with a white chevron',
  titleTile(core, 2, 12) === whiteChevron &&
  titleTile(core, 3, 12) === whiteFont['S'.charCodeAt(0)] &&
  titleTile(core, 1, 16) === T.TITLE_BLACK_TILE,
  `chevron=${titleTile(core, 2, 12)} delete=${titleTile(core, 1, 16)}`);
check('active level and number are white, inactive DELETE is grey',
  titleTile(core, 9, 13) === hudDigits[0][0] &&
  titleTile(core, 10, 13) === hudDigits[3][0] &&
  titleTile(core, 2, 16) === grayFont['D'.charCodeAt(0)],
  `digits=${titleTile(core, 9, 13)},${titleTile(core, 10, 13)}`);
check('DELETE SAVE GAME is offered',
  titleRow(core, 16).trim() === 'DELETE SAVE GAME', titleRow(core, 16));
const frozen = [12, 13, 14, 15, 16].map(y => titleRow(core, y)).join('|');
runFrames(gb, 45);
check('scrolling remains stopped while the menu is open',
  [12, 13, 14, 15, 16].map(y => titleRow(core, y)).join('|') === frozen);

holdKey(gb, 'LEFT', 6);
runFrames(gb, 10);
check('LEFT lowers the starting level to 2', titleLevelDigits(core) === '02',
  titleLevelDigits(core));
holdKey(gb, 'LEFT', 6);
runFrames(gb, 10);
check('LEFT lowers the starting level to 1', titleLevelDigits(core) === '01',
  titleLevelDigits(core));
holdKey(gb, 'LEFT', 6);
runFrames(gb, 10);
check('starting level clamps at 1', titleLevelDigits(core) === '01',
  titleLevelDigits(core));
holdKey(gb, 'RIGHT', 6);
runFrames(gb, 10);
check('RIGHT raises the starting level again', titleLevelDigits(core) === '02',
  titleLevelDigits(core));

/* Delete confirmation: Down selects the option, A asks, B cancels. */
holdKey(gb, 'DOWN', 6);
runFrames(gb, 10);
check('DOWN selects DELETE SAVE GAME', titleRow(core, 16).startsWith(' >'),
  titleRow(core, 16));
check('chevron moves from the heading to DELETE SAVE GAME',
  titleTile(core, 2, 12) === T.TITLE_BLACK_TILE &&
  titleTile(core, 1, 16) === whiteChevron,
  `heading=${titleTile(core, 2, 12)} delete=${titleTile(core, 1, 16)}`);
check('inactive heading and number are dimmed when DELETE is selected',
  titleTile(core, 3, 12) === grayFont['S'.charCodeAt(0)] &&
  titleTile(core, 9, 13) >= T.TITLE_TILE_COUNT &&
  titleTile(core, 9, 13) <= T.TITLE_TILE_COUNT + 3 &&
  titleTile(core, 9, 14) >= T.TITLE_TILE_COUNT &&
  titleTile(core, 2, 16) === whiteFont['D'.charCodeAt(0)],
  `heading=${titleTile(core, 3, 12)} digits=${titleTile(core, 9, 13)},${titleTile(core, 9, 14)}`);
holdKey(gb, 'A', 6);
check('A asks for delete confirmation', waitTitleConfirm(gb, core),
  `row12=${JSON.stringify(titleRow(core, 12))}`);
check('confirmation offers A YES / B NO', titleRow(core, 14).includes('A YES'),
  titleRow(core, 14));
runFrames(gb, 8);
holdKey(gb, 'B', 6);
runFrames(gb, 12);
check('B cancels the deletion', titleMenuReady(core) &&
  validSaveLevel(core) === 3, `save=${validSaveLevel(core)}`);
check('cancelling returns the white chevron to the heading',
  titleTile(core, 2, 12) === whiteChevron &&
  titleTile(core, 1, 16) === T.TITLE_BLACK_TILE,
  `heading=${titleTile(core, 2, 12)} delete=${titleTile(core, 1, 16)}`);
check('cancelling restores the white level and grey DELETE',
  titleTile(core, 3, 12) === whiteFont['S'.charCodeAt(0)] &&
  titleTile(core, 9, 13) === hudDigits[0][0] &&
  titleTile(core, 9, 14) === hudDigits[0][1] &&
  titleTile(core, 2, 16) === grayFont['D'.charCodeAt(0)],
  `heading=${titleTile(core, 3, 12)} digits=${titleTile(core, 9, 13)},${titleTile(core, 9, 14)}`);

holdKey(gb, 'DOWN', 6);
runFrames(gb, 10);
holdKey(gb, 'A', 6);
waitTitleConfirm(gb, core);
runFrames(gb, 8);
holdKey(gb, 'A', 6);
runFrames(gb, 12);
check('confirmed A deletes the save', validSaveLevel(core) === 0,
  `save=${validSaveLevel(core)}`);
check('deleting returns to the scrolling title',
  waitFor(gb, () => !titleRow(core, 16).includes('DELETE'), 120),
  titleRow(core, 16));

holdKey(gb, 'START', 6);
check('START after deletion begins level 1',
  waitGameStart(gb, core, 1), `level=${readMem(gb, S.level_planet, 1)[0]}`);
check('post-delete start did not recreate the save', validSaveLevel(core) === 0,
  `save=${validSaveLevel(core)}`);

/* ------------------------------------------------------------------ */
/* Starting below the save keeps the higher record                     */
/* ------------------------------------------------------------------ */

const lower = loadRom(rom, makeSave(5), { skipTitle: true });
const lowerCore = coreOf(lower);
waitForTitle(lower);
runFrames(lower, 40);
holdKey(lower, 'START', 6);
waitTitleMenu(lower, lowerCore);
check('a level-5 save shows 05 by default', titleLevelDigits(lowerCore) === '05',
  titleLevelDigits(lowerCore));
holdKey(lower, 'LEFT', 6);
runFrames(lower, 10);
holdKey(lower, 'LEFT', 6);
runFrames(lower, 10);
check('starting level lowered to 3', titleLevelDigits(lowerCore) === '03',
  titleLevelDigits(lowerCore));
holdKey(lower, 'A', 6);
check('A starts level 3 from the menu',
  waitGameStart(lower, lowerCore, 3),
  `level=${readMem(lower, S.level_planet, 1)[0]}`);
check('starting lower keeps save level 5', validSaveLevel(lowerCore) === 5,
  `save=${validSaveLevel(lowerCore)}`);

lowerCore.memory[S.game_level_advance_requested] = 1;
check('advancing 3 -> 4 does not downgrade save level 5',
  waitNewLevel(lower, lowerCore, 4) && validSaveLevel(lowerCore) === 5,
  `level=${readMem(lower, S.level_planet, 1)[0]} save=${validSaveLevel(lowerCore)}`);

/* START on the title menu begins at the displayed default (saved) level. */
const startKey = loadRom(rom, makeSave(7), { skipTitle: true });
const startCore = coreOf(startKey);
waitForTitle(startKey);
runFrames(startKey, 40);
holdKey(startKey, 'START', 6);
check('START opens the menu at saved level 7', waitTitleMenu(startKey, startCore) &&
  titleLevelDigits(startCore) === '07', titleLevelDigits(startCore));
holdKey(startKey, 'START', 6);
check('START on the menu begins level 7',
  waitGameStart(startKey, startCore, 7),
  `level=${readMem(startKey, S.level_planet, 1)[0]}`);
check('starting level 7 leaves the save intact', validSaveLevel(startCore) === 7,
  `save=${validSaveLevel(startCore)}`);

/* Regression: the VBlank camera handler must not leave gameplay scroll on
 * the title after EXIT TO MENU. */
check('pause opens at level 7',
  (holdKey(startKey, 'START', 6), waitFor(startKey, () =>
    readMem(startKey, S.pause_menu_state, 1)[0] === PAUSE_STATE_READY, 80)),
  `state=${readMem(startKey, S.pause_menu_state, 1)[0]}`);
startCore.memory[S.cam_scx] = 24;
startCore.memory[S.cam_scy] = 16;
runFrames(startKey, 3);
holdKey(startKey, 'DOWN', 6);
runFrames(startKey, 6);
holdKey(startKey, 'DOWN', 6);
runFrames(startKey, 6);
holdKey(startKey, 'A', 6);
check('EXIT TO MENU returns to the title',
  waitFor(startKey, () => {
    const l = lcdc(startKey);
    return (l & 0x80) !== 0 && (l & 0x01) !== 0 && (l & 0x20) === 0;
  }, 1200), `LCDC=0x${lcdc(startKey).toString(16)}`);
check('title has no leftover camera scroll',
  readMem(startKey, 0xFF43, 1)[0] === 0 &&
  readMem(startKey, 0xFF42, 1)[0] === 0,
  `SCX=${readMem(startKey, 0xFF43, 1)[0]} SCY=${readMem(startKey, 0xFF42, 1)[0]}`);

console.log(failures === 0 ? 'Checkpoint 26 passed' : `Checkpoint 26 FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);
