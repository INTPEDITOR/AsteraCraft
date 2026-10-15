const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const logs={cloak:'v052-cloak-current.log',replay:'v052-replay-current.log',feedback:'v052-feedback-current.log',completion:'completion-v052.log',graphics:'graphics-v052-current.log',visual:'visual-v052.log',audio:'audio-v052.log',releasePack:'release-v052/pack-check.log',releaseBoot:'release-v052/boot-check.log',onlineMenu:'release-v052/online-check.log'};
const checks={};
for(const [name,file] of Object.entries(logs)){
 const p=path.join(root,'build',file); if(!fs.existsSync(p))continue;
 const log=fs.readFileSync(p,'utf8');
 checks[name]={log:'build/'+file,result:log.trim().split(/\r?\n/).filter(l=>/checks|failures|ONLINE_OPEN|RELEASE_PROCESS_EXIT/.test(l))};
}
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const exe=path.join(root,'build/release-v052/AsteraCraft.exe');
const template=path.resolve(root,'../tools/godot/editor_data/export_templates/4.6.stable/windows_release_x86_64.exe');
const report={version:'0.5.2',date:'2026-10-16',checks,
 releaseExecutableMatchesOfficialTemplate:hash(exe)===hash(template),
 releaseObserverNetwork:JSON.parse(fs.readFileSync(path.join(root,'build/observer-network-v052.json'))),
 replayPerformance:JSON.parse(fs.readFileSync(path.join(root,'build/replay-performance-v052.json'))),
 hud:'v0.5.1 source comparison: geometry and scale unchanged. Menu recess and caption corrected after user overlap report.',
 caveats:['Ranked/custom source network test passed but logged ENet send errors during shutdown.','Synthetic death audio; no external TTS recordings.','SCM/SCX source maps not fully applied to runtime terrain.','Parasite mind control remains unimplemented.','Public internet lobby not deployed; competitive balance not certified.']};
fs.writeFileSync(path.join(root,'build/qa-v052.json'),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
