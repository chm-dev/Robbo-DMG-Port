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
await call('controller_button',{player:1,button:'start',action:'press_and_release'});
let hist=[];
for (let f=0; f<100; f++) {
  await call('debug_step_frame',{frames:1,mode:'sync'});
  const c = await call('get_cpu_status');
  hist.push(`${f+1} ${c.PC}/${c.bank} IE=${c.IE} IF=${c.IF} SP=${c.SP}`);
  if (c.PC === '0038') break;
}
console.log(hist.slice(-25).join('\n'));
child.kill();
