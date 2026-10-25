import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
const exe = path.resolve('gearboy', 'Gearboy.exe');
const rom = path.resolve('roms/robbo.gb');
const child = spawn(exe, ['--headless','--mcp-stdio','--portable',rom], { stdio: ['pipe','pipe','pipe'] });
let err=''; child.stderr.on('data', d=> err += d.toString());
let buf=''; const waiters=new Map(); let nextId=1;
child.stdout.on('data', c => { buf += c.toString('utf8'); let nl; while((nl=buf.indexOf('\n'))>=0){ const line=buf.slice(0,nl).trim(); buf=buf.slice(nl+1); if(!line) continue; let m; try{m=JSON.parse(line);}catch{continue;} if(m.id!==undefined && waiters.has(m.id)){ waiters.get(m.id)(m); waiters.delete(m.id);} } });
function rpc(method, params){ return new Promise((res,rej)=>{ const id=nextId++; const t=setTimeout(()=>{waiters.delete(id);rej(new Error('timeout '+method));},180000); waiters.set(id,(m)=>{clearTimeout(t);res(m.result??m.error);}); child.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method,params:params||{}})+'\n'); }); }
function parse(r){ if(r&&r.content){ const t=r.content.filter(c=>c.type==='text').map(c=>c.text).join('\n'); try{return JSON.parse(t);}catch{return t;} } return r; }
const call = async (n,a) => { const r = parse(await rpc('tools/call',{name:n,arguments:a||{}})); return r; };
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
const boot = await call('get_media_info');
console.log('media', boot.file_name, boot.cartridge_type, 'cgb', boot.cgb_mode ?? boot.is_cgb ?? '?');
await call('debug_step_frame',{frames:400,mode:'sync'});
let shot = await call('get_screenshot');
console.log('shot keys', Object.keys(shot||{}), JSON.stringify(shot).slice(0,200));
fs.writeFileSync('gb/tests/screenshots/_gb_title.png', Buffer.from(shot.data ?? shot.image ?? '', 'base64'));
console.log('wrote shot');
child.kill();
