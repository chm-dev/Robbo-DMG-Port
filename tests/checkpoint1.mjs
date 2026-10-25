#!/usr/bin/env node
/*
 * Checkpoint 1: zoomed-in 16x16 rendering, Robbo cell movement, wall collision
 * and two-axis camera scrolling.
 *
 * Run: node gb/tests/checkpoint1.mjs
 */
import { loadRom, run, readMem, savePng, holdKey, tapKey } from '../tools/gb_harness.mjs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = path.join(root, 'gb', 'tests', 'screenshots');
const gb = loadRom(path.join(root, 'roms', 'robbo-debug.gb'));

// WRAM symbols from roms/robbo-debug.noi (this test warps with Select).
const SYM = {
  level_planet: 0xc703,
  robbo_x: 0xc705,
  robbo_y: 0xc706,
  robbo_dir: 0xc707,
  cam_x: 0xc70b,
  cam_y: 0xc70c,
};

const byte = (addr) => readMem(gb, addr, 1)[0];

function state(label) {
  const s = {
    level: byte(SYM.level_planet),
    robbo: [byte(SYM.robbo_x), byte(SYM.robbo_y), byte(SYM.robbo_dir)],
    cam: [byte(SYM.cam_x), byte(SYM.cam_y)],
  };
  console.log(label, JSON.stringify(s));
  return s;
}

run(gb, 120);
state('boot');
savePng(gb.getScreen(), path.join(out, 'cp1-level1.png'));

// Level 1 corridor: left is open, then the outer wall blocks.
holdKey(gb, 'LEFT', 24);
const wallTest = state('level1 after LEFT (wall collision next)');
holdKey(gb, 'LEFT', 24);
const wallTest2 = state('level1 after second LEFT (should be unchanged)');
if (wallTest.robbo[0] !== wallTest2.robbo[0]) {
  console.error('WALL COLLISION FAILED');
}

// Warp to level 5 (large open area). Select advances one level per tap.
for (let i = 0; i < 10 && byte(SYM.level_planet) !== 5; i++) {
  tapKey(gb, 'SELECT', 80);
}
state('level5');
savePng(gb.getScreen(), path.join(out, 'cp1-level5-start.png'));

// Walk left: the camera should follow Robbo's centering target.
holdKey(gb, 'LEFT', 96);
state('level5 after LEFT');
savePng(gb.getScreen(), path.join(out, 'cp1-level5-left.png'));

// Walk down: camera should scroll vertically and stream the 16-row ring.
holdKey(gb, 'DOWN', 160);
state('level5 after DOWN');
savePng(gb.getScreen(), path.join(out, 'cp1-level5-down.png'));

console.log('screenshots saved to', out);
