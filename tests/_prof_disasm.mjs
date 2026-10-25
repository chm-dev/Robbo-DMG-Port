#!/usr/bin/env node
/* TEMP: identify hot SUB_00 functions via disassembly. */
import { spawn } from 'node:child_process';
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
    const t = setTimeout(() => { waiters.delete(id); reject(new Error('timeout')); }, 60000);
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
  return r;
}

await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'probe', version: '1' } });
await rpc('notifications/initialized', {});

for (const addr of ['1BD8', '317A', '2C94', '1454', '1291', '1D80', '2D1C', '3671']) {
  console.log(`\n===== 0x${addr} =====`);
  const r = await call('get_disassembly', { start_address: addr, end_address: (parseInt(addr,16)+0x40).toString(16).toUpperCase(), resolve_symbols: true });
  if (typeof r === 'string') console.log(r);
  else console.log(JSON.stringify(r).slice(0, 3000));
}

child.kill();
process.exit(0);
