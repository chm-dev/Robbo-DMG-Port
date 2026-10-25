import { loadRom, run, readMem, savePng } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
const noi = fs.readFileSync('roms/robbo.noi','utf8');
const S = {};
for (const line of noi.split(/\r?\n/)) { const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/); if (m) S[m[1]] = parseInt(m[2],16); }
const gb = loadRom(path.resolve('roms/robbo.gb'));
run(gb, 200);
const b = (n) => readMem(gb, S[n], 1)[0];
console.log('level_planet', b('level_planet'), 'robbo_x', b('robbo_x'), 'robbo_y', b('robbo_y'));
console.log('intro?', b('intro_active'), 'color_on', b('color_on'), 'cpu', b('cpu'));
savePng(gb.getScreen(), 'gb/tests/screenshots/_tmp_boot.png');
