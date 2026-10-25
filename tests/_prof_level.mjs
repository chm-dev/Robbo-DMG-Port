#!/usr/bin/env node
/* TEMP: raw profiler for a chosen level (default 18). */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const exe = path.resolve(root, 'gearboy', 'Gearboy.exe');
const rom = path.resolve(root, 'roms', 'robbo.gb');
const TARGET = Number(process.argv[2] || 18);
const child = spawn(exe, ['--headless', '--mcp-stdio', '--portable', rom], { stdio: ['pipe', 'pipe', 'pipe'] });
child.stderr.on('data', () => {});
let buf = '';
const waiters = new Map();
child.stdout.on('data', chunk => {
  buf += chunk.toString('utf8');
  let nl;
  while ((nl = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, nl).trim(); buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id !== undefined && waiters.has(msg.id)) { waiters.get(msg.id)(msg); waiters.delete(msg.id); }
  }
});
let nextId = 1;
function rpc(method, params) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const t = setTimeout(() => { waiters.delete(id); reject(new Error('timeout')); }, 120000);
    waiters.set(id, m => { clearTimeout(t); resolve(m.result ?? m.error); });
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params: params || {} }) + '\n');
  });
}
function parseTool(r) { if (r && r.content) { const t = r.content.filter(c => c.type === 'text').map(c => c.text).join('\n'); try { return JSON.parse(t); } catch { return t; } } return r; }
async function call(name, args) { return parseTool(await rpc('tools/call', { name, arguments: args || {} })); }

const noiText = fs.readFileSync(path.join(root, 'roms', 'robbo.noi'), 'utf8');
const S = {};
for (const line of noiText.split(/\r?\n/)) { const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/); if (m) S[m[1]] = parseInt(m[2], 16); }
const hexOff = a => (a - 0xC000).toString(16).toUpperCase();
async function readWram(addr, len) { const r = await call('read_memory', { area: 4, offset: hexOff(addr), size: len }); return r.data.trim().split(/\s+/).map(h => parseInt(h, 16)); }
async function byte(n) { return (await readWram(S[n], 1))[0]; }
async function stepFrames(n) { let l = n; while (l > 0) { const c = Math.min(1000, l); await call('debug_step_frame', { frames: c, mode: 'sync' }); l -= c; } }

await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'probe', version: '1' } });
await rpc('notifications/initialized', {});
await stepFrames(120);
await call('controller_button', { player: 1, button: 'start', action: 'press_and_release' });
for (let i = 0; i < 400; i++) { if (await byte('level_planet') === 1) break; await stepFrames(2); }

if (TARGET !== 1) {
  for (let g = 0; g < 300; g++) {
    const cur = await byte('level_planet');
    if (cur === TARGET) break;
    if (cur < TARGET) await call('controller_button', { player: 1, button: 'select', action: 'press_and_release' });
    else await call('controller_macro', { commands: [{ press: 'select' }, { tap: 'up' }] });
    await stepFrames(2);
  }
}
// settle past intro
await stepFrames(60);
console.log('level_planet=', await byte('level_planet'));

await call('set_profiler', { action: 'reset' });
await call('set_profiler', { action: 'start' });
await stepFrames(600);
await call('set_profiler', { action: 'stop' });
const data = await call('get_profiler_data', { sort: 'inclusive', count: 30 });
console.log('frame_cycles=', data.frame_cycles, 'total_cycles=', data.total_cycles, 'functions=', data.function_count);
for (const f of (data.functions || [])) {
  console.log(`${f.name||f.address}  addr=${f.address} bank=${f.bank} calls=${f.calls} cpf=${f.calls_per_frame?.toFixed(2)} avg=${f.average_cycles} exc=${f.exclusive_cycles} inc=${f.inclusive_cycles} exc%=${f.exclusive_percent?.toFixed(2)}`);
}
child.kill();
process.exit(0);
