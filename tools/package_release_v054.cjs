const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.4-20261016');
const copy=(src,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(root,src),dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck'])copy('build/release-v054/'+name,name);
for(const name of ['node.exe','Node-LICENSE.txt','Node-VERSION.txt'])copy('runtime/'+name,'runtime/'+name);
for(const name of ['Start_Game.cmd','Start_Server.cmd','network.example.json'])copy(name,name);
copy('server/server.js','server/server.js');
const licenseDir=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.4/licenses');
for(const name of fs.readdirSync(licenseDir))copy(path.relative(root,path.join(licenseDir,name)),'licenses/'+name);
copy('docs/changes-v054.txt','CHANGES.txt');copy('docs/nutrient-sprite-v053-prompt.txt','QA/nutrient-sprite-prompt.txt');
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.4 / 2026-10-16',
'ZIP을 전부 압축 해제한 뒤 AsteraCraft.exe를 실행하세요.',
'AsteraCraft.pck, runtime, server 폴더를 EXE 옆에 유지하세요.',
'멀티플레이 참가자는 모두 v0.5.4을 사용하세요. 기본 로비는 로컬/LAN입니다.',
'구버전 로비 서버가 실행 중이면 종료한 뒤 새 버전의 Start_Server.cmd를 실행하세요.',
'',
'군체모수 통합 생산, 12칸 추가배양낭 연결, 13칸 뿌리 지대와 건설 제한, 어택땅 아군 방어 우선.',
'껍질발톱 아스50 / 2마리 생산.',
'원본 세 맵, 접목충 Q 정신 조종, 건설 메뉴 정보, 양분 저장낭 새 그림, 초상화 잘림 수정.',
'HUD 비율과 비행체 시점은 유지했습니다. 세부 동작/검증 범위는 CHANGES.txt와 QA 폴더 참고.',
'원본 맵의 배치와 지형을 적용했으며 충돌은 기존 32픽셀 격자입니다.',
'외부 TTS 교체·공개 인터넷 로비·장시간 경쟁 밸런스 검증은 아직 남아 있습니다.',''
].join('\r\n'));
const reports=['colony-root-ground.png','colony-root-threat.log','colony-root-visual.log','swarm-pair-v053.log','original-maps-control.log','original-maps-visual-final.log','portrait-fit-v053.log','visual-locks-v053.json','bot-v053-report.json','v053-completion_v052_test.log','v053-cloak_v052_test.log','v053-replay_v052_test.log','observer-network-v052.json','release-v054/pack-check.log','release-v054/boot-check.log','release-v054/online-check.log'];
for(const file of reports)if(fs.existsSync(path.join(root,'build',file)))copy('build/'+file,'QA/'+path.basename(file));
const inventory=[];function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);inventory.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.4',date:'2026-10-16',files:inventory},null,2));console.log({out,files:inventory.length});
