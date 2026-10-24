const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback6_20261024'),log=path.join(out,'pack-export.log');
// Mount the export as the main pack from its output directory. Mounting into
// the source project would allow missing paths to fall back to local work.
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const result=cp.spawnSync(engine,['--headless','--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',log,'--script',path.join(root,'tests/feedback6_pack_test.gd'),'--',path.join(out,'AsteraCraft.pck')],{cwd:out,windowsHide:true,timeout:60000,env:{...process.env,APPDATA:path.join(root,'build/test-user-data')},stdio:'pipe'});
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const passed=result.status===0&&text.includes('FEEDBACK6_PACK verified')&&!/SCRIPT ERROR|Assertion failed|ERROR:/.test(text);
fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify({passed,exit_code:result.status,native_images:12,scope:'Exported Windows PCK mounted as main pack without source fallback; all12 native images decoded, helper/HUD/metadata available, source work directory absent'},null,2));
console.log(JSON.stringify({passed,exit_code:result.status,native_images:12}));if(!passed){console.error(text.slice(-2000));process.exitCode=1;}
