const cp=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback8_20261025');
const images=path.join(out,'menu-captures'),log=path.join(out,'menu-pack.log');
fs.mkdirSync(images,{recursive:true});
// Release EXEs restrict command-line script overrides. Mount the exact final
// PCK in the matching Windows engine from the export directory instead; EXE
// startup is independently exercised by smoke_feedback_build_20261024.cjs.
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const result=cp.spawnSync(engine,['--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',log,'--script',path.join(root,'tests/pause_menu_release_capture_20261025.gd'),'--',images],{cwd:out,windowsHide:true,timeout:180000,env:{...process.env,APPDATA:path.join(root,'build/feedback8-menu-appdata')},stdio:'pipe'});
fs.writeFileSync(path.join(out,'menu-pack-console.log'),String(result.stdout||'')+String(result.stderr||''));
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const file=path.join(images,'result.json');
const checks=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{};
const passed=Boolean(result.status===0&&checks.passed&&checks.factions===3&&!/SCRIPT ERROR|Assertion failed|ERROR:/.test(text));
fs.writeFileSync(path.join(out,'menu-pack-result.json'),JSON.stringify({passed,exit_code:result.status,checks:checks.checks,factions:checks.factions,scope:'Final Windows PCK mounted in the matching Godot runtime from the export directory without source fallback. All three faction menus rendered and local/online state and settings/resume validated. Release EXE startup verified separately.'},null,2));
console.log(JSON.stringify({passed,exit_code:result.status,checks:checks.checks,factions:checks.factions}));
if(!passed){console.error((text+String(result.stdout||'')+String(result.stderr||'')).slice(-2800));if(result.error)console.error(result.error.message);process.exitCode=1;}
