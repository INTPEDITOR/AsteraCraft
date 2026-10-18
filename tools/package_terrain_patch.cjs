const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.8-terrainfix-20261018');
const copy=(src,dest)=>{const p=path.join(out,dest);fs.mkdirSync(path.dirname(p),{recursive:true});fs.copyFileSync(path.join(root,src),p)};
for(const n of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v058-terrainfix/'+n,n);
copy('Start_Game.cmd','Start_Game.cmd');
copy('docs/changes-v058-terrain.txt','CHANGES.txt');
for(const n of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+n,'licenses/'+n);
for(const n of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+n,'licenses/'+n);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 v0.5.8 지형 수정판\r\n폴더 전체를 유지하고 AsteraCraft.exe를 실행하세요. PCK와 DLL은 EXE 옆에 있어야 합니다.\r\n기존 HUD 비율과 비행체 시점을 유지하며 평지의 절벽 오류와 마름모 타일 이음새를 수정했습니다.\r\n세부 사항은 CHANGES.txt를 참고하세요.\r\n');
for(const n of ['terrain-seams.log','cliff-roles.log','terrain-patch-scenery.log','terrain-patch-quality.log','terrain-patch-original.log','terrain-patch-visual.log','visual-locks-v053.json','v058-map-r0.png','v058-map-r1.png','v058-map-r2.png','v058-scenery-r0.png','v058-scenery-r1.png','v058-scenery-r2.png','release-v058-terrainfix/pack-check.log','release-v058-terrainfix/boot-check.log']){
 if(fs.existsSync(path.join(root,'build',n)))copy('build/'+n,'QA/'+path.basename(n));
}
const files=[];function scan(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())scan(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
scan(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.8',patch:'terrainfix',date:'2026-10-18',files},null,2));console.log({out,files:files.length});
