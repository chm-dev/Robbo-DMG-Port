#!/usr/bin/env node
/*
 * Checkpoint 17: Robbo's walk frame is a timed step pose, not a persistent flip.
 *
 * GBC rule (render_gr_robbo): frame = moving ? 1 : 0, derived from the per-step
 * delay countdown.  A single step therefore shows the walk pose briefly and
 * then returns to the neutral frame; holding a direction alternates the two.
 *
 * Run: node gb/tests/checkpoint17.mjs
 */
import { loadRom, run, readMem } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rom = path.join(root, 'roms', 'robbo.gb');
const MAP_W = 16;

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
let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
run(gb, 150);
const core = gb[Object.keys(gb)[0]].gameboy;
const byte = (name) => readMem(gb, S[name], 1)[0];
const bg = core.BGCHRBank1;

/* Valid tile indices belonging to any Robbo metatile.  Transient camera/move
 * timing can briefly point robboTile() at a neighbouring wall tile; only
 * frames from this set are meaningful for the walk-animation checks. */
const tilesHeader = fs.readFileSync(path.join(root, 'gb', 'src', 'gen', 'tiles.h'), 'utf8');
const mtRobbo0 = Number(tilesHeader.match(/#define MT_ROBBO_0 (\d+)/)[1]);
const mtRobbo7 = Number(tilesHeader.match(/#define MT_ROBBO_7 (\d+)/)[1]);
const romBytes = fs.readFileSync(rom);
const robboTiles = new Set();
for (let mt = mtRobbo0; mt <= mtRobbo7; mt++) {
  for (let q = 0; q < 4; q++) robboTiles.add(romBytes[S.metatile_tiles + mt * 4 + q]);
}
const isRobboTile = (tile) => robboTiles.has(tile);

function frame(keys) {
  core.JoyPad = 0xff;
  if (keys) gb.pressKeys(keys);
  gb.doFrame();
}

/* Top-left 8x8 tile of the 2x2 metatile in the BG map.  The map is stored at
 * absolute level coordinates; the camera only changes SCX/SCY, so indexing
 * by screen position would read the wrong cell once the view scrolls. */
function tileAtCell(cx, cy) {
  return bg[(0x9800 + cy * 2 * 32 + cx * 2) & 0x7ff];
}
function robboTile() {
  return tileAtCell(byte('robbo_x'), byte('robbo_y'));
}

/* Clear the corridor east of the start so the test only measures movement. */
for (let x = 3; x < 10; x++) {
  core.memory[S.map_type + 2 * MAP_W + x] = 0;
  core.memory[S.map_extra + 2 * MAP_W + x] = 0;
}

/* Face right while idle (A + direction aims but never moves).  Hold long
 * enough for a slow main-loop iteration to sample the pad. */
for (let i = 0; i < 12; i++) frame(['A', 'RIGHT']);
frame();
check('Robbo faces right while idle', byte('robbo_dir') === 0,
  `dir=${byte('robbo_dir')}`);
check('idle step timer is zero', byte('robbo_step_timer') === 0,
  `timer=${byte('robbo_step_timer')}`);

const neutral = robboTile();
const startX = byte('robbo_x');
const staleNext = tileAtCell(startX + 1, byte('robbo_y'));

/* One tap: find the redrawn walk pose before the step timer expires.  Hold
 * for a few frames so a slow main-loop iteration cannot miss the press. */
for (let i = 0; i < 8; i++) frame(['RIGHT']);
let moved = false;
let walk = null;
for (let i = 0; i < 40; i++) {
  if (byte('robbo_x') !== startX) moved = true;
  if (moved && byte('robbo_step_timer') > 0) {
    const tile = robboTile();
    if (isRobboTile(tile) && tile !== staleNext && tile !== neutral) {
      walk = tile;
      break;
    }
  }
  frame();
}
check('single tap moves Robbo', moved, `x=${byte('robbo_x')}`);
check('step shows a walk pose', walk !== null && walk !== neutral,
  `walk=${walk} neutral=${neutral}`);

/* The walk pose must expire back to the neutral frame while standing still. */
let settled = false;
for (let i = 0; i < 40; i++) {
  if (byte('robbo_step_timer') === 0 && robboTile() === neutral) {
    settled = true;
    break;
  }
  frame();
}
check('walk pose returns to neutral when idle', settled,
  `timer=${byte('robbo_step_timer')} tile=${robboTile()}`);

/* Holding the direction must alternate neutral and walk frames. */
const visible = new Set();
for (let i = 0; i < 50; i++) {
  frame(['RIGHT']);
  const tile = robboTile();
  if (isRobboTile(tile)) visible.add(tile);
}
check('held movement alternates frames',
  neutral !== null && walk !== null &&
  visible.has(neutral) && visible.has(walk),
  `tiles=${[...visible].join(',')}`);

/* Releasing must end on the neutral frame again. */
let finalNeutral = false;
for (let i = 0; i < 40; i++) {
  frame();
  if (byte('robbo_step_timer') === 0 && robboTile() === neutral) {
    finalNeutral = true;
    break;
  }
}
check('release leaves Robbo on the neutral frame', finalNeutral,
  `timer=${byte('robbo_step_timer')} tile=${robboTile()}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 17 passed');
process.exit(failures ? 1 : 0);
