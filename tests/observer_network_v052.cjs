const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),dir=path.join(root,'build','observer-net-'+Date.now());fs.mkdirSync(dir,{recursive:true});
const engine=process.env.ASTERA_TEST_EXE||path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const env={...process.env,PORT:'17843',HOST:'127.0.0.1',GAME_PORT:'17943',GODOT_EXECUTABLE:engine,ASTERA_DATA_DIR:dir,APPDATA:path.join(dir,'userdata')};fs.mkdirSync(env.APPDATA,{recursive:true});
const children=[];let logs='';
const server=cp.spawn(process.execPath,[path.join(process.env.ASTERA_TEST_EXE?path.dirname(engine):root,'server/server.js')],{cwd:root,env,windowsHide:true});children.push(server);
server.stdout.on('data',b=>logs+=b);server.stderr.on('data',b=>logs+=b);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function api(route,user,body){const r=await fetch('http://127.0.0.1:17843'+route,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:'Bearer '+user.token}:{})},body:body===undefined?undefined:JSON.stringify(body)});const data=await r.json();if(!r.ok)throw Error(route+' '+JSON.stringify(data));return data}
async function poll(fn){for(let i=0;i<100;i++){const r=await fn();if(r)return r;await sleep(150)}throw Error('Timed out')}
function client(game,surrender,label){const file=path.join(dir,label+'.json');fs.writeFileSync(file,JSON.stringify({...game,surrender,surrender_after:game.spectator?.5:5}));return new Promise((resolve,reject)=>{let output='';const args=['--headless',...(process.env.ASTERA_TEST_EXE?[]:['--path',root]),'--','--test-client',file];const child=cp.spawn(engine,args,{cwd:process.env.ASTERA_TEST_EXE?path.dirname(engine):root,env,windowsHide:true});children.push(child);const timer=setTimeout(()=>{child.kill();reject(Error(label+' timeout'))},45000);child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);child.on('error',reject);child.on('exit',code=>{clearTimeout(timer);fs.writeFileSync(path.join(dir,label+'.log'),output);if(code!==0||/SCRIPT ERROR|ERROR:/.test(output)||!output.includes('ASTERA_CLIENT_RESULT'))reject(Error(label+' '+output));else resolve(output)})})}
(async()=>{
 await poll(async()=>{try{return (await api('/health')).ok}catch{return false}});
 const users=[];for(let i=0;i<3;i++)users.push(await api('/register',null,{nickname:'NetObserver'+i,password:'local-test-password'}));
 const room=(await api('/room/create',users[0],{race:0,map:0})).room;
 await api('/room/join',users[1],{id:room.id,race:2});await api('/room/join',users[2],{id:room.id,race:1});
 await api('/room/update',users[2],{id:room.id,observer:true});
 await api('/room/update',users[0],{id:room.id,ready:true});await api('/room/update',users[1],{id:room.id,ready:true});
 await poll(async()=>{await api('/room/state',users[1]);await api('/room/state',users[2]);return (await api('/room/state',users[0])).game});
 const games=[];for(const u of users)games.push((await api('/active',u)).game);
 assert(games[2].spectator);assert.equal(games[2].slot,-1);
 // Observer deliberately attempts surrender. Server must deny it; player B wins
 // only after player A's legitimate surrender, not through observer slot zero.
 const outputs=await Promise.all(games.map((g,i)=>client(g,i===0||i===2,'client-'+i)));
 assert(outputs[2].includes('ASTERA_CLIENT_RESULT'));
 const result=await poll(async()=>{const g=(await api('/game?id='+games[0].id,users[0])).game;return g.status==='finished'?g:false});
 assert.deepEqual(result.result.winners,[1]); assert(result.result.duration>=5,"observer cannot end match early");
 assert.equal((await api('/me',users[2])).user.rating,1000);
 fs.writeFileSync(path.join(root,'build/observer-network-v052.json'),JSON.stringify({passed:true,engine,players:2,observers:1,observerCommandDenied:true,logs:dir},null,2));
 console.log('OBSERVER_NETWORK_V052 PASS: 2 players + observer; observer commands denied; neutral rating');
})().catch(e=>{console.error(e);console.error(logs);process.exitCode=1}).finally(()=>{for(const child of children)if(child.exitCode===null)child.kill()});



