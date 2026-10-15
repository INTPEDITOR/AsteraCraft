'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const ROOT=path.resolve(__dirname,'..'),DATA=path.join(ROOT,'build','net-test-'+Date.now());fs.mkdirSync(DATA,{recursive:true});
const engine=path.resolve(ROOT,'..','tools','godot','Godot_v4.6-stable_win64_console.exe');
const env={...process.env,PORT:'17841',HOST:'127.0.0.1',GAME_PORT:'17941',GODOT_EXECUTABLE:engine,ASTERA_DATA_DIR:DATA,APPDATA:path.join(DATA,'userdata')};fs.mkdirSync(env.APPDATA,{recursive:true});
let serverLog='',clients=[];
const server=cp.spawn(process.execPath,[path.join(ROOT,'server','server.js')],{cwd:ROOT,env,windowsHide:true});server.stdout.on('data',d=>serverLog+=d);server.stderr.on('data',d=>serverLog+=d);
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function api(route,session,body){const r=await fetch('http://127.0.0.1:17841'+route,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(session?{Authorization:'Bearer '+session.token}:{})},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,...await r.json()};}
async function poll(fn,seconds=15){const until=Date.now()+seconds*1000;while(Date.now()<until){const v=await fn();if(v)return v;await delay(150);}throw Error('poll timeout');}
function client(game,surrender){const file=path.join(DATA,'client-'+game.slot+'-'+Date.now()+'.json');fs.writeFileSync(file,JSON.stringify({...game,surrender}));return new Promise((resolve,reject)=>{let out='';const p=cp.spawn(engine,['--headless','--path',ROOT,'--','--test-client',file],{cwd:ROOT,env,windowsHide:true});clients.push(p);p.stdout.on('data',d=>out+=d);p.stderr.on('data',d=>out+=d);p.on('error',reject);p.on('exit',code=>{if(code!==0||!out.includes('ASTERA_CLIENT_RESULT'))reject(Error('Client failed '+code+' '+out));else resolve(out);});});}
async function play(games){const result=await Promise.all(games.map((g,i)=>client(g,i===0)));assert(result.every(s=>!s.includes('SCRIPT ERROR')&&!s.includes('ERROR:')),result.join('\n'));}
async function run(){
 await poll(async()=>{try{return (await api('/health')).ok;}catch(error){const code=error.cause?.code||error.code;if(code==='EACCES'||code==='EPERM')throw new Error('Local socket access is denied by this execution environment ('+code+'). Run tests/loopback_diagnostic.js for evidence.',{cause:error});return false;}});
 assert.equal((await api('/me')).status,401);
 const a=await api('/register',null,{nickname:'테스트A',password:'test-pass-8546'}),b=await api('/register',null,{nickname:'테스트B',password:'test-pass-8546'});
 assert.equal(a.user.rating,1000);assert.equal(b.user.rating,1000);
 assert.equal((await api('/login',null,{nickname:'테스트A',password:'wrong-pass'})).status,401);
 const room=(await api('/room/create',a,{name:'통합 테스트',race:0})).room;
 await api('/room/join',b,{id:room.id,race:2});
 assert.equal((await api('/room/start',b,{id:room.id})).status,403);
 assert.equal((await api('/room/start',a,{id:room.id})).status,409);
 await api('/room/leave',a,{});assert.equal((await api('/room/state',b)).room.owner,b.user.id);await api('/room/leave',b,{});
 await api('/queue/join',a,{race:0});await api('/queue/join',b,{race:2});
 const offer=(await api('/queue/state',a)).offer;assert(offer);
 await api('/queue/accept',a,{id:offer.id});await api('/queue/accept',b,{id:offer.id});
 const ga=(await api('/queue/state',a)).game,gb=(await api('/queue/state',b)).game;assert(ga.ranked&&gb.ranked);
 await play([ga,gb]);
 const ranked=await poll(async()=>{const r=await api('/game?id='+ga.id,a);return r.game?.status==='finished'?r:false;});
 assert.equal(ranked.user.rating,980);assert.equal((await api('/me',b)).user.rating,1020);assert.equal(ranked.game.result.delta,20);
 assert.equal((await api('/history',a)).matches.length,1);
 assert.equal((await api('/queue/join',a,{race:1})).status,200);assert((await api('/queue/state',a)).queued);await api('/queue/leave',a,{});
 console.log('PASS ranked: real ENet clients + authoritative result + 1000 -> 980/1020 + requeue');
 const custom=(await api('/room/create',a,{name:'커스텀',race:1,map:1})).room;
 await api('/room/join',b,{id:custom.id,race:0});await api('/room/update',b,{id:custom.id,ready:true});
 await api('/room/update',a,{id:custom.id,ready:true});
 const cga=await poll(async()=>{await api('/room/state',b);const state=await api('/room/state',a);return state.game||false;},10),cgb=(await api('/room/state',b)).game;assert(!cga.ranked);
 await play([cga,cgb]);
 await poll(async()=>{const r=await api('/game?id='+cga.id,a);return r.game?.status==='finished';});
 assert.equal((await api('/me',a)).user.rating,980);assert.equal((await api('/me',b)).user.rating,1020);
 assert.equal((await api('/history',a)).matches.length,2);
 const db=JSON.parse(fs.readFileSync(path.join(DATA,'accounts.json'),'utf8'));
 assert.equal(Object.keys(db.matches).length,2);assert(!serverLog.includes('SCRIPT ERROR'),serverLog);
 console.log('PASS custom: owner/ready rules, owner transfer, real match, no rating change, persistence');
 fs.writeFileSync(path.join(ROOT,'build','network-test-result.txt'),'PASS ranked and custom end-to-end\n'+serverLog);
}
run().then(()=>console.log('NETWORK_TEST PASS')).catch(e=>{console.error(e);console.error(serverLog);process.exitCode=1;}).finally(()=>{for(const p of clients)if(p.exitCode===null)p.kill();server.kill();});
