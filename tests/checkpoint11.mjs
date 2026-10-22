#!/usr/bin/env node
/*
 * Checkpoint 11: sound-effect wiring.
 *
 * The player lives in bank 9.  Game events start sound-port2 patterns with
 * sfx_play_note(SFX_*), and the retained effects (explosion, destruct, door)
 * with sfx_play_def().  main() advances the player once per elapsed VBlank.
 * This test boots the ROM in serverboy, drives real gameplay events and
 * inspects the generated audio buffer.
 *
 * Level 1 contains turrets and a few bullets in flight, so tests that expect
 * silence remove those actors from WRAM first; the turrets fire on a random
 * timer and would otherwise beep in the measurement windows.
 *
 * Run: node gb/tests/checkpoint11.mjs
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
const CT_STONE = 10;
const CT_DOOR = 12;
const CT_BOMB = 15;
const CT_KEY = 16;
const CT_SCREW = 17;
const CT_AMMO = 19;
const CT_MAGNET = 25;
const CT_MUSTACHE = 21;
const CT_BUTTERFLY = 22;
const CT_BEAR = 23;
const CT_TURRET = 18;
const CT_BULLET = 27;

/* serverboy's resampler rate; audioBuffer holds float32 L/R pairs where
 * -1 is silence and 0 is full scale. */
