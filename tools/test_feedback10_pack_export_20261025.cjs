const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback10_20261025');
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe'),pack=path.join(out,'AsteraCraft.pck');
const debug='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';
fs.mkdirSync(path.dirname(path.join(out,debug)),{recursive:true});fs.copyFileSync(path.join(root,debug),path.join(out,debug));
const selected=process.argv.slice(2);
const runs=[
 ['native','feedback10_pack_test.gd',[pack]],
 ['worker','worker_passages_20261025_test.gd',[]],
 ['worker-jobs','worker_passage_jobs_20261025_test.gd',[]],
 ['tera','tera_source_comparison_20261025_test.gd',[]],
 ['construction','base_spacing_commands_20261025_test.gd',[]],
 ['cliff','cliff_guard_20261025_test.gd',['feedback10']],
 ['formations','group_move_continuity_20261025_test.gd',['feedback10']],
 ['types','move_continuity_20261025_test.gd',['feedback10']],
 ['melee','melee_scenarios_20261025_test.gd',[]],
 ['ramps','source_terrain_detail_test.gd',[]],
 ['opening0','difficulty_progression_20261025_test.gd',['opening','0']],
 ['opening1','difficulty_progression_20261025_test.gd',['opening','1']],
 ['opening2','difficulty_progression_20261025_test.gd',['opening','2']],
 ['response','difficulty_progression_20261025_test.gd',['response']],
];
let records=[];
for(const [name,script,args] of runs){
 if(selected.length&&!selected.includes(name))continue;
 let source=fs.readFileSync(path.join(root,'tests',script),'utf8');
 if(source.startsWith('extends "res://tests/abilities_v060_test.gd"')){
  const base=fs.readFileSync(path.join(root,'tests/abilities_v060_test.gd'),'utf8').split('func run():')[0];
  source=base+source.split('\n').slice(1).join('\n');
 }
 // The cliff driver uses a frozen list of problematic source foot samples.
 const probe='cliff-fix-20261025/height-probe-before.json';
 const reportRoot=path.join(out,'test-results').replaceAll('\\','/')+'/';
 fs.mkdirSync(path.dirname(reportRoot+probe),{recursive:true});fs.copyFileSync(path.join(root,'build',probe),reportRoot+probe);
 source=source.replaceAll('res://build/',reportRoot);
 const driver=path.join(out,'external-test-drivers',name+'.gd');fs.mkdirSync(path.dirname(driver),{recursive:true});fs.writeFileSync(driver,source);
 const log=path.join(out,'pack-'+name+'.log');
 const result=cp.spawnSync(engine,['--headless','--path',out,'--main-pack',pack,'--log-file',log,'--script',driver,'--',...args],{cwd:out,windowsHide:true,timeout:300000,env:{...process.env,APPDATA:path.join(root,'build/feedback10-pack-appdata')},stdio:'pipe'});
 const text=String(result.stdout||'')+String(result.stderr||'')+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
 const summaries=[...String(result.stdout||'').matchAll(/^[A-Z_0-9]+ (\{.*\})$/gm)].map(m=>{try{return JSON.parse(m[1]);}catch{return null;}}).filter(Boolean);
 const last=summaries.at(-1),clean=last&&(last.passed===true||(Array.isArray(last.failures)&&last.failures.length===0))&&(!last.failures||(Array.isArray(last.failures)&&last.failures.length===0));
 const passed=result.status===0&&!/SCRIPT ERROR|Assertion failed|ERROR:|FAIL /.test(text)&&(name==='native'?text.includes('FEEDBACK10_PACK verified'):clean);
 records.push({name,passed,exit_code:result.status,summary:summaries.at(-1)||null});
 fs.writeFileSync(path.join(out,'pack-'+name+'-result.json'),JSON.stringify(records.at(-1),null,2));
 console.log('PACK_TEST '+JSON.stringify({name,passed,exit_code:result.status}));
 if(!passed){console.error(text.slice(-3000));process.exit(1);}
}
fs.writeFileSync(path.join(out,'pack-result'+(selected.length?'-'+selected.join('-'):'')+'.json'),JSON.stringify({passed:records.every(r=>r.passed),runs:records,scope:'Exact final Windows PCK mounted from export directory; production scripts, data, and assets resolve exclusively from PCK. External test drivers and an explicit test-only debug WebRTC DLL are supplied for the editor engine. Shipping EXE startup and release DLL are verified separately.'},null,2));
const complete=runs.map(([name])=>{const file=path.join(out,'pack-'+name+'-result.json');return fs.existsSync(file)&&fs.statSync(file).mtimeMs>=fs.statSync(pack).mtimeMs?JSON.parse(fs.readFileSync(file,'utf8')):null;});
if(complete.every(r=>r?.passed))fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify({passed:true,runs:complete,scope:'Exact final Windows PCK mounted from export directory without source script, data, or texture fallback; external drivers and explicit test-only debug WebRTC DLL. All result files were created after this pack export. Actual shipping EXE startup is verified separately.'},null,2));
