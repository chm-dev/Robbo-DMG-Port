import { loadRom, readMem } from '../tools/gb_harness.mjs';
import path from 'node:path';
const gb = loadRom(path.resolve('roms/robbo.gb'));
console.log('cpu =', readMem(gb, 0xC0A0, 1)[0].toString(16));
