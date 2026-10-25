import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
const exe = path.resolve('gearboy','Gearboy.exe');
const rom = path.resolve('robbo-gbc/build/robbo.gbc');
const child = spawn(exe,['--headless','--mcp-stdio','--portable',rom],{stdio:['pipe','pipe','pipe']});
let buf='';const w=new Map();let id=1;
child.stdout.on('data',c=>{buf+=c.toString('utf8');let n;while((n=buf.indexOf('\n'))>=0){const l=buf.slice(0,n).trim();buf=buf.slice(n+1);if(!l)continue;let m;try{m=JSON.parse(l);}catch{continue;}if(m.id!==undefined&&w.has(m.id)){w.get(m.id)(m);w.delete(m.id);}}});
const rpc=(m,p)=>new Promise((res,rej)=>{const i=id++;const t=setTimeout(()=>{w.delete(i);rej(new Error('t '+m));},180000);w.set(i,r=>{clearTimeout(t);res(r.result??r.error);});child.stdin.write(JSON.stringify({jsonrpc:'2.0',id:i,method:m,params:p||{}})+'\n');});
const raw=(n,a)=>rpc('tools/call',{name:n,arguments:a||{}});
const parse=(r)=>{ if(r&&r.content){const t=r.content.find(c=>c.type==='text'); try{return JSON.parse(t.text);}catch{return t.text;}} return r; };
const call=async(n,a)=>parse(await raw(n,a));
const shot=async(name)=>{ const r=await raw('get_screenshot'); const img=r.content.find(c=>c.type==='image'); fs.writeFileSync('gb/tests/screenshots/'+name, Buffer.from(img.data,'base64')); console.log('wrote', name); };
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
await call('debug_step_frame',{frames:240,mode:'sync'});
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
for (const [f,name] of [[120,'_gbc_01.png'],[180,'_gbc_02.png'],[240,'_gbc_03.png'],[300,'_gbc_04.png']]) {
  await call('debug_step_frame',{frames:f,mode:'sync'});
  await shot(name);
}
child.kill();
