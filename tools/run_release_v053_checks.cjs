const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),release=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.3-20261016');
const isolated=path.join(root,'build/release-v053/empty');fs.mkdirSync(isolated,{recursive:true});
const userData=path.join(root,'build/release-v053/test-user-data');fs.mkdirSync(userData,{recursive:true});
const mode=process.argv[2]||'pack';
const args=mode==='boot'?['--quit-after','120']:['--headless','--path',isolated,'--main-pack',path.join(release,'AsteraCraft.pck'),'--script',path.join(root,mode==='online'?'tests/online_v053_probe.gd':'tests/release_v053_pack_test.gd')];
args.push('--log-file',path.join(root,`build/release-v053/${mode}-godot.log`));
const engine=mode==='boot'?path.join(release,'AsteraCraft.exe'):path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const server=mode==='online'?cp.spawn(path.join(release,'runtime/node.exe'),[path.join(release,'server/server.js')],{windowsHide:true,stdio:'ignore',env:{...process.env,PORT:'17844',HOST:'127.0.0.1',ASTERA_DISCOVERY_PORT:'17845',ASTERA_DATA_DIR:path.join(userData,'online-probe')}}):null;
if(server)process.env.ASTERA_TEST_LOBBY='http://127.0.0.1:17844';
const child=cp.spawn(engine,args,{cwd:isolated,windowsHide:true,env:{...process.env,APPDATA:userData},stdio:['ignore','pipe','pipe']});
let output='';child.stdout.on('data',b=>{output+=b});child.stderr.on('data',b=>{output+=b});
const timeout=setTimeout(()=>{child.kill();console.error('Release check timed out');process.exitCode=1},180000);
child.on('exit',code=>{clearTimeout(timeout);if(server)server.kill();fs.writeFileSync(path.join(root,`build/release-v053/${mode}-check.log`),output);console.log(output.slice(-8000));console.log('RELEASE_PROCESS_EXIT '+code);process.exitCode=code??1});

