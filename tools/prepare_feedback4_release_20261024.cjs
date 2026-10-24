const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback4_20261024'),qa=path.join(root,'docs/verification_feedback4_20261024');
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(qa,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const hud=read('docs/egyul-hud-living-v2-art-20261024.json');hud.sha256=require('node:crypto').createHash('sha256').update(fs.readFileSync(path.join(root,hud.runtime))).digest('hex');hud.actual_runtime_verification='verification_feedback4_20261024/common-hud-r1-preview.png';hud.render_source_regions=[[0,134,2170,98],[0,232,2170,234],[0,466,2170,102]];hud.render_target_regions=[[0,0,1963,62],[0,62,1963,218],[0,280,1963,50]];fs.writeFileSync(path.join(root,'docs/egyul-hud-living-v2-art-20261024.json'),JSON.stringify(hud,null,2)+'\n');
const reports={logic:read('build/feedback4-20261024/logic-result.json'),screen:read('build/feedback4-20261024/screen-result.json'),hud:read('build/feedback4-20261024/egyul-hud-preview-result.json'),startup:read('build/feedback4-20261024/startup-preferences-result.json'),edges:read('build/feedback4-20261024/edges/result.json'),passives:read('build/passives-20261024/result.json'),passive_bot:read('build/passives-20261024/bot-result.json'),nuclear:read('build/nuclear_20261024/friendly-fire.json'),source_terrain:read('build/source-terrain/navigation.json'),regression:read('build/feedback3-20261024/result.json')};
for(const [key,value] of Object.entries(reports))if(value.passed===false||value.failures?.length)throw Error('Required check failed: '+key);
for(const [key,file] of Object.entries({updater_controller:'build/updater-test-20261024/controller-result.json',actual_update_restart:'build/updater-feedback4-e2e-20261024/result.json',exported_game:'build/feedback4_20261024/exe-smoke.json'})){
 if(fs.existsSync(path.join(root,file))){reports[key]=read(file);if(reports[key].passed===false||reports[key].failures?.length)throw Error('Required release check failed: '+key);}
}
fs.writeFileSync(path.join(qa,'checks.json'),JSON.stringify(reports,null,2)+'\n');
for(const name of ['common-hud-r1-preview','hud-common-comparison','menu-update-r0','menu-update-r1','menu-update-r2','tera-placement-r0','bomber-idle-sixteen-directions','bomber-moving-sixteen-directions','bomber-impact-complete','owl-archers-walking-southwest','southern-map-edge-above-hud','nuclear-varco-unavailable'])fs.copyFileSync(path.join(root,'build/feedback4-20261024',name+'.png'),path.join(qa,name+'.png'));
for(let race=0;race<3;race++)fs.copyFileSync(path.join(root,'build/feedback4-20261024/edges',`map${race}-perimeter.jpg`),path.join(qa,`map${race}-perimeter.jpg`));
const passive=read('docs/passive-research-20261024.json');passive.status='implemented_and_verified';passive.verification='verification_feedback4_20261024/checks.json';fs.writeFileSync(path.join(root,'docs/passive-research-20261024.json'),JSON.stringify(passive,null,2)+'\n');
const sound=read('docs/nuclear-sound-request-20261024.json');sound.retry_20261024={prompt:'One realistic nuclear-scale blast, 8 seconds. Abrupt enormous pressure-wave crack and deep sub-bass impact, followed by dense rolling thunder, turbulent air and heavy low-frequency rumble decaying naturally over open terrain. Documentary field-recording realism. No laser, sci-fi, metal, beeps, music, voices or repeated explosions.',result:'Three new Nuclear_blast candidates again show 00:00 / 00:00 with disabled playback. The download control produced no download within20seconds. Existing project track also displays error. No generated audio was integrated.',credits_before:200,credits_after:150,evidence:'verification_feedback4_20261024/nuclear-varco-unavailable.png'};fs.writeFileSync(path.join(root,'docs/nuclear-sound-request-20261024.json'),JSON.stringify(sound,null,2)+'\n');
const notes=`승인된 생체형 이귤 HUD와 화면·연구·공격 효과 수정입니다.

- 이귤 HUD를 승인된 새 생체형 원화로 교체하고 세 종족의 전체 높이, 미니맵·초상화·명령칸 크기를 통일했습니다. 제목과 설명은 뿌리 장식 안쪽에 배치합니다.
- 종족 이름을 노바너·이귤·아라아울로 적용했습니다. 영문 이름은 표시하지 않습니다.
- 시작 로고부터 저장한 해상도와 음악 음량을 적용하며, 시작 화면 음악을 메인 화면까지 이어 재생합니다.
- 메인 화면의 큰 업데이트 배너를 작은 종족별 버튼으로 바꿨습니다. 기존 실패 재시도 방지와 복구 절차는 유지합니다.
- 패시브 연구를 실제 유닛 생산 건물에서 모두 분리했습니다. 강화 전투복은 야전의료소, 자동 장전기·장축 화염노즐은 탄도시험장, 고출력 추진기는 중병기 설계국, 신속 행군·장거리 결정포는 율법제련소에서 연구합니다. 기존 선행 조건과 효과·가격·시간은 유지합니다.
- 방패보병의 방패 전개 명령을 제거했습니다. 테라 정제시설의 배치 사각형을 실제 건설 위치와 맞췄습니다.
- 실제 기술25종과 기본 전환 명령의 소리 연결을 확인하고 재생 우선순위를 높였습니다. 핵 피해 반경은5→8로 넓혔으며 최대 피해와 아군 피해 규칙은 유지합니다.
- 아이콘205개를 검토해 전투자극제 아이콘의 이웃 그림 조각을 제거했습니다. 피격·발사 효과128개를 독립 이미지로 분리하고 잘린 원화 구간은 기존의 완전한 자세로 연결했습니다.
- 강습폭격기의 북쪽 엔진을2개로 맞추고 이동할 때만 분사하도록 분리했습니다. 대기 중에는 부드럽게 떠 있습니다. 성문궁수의 잘못된 남서 이동 자세를 기존 원화 반사로 수정했습니다.
- 남쪽 끝 지형이 HUD 뒤에 가려지던 카메라 제한과 미니맵 표시를 고쳤습니다. 맵 가장자리 높이 정점이 눌리던 왜곡을 수정하고 남쪽 절벽의 빈 면을 연결했습니다. 원본 이동 판정·강·높이·자원 배치는 유지했습니다.

실제 게임 화면 검사159개, 승인 HUD 공통 배치11개, 실제 기술/생산/연구 검사116개, 저장 해상도·첫 음악·메뉴 연결7개, 패시브185개·AI연구9개, 맵 경계32개와24개 화면, 기존 표시 회귀47개, 핵 아군 피해/반경8개를 확인했습니다. 원본 미니타일·경사로786,720개와 실제 경사로 통과44회를 확인했습니다.

새 핵 폭발음은 VARCO에서 재생0초/다운로드 실패가 다시 발생하여 미적용입니다. 기존 음원을 유지했습니다. 인터넷/LAN·리플레이는 이번 묶음에서 새로 검증하지 않았습니다.

이전 feedback3 실행파일의 메인 화면에서 새 버전을 확인하거나, ZIP을 모두 풀고 AsteraCraft.exe를 실행하세요. 기존 배포물과 승인된 로딩 원화30장은 보존했습니다.
`;
fs.writeFileSync(path.join(out,'release-notes.md'),notes);
fs.copyFileSync(path.join(root,'assets/game_icon.ico'),path.join(out,'game_icon.ico'));
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 — HUD·연구·화면 수정판 2026-10-24\n\n압축을 모두 푼 다음 AsteraCraft.exe를 실행하세요.\nEXE, PCK, WebRTC DLL은 같은 폴더에 두세요.\n바탕화면 바로가기는 이 폴더의 AsteraCraft.exe로 만들면 됩니다.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback4-20261024\n');
fs.writeFileSync(path.join(root,'docs/FEEDBACK_FIXES4_20261024.md'),'# 2026-10-24 HUD·연구·화면 수정\n\n'+notes+'\n확인 자료: `verification_feedback4_20261024/checks.json` 및 실제 게임 화면. 새 이귤 HUD는 사용자 승인84e977e9 원본을 보존하고 렌더 구간으로 공통 배치를 맞췄습니다. 전체 프롬프트/참조/승인은 `egyul-hud-living-v2-art-20261024.json`에 기록했습니다. 이웃 아이콘 조각/강습폭격기/성문궁수/피격 효과는 기존 원화의 비파괴 파생 파일로 수정했습니다.\n');
console.log('FEEDBACK4_REVIEW_ARTIFACTS_READY');
