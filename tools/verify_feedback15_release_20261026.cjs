const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback15_20261026'),qa=path.join(root,'docs/verification_feedback15_20261026');fs.mkdirSync(qa,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'')),reports={};
for(const [name,file] of Object.entries({selection:path.join(root,'build/top-edge-selection-20261026/result.json'),executable:path.join(out,'exe-smoke.json'),archive:path.join(out,'package-result.json')})){
 const report=read(file);assert(report.passed,name+' failed');reports[name]=report;fs.copyFileSync(file,path.join(qa,name+'.json'));
}
assert.equal(reports.selection.failures.length,0);
const before=JSON.parse(cp.execFileSync('git',['show','c50eb24049fdb6579669535d77bdd942f41474d8:data/game.json'],{cwd:root,encoding:'utf8'})),after=read(path.join(root,'data/game.json'));delete before.version;delete after.version;assert.deepEqual(before,after,'Gameplay values must stay unchanged');
const registry=fs.readFileSync(path.join(root,'.godot/global_script_class_cache.cfg'),'utf8');assert(!/res:\/\/(build|work)\//.test(registry),'Archived class registered');
reports.icons=JSON.parse(cp.execFileSync(process.execPath,['tools/verify_windows_icon.cjs',path.join(out,'AsteraCraft.exe'),path.join(root,'assets/game_icon.ico')],{cwd:root,encoding:'utf8'}));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const earlier=read(path.join(root,'build/feedback14_20261026/release-validation.json'));assert.equal(hash('scripts/game_updater.gd'),earlier.source_sha256['scripts/game_updater.gd']);
reports.updater_unchanged={passed:true,source_sha256:hash('scripts/game_updater.gd'),evidence:'docs/verification_feedback14_20261026/exports.json',checks:earlier.source_checks,scope:'Exactly unchanged updater source retains the already-verified lifecycle fix; repeated updater and installer tests omitted.'};
const source_sha256={};for(const file of ['scripts/main.gd','scripts/rts_hud.gd','scripts/game_updater.gd','data/game.json','data/update_channel.json','project.godot'])source_sha256[file]=hash(file);
const result={passed:true,version:'0.6.9',tag:'feedback15-20261026',source_checks:reports.selection.checks,reports,source_sha256,scope:'New top-edge native selection regressions, shipping EXE startup, unchanged gameplay data and prior updater fix, ZIP CRC/SHA256/icon. No AI matches or repeated full gameplay validation.'};
fs.writeFileSync(path.join(qa,'exports.json'),JSON.stringify(result,null,2));fs.writeFileSync(path.join(out,'release-validation.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({passed:true,checks:result.source_checks,bytes:reports.archive.bytes}));
