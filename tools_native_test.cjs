const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=__dirname,privateData=path.join(root,'build/test-user-data');
for(const name of ['state','focus','menu']){const file=path.join(root,'build',`native-input-v04-${name}.json`);if(fs.existsSync(file))fs.unlinkSync(file);}
const engine=path.join(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const game=cp.spawn(engine,['--path',root,'--rendering-method','gl_compatibility','--scene','res://tests/native_input_v04.tscn','--log-file',path.join(root,'build/native-input-v04.log')],{cwd:root,windowsHide:true,env:{...process.env,APPDATA:privateData},stdio:'inherit'});
const helper=cp.spawn('pwsh',['-NoProfile','-File',path.join(root,'scripts/tools/native_input_v04.ps1')],{cwd:root,windowsHide:true,stdio:'inherit'});
game.on('exit',code=>{helper.kill();process.exitCode=code??1;});
helper.on('exit',()=>{setTimeout(()=>{if(game.exitCode===null)game.kill();},1500);});
