#!/usr/bin/env node
/*
 * TEMP profiling via Gearboy's embedded MCP server (STDIO transport).
 * Boots the ROM headless, profiles a quiet window and a bomb cascade with the
 * per-function CPU profiler, and reports debug_ticks-per-frame as ground truth
 * (is the 0.73 quiet overrun seen in serverboy real?).
 *
 * Run: node gb/tests/gearboy_prof.mjs [--frames N]
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const argVal = (name, dflt) => {
  const i = process.argv.indexOf(name);
  return i > 0 ? process.argv[i + 1] : dflt;
};
const rom = path.resolve(root, argVal('--rom', 'roms/robbo.gb'));
const exe = path.resolve(root, 'gearboy', 'Gearboy.exe');

/* ---------------- MCP stdio client ---------------- */
const child = spawn(exe, ['--headless', '--mcp-stdio', '--portable', rom], {
  stdio: ['pipe', 'pipe', 'pipe'],
});
let stderrBuf = '';
child.stderr.on('data', (d) => { stderrBuf += d.toString(); });
let buf = '';
const waiters = new Map();
child.stdout.on('data', (chunk) => {
  buf += chunk.toString('utf8');
  let nl;
  while ((nl = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id !== undefined && waiters.has(msg.id)) {
      waiters.get(msg.id)(msg);
      waiters.delete(msg.id);
    }
  }
});

let nextId = 1;
function rpc(method, params) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    const timer = setTimeout(() => { waiters.delete(id); reject(new Error(`${method} timed out`)); }, 300000);
    waiters.set(id, (msg) => { clearTimeout(timer); resolve(msg.result ?? msg.error); });
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

/* ---------------- memory helpers (WRAM0 = area 4, base 0xC000) ---------- */
const noiText = fs.readFileSync(path.join(root, 'roms', 'robbo.noi'), 'utf8');
const S = {};
for (const line of noiText.split(/\r?\n/)) {
  const m = line.match(/^DEF _([A-Za-z0-9_]+) (0x[0-9A-Fa-f]+)/);
  if (m) S[m[1]] = parseInt(m[2], 16);
}

function hexOff(addr) { return (addr - 0xC000).toString(16).toUpperCase(); }
function hexBytes(bytes) { return Array.from(bytes).map(b => b.toString(16).toUpperCase().padStart(2, '0')).join(' '); }
function parseHex(s) { return s.trim().split(/\s+/).map(h => parseInt(h, 16)); }

async function readWram(addr, len) {
  const r = await call('read_memory', { area: 4, offset: hexOff(addr), size: len });
  return parseHex(r.data);
}
async function writeWram(addr, bytes) {
  return call('write_memory', { area: 4, offset: hexOff(addr), bytes: hexBytes(bytes) });
}
async function readU16(addr) {
  const d = await readWram(addr, 2);
  return d[0] | (d[1] << 8);
}

async function stepFrames(n) {
  let left = n;
  while (left > 0) {
    const c = Math.min(1000, left);
    const r = await call('debug_step_frame', { frames: c, mode: 'sync' });
    if (!r || !r.success) throw new Error(`step failed: ${JSON.stringify(r)}`);
    left -= c;
  }
}

async function profileWindow(label, frames, top) {
  await call('set_profiler', { action: 'reset' });
  await call('set_profiler', { action: 'start' });
  const t0 = await readU16(S.debug_ticks);
  await stepFrames(frames);
  const t1 = await readU16(S.debug_ticks);
  await call('set_profiler', { action: 'stop' });
  const data = await call('get_profiler_data', { sort: 'inclusive', count: top || 15 });
  const iters = (((t1 - t0) & 0xffff) / frames).toFixed(3);
  console.log(`\n=== ${label} === stepped=${frames} iters/frame=${iters} ` +
    `frame_cycles=${data?.frame_cycles} total_cycles=${data?.total_cycles} functions=${data?.function_count}`);
  for (const f of (data?.functions || [])) {
    console.log(
      `  inc ${String(f.inclusive_percent).padStart(6)}%  exc ${String(f.exclusive_percent).padStart(6)}%` +
      `  calls=${f.calls}  cpf=${(f.calls_per_frame ?? 0).toFixed(2)}  ${f.name || f.symbol || f.address}`);
  }
}

async function main() {
  await rpc('initialize', {
    protocolVersion: '2024-11-05', capabilities: {},
    clientInfo: { name: 'robbo-prof', version: '1' },
  });
  await rpc('notifications/initialized', {});

  const info = await call('get_media_info');
  console.log('media:', info.file_name, info.cartridge_type, 'valid=', info.valid_rom);

  // Boot + level 1; jingle done by ~frame 230.
  await stepFrames(320);
  console.log('sys_time=', await readU16(S.sys_time), 'debug_ticks=', await readU16(S.debug_ticks));

  await profileWindow('QUIET', 600);

  /* ---- bomb-field cascade ---- */
  const CT_BOMB = 15, CT_EMPTY = 0, MAP = 16 * 31;
  const mt = await readWram(S.map_type, MAP);
  const nw = Array.from(mt);
  for (let i = 0; i < MAP; i++) {
    const t = mt[i];
    if ((t >= 18 && t <= 25) || t === 27) nw[i] = CT_EMPTY;
  }
  const GX0 = 4, GX1 = 11, GY0 = 5, GY1 = 12;
  for (let y = GY0; y <= GY1; y++)
    for (let x = GX0; x <= GX1; x++)
      nw[y * 16 + x] = CT_BOMB;
  await writeWram(S.map_type, nw);
  await writeWram(S.map_extra, new Array(MAP).fill(0));
  await writeWram(S.map_obj, new Array(MAP).fill(0));
  await writeWram(S.map_extra + GY0 * 16 + GX0, [1]); // light one fuse
  await stepFrames(2);

  await profileWindow('CASCADE', 240, 20);
}

main().catch(e => console.error('ERR', e)).finally(() => {
  child.kill();
  setTimeout(() => process.exit(0), 500);
});




