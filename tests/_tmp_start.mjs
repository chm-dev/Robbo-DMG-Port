import { loadRom, run, readMem, savePng, tapKey } from '../tools/gb_harness.mjs';
import path from 'node:path';
const gb = loadRom(path.resolve('roms/robbo.gb'), undefined, { skipTitle: true });
const core = gb[Object.keys(gb)[0]].gameboy;
const lcdc = () => readMem(gb, 0xFF40, 1)[0];
for (let i=0;i<240;i++) gb.doFrame();
console.log('title up lcdc=%02x', lcdc());
core.JoyPad = 0xff; gb.doFrame();
tapKey(gb, 'START', 4);
for (let i=0;i<8;i++) {
  for (let j=0;j<20;j++) gb.doFrame();
  console.log('after', (i+1)*20, 'lcdc', lcdc().toString(16), 'lp', readMem(gb, 0xC100, 1)[0]);
}
savePng(gb.getScreen(), 'gb/tests/screenshots/_tmp_after_start.png');
