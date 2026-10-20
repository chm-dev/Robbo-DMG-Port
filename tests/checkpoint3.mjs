#!/usr/bin/env node
/*
 * Checkpoint 3: ammo pickup and one-projectile shooting.
 *
 * Run: node gb/tests/checkpoint3.mjs
 */
import { loadRom, run, readMem, savePng, holdKey } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = path.join(root, 'gb', 'tests', 'screenshots');
const gb = loadRom(path.join(root, 'roms', 'robbo.gb'));

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
const core = gb[Object.keys(gb)[0]].gameboy;
const mem = core.memory;
const byte = (name) => readMem(gb, S[name], 1)[0];
const mapCell = (x, y) => readMem(gb, S.map_type + y * 16 + x, 1)[0];
const CT_BULLET = 27;
const CT_EXPLOSION = 28;

function clearTurretsAndBullets() {
  for (let i = 0; i < 16 * 31; i++) {
    if (mem[S.map_type + i] === 18 || mem[S.map_type + i] === 27) {
      mem[S.map_type + i] = 0;
      mem[S.map_extra + i] = 0;
    }
  }
}

function countType(type) {
  const cells = readMem(gb, S.map_type, 16 * 31);
  return cells.filter(v => v === type).length;
}

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function settle(frames = 20) {
  for (let i = 0; i < frames; i++) gb.doFrame();
}

run(gb, 150);
clearTurretsAndBullets();

// Fire is a modifier: with 0 ammo, fire+direction only changes facing.
holdKey(gb, ['LEFT', 'A'], 12);
check('fire+direction with no ammo does not move', byte('robbo_x') === 2 && byte('robbo_y') === 2,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
check('fire+direction with no ammo faces direction', byte('robbo_dir') === 2,
  `dir=${byte('robbo_dir')}`);
check('no ammo consumed with none', byte('ammo') === 0, `ammo=${byte('ammo')}`);

// Level 1: ammo pickup at (4,2), directly right of Robbo.
let guard = 0;
while (byte('robbo_x') !== 4 && guard++ < 10) holdKey(gb, 'RIGHT', 12);
check('reached ammo cell', byte('robbo_x') === 4 && byte('robbo_y') === 2,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
check('ammo pickup gave 9 shots', byte('ammo') === 9, `ammo=${byte('ammo')}`);
settle();
savePng(gb.getScreen(), path.join(out, 'cp3-ammo.png'));

// Fire alone (no direction) must not shoot.
for (let i = 0; i < 30; i++) gb.doFrame();
holdKey(gb, 'A', 8);
check('fire without direction does nothing', byte('ammo') === 9 && countType(CT_BULLET) === 0,
  `ammo=${byte('ammo')} bullets=${countType(CT_BULLET)}`);

// Hold fire and press left: face left and shoot without moving.
holdKey(gb, ['LEFT', 'A'], 8);
check('fire+direction shot consumed one ammo', byte('ammo') === 8, `ammo=${byte('ammo')}`);
check('fire+direction did not move Robbo', byte('robbo_x') === 4 && byte('robbo_y') === 2,
  `pos=${byte('robbo_x')},${byte('robbo_y')}`);
check('facing left', byte('robbo_dir') === 2, `dir=${byte('robbo_dir')}`);
check('exactly one projectile exists', countType(CT_BULLET) === 1,
  `bullets=${countType(CT_BULLET)}`);
check('projectile spawned in front', mapCell(3, 2) === CT_BULLET,
  `cell(3,2)=${mapCell(3, 2)}`);

// Firing again while the projectile is active must not consume ammo or spawn.
holdKey(gb, ['LEFT', 'A'], 2);
check('second shot blocked while projectile active', byte('ammo') === 8,
  `ammo=${byte('ammo')}`);
check('still exactly one projectile', countType(CT_BULLET) === 1,
  `bullets=${countType(CT_BULLET)}`);
savePng(gb.getScreen(), path.join(out, 'cp3-shot.png'));

// Let it hit the wall at x=0; the explosion then clears.
for (let i = 0; i < 160; i++) gb.doFrame();
check('projectile disappeared', countType(CT_BULLET) === 0,
  `bullets=${countType(CT_BULLET)}`);
check('explosion cleared', countType(CT_EXPLOSION) === 0,
  `explosions=${countType(CT_EXPLOSION)}`);

// One projectile again after the first disappears.
holdKey(gb, ['LEFT', 'A'], 2);
check('next shot allowed after projectile disappears', byte('ammo') === 7,
  `ammo=${byte('ammo')}`);
check('new projectile exists', countType(CT_BULLET) === 1,
  `bullets=${countType(CT_BULLET)}`);

settle();
savePng(gb.getScreen(), path.join(out, 'cp3-hud.png'));

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 3 passed');
process.exit(failures ? 1 : 0);
