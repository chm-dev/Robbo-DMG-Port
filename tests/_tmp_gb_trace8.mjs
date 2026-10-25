import { spawn } from 'node:child_process';
import path from 'node:path';
const exe = path.resolve('gearboy','Gearboy.exe');
const child = spawn(exe,['--headless','--mcp-stdio','--portable',path.resolve('roms/robbo.gb')],{stdio:['pipe','pipe','pipe']});
let buf='';const w=new Map();let id=1;
child.stdout.on('data',c=>{buf+=c.toString('utf8');let n;while((n=buf.indexOf('\n'))>=0){const l=buf.slice(0,n).trim();buf=buf.slice(n+1);if(!l)continue;let m;try{m=JSON.parse(l);}catch{continue;}if(m.id!==undefined&&w.has(m.id)){w.get(m.id)(m);w.delete(m.id);}}});
const rpc=(m,p)=>new Promise((res,rej)=>{const i=id++;const t=setTimeout(()=>{w.delete(i);rej(new Error('t '+m));},180000);w.set(i,r=>{clearTimeout(t);res(r.result??r.error);});child.stdin.write(JSON.stringify({jsonrpc:'2.0',id:i,method:m,params:p||{}})+'\n');});
const raw=(n,a)=>rpc('tools/call',{name:n,arguments:a||{}});
const parse=(r)=>{ if(r&&r.content){const t=r.content.find(c=>c.type==='text'); try{return JSON.parse(t.text);}catch{return t.text;}} return r; };
const call=async(n,a)=>parse(await raw(n,a));
await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'x',version:'1'}});
await rpc('notifications/initialized',{});
await call('debug_step_frame',{frames:400,mode:'sync'});
await call('set_trace_log',{enabled:true,output:'memory',memory_size:'5M',filters:['cpu.instructions']});
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
await call('debug_step_frame',{frames:45,mode:'sync'});
for (const back of [22000,24000,26000,28000,30000,32000]) {
  const tr = await call('get_trace_log',{count:1000,start:-back});
  const lines = tr.lines||[];
  const i = lines.findIndex(l=>/:41D8|:41D9|:473B/.test(l));
  if (i>=0) { console.log('found at back',back,'idx',i); console.log(lines.slice(Math.max(0,i-30),i+6).join('\n')); break; }
  console.log('back',back,'none');
}
child.kill();
