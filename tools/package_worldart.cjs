const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.8-worldart-20261018');
const copy=(src,dest)=>{const p=path.join(out,dest);fs.mkdirSync(path.dirname(p),{recursive:true});fs.copyFileSync(path.join(root,src),p)};
for(const n of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v058-worldart/'+n,n);
copy('Start_Game.cmd','Start_Game.cmd');copy('docs/changes-v058-worldart.txt','CHANGES.txt');
for(const n of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+n,'licenses/'+n);
for(const n of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+n,'licenses/'+n);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.5.8 신규 지형 아트판\r\n폴더 전체를 유지하고 AsteraCraft.exe를 실행하세요. PCK와 DLL은 EXE 옆에 있어야 합니다.\r\n새 재질21종/장식54종을 세 맵에 적용하고 물·지면·층간 경계를 분리했습니다.\r\n기본 바닥은 개별 고해상도 원본, 장식은 기존 포함 총90종입니다.\r\nHUD 비율과 비행체 시점을 유지합니다. 세부 사항은 CHANGES.txt를 참고하세요.\r\n');
for(const n of ['worldart-seams.log','worldart-cliff-roles.log','worldart-scenery.log','worldart-quality.log','worldart-original.log','worldart-visual.log','visual-locks-v053.json','release-v058-worldart/pack-check.log','release-v058-worldart/boot-check.log'])if(fs.existsSync(path.join(root,'build',n)))copy('build/'+n,'QA/'+path.basename(n));
for(const n of fs.readdirSync(path.join(root,'build')).filter(n=>/^worldart-(start|ground|cliff|shore|zoom)-\d\.png$/.test(n)))copy('build/'+n,'QA/'+n);
for(const n of ['art-prompts-worldart.json','art-prompts-worldart-refined.json','art-prompts-worldart-hd.json','art-prompts-worldart-decor-expanded.json'])copy('docs/'+n,'QA/'+n);
const files=[];function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.8',patch:'worldart',date:'2026-10-18',files},null,2));console.log({out,files:files.length});
