const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback13_20261026'),qa=path.join(root,'docs/verification_feedback13_20261026');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const reports={};
for(const [name,file]of Object.entries({pack:path.join(out,'pack-result.json'),startup:path.join(out,'exe-smoke.json'),archive:path.join(out,'package-result.json'),updater:path.join(root,'build/updater-feedback13-e2e-20261026/result.json')})){
 const report=read(file);if(!report.passed)throw Error(name+' verification failed');reports[name]=report;fs.copyFileSync(file,path.join(qa,name+'.json'));
}
let checks=0;for(const name of ['balance-difficulty','apm','combat','ara-behaviour']){const r=read(path.join(qa,name+'.json'));if(!r.passed||r.failures?.length)throw Error(name);checks+=r.checks;}
if(checks!==90||reports.updater.tag!=='feedback13-20261026'||reports.updater.checks!==11)throw Error('Unexpected validation scope');
const registry=fs.readFileSync(path.join(root,'.godot/global_script_class_cache.cfg'),'utf8');if(/res:\/\/(build|work)\//.test(registry))throw Error('Experimental source registered as global class');
const icons=JSON.parse(cp.execFileSync(process.execPath,['tools/verify_windows_icon.cjs',path.join(out,'AsteraCraft.exe'),path.join(root,'assets/game_icon.ico')],{cwd:root,encoding:'utf8'}));reports.icons=icons;
const sourceFiles=cp.execFileSync('git',['ls-files','scripts','data','project.godot'],{cwd:root,encoding:'utf8'}).trim().split(/\r?\n/).filter(Boolean);
for(const n of fs.readdirSync(path.join(root,'scripts')))if(n.endsWith('.gd')&&!sourceFiles.includes('scripts/'+n))sourceFiles.push('scripts/'+n);
for(const n of fs.readdirSync(path.join(root,'data')))if((n.endsWith('.json')||n.endsWith('.txt'))&&!sourceFiles.includes('data/'+n))sourceFiles.push('data/'+n);
const source_sha256=Object.fromEntries(sourceFiles.map(file=>[file,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')]));
const result={passed:true,version:'0.6.7',tag:'feedback13-20261026',source_checks:checks,reports,source_sha256,difficulty_matches:'Skipped at explicit user request; no difficulty win-rate claim.',scope:'Current source behavior checks, final PCK metadata and core setup, real Windows EXE startup with thirty loading images, full ZIP CRC/SHA256 and actual previous-version installer/restart confirmation.'};
fs.writeFileSync(path.join(qa,'exports.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({passed:true,checks,updater_checks:11,icon_resolutions:icons.resolutions,bytes:reports.archive.bytes}));
