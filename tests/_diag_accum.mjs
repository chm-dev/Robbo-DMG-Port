#!/usr/bin/env node
/* TEMP: watch bullet/explosion counts on level 18 over time. */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const exe = path.resolve(root, 'gearboy', 'Gearboy.exe');
const rom = path.resolve(root, 'roms', 'robbo.gb');
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
await stepFrames(400);

// warp to 18
await call('controller_button', { player: 1, button: 'down', action: 'press' });
await stepFrames(2);
await call('controller_button', { player: 1, button: 'select', action: 'press' });
await stepFrames(2);
await call('controller_button', { player: 1, button: 'select', action: 'release' });
await call('controller_button', { player: 1, button: 'down', action: 'release' });
for (let i = 0; i < 200; i++) { if (await byte('level_planet') === 18) break; await stepFrames(2); }
await stepFrames(60);

const MAP = 16 * 31;
const mt = await readWram(S.map_type, MAP);
console.log('start level_planet=', await byte('level_planet'));

function counts(arr) {
  let bullets = 0, explosions = 0, turrets = 0;
  for (const v of arr) {
    if (v === 27) bullets++;
    else if (v === 28) explosions++;
    else if (v === 18) turrets++;
  }
  return { bullets, explosions, turrets };
}

// sample every 10 frames for 1200 frames
for (let t = 0; t <= 1200; t += 10) {
  const m = await readWram(S.map_type, MAP);
  const c = counts(m);
  console.log(`t=${t} bullets=${c.bullets} explosions=${c.explosions} turrets=${c.turrets}`);
  await stepFrames(10);
}
child.kill();
process.exit(0);
