const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback14_20261026'),qa=path.join(root,'docs/verification_feedback14_20261026');fs.mkdirSync(qa,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'')),reports={};
for(const [name,file] of Object.entries({lifecycle:path.join(root,'build/updater-startup-lifecycle-20261026/result.json'),startup:path.join(out,'startup-result.json'),executable:path.join(out,'exe-smoke.json'),archive:path.join(out,'package-result.json')})){
 const report=read(file);assert(report.passed,name+' failed');reports[name]=report;fs.copyFileSync(file,path.join(qa,name+'.json'));
}
assert.equal(reports.lifecycle.checks,21);assert(reports.lifecycle.released_source_failure_reproduced);assert.equal(reports.startup.version,'0.6.8');assert.equal(reports.startup.button,'최신 버전');
const before=JSON.parse(cp.execFileSync('git',['show','da96c660f3e4ded4cdeac4baa70470d74e2f31c1:data/game.json'],{cwd:root,encoding:'utf8'})),after=read(path.join(root,'data/game.json'));delete before.version;delete after.version;assert.deepEqual(before,after,'Gameplay values must stay unchanged');
const registry=fs.readFileSync(path.join(root,'.godot/global_script_class_cache.cfg'),'utf8');assert(!/res:\/\/(build|work)\//.test(registry),'Archived class registered');
reports.icons=JSON.parse(cp.execFileSync(process.execPath,['tools/verify_windows_icon.cjs',path.join(out,'AsteraCraft.exe'),path.join(root,'assets/game_icon.ico')],{cwd:root,encoding:'utf8'}));
const source_sha256={};for(const file of ['scripts/game_updater.gd','data/game.json','data/update_channel.json','project.godot'])source_sha256[file]=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const result={passed:true,version:'0.6.8',tag:'feedback14-20261026',source_checks:21,reports,source_sha256,scope:'Updater lifecycle regression and public HTTPS check after real title preparation/reparent from final PCK; actual release EXE smoke, unchanged gameplay data, ZIP CRC/SHA256/icon. Installer payload replacement was not changed or retested.'};
fs.writeFileSync(path.join(qa,'exports.json'),JSON.stringify(result,null,2));fs.writeFileSync(path.join(out,'release-validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({passed:true,checks:21,startup_check_msec:reports.startup.check_msec,bytes:reports.archive.bytes}));
