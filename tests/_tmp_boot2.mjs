import { loadRom, run, readMem } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
const noi = fs.readFileSync('roms/robbo.noi','utf8');
const S = {};
for (const line of noi.split(/\r?\n/)) { const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/); if (m) S[m[1]] = parseInt(m[2],16); }
const gb = loadRom(path.resolve('roms/robbo.gb'));
const b = (n) => S[n] === undefined ? '?' : readMem(gb, S[n], 1)[0];
const core = gb[Object.keys(gb)[0]].gameboy;
console.log('after boot: saved_level', b('saved_level'), 'level_planet', b('level_planet'), 'cpu', readMem(gb,0xC0A0,1)[0]);
console.log('cart ram @A000', Array.from(core.memory.slice(0xA000,0xA008)).map(v=>v.toString(16)).join(' '));
run(gb, 400);
console.log('after 400: saved_level', b('saved_level'), 'level_planet', b('level_planet'), 'robbo_x', b('robbo_x'));
