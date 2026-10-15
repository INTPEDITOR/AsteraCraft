const cp=require('node:child_process'),path=require('node:path'),fs=require('node:fs');
const root=__dirname, privateData=path.join(root,'build','test-user-data');
fs.mkdirSync(privateData,{recursive:true});
const engine=path.join(root,'..','tools','godot','Godot_v4.6-stable_win64_console.exe');
const p=cp.spawn(engine,process.argv.slice(2),{cwd:root,env:{...process.env,APPDATA:privateData},windowsHide:true,stdio:'inherit'});
p.on('exit',c=>process.exit(c??1));
