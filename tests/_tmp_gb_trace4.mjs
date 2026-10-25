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
await call('debug_step_frame',{frames:30,mode:'sync'});
for (const back of [1000, 3000, 8000, 20000, 60000, 150000, 400000]) {
  const tr = await call('get_trace_log',{count:1000,start:-back});
  const lines = tr.lines||[];
  const firstBad = lines.findIndex(l=>/000:0038/.test(l));
  console.log('back', back, 'lines', lines.length, 'firstBad', firstBad, 'sample', lines[0]?.slice(40,120));
}
child.kill();
