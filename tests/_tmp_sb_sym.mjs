import { loadRom, run, readMem } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
const text = fs.readFileSync('roms/robbo.noi','utf8');
const S={};
for (const line of text.split(/\r?\n/)) { const m=line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/); if (m) S[m[1]]=parseInt(m[2],16); }
for (const n of ['level_planet','robbo_x','robbo_y','level_height','screws_left','color_on','cpu','intro_active','game_state']) if (S[n]!==undefined) console.log(n, '0x'+S[n].toString(16));
const gb = loadRom(path.resolve('roms/robbo.gb'));
run(gb, 300);
for (const n of ['level_planet','robbo_x','robbo_y','screws_left','color_on','intro_active']) if (S[n]!==undefined) console.log('after:', n, readMem(gb,S[n],1)[0]);
