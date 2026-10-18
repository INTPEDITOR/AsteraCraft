const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.9-20261018');
function copy(src,dest){const p=path.join(out,dest);fs.mkdirSync(path.dirname(p),{recursive:true});fs.copyFileSync(path.join(root,src),p);}
for(const name of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v059/'+name,name);
copy('Start_Game.cmd','Start_Game.cmd');copy('docs/changes-v059.txt','CHANGES.txt');copy('docs/art-v059-prompts.txt','QA/art-prompts.txt');
copy('docs/citrus-bat-atlas-layout-prompt.txt','QA/bat-layout-prompt.txt');copy('build/bat-atlas.log','QA/bat-atlas.log');
copy('assets/game_icon.ico','AsteraCraft.ico');
copy('build/exe-icon-final.png','QA/windows-exe-icon.png');copy('build/p2p-release-v058.json','QA/p2p-release-v059.json');
for(const name of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+name,'licenses/'+name);
for(const name of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+name,'licenses/'+name);
for(const name of ['interaction-v059.log','citrus_cancel_worker_test.log','root-growth.log','root-chunks.log','root-visual-updated.log','lobby_buttons_v058_test-v059.log','fog_building_memory_test-v059.log','p2p-source-v058.json','interaction-v059.png'])if(fs.existsSync(path.join(root,'build',name)))copy('build/'+name,'QA/'+name);
for(const name of ['pack-check.log','boot-check.log'])if(fs.existsSync(path.join(root,'build/release-v059',name)))copy('build/release-v059/'+name,'QA/'+name);
for(let i=0;i<3;i++)copy(`build/map-photo-tour/map-${i}-roots-hidden-source.png`,`QA/map-${i}-root-boundary.png`);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.5.9\r\n폴더 전체를 유지하고 AsteraCraft.exe 또는 Start_Game.cmd를 실행하세요.\r\nPCK와 DLL은 실행 파일 옆에 있어야 합니다. 변경 내용은 CHANGES.txt를 참고하세요.\r\n');
const files=[];function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')});}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.9',date:'2026-10-18',files},null,2));console.log({out,files:files.length});
