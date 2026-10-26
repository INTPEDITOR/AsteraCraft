const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback14_20261026');fs.mkdirSync(out,{recursive:true});
const version='0.6.8',tag='feedback14-20261026';
const project=path.join(root,'project.godot');fs.writeFileSync(project,fs.readFileSync(project,'utf8').replace(/config\/version="[^"]+"/,'config/version="'+version+'"'));
const dataPath=path.join(root,'data/game.json'),data=JSON.parse(fs.readFileSync(dataPath));data.version=version;fs.writeFileSync(dataPath,JSON.stringify(data,null,2)+'\n');
fs.writeFileSync(path.join(root,'data/update_channel.json'),JSON.stringify({repository:'INTPEDITOR/AsteraCraft',tag,built_at_unix:Math.floor(Date.now()/1000),channel:'official'},null,2)+'\n');
const notes=`업데이트 버튼이 ‘확인 중…’에서 멈추는 시작 화면 전환 오류를 수정했습니다.

- 타이틀에서 메인 화면을 미리 준비하는 동안에는 업데이트 연결을 시작하지 않습니다. 메인 화면으로 이동한 뒤 한 번 확인합니다.
- 연결이 중단되거나 응답이 없으면 대기를 종료하고 수동 재시도 버튼을 제공합니다. 자동으로 반복 다운로드하거나 재시작하지 않습니다.
- 0.6.7의 유닛 밸런스와 여섯 난이도는 그대로 유지합니다.

0.6.7에서 ‘확인 중…’이 계속 보이면 이 ZIP 전체를 새 폴더에 풀고 AsteraCraft.exe를 실행해 주세요. EXE/PCK/DLL을 함께 두세요. 기존 사용자 설정은 같은 저장 위치를 사용합니다. 0.6.8부터는 메인 화면의 업데이트 확인이 정상 작동합니다.
`;
fs.writeFileSync(path.join(out,'release-notes.md'),notes);
fs.writeFileSync(path.join(root,'docs/FEEDBACK_FIXES14_20261026.md'),'# 업데이트 확인 멈춤 수정\n\n'+notes);
for(const [src,dst]of [['assets/game_icon.ico','game_icon.ico'],['assets/fonts/OFL-LevelUp.txt','LICENSES-LevelUp.txt']])fs.copyFileSync(path.join(root,src),path.join(out,dst));
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 '+version+'\nZIP 전체를 새 폴더에 풀고 AsteraCraft.exe를 실행하세요. EXE/PCK/DLL은 같은 폴더에 두세요.\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/'+tag+'\n');
for(const kind of ['export','publish']){
 let source=fs.readFileSync(path.join(root,'tools/'+kind+'_feedback13_20261026.cjs'),'utf8');
 source=source.replaceAll('feedback13_20261026','feedback14_20261026').replaceAll('feedback13-20261026',tag).replaceAll('FEEDBACK13','FEEDBACK14').replace('AsteraCraft AI·밸런스·난이도 수정판 - 2026-10-26','AsteraCraft 업데이트 확인 수정판 - 2026-10-26');
 fs.writeFileSync(path.join(root,'tools/'+kind+'_feedback14_20261026.cjs'),source);
}
fs.writeFileSync(path.join(root,'tools/package_feedback14_20261026.py'),fs.readFileSync(path.join(root,'tools/package_feedback13_20261026.py'),'utf8').replaceAll('feedback13_20261026','feedback14_20261026').replaceAll('feedback13-20261026',tag));
const readmePath=path.join(root,'README.md');let readme=fs.readFileSync(readmePath,'utf8').replaceAll('v0.6.7','v0.6.8').replaceAll('feedback13-20261026',tag);
const start=readme.indexOf('## 현재 버전'),end=readme.indexOf('## 게임 기능',start);
if(start>=0&&end>start)readme=readme.slice(0,start)+'## 현재 버전\n\n- 시작 화면 전환 후 업데이트 버튼이 계속 확인 중으로 남는 오류를 수정했습니다.\n- [이번 수정 내역](docs/FEEDBACK_FIXES14_20261026.md). 0.6.7 밸런스·AI·난이도 설정은 유지합니다.\n\n'+readme.slice(end);
fs.writeFileSync(readmePath,readme);
console.log('FEEDBACK14_PREPARED '+out);
