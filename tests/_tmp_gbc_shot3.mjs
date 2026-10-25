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
const rd=(addr,size)=>call('read_memory',{area:4,offset:(addr-0xC000).toString(16).toUpperCase(),size}).then(r=>r.data?r.data.split(' ').map(h=>parseInt(h,16)):[]);
const shot=async(name)=>{ const r=await raw('get_screenshot'); const img=r.content.find(c=>c.type==='image'); fs.writeFileSync('gb/tests/screenshots/'+name, Buffer.from(img.data,'base64')); };
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
await call('debug_step_frame',{frames:240,mode:'sync'});
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
for (let i=0;i<12;i++) {
  await call('debug_step_frame',{frames:60,mode:'sync'});
  const gm = (await rd(0xC0D5,1))[0], lv = (await rd(0xC0B5,1))[0];
  const pc = await call('get_cpu_status');
  console.log((i+1)*60, 'mode', gm, 'level', lv, 'PC', pc.PC, 'bank', pc.bank);
  if (i===3) await call('controller_button',{player:1,button:'a',action:'press_and_release'});
  if (i===6) await call('controller_button',{player:1,button:'start',action:'press_and_release'});
}
await shot('_gbc_final.png');
child.kill();
