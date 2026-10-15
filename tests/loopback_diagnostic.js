'use strict';
// Local-only diagnostic: compare fetch, Node HTTP and Godot HTTP without external traffic.
const http=require('node:http'),cp=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'..'),PORT=17862;
function explain(e){return {message:e.message,code:e.code,cause:e.cause?{message:e.cause.message,code:e.cause.code,syscall:e.cause.syscall,address:e.cause.address,port:e.cause.port}:undefined,syscall:e.syscall,address:e.address,port:e.port};}
if(process.argv[2]==='client'){
 (async()=>{
  for(const host of ['127.0.0.1','localhost']){
   const url=`http://${host}:${PORT}/health`;
   try{const res=await fetch(url,{signal:AbortSignal.timeout(2500)});console.log('FETCH '+host+' '+res.status+' '+await res.text());}catch(e){console.log('FETCH_ERROR '+host+' '+JSON.stringify(explain(e)));}
   await new Promise(resolve=>{const req=http.get(url,{timeout:2500},res=>{let body='';res.on('data',c=>body+=c);res.on('end',()=>{console.log('HTTP '+host+' '+res.statusCode+' '+body);resolve();});});req.on('timeout',()=>req.destroy(Error('HTTP timeout')));req.on('error',e=>{console.log('HTTP_ERROR '+host+' '+JSON.stringify(explain(e)));resolve();});});
  }
 })().catch(e=>{console.error(e);process.exitCode=1;});
}else{
 let hits=0;
 const server=http.createServer((req,res)=>{hits++;console.log('SERVER_REQUEST '+req.socket.remoteAddress+' '+req.url);res.setHeader('Content-Type','application/json');res.end(JSON.stringify({ok:true,diagnostic:true,port:PORT}));});
 server.on('error',e=>{console.error('LISTEN_ERROR '+JSON.stringify(explain(e)));process.exitCode=1;});
 server.listen(PORT,'127.0.0.1',async()=>{
  console.log('LISTEN_READY '+JSON.stringify(server.address()));
  console.log('PROXY_FLAGS '+JSON.stringify({http:!!process.env.HTTP_PROXY,https:!!process.env.HTTPS_PROXY,nodeUseEnvProxy:!!process.env.NODE_USE_ENV_PROXY,noProxyContainsLoopback:/localhost|127\.0\.0\.1/.test(process.env.NO_PROXY||'')}));
  function run(command,args,env={}){return new Promise(resolve=>{const child=cp.spawn(command,args,{cwd:ROOT,windowsHide:true,env:{...process.env,...env},stdio:['ignore','pipe','pipe']});let output='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>output+=d);child.on('error',e=>{output+=JSON.stringify(explain(e));resolve({exit:-1,output});});child.on('exit',exit=>resolve({exit,output}));});}
  const appData=path.join(ROOT,'build','loopback-diag-userdata');fs.mkdirSync(appData,{recursive:true});
  const engine=path.join(ROOT,'..','tools','godot','Godot_v4.6-stable_win64_console.exe');
  const results=await Promise.all([run(process.execPath,[__filename,'client']),run(engine,['--headless','--path',ROOT,'--script','tests/loopback_http_diagnostic.gd'],{APPDATA:appData,ASTERA_DIAG_PORT:String(PORT)})]);
  for(let i=0;i<results.length;i++)console.log('CLIENT_'+i+' exit='+results[i].exit+'\n'+results[i].output.trim());
  console.log('SERVER_TOTAL_REQUESTS '+hits);
  server.close();
 });
}
