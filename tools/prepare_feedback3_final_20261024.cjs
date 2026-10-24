const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback3_20261024'),qa=path.join(root,'docs/verification_feedback3_20261024');
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(qa,{recursive:true});
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
const reports={terrain:read('build/rock-terrain-20261024/result.json'),navigation:read('build/source-terrain/navigation.json'),original:read('build/qa-v060/original-map-audit.json'),visual:read('build/visual_feedback_20261024/result.json'),feedback:read('build/feedback3-20261024/result.json'),nuclear:read('build/nuclear_20261024/visual-result.json'),friendlyFire:read('build/nuclear_20261024/friendly-fire.json'),bat:read('build/citrus-bat-20261024/result.json'),stim:read('build/stim-20261024/result.json'),contact:read('build/contact-20261024/result.json'),startup:read('build/startup-20261024/result.json'),font:read('build/font-layout-20261024/result.json'),finalScreen:read('build/visual_feedback_20261024/final-screen.json')};
Object.assign(reports,{passives:read('build/passives-20261024/result.json'),passiveIcons:read('build/passives-20261024/icons-result.json'),frontline:read('build/frontline-20261024/result.json'),updaterController:read('build/updater-test-20261024/controller-result.json'),updaterWindows:read('build/updater-test-20261024/result.json'),updaterFeed:read('build/updater-test-20261024/feed-result.json')});
Object.assign(reports,{updaterExported:read('build/updater-e2e-20261024/result.json'),updaterBootRollback:read('build/updater-boot-rollback-20261024/result.json'),exportedSmoke:read('build/feedback3_20261024/exe-smoke.json')});
reports.passiveBot=read('build/passives-20261024/bot-result.json');
if(Object.values(reports).some(v=>Array.isArray(v)?v.some(r=>r.water_rock_or_bridge_conflicts!==0||!r.unchanged_navigation_and_resources):v.passed===false||v.failures?.length))throw Error('A required scoped check failed');
reports.limitations={nuclear_audio:'New VARCO candidates could not play/download; old sound retained. Computer Use stopped on Windows URL validation.',network:'No new Internet/LAN validation in this feedback batch; protocol/payload unchanged. Authoritative public match host runs the elected player build.',legacyMenu:'menu_v04_test was also attempted:13 failures/66 checks. It still assumes108 resources, four lobby slots and an older result/replay fixture. Its replay fixture emitted decompression/missing-resource errors. Those runtime replay paths were not changed in this batch; no claim of replay validation.'};
fs.writeFileSync(path.join(qa,'checks.json'),JSON.stringify(reports,null,2));
for(const name of ['top-edge-no-black-strip','northwest-resources-offset-clip','death-and-rally-player-colors','blue-construction-ghost','siege-four-directions','laser-current-muzzles-soft-contacts'])fs.copyFileSync(path.join(root,'build/feedback3-20261024',name+'.png'),path.join(qa,name+'.png'));
for(let map=0;map<3;map++)for(const kind of ['overview','river'])fs.copyFileSync(path.join(root,'build/rock-terrain-20261024',`${kind}-${map}.png`),path.join(qa,`${kind}-${map}.png`));
for(const [from,to] of [['build/startup-20261024/title-1600x900.png','title-levelup.png'],['build/startup-20261024/publisher-logo.png','publisher-logo.png'],['build/contact-20261024/deployed-contact-close.png','deployed-contact.png'],['build/font-layout-20261024/main-menu-levelup.png','main-menu-levelup.png'],['build/font-layout-20261024/loading-r1-levelup.png','loading-levelup.png'],['build/visual_feedback_20261024/citrus-readable-ground-and-complete-hud.png','citrus-new-wood-hud.png'],['build/visual_feedback_20261024/computer-surrender-above-minimap.png','surrender-levelup.png']])fs.copyFileSync(path.join(root,from),path.join(qa,to));
fs.copyFileSync(path.join(root,'assets/game_icon.ico'),path.join(out,'game_icon.ico'));
fs.copyFileSync(path.join(root,'build/passives-20261024/research-icons-ten.png'),path.join(qa,'research-icons-ten.png'));
fs.copyFileSync(path.join(root,'build/updater-test-20261024/menu-update-failed.png'),path.join(qa,'update-failure-stops.png'));
fs.writeFileSync(path.join(out,'LICENSES-LevelUp.txt'),fs.readFileSync(path.join(root,'assets/fonts/COPYRIGHT-LevelUp.txt'),'utf8')+'\n\n'+fs.readFileSync(path.join(root,'assets/fonts/OFL-LevelUp.txt'),'utf8'));
const notes=`지형·이동 표시, 전차 접지, 플레이어 색상, 새 시작 화면과 LevelUp 글꼴을 반영했습니다.

- 세 맵의 원본 지형을 대조해 누락된 강 가장자리 물을 복구하고 통행 불가 육지는 새 절벽·암반 타일로 표시합니다. 원본 통행 판정·자원·다리는 유지했습니다.
- 사망 동작·건설 배치 실루엣·집결 지점에도 플레이어 색을 적용했습니다. 화면 가장자리 자원 누락과 최상단 검은띠를 수정했습니다.
- 굴착포 전차는 이어진 전개 프레임과 보정한 접지 기준점을 사용합니다. 선택 원은 고정합니다.
- 레이저·지속 광선·치료 연결선이 현재 발사구와 실제 대상 표면에 부드럽게 이어집니다.
- 핵 폭발은 새 고정 기준점 구름을 사용하며 자신/아군에도 동일한 거리별 피해를 줍니다. 새 폭발음은 사이트에서 파일을 받지 못해 기존 소리를 유지했습니다.
- 세 종족 미니맵에 안전 여백을 확보했고 귤박쥐 우상단 방향의 잘못된 반사를 제거했습니다. 귤 전투 HUD는 새로 그린 짙은 나무 프레임입니다.
- 전투자극제를 전열사수·돌격병으로 옮겼습니다. 체력10을 쓰며 체력10이하이면 사용 불가입니다.
- 검은 화면 ZIPZA GAMES 로고 페이드아웃 → 승인된3종족 타이틀 → 아무 버튼 입력 → 기존 메인 화면으로 이어집니다. 기존 아스테라크래프트 로고를 그대로 사용합니다.
- 전체 UI는 사용자 제공 무료 LevelUp 글꼴입니다. OFL 라이선스와 저작권 고지를 포함했습니다. 승인된 로딩 원화30장은 유지합니다.
- 전열사수 체력+15를 포함한 보완 대상10종에 각각1회 연구·효과1개 전용 패시브와 새 아이콘을 추가했습니다. 연구 건물·가격·시간·고급 선행 조건을 연결했으며 기존/신규 병력과 공개 수치에 함께 적용됩니다. 의무병·접목충에는 추가하지 않았습니다.
- 이번 배포본부터 메인 화면에서 공식 새 버전을 확인하고 다운로드·교체·재시작합니다. 실패한 버전은 자동 재시도하지 않으며, 교체 실패/새 버전 시작 실패 시 이전 파일로 한 번 복구하고 멈춥니다. 경기 중 설치하지 않습니다.

원본 맵 대조246,132개, 세밀한 통행 판정786,720개와 실제 경사로44회, 화면199개, 수정 화면47개, 접지88개, 글꼴/배치88개, 시작 화면10개 및 핵/자극제/귤박쥐 관련 검사를 통과했습니다. 인터넷 멀티플레이와 리플레이 동작은 이번 배포에서 새로 검증하지 않았습니다.

패시브 효과187개/아이콘10개 확인, 전열사수 체력29개 확인, 업데이트 상태20개 확인과 실제 Windows 교체/거부/복원8경우64개 확인을 통과했습니다. 실제 이전 배포본→최종 새 실행파일 교체·재시작 확인11개 및 새 실행 실패 시1회 복구 확인7개도 통과했습니다. 이전 배포물은 보존했습니다. ZIP을 모두 풀고 AsteraCraft.exe를 실행하세요.
`;
fs.writeFileSync(path.join(out,'release-notes.md'),notes);
fs.writeFileSync(path.join(out,'README.txt'),'아스테라크래프트 — 지형·패시브·업데이트·시작 화면 수정판 2026-10-24\n\n압축을 모두 푼 뒤 AsteraCraft.exe를 실행하세요. EXE/PCK/WebRTC DLL은 같은 폴더에 두세요.\n이 버전부터 다음 공식 업데이트는 메인 화면에서 받을 수 있습니다. 실패 시 자동 재시도하지 않고 이전 파일을 복원합니다. 멀티플레이는 같은 배포본끼리 이용하세요.\n실행파일 아이콘7개 크기를 포함했습니다. LevelUp 글꼴 라이선스는 LICENSES-LevelUp.txt에 있습니다.\n새 핵 폭발음은 아직 미적용이며 기존 소리를 유지합니다. 전용 패시브 연구10종을 적용했습니다.\n\nhttps://github.com/INTPEDITOR/AsteraCraft/releases/tag/feedback3-20261024\n');
fs.writeFileSync(path.join(root,'docs/FEEDBACK_FIXES3_20261024.md'),'# 2026-10-24 지형·표시·시작 화면 수정\n\n'+notes+'\n증거: verification_feedback3_20261024/checks.json 및 실제 화면21장. 새 원화 프롬프트/출처는 terrain-rock-art-20261024.json, nuclear-art-20261024.json, citrus-wood-hud-art-20261024.json, startup-art-20261024.json, passive-icons-art-20261024.json. LevelUp 원본 해시/라이선스는 font-selection-20261024.json. 확정 연구 수치는 passive-research-20261024.json. 원본 맵 픽셀과 미선택 글꼴은 build/work에만 두고 배포에서 제외했습니다.\n');
console.log('FEEDBACK3_FINAL_REVIEW_READY');
