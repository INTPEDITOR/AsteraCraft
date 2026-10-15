const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5.2-20261016');
fs.mkdirSync(out,{recursive:true});
const copy=(from,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(from,dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck'])copy(path.join(root,'build/release-v052',name),name);
for(const name of ['node.exe','Node-LICENSE.txt','Node-VERSION.txt'])copy(path.join(root,'runtime',name),'runtime/'+name);
for(const name of ['Start_Game.cmd','Start_Server.cmd','network.example.json'])copy(path.join(root,name),name);
copy(path.join(root,'server/server.js'),'server/server.js');
const licenses=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.4/licenses');
for(const name of fs.readdirSync(licenses))copy(path.join(licenses,name),'licenses/'+name);
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5.2 / Windows / 2026-10-16','',
'ZIP을 전부 압축 해제한 뒤 AsteraCraft.exe를 실행하세요.',
'AsteraCraft.pck와 runtime, server 폴더를 EXE 옆에 유지하세요. Godot나 Node.js 별도 설치는 필요하지 않습니다.','',
'변경 내용',
'- 건설은 일꾼 현장 도착 후 배치와 자원을 다시 확인한 뒤 시작합니다.',
'- 바위너구리 정찰병 C키 에너지 은폐, 접목충 공격 후 2초 노출, 황혼잠행자 영구 은폐.',
'- 관전자 최대 4명, 전투 참가자 최대 4명. 관전 종료 화면은 승패/래더 점수와 분리됩니다.',
'- 리플레이는 기록 시간에 맞춰 재생하며 위치/방향을 보간합니다.',
'- 유닛별 사망 효과음 39개를 추가했습니다. 효과음 음량 설정을 따릅니다.',
'- 부엉이 공중 4종의 실루엣을 구분하고 공중 유닛의 사선 시점과 방향을 수정했습니다.',
'- 무인 정찰 드론은 몸체와 고정된 세 회전익을 조합합니다.',
'- 미사일 차량의 차체와 포탑은 각각 이동/공격 방향을 따릅니다.','',
'- HUD 전체 비율과 칸 배치는 유지하고, 귤/부엉이 메뉴를 겹침 없는 검은색 한 줄 버튼으로 수정했습니다.','',
'검수 자료: QA_REPORT.json 및 BUILD_MANIFEST.json.','',
'남아 있는 한계',
'- 공개 인터넷 로비 서버는 배포하지 않았습니다. 기본 멀티플레이는 로컬/LAN입니다.',
'- 사망 효과음은 자체 합성입니다. 외부 TTS 녹음 교체는 포함되지 않았습니다.',
'- 공중 시트는 5개 원화 방향을 좌우 반전해 8방향으로 표시합니다. 귤 날갯짓 원화는 2자세입니다.',
'- 제공된 SCM/SCX 맵 분석 자료는 있으나 원본 지형과 동일한 게임 맵 적용은 아직 완료되지 않았습니다.',
'- 접목충의 기생/정신 조종 능력은 구현되지 않았습니다. 최종 경쟁 밸런스 검증은 별도입니다.','',
'Godot 4.6 stable 공식 Windows x86_64 release template. 라이선스는 licenses 폴더 참고.',''
].join('\r\n'));
const qa=path.join(root,'build/qa-v052.json');if(fs.existsSync(qa))copy(qa,'QA_REPORT.json');
for(const name of ['replay-performance-v052.json','observer-network-v052.json'])if(fs.existsSync(path.join(root,'build',name)))copy(path.join(root,'build',name),'QA/'+name);
copy(path.join(root,'assets/audio/death_v052.json'),'QA/death-audio.json');
const inventory=[];
function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);inventory.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.2',date:'2026-10-16',engine:'4.6.stable.official.89cea1439',files:inventory},null,2));
console.log(JSON.stringify({out,files:inventory.length,bytes:inventory.reduce((n,f)=>n+f.bytes,0)}));
