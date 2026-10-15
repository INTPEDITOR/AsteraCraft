'use strict';
// Dependency-free local/LAN account, lobby, matchmaking and authoritative-game service.
const http=require('node:http'), fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto'), cp=require('node:child_process'), dgram=require('node:dgram');
const ROOT=path.resolve(__dirname,'..');
const DATA=process.env.ASTERA_DATA_DIR||path.join(__dirname,'data');
fs.mkdirSync(DATA,{recursive:true});
const DBFILE=path.join(DATA,'accounts.json');
let db={users:{},matches:{}};
if(fs.existsSync(DBFILE)){try{db=JSON.parse(fs.readFileSync(DBFILE,'utf8'));}catch(e){console.error('Account database cannot be read; stopping to preserve data.');process.exit(1);}}
const sessions=new Map(),rooms=new Map(),queue=new Map(),offers=new Map(),games=new Map(),cooldowns=new Map();
const PORT=Number(process.env.PORT||17800), HOST=process.env.HOST||'0.0.0.0';
const PUBLIC_HOST=process.env.PUBLIC_HOST||'';
let gamePort=Number(process.env.GAME_PORT||17900);
const VERSION='0.5.6', STARTED=Date.now(), DISCOVERY_PORT=Number(process.env.ASTERA_DISCOVERY_PORT||17801);
function save(){const temp=DBFILE+'.tmp';fs.writeFileSync(temp,JSON.stringify(db,null,2));fs.renameSync(temp,DBFILE);}
function token(){return crypto.randomBytes(24).toString('hex');}
function uid(){return crypto.randomUUID();}
function safeUser(u){const played=u.wins+u.losses;return {id:u.id,nickname:u.nickname,nickname_confirmed:u.identity_source!=='legacy_generated',rating:u.rating,wins:u.wins,losses:u.losses,games:played,win_rate:played?Math.round(u.wins/played*1000)/10:0};}
// v0.3 generated this exact nickname/password pair. A similar-looking name alone is never proof.
function legacyGeneratedCredentials(nickname,password){return /^[0-9a-f]{40}$/.test(password)&&nickname==='지휘관'+password.slice(0,12);}
function verifyPassword(u,password){const attempt=hash(password,u?.salt||'invalid-user-salt');return !!u&&crypto.timingSafeEqual(Buffer.from(attempt,'hex'),Buffer.from(u.password,'hex'));}
function markLegacyAccount(u){if(u.identity_source!=='legacy_generated'){u.identity_source='legacy_generated';u.legacy_verified_at=Date.now();save();}}
function hash(pass,salt){return crypto.scryptSync(pass,salt,32).toString('hex');}
function elo(a,b){return Math.max(1,Math.round(40*(1-1/(1+10**((b-a)/400)))));}
function response(res,status,body){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(body));}
function error(code,message){const e=new Error(message);e.code=code;throw e;}
function requireUser(req){const t=String(req.headers.authorization||'').replace(/^Bearer /,'');const s=sessions.get(t);if(!s||Date.now()-s.at>86400000)error(401,'다시 로그인하세요.');const u=db.users[s.id];if(!u||u.identity_source==='legacy_generated')error(401,'직접 정한 닉네임으로 가입하거나 로그인하세요.');s.at=Date.now();return u;}
function requireRoom(user,id){const r=rooms.get(id);if(!r||!r.members.some(m=>m.user===user.id))error(404,'방을 찾을 수 없습니다.');return r;}
function userBusy(id){for(const g of games.values())if(g.status==='playing'&&g.people.some(p=>p.user===id))return true;return false;}
function sanitizeRace(v){const n=Number(v);if(!Number.isInteger(n)||n<0||n>2)error(400,'종족을 확인하세요.');return n;}
function sanitizeMap(v){const n=Number(v);if(!Number.isInteger(n)||n<0||n>2)error(400,'전장을 확인하세요.');return n;}
function cleanRoom(r){const remaining=r.countdown?Math.max(0,Math.ceil((r.countdown-Date.now())/1000)):null;return {id:r.id,name:r.name,owner:r.owner,map:r.map,mode:r.mode,password:!!r.password,members:r.members.map(({seen,...m})=>({...m,nickname:m.bot?m.nickname:db.users[m.user].nickname})),status:r.status,countdown:remaining,locked:remaining!==null&&remaining<=3,start_error:r.start_error||null};}
function gameInfo(g,user){const p=g.people.find(x=>x.user===user.id);return {id:g.id,status:g.status,host:g.host,port:g.port,ticket:p?.ticket,slot:p?.slot,spectator:!!p?.observer,ranked:g.ranked,map:g.map,spawn_slot:g.spawn_slots?.[p?.slot],mode:g.mode,result:g.result||null};}
function randomMatchSetup(playerCount,ranked,map,randomInt=crypto.randomInt){
 if(!Number.isInteger(playerCount)||playerCount<2||playerCount>4)error(400,'참가 인원을 확인하세요.');
 const chosen=ranked?randomInt(0,3):sanitizeMap(map);
 const slots=[0,1,2,3];for(let i=slots.length-1;i>0;i--){const j=randomInt(0,i+1);[slots[i],slots[j]]=[slots[j],slots[i]];}
 return {map:chosen,spawn_slots:slots.slice(0,playerCount)};
}
function enginePath(){const candidates=[process.env.GODOT_EXECUTABLE,path.join(ROOT,'AsteraCraft.exe'),path.join(ROOT,'build','AsteraCraft.exe'),path.join(ROOT,'runtime','Godot.exe'),path.join(ROOT,'..','tools','godot','Godot_v4.6-stable_win64.exe')].filter(Boolean);return candidates.find(p=>fs.existsSync(p));}
function projectArguments(engine){
 const pack=path.join(ROOT,'AsteraCraft.pck');
 // Release templates load their sibling PCK automatically and reject path overrides.
 if(fs.existsSync(pack)&&path.resolve(engine).toLowerCase()===path.join(ROOT,'AsteraCraft.exe').toLowerCase())return [];
 return fs.existsSync(pack)?['--main-pack',pack]:['--path',ROOT];
}
function startGame(members,map,mode,ranked,host){
 const active=members.filter(m=>!m.observer),watchers=members.filter(m=>m.observer);
 if(ranked&&watchers.length)error(400,'래더에는 관전자를 추가할 수 없습니다.');
 const setup=randomMatchSetup(active.length,ranked,map);map=setup.map;
 const engine=enginePath();if(!engine)error(503,'Godot 실행 파일을 찾지 못했습니다. 서버 실행 안내를 확인하세요.');
 const id=uid(),port=gamePort++;if(gamePort>18000)gamePort=17900;
 const people=[...active,...watchers].map((m,i)=>({...m,slot:m.observer?-1:i,ticket:token(),rating:m.bot?null:db.users[m.user].rating}));
 const config={id,port,seed:crypto.randomInt(1,100000000),map,spawn_slots:setup.spawn_slots,mode,ranked,lobby_countdown_done:!ranked,players:people.filter(p=>!p.observer).map(p=>({name:p.bot?p.nickname:db.users[p.user].nickname,race:p.race,team:p.team??p.slot,bot:!!p.bot,difficulty:p.difficulty??1,ticket:p.ticket})),observers:people.filter(p=>p.observer).map(p=>({ticket:p.ticket}))};
 const configPath=path.join(DATA,`match-${id}.json`);fs.writeFileSync(configPath,JSON.stringify(config));
 const g={id,port,host:PUBLIC_HOST||host,people,map,spawn_slots:setup.spawn_slots,mode,ranked,status:'playing',created:Date.now(),configPath};games.set(id,g);
 const projectArgs=projectArguments(engine);
 const child=cp.spawn(engine,['--headless',...projectArgs,'--','--battle-config',configPath],{cwd:ROOT,windowsHide:true,stdio:['ignore','pipe','pipe']});g.child=child;
 let buffer='';child.stdout.on('data',chunk=>{buffer+=chunk.toString();let n;while((n=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,n).trim();buffer=buffer.slice(n+1);if(line.startsWith('ASTERA_RESULT ')){try{finishGame(g,JSON.parse(line.slice(14)));}catch(e){console.error('Invalid game result:',e.message);}}}});
 child.stderr.on('data',d=>{const s=d.toString();if(/ERROR|SCRIPT ERROR/.test(s))console.error(`[game ${id.slice(0,8)}] ${s.trim()}`);});
 child.on('error',e=>{finishGame(g,{void:true,reason:'전투 서버를 시작하지 못했습니다. 점수 변화 없음.'});console.error(e.message);});
 child.on('exit',()=>{if(g.status==='playing')finishGame(g,{void:true,reason:'전투 서버가 종료되었습니다. 점수 변화 없음.'});try{fs.unlinkSync(configPath);}catch{}});
 console.log(`Game ${id.slice(0,8)} ${ranked?'ranked':'custom'} port ${port}`);
 return g;
}
function finishGame(g,result){
 if(g.status!=='playing'||db.matches[g.id])return;
 for(const [id,o] of offers)if(o.game===g.id)offers.delete(id);
 for(const r of rooms.values())if(r.game===g.id){r.status='waiting';delete r.game;cancelCountdown(r);for(const m of r.members){m.ready=!!m.bot;m.seen=Date.now();}}
 if(result.void){g.status='void';g.result={reason:String(result.reason||'경기 무효'),delta:0};return;}
 const winners=Array.isArray(result.winners)?result.winners.filter(Number.isInteger):[];
 const valid=winners.length>0&&winners.every(i=>g.people.some(p=>!p.observer&&p.slot===i));
 if(!valid){g.status='void';g.result={reason:'승패를 확정하지 못했습니다. 점수 변화 없음.'};return;}
 let change=0;
 if(g.ranked){
  if(g.people.length!==2||g.people.some(p=>p.bot)||winners.length!==1){g.status='void';return;}
  const w=g.people[winners[0]],l=g.people[1-winners[0]];const wu=db.users[w.user],lu=db.users[l.user];
  // The delta is computed once and applied as a zero-sum transaction.
  change=elo(w.rating,l.rating);wu.rating+=change;lu.rating-=change;wu.wins++;lu.losses++;wu.lastOpponent=lu.id;lu.lastOpponent=wu.id;
 }
 g.status='finished';g.result={winners,delta:change,duration:Number(result.duration||0),reason:result.reason||'경기 종료'};
 db.matches[g.id]={id:g.id,ranked:g.ranked,time:Date.now(),players:g.people.filter(p=>!p.bot).map(p=>({id:p.user,name:db.users[p.user].nickname,race:p.race,before:p.rating,after:db.users[p.user].rating})),...g.result};
 save();
}
function roomForUser(id){return [...rooms.values()].find(r=>r.members.some(m=>m.user===id));}
function cancelCountdown(r){delete r.countdown;delete r.countdown_members;}
function leaveRoom(id){for(const [rid,r] of rooms){if(r.members.some(m=>m.user===id))cancelCountdown(r);r.members=r.members.filter(m=>m.user!==id);if(!r.members.some(m=>!m.bot)){rooms.delete(rid);continue;}if(r.owner===id)r.owner=r.members.find(m=>!m.bot).user;}}
function canStartRoom(r){const active=r.members.filter(m=>!m.observer);return r.status==='waiting'&&active.length>=2&&active.length<=4&&active.every(m=>m.ready)&&(r.mode!=='teams'||new Set(active.map(m=>m.team)).size>=2);}
function beginCountdown(r,now=Date.now()){if(!r.countdown&&canStartRoom(r)){r.countdown=now+5000;r.countdown_members=r.members.map(m=>m.user).join('|');delete r.start_error;}}
function maintainRooms(now=Date.now()){
 for(const r of rooms.values()){
  if(r.status!=='waiting')continue;
  for(const m of [...r.members])if(!m.bot&&now-(m.seen||now)>8000)leaveRoom(m.user);
  if(!rooms.has(r.id)||!r.countdown)continue;
  if(!canStartRoom(r)||r.countdown_members!==r.members.map(m=>m.user).join('|')){cancelCountdown(r);continue;}
  if(now<r.countdown)continue;
  const missing=r.members.filter(m=>!m.bot&&!m.observer&&now-(m.seen||0)>2500);
  if(missing.length){for(const m of missing)m.ready=false;cancelCountdown(r);r.start_error='연결 상태가 바뀌어 시작을 취소했습니다.';continue;}
  try{const g=startGame(r.members,r.map,r.mode,false,r.host||'127.0.0.1');r.status='playing';r.game=g.id;cancelCountdown(r);}catch(e){cancelCountdown(r);for(const m of r.members)if(!m.bot)m.ready=false;r.start_error=e.message;}
 }
}
function offerForUser(id){return [...offers.values()].find(o=>o.users.includes(id)&&(!o.game||games.get(o.game)?.status==='playing'));}
function latestGame(id){return [...games.values()].reverse().find(g=>g.people.some(p=>p.user===id));}
function matchQueues(){
 const now=Date.now();
 for(const [id,o] of offers){if(o.until<now&&!o.game){offers.delete(id);for(const user of o.users)cooldowns.set(user,now+30000);}}
 const list=[...queue.values()].sort((a,b)=>a.at-b.at);const used=new Set();
 for(const a of list){if(used.has(a.user)||!queue.has(a.user)||userBusy(a.user)||offerForUser(a.user))continue;
  const elapsed=(now-a.at)/1000;const range=elapsed<20?100:elapsed<45?150:elapsed<90?250:350;
  const candidates=list.filter(b=>b.user!==a.user&&!used.has(b.user)&&queue.has(b.user)&&!userBusy(b.user)&&!offerForUser(b.user)&&Math.abs(db.users[b.user].rating-db.users[a.user].rating)<=range);
  candidates.sort((b,c)=>Math.abs(db.users[b.user].rating-db.users[a.user].rating)-Math.abs(db.users[c.user].rating-db.users[a.user].rating));
  const b=candidates[0];if(!b)continue;
  used.add(a.user);used.add(b.user);queue.delete(a.user);queue.delete(b.user);
  const id=uid();offers.set(id,{id,users:[a.user,b.user],entries:[a,b],accepted:[],until:now+20000});
 }
}
const limiter=new Map();
async function api(req,res){
 const ip=req.socket.remoteAddress||'unknown';const limit=limiter.get(ip)||{at:Date.now(),n:0};if(Date.now()-limit.at>60000){limit.at=Date.now();limit.n=0;}limit.n++;limiter.set(ip,limit);if(limit.n>600)error(429,'요청이 너무 많습니다. 잠시 후 시도하세요.');
 const url=new URL(req.url,'http://localhost');
 let body={};if(req.method==='POST'){let s='';for await(const c of req){s+=c;if(s.length>65536)error(413,'요청이 너무 큽니다.');}try{body=s?JSON.parse(s):{};}catch{error(400,'잘못된 요청입니다.');}}
 if(url.pathname==='/health'){response(res,200,{ok:true,version:VERSION,protocol:8,queued:queue.size,rooms:rooms.size,started:STARTED,name:'AsteraCraft LAN'});return;}
 if(url.pathname==='/register'&&req.method==='POST'){
  const nickname=String(body.nickname||'').trim(),password=String(body.password||'');if(nickname.length<2||nickname.length>16||password.length<6||password.length>100)error(400,'닉네임 2~16자, 비밀번호 6~100자를 입력하세요.');
  if(legacyGeneratedCredentials(nickname,password))error(400,'자동 닉네임 대신 직접 정한 닉네임을 입력하세요.');
  if(Object.values(db.users).some(u=>u.nickname.toLocaleLowerCase()===nickname.toLocaleLowerCase()))error(409,'이미 사용 중인 닉네임입니다.');
  const id=uid(),salt=token();db.users[id]={id,nickname,salt,password:hash(password,salt),identity_source:'explicit',rating:1000,wins:0,losses:0,created:Date.now()};save();const t=token();sessions.set(t,{id,at:Date.now()});response(res,200,{token:t,user:safeUser(db.users[id])});return;
 }
 if(url.pathname==='/account/legacy'&&req.method==='POST'){
  const nickname=String(body.nickname||'').trim(),password=String(body.password||'');
  if(!legacyGeneratedCredentials(nickname,password))error(400,'자동 생성 계정의 증명이 일치하지 않습니다.');
  const u=Object.values(db.users).find(u=>u.nickname===nickname);if(!verifyPassword(u,password))error(401,'계정 정보를 확인할 수 없습니다.');
  markLegacyAccount(u);response(res,200,{ok:true,migrated:true});return;
 }
 if(url.pathname==='/login'&&req.method==='POST'){
  const u=Object.values(db.users).find(u=>u.nickname.toLocaleLowerCase()===String(body.nickname||'').trim().toLocaleLowerCase());
  const password=String(body.password||'');if(!verifyPassword(u,password))error(401,'닉네임 또는 비밀번호를 확인하세요.');
  if(legacyGeneratedCredentials(u.nickname,password)){markLegacyAccount(u);error(403,'직접 정한 닉네임으로 새 계정을 만들어 주세요.');}
  if(u.identity_source==='legacy_generated')error(403,'직접 정한 닉네임으로 새 계정을 만들어 주세요.');
  const t=token();sessions.set(t,{id:u.id,at:Date.now()});response(res,200,{token:t,user:safeUser(u)});return;
 }
 const user=requireUser(req);const route=url.pathname;const currentRoom=roomForUser(user.id);if(currentRoom){const member=currentRoom.members.find(m=>m.user===user.id);if(member)member.seen=Date.now();}maintainRooms();
 if(route==='/me'){response(res,200,{user:safeUser(user)});return;}
 if(route==='/active'){const g=latestGame(user.id);response(res,200,{game:g?.status==='playing'?gameInfo(g,user):null});return;}
 if(route==='/rooms'){response(res,200,{rooms:[...rooms.values()].filter(r=>r.status==='waiting').map(cleanRoom)});return;}
 if(route==='/room/create'&&req.method==='POST'){
  if(userBusy(user.id))error(409,'진행 중인 경기가 있습니다.');queue.delete(user.id);leaveRoom(user.id);
  const r={id:uid(),name:String(body.name||`${user.nickname}의 방`).slice(0,40),owner:user.id,map:sanitizeMap(body.map??0),mode:body.mode==='teams'?'teams':'ffa',password:body.password?hash(String(body.password),'room-password'):null,members:[{user:user.id,race:sanitizeRace(body.race??0),team:0,ready:false,bot:false,seen:Date.now()}],status:'waiting',host:String(req.headers.host||'127.0.0.1').split(':')[0]};rooms.set(r.id,r);response(res,200,{room:cleanRoom(r)});return;
 }
 if(route==='/room/join'&&req.method==='POST'){
  const existing=rooms.get(body.id);if(existing&&existing.status==='waiting'&&existing.members.some(m=>m.user===user.id)){response(res,200,{room:cleanRoom(existing)});return;}
  const r=rooms.get(body.id);if(!r||r.status!=='waiting')error(404,'입장 가능한 방이 없습니다.');if(userBusy(user.id))error(409,'진행 중인 경기가 있습니다.');if(r.password&&hash(String(body.password||''),'room-password')!==r.password)error(403,'방 비밀번호를 확인하세요.');if(r.members.length>=8)error(409,'방이 가득 찼습니다.');
  const observer=!!body.observer||r.members.filter(m=>!m.observer).length>=4;
  if(observer&&r.members.filter(m=>m.observer).length>=4)error(409,'관전자 자리가 가득 찼습니다.');
  queue.delete(user.id);leaveRoom(user.id);cancelCountdown(r);r.members.push({user:user.id,race:sanitizeRace(body.race??0),team:r.members.length%2,observer,ready:false,bot:false,seen:Date.now()});response(res,200,{room:cleanRoom(r)});return;
 }
 if(route==='/room/state'){
  const r=roomForUser(user.id);response(res,200,{room:r?cleanRoom(r):null,game:r?.game?gameInfo(games.get(r.game),user):null});return;
 }
 if(route==='/room/update'&&req.method==='POST'){
  const r=requireRoom(user,body.id),m=r.members.find(m=>m.user===user.id);if(r.status!=='waiting')error(409,'이미 시작된 방입니다.');
  if(r.countdown&&r.countdown-Date.now()<=3000)error(409,'시작 3초 전부터는 준비를 취소하거나 설정을 바꿀 수 없습니다.');if(r.countdown)cancelCountdown(r);
  if(body.observer!==undefined){
   const observer=!!body.observer;
   if(r.members.filter(x=>x!==m&&!!x.observer===observer).length>=4)error(409,observer?'관전자 자리가 가득 찼습니다.':'플레이어 자리가 가득 찼습니다.');
   m.observer=observer;m.ready=false;
  }
  if(body.race!==undefined)m.race=sanitizeRace(body.race);if(body.team!==undefined)m.team=Number(body.team)===1?1:0;if(body.ready!==undefined&&!m.observer)m.ready=!!body.ready;
  if(r.owner===user.id){if(body.map!==undefined)r.map=sanitizeMap(body.map);if(body.mode!==undefined)r.mode=body.mode==='teams'?'teams':'ffa';
   if(body.add_bot){if(r.members.filter(m=>!m.observer).length>=4||r.members.length>=8)error(409,'플레이어 자리가 가득 찼습니다.');r.members.push({user:'bot-'+uid(),nickname:'컴퓨터 '+(r.members.length+1),race:sanitizeRace(body.bot_race??(r.members.length%3)),team:r.members.filter(m=>!m.observer).length%2,ready:true,bot:true,difficulty:1});}
   if(body.remove_bot){const i=r.members.findLastIndex(m=>m.bot);if(i>=0)r.members.splice(i,1);}
  }
  beginCountdown(r);response(res,200,{room:cleanRoom(r)});return;
 }
 if(route==='/room/leave'&&req.method==='POST'){leaveRoom(user.id);response(res,200,{ok:true});return;}
 if(route==='/room/start'&&req.method==='POST'){
  const r=requireRoom(user,body.id);if(r.owner!==user.id)error(403,'방장만 시작을 요청할 수 있습니다.');if(!canStartRoom(r))error(409,'두 명 이상 모두 준비해야 합니다.');
  beginCountdown(r);response(res,200,{room:cleanRoom(r)});return;
 }
 if(route==='/queue/join'&&req.method==='POST'){
  if(userBusy(user.id)||offerForUser(user.id))error(409,'이미 매칭 또는 경기가 진행 중입니다.');if((cooldowns.get(user.id)||0)>Date.now())error(429,'매칭 수락을 취소했습니다. 잠시 후 다시 검색하세요.');leaveRoom(user.id);queue.set(user.id,{user:user.id,race:sanitizeRace(body.race??0),at:Date.now()});matchQueues();response(res,200,{ok:true});return;
 }
 if(route==='/queue/leave'&&req.method==='POST'){queue.delete(user.id);const o=offerForUser(user.id);if(o){offers.delete(o.id);cooldowns.set(user.id,Date.now()+30000);}response(res,200,{ok:true});return;}
 if(route==='/queue/state'){
  matchQueues();const o=offerForUser(user.id),q=queue.get(user.id);let game=null;if(o?.game)game=gameInfo(games.get(o.game),user);else {const g=latestGame(user.id);if(g?.status==='playing'&&g.ranked)game=gameInfo(g,user);}
  response(res,200,{queued:!!q,wait:q?Math.floor((Date.now()-q.at)/1000):0,offer:o?{id:o.id,seconds:Math.max(0,Math.ceil((o.until-Date.now())/1000)),accepted:o.accepted.includes(user.id)}:null,game,user:safeUser(user)});return;
 }
 if(route==='/queue/accept'&&req.method==='POST'){
  const o=offerForUser(user.id);if(!o||o.id!==body.id||o.until<Date.now())error(404,'매칭 수락 시간이 지났습니다.');if(!o.accepted.includes(user.id))o.accepted.push(user.id);
  if(o.accepted.length===2&&!o.game){const host=String(req.headers.host||'localhost').split(':')[0];const g=startGame(o.entries.map((e,i)=>({...e,team:i,bot:false})),null,'ffa',true,host);o.game=g.id;o.until=Date.now()+3600000;}
  response(res,200,{ok:true});return;
 }
 if(route==='/game'){
  const g=games.get(url.searchParams.get('id'));if(!g||!g.people.some(p=>p.user===user.id))error(404,'경기를 찾을 수 없습니다.');response(res,200,{game:gameInfo(g,user),user:safeUser(user)});return;
 }
 if(route==='/leaderboard'){response(res,200,{users:Object.values(db.users).filter(u=>u.identity_source!=='legacy_generated').sort((a,b)=>b.rating-a.rating||b.wins-a.wins||a.created-b.created).slice(0,100).map(safeUser)});return;}
 if(route==='/history'){response(res,200,{matches:Object.values(db.matches).filter(m=>m.players.some(p=>p.id===user.id)).sort((a,b)=>b.time-a.time).slice(0,30)});return;}
 error(404,'없는 요청입니다.');
}
const server=http.createServer((req,res)=>{api(req,res).catch(e=>{if(!res.headersSent)response(res,e.code||500,{error:e.code?e.message:'서버 오류가 발생했습니다.'});else res.end();if(!e.code)console.error(e);});});
const timer=setInterval(()=>{matchQueues();maintainRooms();},100);timer.unref();
let discovery;
function listenDiscovery(){
 discovery=dgram.createSocket({type:'udp4',reuseAddr:true});
 discovery.on('error',e=>{console.error('LAN discovery unavailable:',e.message);try{discovery.close();}catch{}});
 discovery.on('message',(msg,peer)=>{if(msg.toString()!=='ASTERA_DISCOVER_V8')return;const answer=Buffer.from(JSON.stringify({app:'AsteraCraft',version:VERSION,protocol:8,port:PORT,rooms:rooms.size,started:STARTED}));discovery.send(answer,peer.port,peer.address);});
 discovery.bind(DISCOVERY_PORT,HOST);
}
if(require.main===module)server.listen(PORT,HOST,()=>{console.log(`AsteraCraft lobby ${HOST}:${PORT} version ${VERSION}`);listenDiscovery();});
function shutdown(){for(const g of games.values())g.child?.kill();try{discovery?.close();}catch{}server.close(()=>process.exit(0));setTimeout(()=>process.exit(0),1000).unref();}
process.on('SIGINT',shutdown);process.on('SIGTERM',shutdown);
module.exports={elo,finishGame,api,_test:{db,games,rooms,offers,queue,maintainRooms,beginCountdown,canStartRoom,randomMatchSetup,legacyGeneratedCredentials,projectArguments}};
