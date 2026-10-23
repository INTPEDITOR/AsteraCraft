const cp=require('node:child_process'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const p=cp.spawn(path.join(root,'build/sprite_connected_20261024/AsteraCraft.exe'),['--headless','--quit-after','120','--log-file',path.join(root,'build/sprite_connected_20261024/exe-startup.log')],{cwd:path.join(root,'build/sprite_connected_20261024'),windowsHide:true,stdio:'inherit',env:{...process.env,APPDATA:path.join(root,'build/test-user-data')}});
p.on('error',e=>{console.error(e.message);process.exitCode=1;});
p.on('exit',code=>{console.log('EXPORTED_STARTUP_EXIT '+code);process.exit(code??1);});
