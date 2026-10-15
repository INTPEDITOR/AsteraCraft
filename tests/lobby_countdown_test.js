'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const ROOT=path.resolve(__dirname,'..');
process.env.ASTERA_DATA_DIR=path.join(ROOT,'build','lobby-v03-test-'+Date.now());
process.env.GODOT_EXECUTABLE=path.join(ROOT,'..','tools','godot','Godot_v4.6-stable_win64.exe');
process.env.APPDATA=path.join(process.env.ASTERA_DATA_DIR,'userdata');fs.mkdirSync(process.env.APPDATA,{recursive:true});
const svc=require('../server/server.js');let checks=0;
function check(value,label){assert(value,label);checks++;}
async function api(route,session,body){let code,data;const req={url:route,method:body===undefined?'GET':'POST',socket:{remoteAddress:'countdown-test'},headers:{host:'192.168.1.10:17800',...(session?{authorization:'Bearer '+session.token}:{})},async *[Symbol.asyncIterator](){if(body!==undefined)yield Buffer.from(JSON.stringify(body));}};const res={writeHead(c){code=c;},end(s){data=JSON.parse(s);}};try{await svc.api(req,res);}catch(e){code=e.code||500;data={error:e.message};}return {status:code,...data};}
function elapse(r,ms,alive=true){const future=Date.now()+ms;if(alive)for(const m of r.members)m.seen=future;svc._test.maintainRooms(future);}
async function run(){
 const a=await api('/register',null,{nickname:'CountdownA',password:'test-password'}),b=await api('/register',null,{nickname:'CountdownB',password:'test-password'});
 check(a.user.rating===1000&&b.user.rating===1000,'rating starts at 1000');
 const created=(await api('/room/create',a,{race:0,name:'Countdown'})).room;
 check(!created.members[0].ready&&created.countdown===null,'creator must explicitly ready');
 check((await api('/room/join',a,{id:created.id,race:0})).room.id===created.id&&svc._test.rooms.has(created.id),'re-entering own waiting room preserves room membership');
 await api('/room/join',b,{id:created.id,race:1});const r=svc._test.rooms.get(created.id);
 await api('/room/update',a,{id:r.id,ready:true});check(!r.countdown,'one ready never starts');
 let reply=await api('/room/update',b,{id:r.id,ready:true});check(reply.room.countdown===5&&!reply.room.locked,'second ready starts 5-second countdown');
 check(!reply.game&&r.status==='waiting','no immediate start');
 reply=await api('/room/update',a,{id:r.id,ready:false});check(reply.status===200&&!r.countdown,'unready cancels before 3 seconds');
 await api('/room/update',a,{id:r.id,ready:true});r.countdown=Date.now()+2800;
 reply=await api('/room/update',a,{id:r.id,ready:false});check(reply.status===409&&r.members[0].ready,'3-second ready lock is authoritative');
 check((await api('/room/update',a,{id:r.id,map:2})).status===409,'map is locked too');
 check((await api('/room/state',b)).room.locked,'clients receive lock state');
 await api('/room/leave',b,{});check(!r.countdown&&r.members.length===1,'leaving always cancels a locked countdown');
 await api('/room/join',b,{id:r.id,race:1});await api('/room/update',b,{id:r.id,ready:true});
 check(!!r.countdown,'fresh membership can start a new countdown');
 r.members.find(m=>m.user===b.user.id).seen=Date.now()-4000;r.countdown=Date.now()-1;svc._test.maintainRooms();
 check(!r.game&&!r.countdown&&!r.members.find(m=>m.user===b.user.id).ready,'missing heartbeat prevents launch');
 await api('/room/update',b,{id:r.id,ready:true});elapse(r,5100);
 check(r.status==='playing'&&!!r.game,'automatic start after full 5 seconds');
 const ga=(await api('/room/state',a)).game,gb=(await api('/room/state',b)).game;
 check(ga.id===gb.id&&ga.ticket!==gb.ticket,'each player gets unique battle ticket');
 check(ga.host==='192.168.1.10'&&!ga.ranked,'LAN host is reachable service address; custom remains unranked');
 svc.finishGame(svc._test.games.get(ga.id),{winners:[0],duration:60});
 check(r.status==='waiting'&&r.members.every(m=>!m.ready),'completed match resets all human readiness');
 check((await api('/me',a)).user.rating===1000,'custom does not change rating');
 check(svc.elo(1000,1200)===30&&svc.elo(1200,1000)===10,'Elo weighting preserved');
 console.log('LOBBY_COUNTDOWN_TEST checks='+checks+' failures=0 (in-process API and authoritative timer)');
}
run().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>{for(const g of svc._test.games.values())g.child?.kill();setTimeout(()=>process.exit(process.exitCode||0),200).unref();});
