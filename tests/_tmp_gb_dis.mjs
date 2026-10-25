import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
const exe = path.resolve('gearboy', 'Gearboy.exe');
const child = spawn(exe, ['--headless','--mcp-stdio','--portable',path.resolve('roms/robbo.gb')], { stdio:['pipe','pipe','pipe'] });
let buf=''; const w=new Map(); let id=1;
child.stdout.on('data',c=>{buf+=c.toString('utf8');let n;while((n=buf.indexOf('\n'))>=0){const l=buf.slice(0,n).trim();buf=buf.slice(n+1);if(!l)continue;let m;try{m=JSON.parse(l);}catch{continue;}if(m.id!==undefined&&w.has(m.id)){w.get(m.id)(m);w.delete(m.id);} }});
const rpc=(m,p)=>new Promise((res,rej)=>{const i=id++;const t=setTimeout(()=>{w.delete(i);rej(new Error('t '+m));},180000);w.set(i,r=>{clearTimeout(t);res(r.result??r.error);});child.stdin.write(JSON.stringify({jsonrpc:'2.0',id:i,method:m,params:p||{}})+'\n');});
const raw=(n,a)=>rpc('tools/call',{name:n,arguments:a||{}});
const parse=(r)=>{ if(r&&r.content){const t=r.content.find(c=>c.type==='text'); try{return JSON.parse(t.text);}catch{return t.text;}} return r; };
const call=async(n,a)=>parse(await raw(n,a));
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
await call('debug_step_frame',{frames:400,mode:'sync'});
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
await call('debug_step_frame',{frames:240,mode:'sync'});
for (const a of [0x0038,0x3DE0,0x3F00]) {
  const d = await call('get_disassembly',{start_address:a,count:24});
  console.log('--- ', a.toString(16));
  console.log(typeof d === 'string' ? d : (d.instructions||d.lines||JSON.stringify(d)).toString().slice(0,1200));
}
const st = await call('read_memory',{area:4,offset:(0xDCF8-0xC000).toString(16),size:32});
console.log('stack', typeof st === 'string' ? st : JSON.stringify(st));
child.kill();
