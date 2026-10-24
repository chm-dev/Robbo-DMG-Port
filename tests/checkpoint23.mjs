#!/usr/bin/env node
/*
 * Checkpoint 23: Atari-style level entry, death respawn and level transition.
 *
 * Reproduces R1.ASM's flow:
 *   - ENTCV paints the playfield in one column at a time; WFAC then materializes
 *     Robbo at the start cell and plays the entry sound.
 *   - PLA1 restores the pristine level on death, so every item/screw/actor is
 *     back, ammo and keys are zero, and the camera pans from the death view to
 *     the start instead of snapping there behind a black frame.
 *   - NXCV clears the finished room column by column, then the next level is
 *     painted in with the same intro.
 *
 * Run: node gb/tests/checkpoint23.mjs
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
const CT_SPACESHIP = 13;
const CT_BOMB = 15;
const CT_ROBBO = 26;
const MAP_CELLS = 16 * 31;

/* Tile ids for the spawn sequence, read from bank 0's metatile table. */
const tilesHeader = fs.readFileSync(path.join(root, 'gb', 'src', 'gen', 'tiles.h'), 'utf8');
const mtNum = (name) => Number(tilesHeader.match(new RegExp(`#define\\s+${name}\\s+(\\d+)`))[1]);
const romBytes = fs.readFileSync(rom);
const firstTile = (mt) => romBytes[S.metatile_tiles + mt * 4];
const explosionTiles = [0, 1, 2, 3].map((f) => firstTile(mtNum('MT_EXPLOSION_0') + f));
const robboNeutralTile = firstTile(mtNum('MT_ROBBO_0') + 2);

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

const gb = loadRom(rom);
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const cell = (x, y) => mem[S.map_type + y * 16 + x];
const lcdc = () => readMem(gb, 0xFF40, 1)[0];
const spawnTile = () => {
  const x = byte('robbo_x');
  const y = byte('robbo_y');
  return core.BGCHRBank1[(((y & 15) * 2) * 32 + x * 2) & 0x7ff];
};

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
function holdRight(predicate, maxFrames = 400) {
  for (let i = 0; i < maxFrames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(['RIGHT']);
    gb.doFrame();
    if (predicate()) {
      core.JoyPad = 0xff;
      gb.doFrame();
      return true;
    }
  }
  core.JoyPad = 0xff;
  return false;
}

/* ------------------------------------------------------------------ */
/* 1. Boot: the title starts level 1 with the ENTCV paint and spawn.  */
/* ------------------------------------------------------------------ */
check('boot starts the level-entry intro', byte('intro_active') === 1,
  `intro=${byte('intro_active')}`);
check('intro keeps the display on', (lcdc() & 0x80) !== 0,
  `LCDC=0x${lcdc().toString(16)}`);
