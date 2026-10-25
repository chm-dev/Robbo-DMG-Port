import { loadRom, readMem, savePng } from '../tools/gb_harness.mjs';
import path from 'node:path';
const gb = loadRom(path.resolve('roms/robbo.gb'), undefined, { skipTitle: true });
for (let i=0;i<20;i++) {
  for (let j=0;j<30;j++) gb.doFrame();
  console.log((i+1)*30, 'lcdc', readMem(gb,0xFF40,1)[0].toString(16), 'lp', readMem(gb,0xC0C0,1)[0]);
}
savePng(gb.getScreen(), 'gb/tests/screenshots/_tmp_sb_title.png');
