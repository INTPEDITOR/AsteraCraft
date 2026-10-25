const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback11_20261025');
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe'),pack=path.join(out,'AsteraCraft.pck');
const reportRoot=path.join(out,'test-results').replaceAll('\\','/')+'/';
for(const folder of ['player_colors_20261024','source-terrain'])fs.mkdirSync(reportRoot+folder,{recursive:true});
const drivers=path.join(out,'external-test-drivers');fs.mkdirSync(drivers,{recursive:true});
const debug='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';fs.mkdirSync(path.dirname(path.join(out,debug)),{recursive:true});fs.copyFileSync(path.join(root,debug),path.join(out,debug));
const probe='cliff-fix-20261025/height-probe-before.json';fs.mkdirSync(path.dirname(reportRoot+probe),{recursive:true});fs.copyFileSync(path.join(root,'build',probe),reportRoot+probe);
const runs=[
 ['manifest','feedback11_pack_test.gd',[pack]],
 ['spacing','base_resource_spacing_20261025_test.gd',['feedback11']],
 ['construction','base_spacing_commands_20261025_test.gd',[]],
 ['islands','python_island_mining_20261025_test.gd',[]],
 ['tera','tera_source_comparison_20261025_test.gd',[]],
 ['ai','ai_forward_staging_20261025_test.gd',[]],
 ['ai-economy','bot_ai_v062_test.gd',[]],
 ['ai-routes','ai_staging_source_walk_20261025_test.gd',[]],
 ['formations','group_move_continuity_20261025_test.gd',['feedback11']],
 ['cliff','cliff_guard_20261025_test.gd',['feedback11']],
 ['highground','highground_beam_20261024_test.gd',[]],
 ['worker','worker_passages_20261025_test.gd',[]],
 ['worker-jobs','worker_passage_jobs_20261025_test.gd',[]],
 ['melee','melee_follow_20261024_test.gd',[]],
 ['fog-memory','fog_building_memory_test.gd',[]],
 ['fog-revision','fog_revision_v061_test.gd',[]],
 ['fog','fog_north_visual_20261025.gd',['after','fog'],true],
 ['north','fog_north_visual_20261025.gd',['after','north'],true],
 ['boundaries','side_bottom_boundary_20261025_test.gd',[],true],
 ['spacing-render','spacing3_visual_20261025.gd',[],true],
 ['fog-cache','fog_projection_cache_20261025_test.gd',[],true],
];
function flatten(source){
 const match=source.match(/^extends "res:\/\/tests\/([^"\r\n]+)"/);
 if(!match)return source;
 const base=flatten(fs.readFileSync(path.join(root,'tests',match[1]),'utf8')).split(/^func run\(.*$/m)[0];
 return base+source.split('\n').slice(1).join('\n');
}
const selected=process.argv.slice(2);let records=[];
for(const [name,script,args,native] of runs){
 if(selected.length&&!selected.includes(name))continue;
 let source=flatten(fs.readFileSync(path.join(root,'tests',script),'utf8'));
 source=source.replaceAll('res://tests/menu_v04_harness.gd','res://scripts/main.gd').replaceAll('res://build/',reportRoot);
 const driver=path.join(drivers,name+'.gd');fs.writeFileSync(driver,source);
 const log=path.join(out,'pack-'+name+'.log');
 const result=cp.spawnSync(engine,[...(native?[]:['--headless']),'--path',out,'--main-pack',pack,'--log-file',log,'--script',driver,'--',...args],{cwd:out,windowsHide:true,timeout:600000,env:{...process.env,APPDATA:path.join(root,'build/feedback11-pack-appdata')},stdio:'pipe',maxBuffer:8*1024*1024});
 const text=String(result.stdout||'')+String(result.stderr||'')+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
 const summaries=[...String(result.stdout||'').matchAll(/^[A-Z_0-9]+ (\{.*\})$/gm)].map(m=>{try{return JSON.parse(m[1]);}catch{return null;}}).filter(Boolean);
 const summary=summaries.at(-1),clean=summary&&(summary.passed===true||(Array.isArray(summary.failures)&&summary.failures.length===0))&&(!summary.failures||(Array.isArray(summary.failures)&&summary.failures.length===0));
 const passed=result.status===0&&!/SCRIPT ERROR|Assertion failed|ERROR:|FAIL[: ]/.test(text)&&(name==='manifest'?text.includes('FEEDBACK11_PACK verified'):clean);
 const record={name,passed,exit_code:result.status,summary:summary||null,native:Boolean(native)};records.push(record);
 fs.writeFileSync(path.join(out,'pack-'+name+'-result.json'),JSON.stringify(record,null,2));
 console.log('PACK_TEST '+JSON.stringify({name,passed,exit_code:result.status}));
 if(!passed){console.error(text.slice(-4500));if(result.error)console.error(result.error.message);process.exit(1);}
}
const complete=runs.map(([name])=>{const file=path.join(out,'pack-'+name+'-result.json');return fs.existsSync(file)&&fs.statSync(file).mtimeMs>=fs.statSync(pack).mtimeMs?JSON.parse(fs.readFileSync(file,'utf8')):null;});
if(complete.every(r=>r?.passed))fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify({passed:true,runs:complete,scope:'Exact final Windows PCK mounted from export folder. Production scripts, data, and artwork resolve only from PCK. External QA drivers and an explicit test-only debug WebRTC DLL are supplied to the editor runtime. Shipping EXE startup with its release DLL is verified separately. All results postdate this PCK.'},null,2));
