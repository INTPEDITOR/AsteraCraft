const {spawn}=require('node:child_process'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),endpoint=process.env.ASTERA_TEST_URL||'http://127.0.0.1:17900/api';
const observerHost=process.env.ASTERA_OBSERVER_HOST==='1';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function api(route,token,body){const r=await fetch(endpoint+route,{method:body?'POST':'GET',headers:{'Content-Type':'application/json','X-Astera-Protocol':'11',Authorization:'Bearer '+(token||'')},body:body?JSON.stringify(body):undefined});const d=await r.json();assert.equal(r.status,200,JSON.stringify(d));return d;}
(async()=>{
 const suffix=Date.now().toString(36),players=[];
 for(let i=0;i<3;i++)players.push(await api('/register','',{nickname:'qa'+suffix+i,password:require('node:crypto').randomBytes(24).toString('hex')}));
 const room=(await api('/room/create',players[0].token,{name:'P2P verification',race:0})).room;
 if(observerHost)await api('/room/update',players[0].token,{id:room.id,observer:true});
 for(let i=1;i<3;i++)await api('/room/join',players[i].token,{id:room.id,race:i,observer:!observerHost&&i===2});
 for(let i=0;i<(observerHost?3:2);i++)await api('/room/update',players[i].token,{id:room.id,ready:true});
 await sleep(5100);
 const jobs=[];
 for(let i=0;i<3;i++){
  const game=(await api('/room/state',players[i].token)).game;
  assert.ok(game);const file=path.join(root,'build',`p2p-${suffix}-${i}.json`);
  fs.writeFileSync(file,JSON.stringify({...game,endpoint,session_token:players[i].token,surrender:i===1,surrender_after:5}));
  const executable=process.env.ASTERA_TEST_EXE;
  const log=path.join(root,'build',`p2p-${i}.log`);
  const args=executable?['--headless','--log-file',log,'--','--test-client',file]:['tools_run_godot.js','--headless','--path','.', '--log-file',log,'--','--test-client',file];
  const userData=path.join(root,'build/release-v061/p2p-user-'+i);fs.mkdirSync(userData,{recursive:true});
  const proc=spawn(executable||'node',args,{cwd:executable?path.dirname(executable):root,windowsHide:true,env:{...process.env,APPDATA:userData}});
  jobs.push(new Promise((resolve,reject)=>{let output='';proc.stdout.on('data',x=>output+=x);proc.stderr.on('data',x=>output+=x);const timer=setTimeout(()=>{proc.kill();reject(Error('P2P timeout '+i+' '+output))},90000);proc.on('exit',code=>{clearTimeout(timer);fs.unlinkSync(file);fs.writeFileSync(path.join(root,'build',`p2p-${i}-output.log`),output);if(code!==0||!output.includes('ASTERA_CLIENT_RESULT')||/SCRIPT ERROR|RPC.*error/i.test(output))reject(Error('P2P '+i+' failed '+output));else resolve({slot:i,code,result:JSON.parse(output.match(/ASTERA_CLIENT_RESULT (.+)/)[1])})})}));
 }
 const results=await Promise.all(jobs);const winner=observerHost?1:0;
 for(const result of results)assert.deepEqual(result.result.winners,[winner]);
 const history=await api('/history',players[observerHost?2:0].token);assert.ok(history.matches.some(m=>!m.ranked&&m.winners?.[0]===winner));
 const report={ok:true,endpoint,executable:process.env.ASTERA_TEST_EXE||'source Godot',transport:'native WebRTC direct',players:2,observers:1,hostProcess:'player PC',scope:'same PC, public HTTPS service',results};
 fs.writeFileSync(path.join(root,'build',process.env.ASTERA_TEST_EXE?'p2p-release-v061.json':'p2p-source-v061.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(e=>{console.error(e);process.exitCode=1});
