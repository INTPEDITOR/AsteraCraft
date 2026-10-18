const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.8-20261018');
const copy=(src,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,src),dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck','libwebrtc_native.windows.template_release.x86_64.dll'])copy('build/release-v058/'+name,name);
copy('Start_Game.cmd','Start_Game.cmd');
for(const name of fs.readdirSync(path.join(root,'licenses')))copy('licenses/'+name,'licenses/'+name);
for(const name of fs.readdirSync(path.join(root,'addons/webrtc_native')).filter(n=>n.startsWith('LICENSE.')))copy('addons/webrtc_native/'+name,'licenses/'+name);
copy('docs/changes-v058.txt','CHANGES.txt');
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.8 / 2026-10-18',
'ZIP 전체를 압축 해제하고 AsteraCraft.exe를 실행하세요.',
'AsteraCraft.pck와 libwebrtc_native.windows.template_release.x86_64.dll은 EXE 옆에 유지하세요.',
'로그인, 래더 대기, 커스텀 방 목록·입장·관전은 게임 안에서 이용합니다. 모든 참가자는 같은 버전을 사용하세요.',
'공개 서비스는 계정·매칭·연결 정보만 처리합니다. 실제 전투는 방장 PC의 별도 게임 프로세스에서 진행됩니다.',
'현재 직접 연결만 지원합니다. 엄격한 공유기/NAT/방화벽에서는 연결 실패할 수 있으며 중계 서버는 사용하지 않습니다.',
'온라인 자동 검증은 같은 PC의 방장·참가자·관전자 세 프로세스로 공개 HTTPS 서비스를 이용해 수행했습니다. 서로 다른 인터넷 회선 검증은 남아 있습니다.',
'36종 지형 장식, 192×96 마름모 배치, 지면 색감 통일, 대형 유닛 경로·근접 접근·건설 일꾼 충돌 수정, 테라 3초 주기, 부엉이 탑 건설 범위를 적용했습니다.',
'HUD 비율과 승인된 비행체 시점은 유지합니다. 종족별 BGM과 기존 수정 사항을 포함합니다.',
'대규모 밀집 근접전 성능과 경쟁 밸런스는 추가 검증이 필요합니다. 자세한 내용은 CHANGES.txt와 QA 폴더를 참고하세요.',''
].join('\r\n'));
const reports=['scenery-v058.log','scenery-v058.json','terrain-v058-final.log','visual-v058-final.log','movement-v058.log','collision-v058.log','auto-mining-v056.log','tera-map-audit.log','original-maps-control.log','colony-root-threat.log','motion-v058.log','motion-v058-audit.json','visual-locks-v053.json','performance-v058-combat.log','v058-map-r0.png','v058-map-r1.png','v058-map-r2.png','v058-scenery-r0.png','v058-scenery-r1.png','v058-scenery-r2.png','p2p-release-v058.json','release-v058/pack-check.log','release-v058/boot-check.log','release-v058/music-check.log'];
for(const f of reports)if(fs.existsSync(path.join(root,'build',f)))copy('build/'+f,'QA/'+path.basename(f));
for(const f of ['mining-v058.log','tera-v058.log','original-v058.log','colony-v058.log','bot-v058.log','p2p-0-output.log','p2p-1-output.log','p2p-2-output.log','matchmaking-service-v058.json'])copy('build/'+f,'QA/'+f);
copy('assets/music/manifest.json','QA/music-manifest.json');
copy('docs/art-prompts-v058-final.json','QA/art-prompts-v058-final.json');
copy('docs/art-prompts-v058.json','QA/art-prompts-v058.json');
fs.writeFileSync(path.join(out,'QA/README.txt'),'v058 이름 검사와 visual-locks-v053.json은 이번 작업에서 실행했습니다. pack-check는 최종 PCK를 Godot 검사 실행기로 로드한 검사이며, boot-check와 p2p-release-v058.json은 실제 배포 EXE 검사입니다. p2p는 공개 HTTPS 서비스를 거친 동일 PC의 2명+관전자 연결이며 서로 다른 회선 검증이 아닙니다. 이름이 이전 버전인 별도 기록은 참고용입니다.\r\n');
const files=[];function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);files.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.8',date:'2026-10-18',files},null,2));console.log({out,files:files.length});
