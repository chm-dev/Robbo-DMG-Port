import { spawn } from 'node:child_process';
import path from 'node:path';
const exe = path.resolve('gearboy', 'Gearboy.exe');
const rom = path.resolve('roms/robbo.gb');
const child = spawn(exe, ['--headless','--mcp-stdio','--portable',rom], { stdio: ['pipe','pipe','pipe'] });
let buf=''; const waiters=new Map(); let nextId=1;
child.stdout.on('data', c => { buf += c.toString('utf8'); let nl; while((nl=buf.indexOf('\n'))>=0){ const line=buf.slice(0,nl).trim(); buf=buf.slice(nl+1); if(!line) continue; let m; try{m=JSON.parse(line);}catch{continue;} if(m.id!==undefined && waiters.has(m.id)){ waiters.get(m.id)(m); waiters.delete(m.id);} } });
function rpc(method, params){ return new Promise((res,rej)=>{ const id=nextId++; const t=setTimeout(()=>{waiters.delete(id);rej(new Error('timeout'));},120000); waiters.set(id,(m)=>{clearTimeout(t);res(m.result??m.error);}); child.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method,params:params||{}})+'\n'); }); }
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
const tools = await rpc('tools/list',{});
for (const t of (tools.tools||[])) if (/screenshot|step_frame|press|input/.test(t.name)) console.log(t.name, JSON.stringify(t.inputSchema).slice(0,400));
child.kill();
