import { spawn } from 'node:child_process';
const exe = 'C:/dev/AI/robbo-port2/gearboy/Gearboy.exe';
const rom = 'C:/dev/AI/robbo-port2/roms/robbo.gb';
const child = spawn(exe, ['--headless', '--mcp-stdio', '--portable', rom], { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = ''; const waiters = new Map();
child.stdout.on('data', c => {
  buf += c.toString(); let nl;
  while ((nl = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, nl).trim(); buf = buf.slice(nl + 1);
    if (!line) continue; let m; try { m = JSON.parse(line); } catch { continue; }
    if (m.id !== undefined && waiters.has(m.id)) { waiters.get(m.id)(m); waiters.delete(m.id); }
  }
});
let id = 0;
const rpc = (method, params) => new Promise(res => {
  const i = ++id;
  waiters.set(i, m => res(m.result ?? m.error));
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: i, method, params: params || {} }) + '\n');
});
const call = async (n, a) => (await rpc('tools/call', { name: n, arguments: a }));
const parse = r => { try { return JSON.parse(r.content.filter(c=>c.type==='text').map(c=>c.text)[0]); } catch { return r; } };
await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'x', version: '1' } });
await rpc('notifications/initialized', {});
const step = async (n) => parse(await call('debug_step_frame', { frames: n, mode: 'sync' }));
const writeWram = async (addr, bytes) => call('write_memory', { area: 4, offset: (addr - 0xc000).toString(16).toUpperCase(), bytes: bytes.map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(' ') });
const readWram = async (addr, len) => parse(await call('read_memory', { area: 4, offset: (addr - 0xc000).toString(16).toUpperCase(), size: len })).data.split(' ').map(h => parseInt(h, 16));

import fs from 'node:fs';
const noi = fs.readFileSync('C:/dev/AI/robbo-port2/roms/robbo.noi', 'utf8');
const S = {};
for (const line of noi.split(/\r?\n/)) {
  const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
  if (m) S[m[1]] = parseInt(m[2], 16);
}

await step(400);
// one bomb at (15,15), light fuse
await writeWram(S.map_type + 15 * 16 + 15, [15]);
await writeWram(S.map_extra + 15 * 16 + 15, [1]);
for (let k = 0; k < 5; k++) {
  await step(4);
  const apu = parse(await call('get_apu_status', {}));
  const ch = apu.channels[3];
  console.log(`t${k}`, JSON.stringify(ch));
}
child.kill(); setTimeout(() => process.exit(0), 300);

