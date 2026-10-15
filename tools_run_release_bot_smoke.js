'use strict';
const cp=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=__dirname,output=path.join(root,'build','release-bot-smoke.log'),userdata=path.join(root,'build','release-bot-smoke-userdata');fs.mkdirSync(userdata,{recursive:true});
const engine=path.join(root,'..','tools','godot','Godot_v4.6-stable_win64_console.exe');
const child=cp.spawn(engine,['--headless','--path',root,'--script','tests/release_bot_smoke.gd'],{cwd:root,env:{...process.env,APPDATA:userdata},windowsHide:true,stdio:['ignore','pipe','pipe']});
let log='';const stream=fs.createWriteStream(output);for(const pipe of [child.stdout,child.stderr])pipe.on('data',chunk=>{log+=chunk.toString();stream.write(chunk);process.stdout.write(chunk);});
child.on('error',error=>{stream.end(String(error));console.error(error);process.exitCode=1;});
child.on('close',code=>{stream.end();const engineErrors=(log.match(/(?:^|\n)(?:SCRIPT ERROR:|ERROR:)/g)||[]).length;console.log('RELEASE_BOT_RUNNER exit='+code+' engine_errors='+engineErrors+' log='+output);process.exitCode=code===0&&engineErrors===0?0:1;});
