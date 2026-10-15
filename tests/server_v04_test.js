'use strict';
// Isolated in-process service/config tests; no socket or ENet coverage is implied.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto'),cp=require('node:child_process'),{EventEmitter}=require('node:events');
const ROOT=path.resolve(__dirname,'..');
process.env.ASTERA_DATA_DIR=path.join(ROOT,'build','server-v04-'+Date.now());
process.env.GODOT_EXECUTABLE=path.resolve(ROOT,'..','tools','godot','Godot_v4.6-stable_win64.exe');
fs.mkdirSync(process.env.ASTERA_DATA_DIR,{recursive:true});
function fixture(id,password,nickname,rating=1200){const salt='fixture-'+id;return {id,nickname,salt,password:crypto.scryptSync(password,salt,32).toString('hex'),rating,wins:3,losses:1,created:1};}
const oldPass='1'.repeat(40),otherPass='2'.repeat(40);
const legacy=fixture('old-auto',oldPass,'지휘관'+oldPass.slice(0,12));
const other=fixture('other-auto',otherPass,'지휘관'+otherPass.slice(0,12));
const similar=fixture('chosen-name','chosen-password','지휘관333333333333');
fs.writeFileSync(path.join(process.env.ASTERA_DATA_DIR,'accounts.json'),JSON.stringify({users:{[legacy.id]:legacy,[other.id]:other,[similar.id]:similar},matches:{preserved:{id:'preserved',players:[]}}}));
const children=[];cp.spawn=()=>{const child=new EventEmitter();child.stdout=new EventEmitter();child.stderr=new EventEmitter();child.kill=()=>child.emit('exit',0);children.push(child);return child;};
const svc=require('../server/server.js');let checks=0;
function check(value,label){assert(value,label);checks++;}
async function api(route,session,body){let status,result;const req={url:route,method:body===undefined?'GET':'POST',socket:{remoteAddress:'v04-test'},headers:{host:'192.168.1.5:17800',...(session?{authorization:'Bearer '+session.token}:{})},async *[Symbol.asyncIterator](){if(body!==undefined)yield Buffer.from(JSON.stringify(body));}};const res={writeHead(code){status=code;},end(data){result=JSON.parse(data);}};try{await svc.api(req,res);}catch(e){status=e.code||500;result={error:e.message};}return {status,...result};}
function validStarts(config,count){return config.spawn_slots.length===count&&new Set(config.spawn_slots).size===count&&config.spawn_slots.every(x=>Number.isInteger(x)&&x>=0&&x<4);}
async function run(){
 const health=await api('/health');check(health.version==='0.4.0'&&health.protocol===4,'new service version and compatible protocol');
 check((await api('/rooms')).status===401,'room entry requires account');
 check((await api('/queue/join',null,{race:0})).status===401,'ladder entry requires account');
 check((await api('/register',null,{nickname:legacy.nickname,password:oldPass})).status===400,'old automatic clients cannot generate accounts');
 const a=await api('/register',null,{nickname:'명시선택A',password:'chosen-password'}),b=await api('/register',null,{nickname:'명시선택B',password:'chosen-password'});
 check(a.user.nickname_confirmed===true&&a.user.rating===1000,'explicit registration is confirmed and starts at 1000');
 check(a.user.win_rate===0&&a.user.games===0,'new account reports actual empty record');
 check((await api('/login',null,{nickname:legacy.nickname,password:oldPass.slice(0,39)+'f'})).status===401,'wrong password cannot classify a legacy account');
 check(!svc._test.db.users[legacy.id].identity_source,'failed proof leaves existing profile intact');
 check((await api('/account/legacy',null,{nickname:similar.nickname,password:'chosen-password'})).status===400,'similar chosen nickname cannot be marked as generated');
 check((await api('/login',null,{nickname:legacy.nickname,password:oldPass})).status===403,'verified generated account cannot enter multiplayer');
 check(svc._test.db.users[legacy.id].identity_source==='legacy_generated','exact generation rule plus valid password verifies legacy account');
 check((await api('/account/legacy',null,{nickname:other.nickname,password:otherPass})).migrated,'stored client proof migrates another generated profile');
 const board=(await api('/leaderboard',a)).users;
 check(!board.some(u=>u.id===legacy.id||u.id===other.id),'verified generated profiles excluded from standings');
 check(board.some(u=>u.id===similar.id),'similar manually chosen nickname remains visible');
 check(board.find(u=>u.id===similar.id).win_rate===75,'win rate derives from actual wins/losses');
 const saved=JSON.parse(fs.readFileSync(path.join(process.env.ASTERA_DATA_DIR,'accounts.json'),'utf8'));
 check(saved.users[legacy.id].rating===1200&&saved.users[legacy.id].wins===3&&saved.matches.preserved.id==='preserved','migration preserves account records and match history');
 for(const map of [0,1,2]){
  let calls=0;const bounds=[];const setup=svc._test.randomMatchSetup(4,true,99,(min,max)=>{bounds.push([min,max]);return calls++===0?map:0;});
  check(setup.map===map&&validStarts(setup,4),'ranked selector can choose each of three maps and four unique starts');
  check(JSON.stringify(bounds)===JSON.stringify([[0,3],[0,4],[0,3],[0,2]]),'uniform bounded map draw and Fisher-Yates bounds');
 }
 check(svc._test.randomMatchSetup(2,false,1,()=>0).map===1,'custom map selection preserved');
 assert.throws(()=>svc._test.randomMatchSetup(2,false,9),/전장/);checks++;
 assert.throws(()=>svc._test.randomMatchSetup(5,true,0),/인원/);checks++;
 await api('/queue/join',a,{race:0,map:99,spawn_slots:[0,0]});await api('/queue/join',b,{race:1,map:-1,spawn_slots:[3,3]});
 const offer=(await api('/queue/state',a)).offer;
 await api('/queue/accept',a,{id:offer.id,map:99,spawn_slots:[0,0]});await api('/queue/accept',b,{id:offer.id,map:99,spawn_slots:[0,0]});
 const game=(await api('/queue/state',a)).game,g=svc._test.games.get(game.id),config=JSON.parse(fs.readFileSync(g.configPath,'utf8'));
 check(Number.isInteger(config.map)&&config.map>=0&&config.map<3,'ranked client cannot choose or poison server map');
 check(validStarts(config,2),'ranked server writes distinct random starts');
 check(config.players[0].name===a.user.nickname&&config.players[1].name===b.user.nickname,'start shuffle preserves authoritative owner/player order');
 check(game.spawn_slot===config.spawn_slots[game.slot]&&!('spawn_slots' in game),'client receives only its own confirmed start, not enemy starts');
 svc.finishGame(g,{void:true,reason:'configuration test'});
 check((await api('/room/create',a,{race:2,map:1.5})).status===400,'fractional custom map is rejected');
 const room=(await api('/room/create',a,{race:2,map:2})).room;
 check((await api('/room/update',a,{id:room.id,map:99})).status===400&&svc._test.rooms.get(room.id).map===2,'invalid custom map cannot corrupt room selection');
 await api('/room/update',a,{id:room.id,add_bot:true});await api('/room/update',a,{id:room.id,ready:true});
 const actual=svc._test.rooms.get(room.id),future=Date.now()+5100;for(const member of actual.members)member.seen=future;svc._test.maintainRooms(future);
 const custom=svc._test.games.get(actual.game),customConfig=JSON.parse(fs.readFileSync(custom.configPath,'utf8'));
 check(customConfig.map===2&&validStarts(customConfig,2),'custom preserves selected map and randomizes starts');
 check(customConfig.players[0].race===2&&!customConfig.ranked,'custom faction and unranked mode preserved');
 console.log('SERVER_V04_TEST checks='+checks+' failures=0 (in-process auth/config; no socket/ENet test)');
}
run().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>{for(const child of children)child.kill();});
