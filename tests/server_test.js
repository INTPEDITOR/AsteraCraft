'use strict';
// In-process API integration. Does not claim socket/ENet end-to-end coverage.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const ROOT=path.resolve(__dirname,'..');
process.env.ASTERA_DATA_DIR=path.join(ROOT,'build','api-test-'+Date.now());
process.env.GODOT_EXECUTABLE=[process.env.GODOT_EXECUTABLE,path.resolve(ROOT,'..','tools','godot','Godot_v4.6-stable_win64.exe'),path.resolve(ROOT,'..','AsteraCraft-Windows','AsteraCraft.exe')].filter(Boolean).find(p=>fs.existsSync(p))||'';
process.env.APPDATA=path.join(process.env.ASTERA_DATA_DIR,'userdata');fs.mkdirSync(process.env.APPDATA,{recursive:true});
const svc=require('../server/server.js');
let checks=0;
function check(value,message){assert(value,message);checks++;}
async function request(route,session,body){
 const req={url:route,method:body===undefined?'GET':'POST',socket:{remoteAddress:'test-process'},headers:{host:'127.0.0.1:17800',...(session?{authorization:'Bearer '+session.token}:{})},async *[Symbol.asyncIterator](){if(body!==undefined)yield Buffer.from(JSON.stringify(body));}};
 let status,result;
 const res={writeHead(code){status=code;},end(s){result=JSON.parse(s);}};
 try{await svc.api(req,res);}catch(e){status=e.code||500;result={error:e.message};}
 return {status,...result};
}
async function startReadyRoom(session,id){
 await request('/room/update',session,{id,ready:true});
 const r=svc._test.rooms.get(id),now=Date.now()+5100;
 for(const m of r.members)m.seen=now;
 svc._test.maintainRooms(now);
 return (await request('/room/state',session)).game;
}
async function run(){
 check((await request('/health')).ok,'health');check((await request('/me')).status===401,'auth required');
 const a=await request('/register',null,{nickname:'검증A',password:'password-test'}),b=await request('/register',null,{nickname:'검증B',password:'password-test'});
 check(a.user.rating===1000&&b.user.rating===1000,'initial rating');
 check(!('password' in a.user)&&!('salt' in a.user),'no credentials in response');
 check((await request('/register',null,{nickname:'검증A',password:'password-test'})).status===409,'duplicate nickname');
 check((await request('/login',null,{nickname:'검증A',password:'wrong-password'})).status===401,'wrong password');
 check((await request('/login',null,{nickname:'검증A',password:'password-test'})).status===200,'login');
 const room=(await request('/room/create',a,{race:0,name:'Test',password:'private'})).room;
 check((await request('/room/join',b,{id:room.id})).status===403,'room password');
 await request('/room/join',b,{id:room.id,password:'private',race:2});
 check((await request('/room/start',b,{id:room.id})).status===403,'owner-only start');
 check((await request('/room/start',a,{id:room.id})).status===409,'ready gate');
 await request('/room/leave',a,{});check((await request('/room/state',b)).room.owner===b.user.id,'owner transfer');await request('/room/leave',b,{});
 check((await request('/queue/join',a,{race:0})).status===200,'queue A');await request('/queue/join',b,{race:2});
 const offer=(await request('/queue/state',a)).offer;check(!!offer,'matching nearby ratings');
 check((await request('/queue/accept',a,{id:'invalid'})).status===404,'reject invalid acceptance');
 await request('/queue/accept',a,{id:offer.id});await request('/queue/accept',b,{id:offer.id});
 const ga=(await request('/queue/state',a)).game,gb=(await request('/queue/state',b)).game;
 check(ga.id===gb.id&&ga.ranked&&ga.ticket!==gb.ticket,'separate battle tickets');
 check((await request('/queue/join',a,{race:0})).status===409,'no double match');
 check((await request('/active',a)).game.id===ga.id,'reconnect discovery');
 const g=svc._test.games.get(ga.id);svc.finishGame(g,{winners:[1],duration:123});
 check((await request('/me',a)).user.rating===980,'loser -20');check((await request('/me',b)).user.rating===1020,'winner +20');
 svc.finishGame(g,{winners:[1],duration:123});check((await request('/me',b)).user.rating===1020,'result idempotency');
 check(svc.elo(1000,1200)===30&&svc.elo(1200,1000)===10,'higher/lower opponent delta');
 check((await request('/queue/join',a,{race:1})).status===200,'requeue after result');await request('/queue/leave',a,{});
 const custom=(await request('/room/create',a,{race:1,map:1})).room;
 await request('/room/update',a,{id:custom.id,add_bot:true,bot_race:2});
 const cg=await startReadyRoom(a,custom.id);
 check(!cg.ranked,'custom never ranked');svc.finishGame(svc._test.games.get(cg.id),{winners:[0],duration:100});
 check((await request('/me',a)).user.rating===980,'custom preserves rating');
 check((await request('/room/state',a)).room.status==='waiting','room reusable after game');
 check((await request('/history',a)).matches.length===2,'history');
 const voidg=await startReadyRoom(a,custom.id);svc.finishGame(svc._test.games.get(voidg.id),{void:true,reason:'test crash'});
 check((await request('/me',a)).user.rating===980,'void preserves rating');
 const saved=JSON.parse(fs.readFileSync(path.join(process.env.ASTERA_DATA_DIR,'accounts.json'),'utf8'));
 check(Object.keys(saved.matches).length===2,'persistent completed matches');
 check(Object.values(saved.users).every(u=>u.password.length===64&&u.password!=='password-test'),'hashed passwords');
 console.log('SERVER_TEST checks='+checks+' failures=0 (in-process API; socket tests require unrestricted network)');
}
run().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{for(const g of svc._test.games.values())g.child?.kill();setTimeout(()=>process.exit(process.exitCode||0),300).unref();});
