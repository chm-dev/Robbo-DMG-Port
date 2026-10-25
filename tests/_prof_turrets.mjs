#!/usr/bin/env node
/* TEMP: profile turret/beam cost on level 18 vs level 1 (proper boot). */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const exe = path.resolve(root, 'gearboy', 'Gearboy.exe');
const rom = path.resolve(root, 'roms', 'robbo.gb');

const child = spawn(exe, ['--headless', '--mcp-stdio', '--portable', rom], { stdio: ['pipe', 'pipe', 'pipe'] });
child.stderr.on('data', d => process.stderr.write(d));
let buf = '';
const waiters = new Map();
child.stdout.on('data', chunk => {
  buf += chunk.toString('utf8');
  let nl;
  while ((nl = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id !== undefined && waiters.has(msg.id)) { waiters.get(msg.id)(msg); waiters.delete(msg.id); }
  }
});
let nextId = 1;
function rpc(method, params) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const t = setTimeout(() => { waiters.delete(id); reject(new Error('timeout ' + method)); }, 120000);
    waiters.set(id, m => { clearTimeout(t); resolve(m.result ?? m.error); });
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params: params || {} }) + '\n');
  });
}
function parseTool(r) {
  if (r && r.content) {
    const txt = r.content.filter(c => c.type === 'text').map(c => c.text).join('\n');
    try { return JSON.parse(txt); } catch { return txt; }
  }
  return r;
}
async function call(name, args) {
  const r = parseTool(await rpc('tools/call', { name, arguments: args || {} }));
  if (r && r.code) throw new Error(`${name}: ${JSON.stringify(r)}`);
  return r;
}

const noiText = fs.readFileSync(path.join(root, 'roms', 'robbo.noi'), 'utf8');
const S = {};
for (const line of noiText.split(/\r?\n/)) {
  const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
  if (m) S[m[1]] = parseInt(m[2], 16);
}
const hexOff = a => (a - 0xC000).toString(16).toUpperCase();
async function readWram(addr, len) {
  const r = await call('read_memory', { area: 4, offset: hexOff(addr), size: len });
  return r.data.trim().split(/\s+/).map(h => parseInt(h, 16));
}
async function byte(name) { return (await readWram(S[name], 1))[0]; }
async function stepFrames(n) {
  let left = n;
  while (left > 0) {
    const c = Math.min(1000, left);
    await call('debug_step_frame', { frames: c, mode: 'sync' });
    left -= c;
  }
}
async function press(button) {
  await call('controller_button', { player: 1, button, action: 'press_and_release' });
}
async function waitLevel(level, tries = 300) {
  for (let i = 0; i < tries; i++) {
    if (await byte('level_planet') === level) return true;
    await stepFrames(2);
  }
  return false;
}

async function warpTo(level) {
  for (let g = 0; g < 400; g++) {
    const cur = await byte('level_planet');
    if (cur === level) return cur;
    if (cur < level) await press('select');
    else await call('controller_macro', { commands: [{ press: 'select' }, { tap: 'up' }] });
    await stepFrames(2);
  }
  return await byte('level_planet');
}

async function profileWindow(label, frames, top) {
  await call('set_profiler', { action: 'reset' });
  await call('set_profiler', { action: 'start' });
  const t0b = await readWram(S.debug_ticks, 2);
  const t0 = t0b[0] | (t0b[1] << 8);
  await stepFrames(frames);
  const t1b = await readWram(S.debug_ticks, 2);
  const t1 = t1b[0] | (t1b[1] << 8);
  await call('set_profiler', { action: 'stop' });
  const data = await call('get_profiler_data', { sort: 'inclusive', count: top || 20 });
  const iters = (((t1 - t0) & 0xffff) / frames).toFixed(3);
  console.log(`\n=== ${label} === frames=${frames} iters/frame=${iters} frame_cycles=${data?.frame_cycles} total_cycles=${data?.total_cycles} functions=${data?.function_count}`);
  for (const f of (data?.functions || [])) {
    console.log(`  inc ${String(f.inclusive_percent).padStart(6)}%  exc ${String(f.exclusive_percent).padStart(6)}%  calls=${f.calls}  cpf=${(f.calls_per_frame ?? 0).toFixed(2)}  ${f.name || f.symbol || f.address}`);
  }
}

async function main() {
  await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'robbo-prof', version: '1' } });
  await rpc('notifications/initialized', {});
  // Boot through title: wait for title loop, press START.
  await stepFrames(120);
  await press('start');
  if (!(await waitLevel(1, 400))) {
    // retry start in case timing missed
    await press('start');
    await waitLevel(1, 400);
  }
  console.log('level_planet=', await byte('level_planet'), 'debug_ticks=', (await readWram(S.debug_ticks, 2))[0]);

  await profileWindow('LEVEL1 quiet', 600);

  const l18 = await warpTo(18);
  console.log('warped to', l18);
  await profileWindow('LEVEL18 laser turrets', 600);

  const l55 = await warpTo(55);
  console.log('warped to', l55);
  await profileWindow('LEVEL55 23 turrets', 600);
}

main().catch(e => console.error('ERR', e)).finally(() => {
  child.kill();
  setTimeout(() => process.exit(0), 500);
});
