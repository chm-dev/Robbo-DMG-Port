import { loadRom, run, readMem, savePng } from '../tools/gb_harness.mjs';
import fs from 'node:fs';
import path from 'node:path';
const text = fs.readFileSync('roms/robbo.noi','utf8');
const S={};
for (const line of text.split(/\r?\n/)) { const m=line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/); if (m) S[m[1]]=parseInt(m[2],16); }
const gb = loadRom(path.resolve('roms/robbo.gb'));
run(gb, 100);
console.log('after autostart+100: lp', readMem(gb,S.level_planet,1)[0], 'robbo', readMem(gb,S.robbo_x,1)[0], readMem(gb,S.robbo_y,1)[0]);
savePng(gb.getScreen(), 'gb/tests/screenshots/_tmp_sb_autostart.png');
