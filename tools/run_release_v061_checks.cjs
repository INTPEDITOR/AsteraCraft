const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),release=path.resolve(process.env.ASTERA_CHECK_RELEASE||path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.6.1-20261021'));
const logDir=path.resolve(process.env.ASTERA_CHECK_LOGS||path.join(root,'build/release-v061'));fs.mkdirSync(logDir,{recursive:true});
const isolated=path.join(root,'build/release-v061/empty');fs.mkdirSync(isolated,{recursive:true});
const userData=path.join(root,'build/release-v061/test-user-data');fs.mkdirSync(userData,{recursive:true});
const mode=process.argv[2]||'pack';
const args=mode==='boot'?['--quit-after','120']:['--headless','--path',release,'--main-pack',path.join(release,'AsteraCraft.pck'),'--script',path.join(root,mode==='music'?'tests/supplied_music_v04_test.gd':'tests/release_v061_pack_test.gd')];
args.push('--log-file',path.join(logDir,`${mode}-godot.log`));
if(mode==='music')args.push('--audio-driver','WASAPI');
const testEngine=path.join(isolated,'Godot_v4.6-stable_win64_console.exe');
if(mode!=='boot'){
 for(const filename of ['Godot_v4.6-stable_win64_console.exe','Godot_v4.6-stable_win64.exe'])if(!fs.existsSync(path.join(isolated,filename)))fs.copyFileSync(path.resolve(root,'../tools/godot',filename),path.join(isolated,filename));
 const dll=path.join(isolated,'libwebrtc_native.windows.template_debug.x86_64.dll');
 if(!fs.existsSync(dll))fs.copyFileSync(path.join(root,'addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll'),dll);
}
const engine=mode==='boot'?path.join(release,'AsteraCraft.exe'):testEngine;
const child=cp.spawn(engine,args,{cwd:isolated,windowsHide:true,env:{...process.env,APPDATA:userData},stdio:['ignore','pipe','pipe']});
let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
const timeout=setTimeout(()=>{child.kill();console.error('Release check timed out');process.exitCode=1},180000);
child.on('exit',code=>{clearTimeout(timeout);fs.writeFileSync(path.join(logDir,`${mode}-check.log`),output);console.log(output.slice(-8000));console.log('RELEASE_PROCESS_EXIT '+code);process.exitCode=code===0&&!/SCRIPT ERROR|ERROR:/.test(output)?0:1});