check('level 1 Robbo at start', byte('robbo_x') === 2 && byte('robbo_y') === 2,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
check('boot intro finishes',
  waitFor(() => byte('intro_active') === 0 && byte('robbo_busy') === 0, 400),
  `intro=${byte('intro_active')} busy=${byte('robbo_busy')}`);
check('level 1 camera snaps to the start edge',
  byte('cam_x') === 0 && byte('cam_y') === 0 &&
  byte('cam_scx') === 0 && byte('cam_scy') === 0,
  `cam=${byte('cam_x')},${byte('cam_y')} sc=${byte('cam_scx')},${byte('cam_scy')}`);

/* ------------------------------------------------------------------ */
/* 2. Death respawn: restored items, zero ammo/keys, and a camera pan. */
/* ------------------------------------------------------------------ */
clearActors();
setCell(3, 2, CT_EMPTY);
setCell(4, 2, CT_EMPTY);
check('walked away from the start cell',
  holdRight(() => byte('robbo_x') >= 5, 400) && byte('robbo_x') === 5,
  `x=${byte('robbo_x')}`);
run(gb, 12);
check('camera target centers the moved Robbo', byte('cam_goal_x') === 1,
  `goal=${byte('cam_goal_x')}`);

setCell(6, 2, CT_BOMB, 1);
check('bomb kills Robbo', waitFor(() => byte('robbo_busy') !== 0, 300),
  `busy=${byte('robbo_busy')}`);

check('respawn intro starts', waitFor(() => byte('intro_active') !== 0, 1200),
  `intro=${byte('intro_active')} request=${byte('game_restart_requested')}`);
check('respawn starts from the death view', byte('cam_x') === 1,
  `cam=${byte('cam_x')},${byte('cam_y')}`);
check('respawn targets the level start', byte('cam_goal_x') === 0,
  `goal=${byte('cam_goal_x')},${byte('cam_goal_y')}`);

let displayOff = false;
let sawPanIntermediate = false;
const spawnSeen = new Set();
const spawnStates = new Set();
for (let i = 0; i < 500 && byte('intro_active'); i++) {
  frame();
  if ((lcdc() & 0x80) === 0) displayOff = true;
  const scx = byte('cam_scx');
  if (scx > 0 && scx < 16) sawPanIntermediate = true;
  spawnSeen.add(spawnTile());
  spawnStates.add(byte('render_robbo_spawn'));
}
check('respawn never turns the display off', !displayOff);
check('respawn intro finishes', byte('intro_active') === 0 && byte('robbo_busy') === 0,
  `intro=${byte('intro_active')} busy=${byte('robbo_busy')}`);
check('respawn pans smoothly to the start', sawPanIntermediate &&
  byte('cam_x') === 0 && byte('cam_scx') === 0,
  `pan=${sawPanIntermediate} cam=${byte('cam_x')} scx=${byte('cam_scx')}`);
check('spawn shows the waiting pod', spawnStates.has(1),
  `states=${[...spawnStates].join(',')}`);
check('spawn runs all four explosion frames',
  [2, 3, 4, 5].every((s) => spawnStates.has(s)),
  `states=${[...spawnStates].join(',')}`);
check('spawn explosion tiles are drawn',
  explosionTiles.filter((t) => spawnSeen.has(t)).length >= 2,
  `seen=${explosionTiles.filter((t) => spawnSeen.has(t)).join(',')}`);
check('Robbo replaces the pod after the morph',
  spawnStates.has(0) && byte('intro_active') === 0,
  `states=${[...spawnStates].join(',')} intro=${byte('intro_active')}`);
check('Robbo is the final spawn tile', spawnTile() === robboNeutralTile,
  `tile=${spawnTile()} robbo=${robboNeutralTile}`);
check('respawn restores the level wall', cell(4, 2) === 2,
  `cell=${cell(4, 2)}`);
check('respawn restores pickups and counters',
  byte('ammo') === 0 && byte('keys') === 0 &&
  byte('screws_left') === byte('level_screw'),
  `ammo=${byte('ammo')} keys=${byte('keys')} screws=${byte('screws_left')}/${byte('level_screw')}`);
check('respawn puts Robbo back at the start',
  byte('robbo_x') === 2 && byte('robbo_y') === 2 && cell(2, 2) === CT_ROBBO,
  `pos=${byte('robbo_x')},${byte('robbo_y')} cell=${cell(2, 2)}`);

/* ------------------------------------------------------------------ */
/* 3. Level complete: NXCV column clear, then the next level paints.  */
/* ------------------------------------------------------------------ */
clearActors();
/* Put the exit far enough right that the camera is not at the top-left; the
 * next level must start at this exit view (Atari PLA1 leaves DLSA untouched),
 * not at SETU's SCRN. */
for (let x = 3; x <= 8; x++) setCell(x, 2, CT_EMPTY);
check('walked to the far exit cell',
  holdRight(() => byte('robbo_x') >= 7, 400) && byte('robbo_x') === 7,
  `x=${byte('robbo_x')}`);
check('camera followed the exit cell',
  waitFor(() => byte('cam_x') >= 2, 300),
  `cam=${byte('cam_x')}`);

setCell(8, 2, CT_SPACESHIP, 0);
mem[S.screws_left] = 0;

check('capsule starts the NXCV clear',
  holdRight(() => byte('game_transition_active') !== 0, 400),
  `trans=${byte('game_transition_active')} busy=${byte('robbo_busy')}`);
const exitCamX = byte('cam_x');
const exitCamY = byte('cam_y');

let clearFrames = 0;
let clearDisplayOff = false;
while (byte('game_transition_active') && clearFrames < 300) {
  frame();
  clearFrames++;
  if ((lcdc() & 0x80) === 0) clearDisplayOff = true;
}
check('NXCV clear takes one column per frame pair',
  clearFrames > 20 && clearFrames < 150, `frames=${clearFrames}`);
check('NXCV clear keeps the display on', !clearDisplayOff);
check('NXCV advances to level 2',
  waitFor(() => byte('level_planet') === 2, 300),
  `level=${byte('level_planet')} adv=${byte('game_level_advance_requested')}`);
check('level 2 intro starts',
  waitFor(() => byte('intro_active') !== 0, 400),
  `intro=${byte('intro_active')} busy=${byte('robbo_busy')}`);
check('level 2 starts at the previous exit view',
  exitCamX > 0 && byte('cam_x') === exitCamX && byte('cam_y') === exitCamY,
  `exit=${exitCamX},${exitCamY} entry=${byte('cam_x')},${byte('cam_y')}`);
check('level 2 intro starts and finishes',
  waitFor(() => byte('intro_active') === 0 && byte('robbo_busy') === 0, 1200),
  `intro=${byte('intro_active')} busy=${byte('robbo_busy')}`);
check('level 2 pans to its own spawn',
  byte('cam_x') === 6 && byte('cam_scx') === 6 * 16,
  `cam=${byte('cam_x')} scx=${byte('cam_scx')}`);
check('level 2 is fully painted',
  cell(byte('robbo_x'), byte('robbo_y')) === CT_ROBBO &&
  cell(2, 2) === 14 && cell(10, 1) === 10 && cell(0, 0) === 2,
  `robbo=${byte('robbo_x')},${byte('robbo_y')} ` +
  `start=${cell(byte('robbo_x'), byte('robbo_y'))} ` +
  `question=${cell(2, 2)} stone=${cell(10, 1)} wall=${cell(0, 0)}`);
check('level 2 display stays on', (lcdc() & 0x80) !== 0,
  `LCDC=0x${lcdc().toString(16)}`);

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 23 passed');
process.exit(failures ? 1 : 0);
