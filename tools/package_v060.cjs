const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.6.0-20261021');
function copy(src,dest){const p=path.join(out,dest);fs.mkdirSync(path.dirname(p),{recursive:true});fs.copyFileSync(path.join(root,src),p);}
for(const name of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v060/'+name,name);
copy('Start_Game.cmd','Start_Game.cmd');copy('docs/changes-v060.txt','CHANGES.txt');copy('assets/game_icon.ico','AsteraCraft.ico');
for(const name of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+name,'licenses/'+name);
for(const name of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+name,'licenses/'+name);
for(const name of ['core-results.json','ui-results.json','final-results.json','long-final-results.json','sprite-crop-audit.json'])copy('build/qa-v060/'+name,'QA/'+name);
copy('build/qa-v060/long-burst-final.json','QA/long-burst-final.json');
for(const name of ['pack-check.log','boot-check.log','music-check.log'])copy('build/release-v060/'+name,'QA/'+name);
for(const name of ['industrial_units_v060.json','portraits_v060.json','voice_effects_v058.json','public_network.json'])copy('data/'+name,'QA/'+name);
copy('assets/audio/manifest_v060.json','QA/sound-effects.json');copy('build/p2p-release-v058.json','QA/p2p-release.json');
copy('docs/art-industrial-v060-prompts.txt','QA/art-industrial-prompts.txt');
copy('build/fortress-cannons-final.png','QA/fortress-directions.png');
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.6.0\r\n압축을 풀고 폴더 전체를 유지한 채 AsteraCraft.exe 또는 Start_Game.cmd를 실행하세요.\r\nPCK와 DLL은 실행 파일 옆에 있어야 합니다. 멀티플레이는 참가자 모두 v0.6.0이 필요합니다.\r\n변경 내용: CHANGES.txt / 생성 음성·효과음 출처: licenses/Audio-Credits.txt\r\n');
const files=[];function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')});}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.6.0',date:'2026-10-21',source_commit:require('child_process').execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),files},null,2));console.log({out,files:files.length});
