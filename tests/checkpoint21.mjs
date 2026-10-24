#!/usr/bin/env node
/*
 * Checkpoint 21: DMG title screen.
 *
 * - Boot waits on the title instead of dropping straight into level 1.
 * - The 20x18 layout uses the authentic 8x8 Atari I.FNT glyphs and the
 *   three-phase logo tile rotation.
 * - Rules, credits, controls and the inverse INSTRUCTIONS heading are in
 *   the expected tile blocks.
 * - The typewriter line feed triggers the high pulse beep.
 * - START and A both begin level 1.
 *
 * Run: node gb/tests/checkpoint21.mjs
 */
import { loadRom, run, readMem, holdKey } from '../tools/gb_harness.mjs';
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
const titleHeader = fs.readFileSync(path.join(root, 'gb', 'src', 'gen', 'title_data.h'), 'utf8');
const T = {};
for (const m of titleHeader.matchAll(/#define (TITLE_[A-Z0-9_]+) (\d+)/g)) {
  T[m[1]] = Number(m[2]);
}

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const byte = (gb, name) => readMem(gb, S[name], 1)[0];

function coreOf(gb) {
  return gb[Object.keys(gb)[0]].gameboy;
}

/* Wait for the title's display-off copy phase to finish and the typewriter
 * loop to turn the display back on with the window still hidden. */
function waitForTitle(gb) {
  const core = coreOf(gb);
  core.JoyPad = 0xff;
  for (let i = 0; i < 200; i++) {
    if ((readMem(gb, 0xFF40, 1)[0] & 0x80) === 0) break;
    gb.doFrame();
  }
  for (let i = 0; i < 300; i++) {
    const lcdc = readMem(gb, 0xFF40, 1)[0];
    if ((lcdc & 0x80) && (lcdc & 0x01) && !(lcdc & 0x20)) break;
    gb.doFrame();
  }
}

function waitForGame(gb) {
  for (let i = 0; i < 400; i++) {
    if (readMem(gb, 0xFF40, 1)[0] & 0x20) return true;
    gb.doFrame();
  }
  return false;
}

function frame(gb) {
  const core = coreOf(gb);
  core.JoyPad = 0xff;
  gb.doFrame();
}

const gb = loadRom(rom, undefined, { skipTitle: true });
const core = coreOf(gb);
waitForTitle(gb);
run(gb, 40);

const bg = core.BGCHRBank1;
const tile = (x, y) => bg[(0x9800 + y * 32 + x) & 0x7ff];

const lcdc = readMem(gb, 0xFF40, 1)[0];
check('title runs with the display on', (lcdc & 0x80) !== 0, `LCDC=0x${lcdc.toString(16)}`);
check('title has BG on', (lcdc & 0x01) !== 0, `LCDC=0x${lcdc.toString(16)}`);
check('title hides the HUD window', (lcdc & 0x20) === 0, `LCDC=0x${lcdc.toString(16)}`);
check('title uses the standard BGP', readMem(gb, 0xFF47, 1)[0] === 0xE4,
  `BGP=0x${readMem(gb, 0xFF47, 1)[0].toString(16)}`);

const black = T.TITLE_BLACK_TILE;
check('playfield uses the title black tile', tile(0, 7) === black, `tile=${tile(0, 7)}`);

const logoBases = [T.TITLE_LOGO_0, T.TITLE_LOGO_1, T.TITLE_LOGO_2];
const logoBase = tile(3, 0);
check('logo starts at a phase base', logoBases.includes(logoBase), `tile=${logoBase}`);
check('logo row 1 follows the phase base', tile(3, 1) === logoBase + T.TITLE_LOGO_TW,
  `tile=${tile(3, 1)}`);
check('logo row 2 follows the phase base', tile(3, 2) === logoBase + 2 * T.TITLE_LOGO_TW,
  `tile=${tile(3, 2)}`);

const white = T.TITLE_FONT_WHITE;
const gray = T.TITLE_FONT_GRAY;
const inverse = T.TITLE_FONT_INVERSE;
const copyright = T.TITLE_COPYRIGHT_TILE;
check('copyright tile is drawn', tile(2, 4) === copyright, `tile=${tile(2, 4)}`);
check('credits use the bright font', tile(4, 4) >= white && tile(4, 4) < gray,
  `tile=${tile(4, 4)}`);
check('control lines use the grey font', tile(0, 8) >= gray && tile(0, 8) < inverse,
  `tile=${tile(0, 8)}`);
check('heading uses the inverse font', tile(4, 16) >= inverse && tile(4, 16) < copyright,
  `tile=${tile(4, 16)}`);

const ruleTop = tile(0, 11);
const ruleBottom = tile(0, 17);
check('top rule spans the screen',
  ruleTop !== black && tile(19, 11) === ruleTop,
  `tile=${ruleTop}`);
check('bottom rule spans the screen',
  ruleBottom !== black && tile(19, 17) === ruleBottom,
  `tile=${ruleBottom}`);

/* The beep must not exist before the first line feed, then must fire when
 * the window scrolls.  sfx_update() keeps it active for exactly four frames. */
check('no line-feed beep while typing the heading',
  byte(gb, 'sfx_beep_frames') === 0,
  `frames=${byte(gb, 'sfx_beep_frames')}`);

const seen = new Set();
let beepStart = -1;
let beepLen = 0;
let beepEnd = -1;
for (let i = 0; i < 400; i++) {
  seen.add(tile(3, 0));
  frame(gb);
  const remaining = byte(gb, 'sfx_beep_frames');
  if (beepStart < 0) {
    if (remaining) {
      beepStart = i;
      beepLen = remaining;
    }
  } else if (remaining === 0) {
    beepEnd = i;
    break;
  }
}
check('logo cycles through all three phases', seen.size === 3,
  `phases=${[...seen].join(',')}`);
check('line feed starts the beep', beepStart >= 0, `frame=${beepStart}`);
/* The audible stop is NR12 volume 4 / envelope period 1 (~4 real frames);
 * the counter is the logical four-frame window used by sfx_stop(). */
check('beep is scheduled for four frames', beepLen === 4 && beepEnd >= 0,
  `len=${beepLen} span=${beepEnd - beepStart}`);

holdKey(gb, 'START', 8);
const started = waitForGame(gb);
check('START begins the game', started, `LCDC=0x${readMem(gb, 0xFF40, 1)[0].toString(16)}`);
check('START loads level 1', byte(gb, 'level_planet') === 1,
  `level=${byte(gb, 'level_planet')}`);
check('level 1 starts Robbo at 2,2',
  byte(gb, 'robbo_x') === 2 && byte(gb, 'robbo_y') === 2,
  `pos=${byte(gb, 'robbo_x')},${byte(gb, 'robbo_y')}`);

/* A is the alternate start button, as on the Atari/GBC title. */
const gbA = loadRom(rom, undefined, { skipTitle: true });
waitForTitle(gbA);
run(gbA, 40);
holdKey(gbA, 'A', 8);
check('A begins the game', waitForGame(gbA),
  `LCDC=0x${readMem(gbA, 0xFF40, 1)[0].toString(16)}`);
check('A loads level 1', byte(gbA, 'level_planet') === 1,
  `level=${byte(gbA, 'level_planet')}`);

console.log(failures === 0 ? 'Checkpoint 21 passed' : `Checkpoint 21 FAILED (${failures})`);
process.exit(failures === 0 ? 0 : 1);
