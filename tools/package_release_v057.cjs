const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.7-20261018');
const copy=(src,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,src),dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck'])copy('build/release-v057/'+name,name);
for(const name of ['node.exe','Node-LICENSE.txt','Node-VERSION.txt'])copy('runtime/'+name,'runtime/'+name);
for(const name of ['Start_Game.cmd','Start_Server.cmd','network.example.json'])copy(name,name);
copy('server/server.js','server/server.js');
const licenseDir=path.join(root,'licenses');
for(const name of fs.readdirSync(licenseDir))copy(path.relative(root,path.join(licenseDir,name)),'licenses/'+name);
copy('docs/changes-v057.txt','CHANGES.txt');copy('docs/nutrient-sprite-v053-prompt.txt','QA/nutrient-sprite-prompt.txt');
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.7 / 2026-10-18',
'ZIP을 전부 압축 해제한 뒤 AsteraCraft.exe를 실행하세요.',
'AsteraCraft.pck, runtime, server 폴더를 EXE 옆에 유지하세요.',
'멀티플레이 참가자는 모두 v0.5.7을 사용하세요. 기본 로비는 로컬/LAN입니다.',
'구버전 로비 서버가 실행 중이면 종료한 뒤 새 버전의 Start_Server.cmd를 실행하세요.',
'',
'메인 Echoes of Astera / 바위너구리 Ironbound Frontier / 귤 Seeds of Dominion / 부엉이 Crimson Covenant. 반복 재생·화면 전환 적용.',
'테라 좌표·건설 수정, 본진 아래 일꾼4명 가로 배치 후 가까운 아스 자동 채취, 채취 경로 개선·채취 일꾼 유닛 충돌 무시.',
'군체모수 통합 생산, 12칸 추가배양낭 연결, 13칸 뿌리 지대와 건설 제한, 어택땅 아군 방어 우선.',
'껍질발톱 아스50 / 2마리 생산.',
'원본 세 맵, 접목충 Q 정신 조종, 건설 메뉴 정보, 양분 저장낭 새 그림, 초상화 잘림 수정.',
'HUD 비율과 비행체 시점은 유지했습니다. 세부 동작/검증 범위는 CHANGES.txt와 QA 폴더 참고.',
'원본 맵의 배치와 지형을 적용했으며 충돌은 기존 32픽셀 격자입니다.',
'외부 TTS 교체·공개 인터넷 로비·장시간 경쟁 밸런스 검증은 아직 남아 있습니다.',''
].join('\r\n'));
copy('assets/music/manifest.json','QA/music-manifest.json');
copy('build/supplied-music-wasapi-v057.log','QA/supplied-music-wasapi-v057.log');
const reports=['supplied-music-v057.log','music-scene-v057.log','user-music-v057.log','release-v057/music-check.log','auto-mining-v056.log','tera-pointer-v055.log','starting-row-0.png','starting-row-1.png','starting-row-2.png','tera-map-audit.log','tera-map-audit.json','mining-route-v055.log','collision-v055.log','colony-root-ground.png','colony-root-threat.log','colony-root-visual.log','swarm-pair-v053.log','original-maps-control.log','original-maps-visual-final.log','portrait-fit-v053.log','visual-locks-v053.json','bot-v053-report.json','v053-completion_v052_test.log','v053-cloak_v052_test.log','v053-replay_v052_test.log','observer-network-v052.json','release-v057/pack-check.log','release-v057/boot-check.log','release-v057/online-check.log'];
for(const file of reports)if(fs.existsSync(path.join(root,'build',file)))copy('build/'+file,'QA/'+path.basename(file));
fs.writeFileSync(path.join(out,'QA/README.txt'),'v0.5.7 신규 검사: supplied-music-v057, supplied-music-wasapi-v057, music-scene-v057, user-music-v057, music-check, pack-check, boot-check, online-check.\r\nvisual-locks-v053.json도 이번 버전에서 재검사했습니다.\r\n나머지 QA 파일은 v0.5.6 이전 기능의 기존 검증 기록이며 이번 BGM 변경에서 재실행한 결과가 아닙니다.\r\n');
const inventory=[];function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);inventory.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.7',date:'2026-10-18',files:inventory},null,2));console.log({out,files:inventory.length});
