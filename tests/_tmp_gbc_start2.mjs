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
const shot=async(name)=>{ const r=await raw('get_screenshot'); const img=r.content.find(c=>c.type==='image'); fs.writeFileSync('gb/tests/screenshots/'+name, Buffer.from(img.data,'base64')); console.log('wrote',name); };
const rd=(addr,size)=>call('read_memory',{area:4,offset:(addr-0xC000).toString(16).toUpperCase().padStart(4,'0'),size}).then(r=>r.data?r.data.split(' ').map(h=>parseInt(h,16)):[]);
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
const zeros = Array(256).fill('00').join(' ');
for (let i=0;i<32;i++) await call('write_memory',{area:3,offset:'0000',bytes:zeros}).catch(()=>{});
await call('debug_reset');
await call('debug_step_frame',{frames:300,mode:'sync'});
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
for (let i=0;i<8;i++) {
  await call('debug_step_frame',{frames:60,mode:'sync'});
  const m = await rd(0xC0D5,1), l = await rd(0xC0B5,1);
  console.log((i+1)*60,'mode',m[0],'level',l[0]);
}
await shot('_gbc_after_start2.png');
child.kill();
