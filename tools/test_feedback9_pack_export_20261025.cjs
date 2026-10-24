const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback9_20261025');
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const pack=path.join(out,'AsteraCraft.pck');
// The editor engine selects the debug extension variant. Supply that one
// explicit test-only DLL; the shipping EXE independently loads its release
// DLL. No source scripts, textures or data are supplied to the mounted pack.
const debugRel='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';
fs.mkdirSync(path.dirname(path.join(out,debugRel)),{recursive:true});
fs.copyFileSync(path.join(root,debugRel),path.join(out,debugRel));
const runs=[
 ['native','tests/feedback9_pack_test.gd',[pack],null],
 ['repro','tests/move_attack_followup_20261025_test.gd',['feedback9'],'build/move-attack-followup-20261025/feedback9/result.json'],
 ['continuity','tests/move_continuity_20261025_test.gd',['feedback9'],'build/move-continuity-20261025/feedback9/result.json'],
 ['formations','tests/group_move_continuity_20261025_test.gd',['feedback9'],'build/group-move-continuity-20261025/feedback9/result.json'],
 ['melee','tests/melee_scenarios_20261025_test.gd',[],'build/move-attack-followup-20261025/melee-scenarios.json'],
 ['range','tests/siege_range_20261025_test.gd',[],'build/move-attack-followup-20261025/siege-range.json'],
];
let records=[];
for(const [name,script,args,resultFile] of runs){
 const drivers=path.join(out,'external-test-drivers');fs.mkdirSync(drivers,{recursive:true});
 // Packed res:// is read-only. Redirect only the external driver's report
 // paths; every production resource still resolves from the final PCK.
 const driver=path.join(drivers,name+'.gd');
 const reportRoot=path.join(out,'test-results').replaceAll('\\','/')+'/';
 fs.writeFileSync(driver,fs.readFileSync(path.join(root,script),'utf8').replaceAll('res://build/',reportRoot));
 const log=path.join(out,'pack-'+name+'.log');
 const result=cp.spawnSync(engine,['--headless','--path',out,'--main-pack',pack,'--log-file',log,'--script',driver,'--',...args],{cwd:out,windowsHide:true,timeout:180000,env:{...process.env,APPDATA:path.join(root,'build/feedback9-pack-appdata')},stdio:'pipe'});
 const text=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+String(result.stdout||'')+String(result.stderr||'');
 const resultPath=resultFile?path.join(out,resultFile.replace(/^build\//,'test-results/')):null;
 let report=resultPath&&fs.existsSync(resultPath)?JSON.parse(fs.readFileSync(resultPath,'utf8')):null;
 const passed=result.status===0&&!/SCRIPT ERROR|Assertion failed|ERROR:/.test(text)&&(name==='native'?text.includes('FEEDBACK9_PACK verified'):Boolean(report?.passed&&report?.failures.length===0));
 records.push({name,passed,exit_code:result.status,checks:report?.checks||0,cases:report?.cases?.length||0,result_file:resultFile});
 console.log('PACK_TEST '+JSON.stringify(records.at(-1)));
 if(!passed){fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify({passed:false,runs:records},null,2));console.error(text.slice(-3000));process.exit(1);}
}
const result={passed:true,native_images:12,checks:records.reduce((n,r)=>n+r.checks,0),runs:records,scope:'Exact final Windows PCK mounted as main pack from export directory, no source script/texture/data fallback. The editor runtime receives its explicit test-only debug WebRTC DLL; the shipping release DLL is tested by the actual EXE separately. External drivers exercise packaged core/data/HUD, 12 native images, 31 ground types, 3 maps x 3 races x 12-unit formations, 88 melee contact scenarios, retreat/retry and seven tank range boundaries.'};
fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify(result,null,2));console.log('FEEDBACK9_PACK_RESULT '+JSON.stringify(result));
