const cp=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback9_20261025');
const images=path.join(out,'siege-captures'),log=path.join(out,'siege-pack.log');
fs.mkdirSync(images,{recursive:true});
const debugRel='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';
fs.mkdirSync(path.dirname(path.join(out,debugRel)),{recursive:true});
fs.copyFileSync(path.join(root,debugRel),path.join(out,debugRel));
// The shipping EXE restricts script overrides. Use its exact PCK with the
// matching Windows engine; independently verify the real EXE startup.
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const result=cp.spawnSync(engine,['--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',log,'--script',path.join(root,'tests/siege_range_release_capture_20261025.gd'),'--',images],{cwd:out,windowsHide:true,timeout:180000,env:{...process.env,APPDATA:path.join(root,'build/feedback9-siege-appdata')},stdio:'pipe'});
fs.writeFileSync(path.join(out,'siege-pack-console.log'),String(result.stdout||'')+String(result.stderr||''));
const text=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+String(result.stdout||'')+String(result.stderr||'');
const checks=fs.existsSync(path.join(images,'result.json'))?JSON.parse(fs.readFileSync(path.join(images,'result.json'),'utf8')):{};
const passed=Boolean(result.status===0&&checks.passed&&checks.checks===8&&!/SCRIPT ERROR|Assertion failed|ERROR:/.test(text));
fs.writeFileSync(path.join(out,'siege-pack-result.json'),JSON.stringify({...checks,passed,exit_code:result.status,scope:'Final PCK rendered at 1920x1080 in matching Windows Godot engine, no source script/texture/data fallback; explicit test-only debug WebRTC DLL provided for editor engine. Real player deployment, allied spotter vision, range 11.5 shot and HUD 7 to 12 verified; shipping EXE/release DLL startup tested separately.'},null,2));
console.log(JSON.stringify({passed,exit_code:result.status,checks:checks.checks}));
if(!passed){console.error((text+String(result.stdout||'')+String(result.stderr||'')).slice(-2800));if(result.error)console.error(result.error.message);process.exitCode=1;}
