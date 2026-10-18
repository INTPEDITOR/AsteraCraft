const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.8-modular-banks-ramp-20261018');
const copy=(src,dest)=>{const p=path.join(out,dest);fs.mkdirSync(path.dirname(p),{recursive:true});fs.copyFileSync(path.join(root,src),p)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v058-modular-banks/'+name,name);
copy('Start_Game.cmd','Start_Game.cmd');copy('docs/changes-v058-modular-banks.txt','CHANGES.txt');
for(const name of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+name,'licenses/'+name);
for(const name of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+name,'licenses/'+name);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.5.8 절벽 연결·장식 배치 수정판\r\n폴더 전체를 유지하고 AsteraCraft.exe를 실행하세요. PCK와 DLL은 EXE 옆에 있어야 합니다.\r\n물가/층간 절벽의 직선·모서리·경사로 연결을 정리하고 같은 장식이 몰리는 배치를 수정했습니다.\r\nHUD 비율과 비행체 시점은 유지합니다. 세부 사항은 CHANGES.txt를 참고하세요.\r\n');
for(const name of fs.readdirSync(path.join(root,'build/modular-banks')).filter(n=>/^(start|ground|cliff|shore|ramp|zoom)-\d\.png$/.test(n)||['modules.log','audit.json','quality.log','scenery.log','variety.log','visual.log','original.log','seams.log'].includes(n)))copy('build/modular-banks/'+name,'QA/'+name);
copy('build/visual-locks-v053.json','QA/visual-locks-v053.json');
for(const name of ['pack-check.log','boot-check.log'])if(fs.existsSync(path.join(root,'build/release-v058-modular-banks',name)))copy('build/release-v058-modular-banks/'+name,'QA/'+name);
for(const name of ['art-prompts-modular-banks.json','art-prompts-modular-banks-refined.json'])copy('docs/'+name,'QA/'+name);
const files=[];
function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.8',patch:'modular-banks',date:'2026-10-18',files},null,2));console.log({out,files:files.length});
