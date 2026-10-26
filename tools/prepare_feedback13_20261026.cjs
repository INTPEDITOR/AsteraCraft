const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback13_20261026');fs.mkdirSync(out,{recursive:true});
const version='0.6.7',tag='feedback13-20261026';
const project=path.join(root,'project.godot');fs.writeFileSync(project,fs.readFileSync(project,'utf8').replace(/config\/version="[^"]+"/,'config/version="'+version+'"'));
const dataPath=path.join(root,'data/game.json'),data=JSON.parse(fs.readFileSync(dataPath));data.version=version;fs.writeFileSync(dataPath,JSON.stringify(data,null,2)+'\n');
fs.writeFileSync(path.join(root,'data/update_channel.json'),JSON.stringify({repository:'INTPEDITOR/AsteraCraft',tag,built_at_unix:Math.floor(Date.now()/1000),channel:'official'},null,2)+'\n');
const notes=`헬 AI 실전 통계에 따른 밸런스와 전술·경제·난이도 개선을 반영했습니다.

- 화염돌파차 공격력9→10, 후피거수 체력310→290, 가시꽃 사거리6.8→6.3, 서약수호자 비용125→110아스.
- 주력 유닛이 쓰는 연구소·선행 건물을 마련하고 사거리·공격속도·전투자극제 연구를 실제 병력에 맞춰 선택합니다. 지원 마법사·의무병 과잉 생산을 줄였습니다.
- 6단계 AI 행동 예산은 매우 쉬움50/쉬움100/보통150/어려움200/매우 어려움250/헬 평시300·교전450APM입니다. 의미 없는 입력으로 수치를 채우지 않습니다.
- AI 운용 인구 목표는50/80/120/160/180/200, 기지당 일꾼 목표는8/12/16/16/16/16입니다. 실제 남은 아스에2기까지만 붙이며 인간 플레이어의 인구·명령은 제한하지 않습니다.
- 난이도별 전술 폭과 확장·생산·정찰·집결·견제·교전 차이를 유지하고, 대규모 상위 AI가 장기 집결만 하지 않게 공세를 앞당겼습니다. 숨은 적 정보나 자원·유닛 특혜, 외부 AI API는 사용하지 않습니다.
- 앞선 미배포 개선도 포함합니다: 아스 회당8, 테라2.5초당12/고갈 후4, 일꾼 가속·감속과 정확한 자기 건물 경계 통행, 근접 포위, 정찰로 찾은 멀티 견제, 병력 우선 생산·확장 적립·보급·배양 개선, APM 표시, 시작 화면 실제 로딩 완료 후 입력.
- 석익병은 체력100/보호막280, 보호막이 있을 때 일반 공격1회의 최종 피해를25까지 받으며 작은 범위 공격을 합니다. 방패보병은 일반 원거리 피해를5 덜 받습니다. 연사·빔 분할 타격은 중복 감소하지 않습니다.
- 반복 표적 군집 계산과 같은 지형의 집결 연결성 탐색을 줄였습니다. 전체 화면FPS나 모든 지연 해소를 보증하는 수치는 아닙니다.

변경 전 헬 종족 간15판: 이귤8승2패, 노바너4승5패1무, 아라아울2승7패1무. 조합별5판의 제한된 표본이며 이번 소폭 조정 후 승률로 해석하지 않습니다. 실제 난이도 간 대전은 사용자 요청으로 생략했습니다. 변경 범위90개 동작 검사와 별도 최종 패키지·시작·업데이트 확인 결과를 함께 기록합니다.

기존 메인 화면의 업데이트 기능을 이용하거나 ZIP 전체를 풀어 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두고 멀티플레이 참가자는 같은 버전을 사용하세요.
`;
fs.writeFileSync(path.join(out,'release-notes.md'),notes);
fs.mkdirSync(path.join(root,'docs/verification_feedback13_20261026'),{recursive:true});
fs.writeFileSync(path.join(root,'docs/FEEDBACK_FIXES13_20261026.md'),'# AI·밸런스·난이도 수정판\n\n'+notes);
for(const [src,dst]of [['assets/game_icon.ico','game_icon.ico'],['assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt']])fs.copyFileSync(path.join(root,src),path.join(out,dst));
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 '+version+'\nZIP 전체를 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/'+tag+'\n');
for(const kind of ['export','publish']){
 let source=fs.readFileSync(path.join(root,'tools/'+(kind==='export'?'export_feedback12_20261026.cjs':'publish_feedback12_20261026.cjs')),'utf8');
 source=source.replaceAll('feedback12_20261026','feedback13_20261026').replaceAll('feedback12-20261026',tag).replaceAll('FEEDBACK12','FEEDBACK13').replace('AsteraCraft 전술·헬·일꾼 중앙 통행 수정판 - 2026-10-26','AsteraCraft AI·밸런스·난이도 수정판 - 2026-10-26');
 fs.writeFileSync(path.join(root,'tools/'+kind+'_feedback13_20261026.cjs'),source);
}
const readmePath=path.join(root,'README.md');let readme=fs.readFileSync(readmePath,'utf8').replaceAll('v0.6.6','v0.6.7').replaceAll('feedback12-20261026',tag);
const start=readme.indexOf('## 현재 버전'),end=readme.indexOf('## 게임 기능',start);
if(start>=0&&end>start)readme=readme.slice(0,start)+'## 현재 버전\n\n- 실전 통계 기반 유닛 소폭 조정과 AI 주력 연구·생산·정찰·견제·교전 개선을 반영했습니다.\n- 6난이도의 APM과 경제·운용 인구·전술을 차등 적용했습니다.\n- [이번 수정 내역](docs/FEEDBACK_FIXES13_20261026.md). 실제 난이도 간 대전은 사용자 요청으로 생략했습니다.\n\n'+readme.slice(end);
fs.writeFileSync(readmePath,readme);
console.log('FEEDBACK13_PREPARED '+out);
