const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback15_20261026');fs.mkdirSync(out,{recursive:true});
const version='0.6.9',tag='feedback15-20261026';
const p=path.join(root,'project.godot');fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/config\/version="[^"]+"/,'config/version="'+version+'"'));
const dataPath=path.join(root,'data/game.json'),data=JSON.parse(fs.readFileSync(dataPath));data.version=version;fs.writeFileSync(dataPath,JSON.stringify(data,null,2)+'\n');
fs.writeFileSync(path.join(root,'data/update_channel.json'),JSON.stringify({repository:'INTPEDITOR/AsteraCraft',tag,built_at_unix:Math.floor(Date.now()/1000),channel:'official'},null,2)+'\n');
const notes=`맵 최상단의 보이는 유닛이 선택되지 않는 문제를 수정했습니다. 업데이트 확인 멈춤 수정도 포함합니다.

- 높이가 있는 북쪽 지형과 경계 위로 보이는 유닛 몸체에도 클릭·드래그·동일 종류 선택이 작동합니다.
- 화면에 일부만 보이는 유닛은 보이는 몸체로 선택합니다. 상단 자원 숫자 뒤의 보이지 않는 클릭 차단 영역을 없앴습니다.
- 실제 하단 HUD, 맵 좌우/아래 바깥과 시야에 없는 적의 선택 제한은 유지합니다. 카메라·맵·유닛 능력치·난이도는 변경하지 않았습니다.
- 0.6.8의 업데이트 수정 포함: 타이틀 전환 후 확인을 시작하고 중단·시간 초과 때 무한 대기하지 않고 수동 재시도가 가능해집니다.

0.6.7에서 ‘확인 중…’이 계속 보이면 이번 한 번은 ZIP 전체를 새 폴더에 풀고 AsteraCraft.exe를 실행해 주세요. EXE/PCK/DLL을 함께 두세요. 사용자 설정 저장 위치는 그대로 사용합니다. 0.6.8 이상에서는 메인 화면 업데이트를 이용할 수 있습니다.
`;
fs.writeFileSync(path.join(out,'release-notes.md'),notes);fs.writeFileSync(path.join(root,'docs/FEEDBACK_FIXES15_20261026.md'),'# 맵 최상단 선택 및 업데이트 확인 수정\n\n'+notes);
for(const [src,dst]of [['assets/game_icon.ico','game_icon.ico'],['assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt']])fs.copyFileSync(path.join(root,src),path.join(out,dst));
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 '+version+'\nZIP 전체를 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/'+tag+'\n');
for(const kind of ['export','publish']){
 let source=fs.readFileSync(path.join(root,'tools/'+kind+'_feedback14_20261026.cjs'),'utf8');
 source=source.replaceAll('feedback14_20261026','feedback15_20261026').replaceAll('feedback14-20261026',tag).replaceAll('FEEDBACK14','FEEDBACK15').replace('AsteraCraft 업데이트 확인 수정판 - 2026-10-26','AsteraCraft 최상단 선택·업데이트 수정판 - 2026-10-26');
 fs.writeFileSync(path.join(root,'tools/'+kind+'_feedback15_20261026.cjs'),source);
}
fs.writeFileSync(path.join(root,'tools/package_feedback15_20261026.py'),fs.readFileSync(path.join(root,'tools/package_feedback14_20261026.py'),'utf8').replaceAll('feedback14_20261026','feedback15_20261026').replaceAll('feedback14-20261026',tag));
const readmePath=path.join(root,'README.md');let readme=fs.readFileSync(readmePath,'utf8').replaceAll('v0.6.8','v0.6.9').replaceAll('feedback14-20261026',tag);
const start=readme.indexOf('## 현재 버전'),end=readme.indexOf('## 게임 기능',start);
if(start>=0&&end>start)readme=readme.slice(0,start)+'## 현재 버전\n\n- 맵 최상단 유닛의 선택과 업데이트 확인 멈춤을 수정했습니다.\n- [이번 수정 내역](docs/FEEDBACK_FIXES15_20261026.md). 기존 밸런스·AI·난이도 설정은 유지합니다.\n\n'+readme.slice(end);
fs.writeFileSync(readmePath,readme);console.log('FEEDBACK15_PREPARED '+out);
