#!/usr/bin/env node
/*
 * Deterministic Game Boy harness for the Robbo port.
 *
 * Uses the same serverboy build that backs the MCP emulator, but drives it
 * directly so tests can press arbitrary key combinations, step exact frame
 * counts, read WRAM and save PNG screenshots.
 *
 * Usage:
 *   node gb/tools/gb_harness.mjs --rom roms/robbo.gb --frames 60 --out shot.png
 *   node gb/tools/gb_harness.mjs --rom roms/bank-smoke.gb --keys A --frames 30
 *   node gb/tools/gb_harness.mjs --rom roms/robbo-debug.gb --dump C000:64
 *
 * The module also exports `loadRom`, `run` and `savePng` for the trace tests.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const Gameboy = require('../../mcp-gameboy/node_modules/serverboy');

export const KEYMAP = {
  RIGHT: 0, LEFT: 1, UP: 2, DOWN: 3,
  A: 4, B: 5, SELECT: 6, START: 7,
};

export function loadRom(romPath, saveData) {
  const gb = new Gameboy();
  gb.loadRom(fs.readFileSync(romPath), saveData);
  return gb;
}

export function readMem(gb, start, length) {
  // serverboy's getMemory(start, end) uses Array.slice(), so `end` is exclusive.
  return Array.from(gb.getMemory(start, start + length));
}

/**
 * Advance frames. `frames` may be a number or an array of
 * { keys: string[], frames: number } script steps.
 */
export function run(gb, plan) {
  if (typeof plan === 'number') {
    for (let i = 0; i < plan; i++) gb.doFrame();
    return;
  }
  for (const step of plan) {
    if (step.keys?.length) gb.pressKeys(step.keys);
    for (let i = 0; i < step.frames; i++) gb.doFrame();
  }
}

/**
 * serverboy's P1/JoyPad handling leaves stale direction bits when switching
 * between d-pad directions.  Resetting JoyPad each frame makes scripted input
 * deterministic; this only affects the harness, not the ROM.
 */
function coreOf(gb) {
  return gb[Object.keys(gb)[0]].gameboy;
}

export function holdKey(gb, key, frames) {
  const core = coreOf(gb);
  const keys = Array.isArray(key) ? key : [key];
  for (let i = 0; i < frames; i++) {
    core.JoyPad = 0xff;
    gb.pressKeys(keys);
    gb.doFrame();
  }
  core.JoyPad = 0xff;
  gb.doFrame();
}

export function tapKey(gb, key, wait = 8) {
  holdKey(gb, key, 2);
  for (let i = 0; i < wait; i++) gb.doFrame();
}

/* ------------------------------------------------------------------ */
/* Minimal PNG writer (RGBA, no external deps)                         */
/* ------------------------------------------------------------------ */

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(Buffer.concat([Buffer.from(type, 'ascii'), data])), 8 + data.length);
  return out;
}

export function savePng(pixels, file) {
  const width = 160;
  const height = 144;
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter: none
    Buffer.from(pixels.buffer ? pixels : Uint8Array.from(pixels))
      .subarray(y * stride, (y + 1) * stride)
      .copy(raw, y * (stride + 1) + 1);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // colour type RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png);
}

/* ------------------------------------------------------------------ */
/* CLI                                                                 */
/* ------------------------------------------------------------------ */

function parseArgs(argv) {
  const args = { frames: 60, keys: [], out: null, dump: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--rom') args.rom = argv[++i];
    else if (a === '--frames') args.frames = Number(argv[++i]);
    else if (a === '--keys') args.keys = argv[++i].split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
    else if (a === '--out') args.out = argv[++i];
    else if (a === '--dump') args.dump.push(argv[++i]);
    else if (a === '--hold') args.hold = Number(argv[++i]);
    else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

function parseDump(spec) {
  const [addrText, lenText] = spec.split(':');
  return { start: parseInt(addrText, 16), length: parseInt(lenText, 10) || 1 };
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);
if (isMain) {
  const args = parseArgs(process.argv.slice(2));
  if (!args.rom) {
    console.error('Usage: gb_harness.mjs --rom <file.gb> [--frames N] [--keys A,B] [--hold F] [--out shot.png] [--dump HEX:LEN]');
    process.exit(2);
  }

  const gb = loadRom(args.rom);
  if (args.keys.length) {
    const hold = args.hold ?? args.frames;
    gb.pressKeys(args.keys);
    for (let i = 0; i < hold; i++) gb.doFrame();
    for (let i = hold; i < args.frames; i++) gb.doFrame();
  } else {
    run(gb, args.frames);
  }

  for (const spec of args.dump) {
    const { start, length } = parseDump(spec);
    const bytes = readMem(gb, start, length);
    console.log(`$${start.toString(16).toUpperCase().padStart(4, '0')}: ${bytes.map(b => b.toString(16).padStart(2, '0')).join(' ')}`);
  }

  if (args.out) {
    savePng(gb.getScreen(), args.out);
    console.log(`saved ${args.out}`);
  }
}
