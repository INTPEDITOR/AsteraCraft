'use strict';
const cp=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=__dirname,gpu=process.argv.includes('--gpu'),logPath=path.join(root,'build',gpu?'menu-v04-gpu.log':'menu-v04-test.log'),userData=path.join(root,'build','menu-v04-userdata-'+Date.now());
fs.mkdirSync(userData,{recursive:true});
const engine=path.join(root,'..','tools','godot','Godot_v4.6-stable_win64_console.exe');
const args=[...(gpu?['--rendering-method','gl_compatibility']:['--headless']),'--path',root,'--script','tests/menu_v04_test.gd'];
const child=cp.spawn(engine,args,{cwd:root,env:{...process.env,APPDATA:userData},windowsHide:true,stdio:['ignore','pipe','pipe']});
let output='',stopping=false;const log=fs.createWriteStream(logPath);
function stop(reason){if(stopping)return;stopping=true;console.error(reason);child.kill();}
const deadline=setTimeout(()=>stop('MENU_V04_RUNNER timeout after 60 seconds'),60000);
for(const pipe of [child.stdout,child.stderr])pipe.on('data',chunk=>{output+=chunk.toString();log.write(chunk);process.stdout.write(chunk);if(/(?:^|\n)(?:SCRIPT ERROR:|ERROR:)/.test(output))stop('MENU_V04_RUNNER stopped on engine error');});
child.on('error',error=>{console.error(error);stopping=true;process.exitCode=1;});
child.on('close',code=>{clearTimeout(deadline);log.end();const errors=(output.match(/(?:^|\n)(?:SCRIPT ERROR:|ERROR:)/g)||[]).length;console.log('MENU_V04_RUNNER exit='+code+' engine_errors='+errors+' gpu='+gpu+' log='+logPath);process.exitCode=code===0&&!stopping&&errors===0?0:1;});
