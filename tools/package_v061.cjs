const fs=require('fs'),path=require('path'),crypto=require('crypto'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.6.1-20261021');
function copy(source,target){const dest=path.join(out,target);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,source),dest);}
for(const name of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v061/'+name,name);
copy('Start_Game.cmd','Start_Game.cmd');copy('docs/changes-v061.txt','CHANGES.txt');copy('assets/game_icon.ico','AsteraCraft.ico');
for(const name of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+name,'licenses/'+name);
for(const name of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+name,'licenses/'+name);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.6.1\r\n압축을 풀고 폴더 전체를 유지한 채 AsteraCraft.exe 또는 Start_Game.cmd를 실행하세요.\r\nPCK와 DLL은 실행 파일 옆에 있어야 합니다. 멀티플레이는 참가자 모두 v0.6.1이 필요합니다.\r\n변경 내용: CHANGES.txt / 검사 결과: QA 폴더\r\n');
if(process.argv.includes('--stage')){console.log('Staged exported game at '+out);process.exit(0);}
for(const name of ['core-results.json','ui-results.json'])copy('build/qa-v061/'+name,'QA/'+name);
for(const name of ['active-frame-audit','area-weapons','art','fog-render','late-game-final','icons'])copy('build/qa-v061-'+name+'.json','QA/'+name+'.json');
for(const name of ['pack-check.log','boot-check.log','music-check.log'])copy('build/release-v061/'+name,'QA/'+name);
copy('build/p2p-release-v061.json','QA/p2p-release.json');copy('docs/art-v061-prompts.txt','QA/art-prompts.txt');copy('docs/qa-v061.txt','QA/NOTES.txt');
for(const name of ['flame-directions','tank-transform','vehicles','fog-game'])copy('build/qa-v061-'+name+'.png','QA/'+name+'.png');
for(const name of ['siege_layers_v061.json','flame_stream_v061.json','frame_cleanup_v061.json','public_network.json'])copy('data/'+name,'QA/'+name);
const files=[];function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')});}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.6.1',date:'2026-10-21',source_commit:cp.execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),files},null,2));console.log(JSON.stringify({out,files:files.length}));
