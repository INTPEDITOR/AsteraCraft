const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback12_20261026');
function run(exe,args){const p=cp.spawnSync(exe,args,{cwd:root,windowsHide:true,stdio:'inherit'});if(p.error)throw p.error;if(p.status!==0)throw Error(exe+' exited '+p.status);}
run(process.execPath,['tools_run_godot.js','--headless','--path','.', '--export-release','Windows Desktop',path.join(out,'AsteraCraft.exe')]);
run('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File','tools/set_windows_icon.ps1','-Executable',path.join(out,'AsteraCraft.exe'),'-Icon',path.join(root,'assets/game_icon.ico')]);
console.log('FEEDBACK12_BUILD_CREATED');
