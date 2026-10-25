const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback10_20261025');
const driver=path.join(out,'external-test-drivers/visual.gd');fs.mkdirSync(path.dirname(driver),{recursive:true});fs.writeFileSync(driver,fs.readFileSync(path.join(root,'tests/feedback10_visual_20261025.gd'),'utf8'));
const captures=path.join(out,'native-captures'),log=path.join(out,'native-captures.log');
const result=cp.spawnSync(path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe'),['--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',log,'--script',driver,'--',captures],{cwd:out,windowsHide:true,timeout:180000,env:{...process.env,APPDATA:path.join(root,'build/feedback10-visual-appdata')},stdio:'pipe'});
const text=String(result.stdout||'')+String(result.stderr||'')+(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'');
const report=JSON.parse(fs.readFileSync(path.join(captures,'result.json'),'utf8'));
if(result.status!==0||!report.passed||/SCRIPT ERROR|ERROR:|FAIL /.test(text)){console.error(text.slice(-3000));process.exit(1);}
fs.writeFileSync(path.join(out,'native-visual-result.json'),JSON.stringify({...report,scope:'Final Windows PCK mounted without source data or asset fallback, with explicit test-only debug extension DLL; actual native 1920x1080 menu and three-race worker/building render. Shipping EXE startup is separate.'},null,2));
console.log('FEEDBACK10_NATIVE_VISUAL '+JSON.stringify(report));
