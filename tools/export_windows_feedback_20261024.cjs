const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),folder=process.argv[2]||'feedback_fixed_20261024';
if(!/^[a-z0-9_-]{1,80}$/.test(folder))throw Error('Invalid build folder name');
const out=path.join(root,'build',folder);fs.mkdirSync(out,{recursive:true});
const buildTag=process.argv[3]||folder.replace(/_(\d{8})$/,'-$1');
fs.writeFileSync(path.join(root,'data/update_channel.json'),JSON.stringify({repository:'INTPEDITOR/AsteraCraft',tag:buildTag,built_at_unix:Math.floor(Date.now()/1000),channel:'official'},null,2)+'\n');
function run(exe,args){const p=cp.spawnSync(exe,args,{cwd:root,windowsHide:true,stdio:'inherit'});if(p.error)throw p.error;if(p.status!==0)throw Error(exe+' exited '+p.status);}
run(process.execPath,['tools_run_godot.js','--headless','--path','.', '--export-release','Windows Desktop',path.join(out,'AsteraCraft.exe')]);
// Godot's template icon is replaced in every packaged build. Keeping this in
// the export entry point prevents GitHub/desktop icons reverting next release.
run('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File','tools/set_windows_icon.ps1','-Executable',path.join(out,'AsteraCraft.exe'),'-Icon',path.join(root,'assets/game_icon.ico')]);
run(process.execPath,['tools/verify_windows_icon.cjs',path.join(out,'AsteraCraft.exe'),path.join(root,'assets/game_icon.ico')]);
if(!fs.existsSync(path.join(out,'libwebrtc_native.windows.template_release.x86_64.dll')))throw Error('Exported WebRTC runtime is missing');
console.log('WINDOWS_EXPORT_VERIFIED '+out);