const SAMPLE_RATE = 4194304 / 95;

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? '  ' + detail : ''}`);
  if (!ok) failures++;
}

function fresh() {
  const gb = loadRom(rom);
  const core = gb[Object.keys(gb)[0]].gameboy;
  return { gb, core, mem: core.memory, byte: (name) => readMem(gb, S[name], 1)[0] };
}

function leftSamples(gb) {
  const buf = gb.getAudio();
  const out = [];
  if (!buf) return out;
  for (let i = 0; i < buf.length; i += 2) out.push(buf[i] + 1);
  return out;
}

function analyze(samples) {
  let peak = 0;
  let sum = 0;
  for (let i = 0; i < samples.length; i++) {
    const a = Math.abs(samples[i]);
    if (a > peak) peak = a;
    sum += samples[i] * samples[i];
  }
  return {
    peak: +peak.toFixed(3),
    rms: +Math.sqrt(sum / Math.max(1, samples.length)).toFixed(3),
  };
}

function lastAudibleMs(samples) {
  let last = -1;
  for (let i = 0; i < samples.length; i++) {
    if (Math.abs(samples[i]) > 0.01) last = i;
  }
  return Math.round(((last + 1) / SAMPLE_RATE) * 1000);
}

/* Run frames, holding keys, and collect everything the APU produced. */
function captureRaw(ctx, frames, keys = null) {
  const samples = [];
  for (let i = 0; i < frames; i++) {
    ctx.core.JoyPad = 0xff;
    if (keys) ctx.gb.pressKeys(keys);
    ctx.gb.doFrame();
    samples.push(...leftSamples(ctx.gb));
  }
  ctx.core.JoyPad = 0xff;
  return samples;
}

function capture(ctx, frames, keys = null) {
  return analyze(captureRaw(ctx, frames, keys));
}

function setCell(ctx, x, y, type, ex = 0) {
  ctx.mem[S.map_type + y * 16 + x] = type;
  ctx.mem[S.map_extra + y * 16 + x] = ex;
  ctx.mem[S.map_obj + y * 16 + x] = 0;
}

/* Remove everything that moves or shoots on its own. */
function clearActors(ctx) {
  for (let i = 0; i < 16 * 31; i++) {
    const type = ctx.mem[S.map_type + i];
    if (type === CT_TURRET || type === CT_MUSTACHE || type === CT_BUTTERFLY ||
        type === CT_BEAR || type === CT_BULLET) {
      ctx.mem[S.map_type + i] = CT_EMPTY;
      ctx.mem[S.map_extra + i] = 0;
      ctx.mem[S.map_obj + i] = 0;
    }
  }
}

/* Run past the boot fanfare and leave a quiet level. */
function quietLevel() {
  const ctx = fresh();
  run(ctx.gb, 420);
  clearActors(ctx);
  /* Clear level 1's pickups/teleport on Robbo's row so tests only see the
   * event they set up. */
  for (let x = 3; x <= 9; x++) setCell(ctx, x, 2, CT_EMPTY);
  return ctx;
}

/* --- Boot: the LEVEL START jingle plays, then the APU goes quiet. -------- */
{
  const ctx = fresh();
  const boot = capture(ctx, 320); /* includes the initial level load */
  check('level start sound at boot', boot.peak > 0.05,
    `peak=${boot.peak} rms=${boot.rms}`);
  check('level start pattern advances', boot.rms > 0.01, `rms=${boot.rms}`);

  clearActors(ctx);
  capture(ctx, 60);
  const idle = capture(ctx, 160);
  check('no sound while idle', idle.peak < 0.02, `peak=${idle.peak}`);
  check('voices idle', ctx.byte('sfx_voice_mask') === 0,
    `mask=${ctx.byte('sfx_voice_mask')}`);
}

/* --- Moving is silent: the step sound was removed. ---------------------- */
{
  const ctx = quietLevel();
  capture(ctx, 5);
  const walk = capture(ctx, 30, ['RIGHT']);
  check('Robbo moved right', ctx.byte('robbo_x') > 2, `x=${ctx.byte('robbo_x')}`);
  check('move is silent', walk.peak < 0.02, `peak=${walk.peak}`);
}

/* --- Blocked move is silent too. ---------------------------------------- */
{
  const ctx = quietLevel();
  setCell(ctx, 2, 1, CT_EMPTY);
  capture(ctx, 20, ['UP']);
  const y = ctx.byte('robbo_y');
  capture(ctx, 5);
  const blocked = capture(ctx, 40, ['UP']);
  check('border blocks the move', ctx.byte('robbo_y') === y, `y=${ctx.byte('robbo_y')}`);
  check('blocked move is silent', blocked.peak < 0.02, `peak=${blocked.peak}`);
}

/* --- Pushing a box plays PUSH. ------------------------------------------ */
{
  const ctx = quietLevel();
  setCell(ctx, 3, 2, CT_STONE);
  setCell(ctx, 4, 2, CT_EMPTY);
  capture(ctx, 5);
  const push = capture(ctx, 24, ['RIGHT']);
  check('box pushed one cell', ctx.byte('robbo_x') === 3 &&
    ctx.mem[S.map_type + 2 * 16 + 4] === CT_STONE,
    `x=${ctx.byte('robbo_x')} cell4=${ctx.mem[S.map_type + 2 * 16 + 4]}`);
  check('push sound', push.peak > 0.005, `peak=${push.peak}`);
}

/* --- Key pickup plays KEY. ---------------------------------------------- */
{
  const ctx = quietLevel();
  setCell(ctx, 3, 2, CT_KEY);
  capture(ctx, 5);
  const pickup = capture(ctx, 40, ['RIGHT']);
  check('key collected', ctx.byte('keys') === 1, `keys=${ctx.byte('keys')}`);
  check('key pickup sound', pickup.peak > 0.005, `peak=${pickup.peak}`);
}

/* --- Door open keeps the retained door sound. --------------------------- */
{
  const ctx = quietLevel();
  ctx.mem[S.keys] = 1;
  setCell(ctx, 3, 2, CT_DOOR);
  capture(ctx, 5);
  const door = capture(ctx, 40, ['RIGHT']);
  check('door opened', ctx.byte('keys') === 0 &&
    ctx.mem[S.map_type + 2 * 16 + 3] === CT_EMPTY,
    `keys=${ctx.byte('keys')} cell=${ctx.mem[S.map_type + 2 * 16 + 3]}`);
  check('door open sound', door.peak > 0.005, `peak=${door.peak}`);
}

/* --- Ammo pickup plays AMMO. -------------------------------------------- */
{
  const ctx = quietLevel();
  setCell(ctx, 3, 2, CT_AMMO);
  capture(ctx, 5);
  const pickup = capture(ctx, 40, ['RIGHT']);
  check('ammo collected', ctx.byte('ammo') === 9, `ammo=${ctx.byte('ammo')}`);
  check('ammo pickup sound', pickup.peak > 0.005, `peak=${pickup.peak}`);
}

/* --- Firing plays SHOT. ------------------------------------------------- */
{
  const ctx = quietLevel();
  ctx.mem[S.ammo] = 9;
  capture(ctx, 5);
  const shot = capture(ctx, 20, ['RIGHT', 'A']);
  check('shot consumed ammo', ctx.byte('ammo') < 9, `ammo=${ctx.byte('ammo')}`);
  check('fire sound', shot.peak > 0.005, `peak=${shot.peak}`);
}

/* --- Magnet capture (MAGNET) and death (retained destroy). -------------- */
{
  const ctx = quietLevel();
  setCell(ctx, 5, 2, CT_MAGNET, 2); /* pointing left at Robbo */
  capture(ctx, 5);
  const magnet = capture(ctx, 80);
  check('magnet captures Robbo', ctx.byte('robbo_no_move') !== 0,
    `noMove=${ctx.byte('robbo_no_move')}`);
  check('magnet sound', magnet.peak > 0.005, `peak=${magnet.peak}`);

  const death = capture(ctx, 400);
  check('magnet kills Robbo', ctx.byte('robbo_busy') !== 0 || ctx.byte('robbo_x') === 2,
    `busy=${ctx.byte('robbo_busy')} x=${ctx.byte('robbo_x')}`);
  check('death sound', death.peak > 0.05, `peak=${death.peak}`);
}

/* --- Regular bolt pickup plays the short BOLT pattern. ----------------- */
{
  const ctx = quietLevel();
  ctx.mem[S.screws_left] = 5;
  setCell(ctx, 3, 2, CT_SCREW);
  capture(ctx, 5);

  const samples = [];
  let picked = false;
  for (let f = 0; f < 120; f++) {
    ctx.core.JoyPad = 0xff;
    if (!picked) ctx.gb.pressKeys(['RIGHT']);
    ctx.gb.doFrame();
    samples.push(...leftSamples(ctx.gb));
    if (ctx.byte('screws_left') === 4) picked = true;
  }
  check('bolt collected', ctx.byte('screws_left') === 4,
    `screws=${ctx.byte('screws_left')}`);
  const ms = lastAudibleMs(samples);
  check('regular bolt uses the short jingle', ms > 200 && ms < 900,
    `duration=${ms}ms`);
}

/* --- Last bolt plays the long GAME OVER pattern instead of BOLT. -------- */
{
  const ctx = quietLevel();
  ctx.mem[S.screws_left] = 1;
  setCell(ctx, 3, 2, CT_SCREW);
  capture(ctx, 5);

  const samples = [];
  let picked = false;
  for (let f = 0; f < 260; f++) {
    ctx.core.JoyPad = 0xff;
    if (!picked) ctx.gb.pressKeys(['RIGHT']);
    ctx.gb.doFrame();
    samples.push(...leftSamples(ctx.gb));
    if (ctx.byte('screws_left') === 0) picked = true;
  }
  check('last bolt collected', ctx.byte('screws_left') === 0,
    `screws=${ctx.byte('screws_left')}`);
  const ms = lastAudibleMs(samples);
  check('last bolt uses the game-over jingle', ms > 700, `duration=${ms}ms`);
}

/* --- Polyphony: retained explosion (noise) + key pickup (tone). --------- */
{
  const ctx = quietLevel();
  setCell(ctx, 3, 2, CT_KEY);

  let bomb = -1;
  for (let i = 0; i < 16 * 31; i++) {
    if (ctx.mem[S.map_type + i] === CT_BOMB) { bomb = i; break; }
  }
  check('level 1 has a bomb to detonate', bomb >= 0, `idx=${bomb}`);
  ctx.mem[S.map_extra + bomb] = 1;

  let explosion = false;
  let noiseAndTone = false;
  for (let f = 0; f < 160; f++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(['RIGHT']);
    ctx.gb.doFrame();
    leftSamples(ctx.gb);
    const m = ctx.byte('sfx_voice_mask');
    if (m & 0x04) explosion = true;
    if ((m & 0x04) && (m & 0x03)) noiseAndTone = true;
  }
  check('bomb explosion sound', explosion);
  check('explosion and key pickup overlap', noiseAndTone);
}

/* --- Polyphony: boot level-start jingle + key pickup (two pulse voices). - */
{
  const ctx = fresh();
  let started = false;
  for (let f = 0; f < 220 && !started; f++) {
    ctx.gb.doFrame();
    leftSamples(ctx.gb);
    if (ctx.byte('sfx_voice_mask') & 0x03) started = true;
  }
  check('boot level start is playing', started);

  clearActors(ctx);
  setCell(ctx, 3, 2, CT_KEY);
  let toneOverlap = false;
  for (let f = 0; f < 140; f++) {
    ctx.core.JoyPad = 0xff;
    ctx.gb.pressKeys(['RIGHT']);
    ctx.gb.doFrame();
    leftSamples(ctx.gb);
    if ((ctx.byte('sfx_voice_mask') & 0x03) === 0x03) toneOverlap = true;
  }
  check('two tone effects play together', toneOverlap);
}

console.log(failures ? `\n${failures} checkpoint(s) failed` : '\nCheckpoint 11 passed');
process.exit(failures ? 1 : 0);
