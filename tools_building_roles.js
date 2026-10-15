// Concise gameplay roles, applied after the longer faction lore.
const roles=[
 ['일꾼 생산 · 자원 반납','테라 자동 추출','인구 한도 +8','보병 생산','기갑 차량 생산','항공 유닛 생산','공격·장갑 업그레이드','야전의무병 해금','그림자 정찰병 해금','굴착포 전차 해금','이동요새·강습폭격기 해금','지상 방어','대공 방어 · 은신 탐지'],
 ['배양체 생성 · 자원 반납','테라 자동 추출','인구 한도 +8','배양체 추가 생산','근접 군체 해금','공격·장갑 연구','중장갑 군체 해금','비행 군체 해금','지원·침투 군체 해금','대과수 해금','지상 방어','대공 방어 · 은신 탐지','뿌리망 확장'],
 ['일꾼 생산 · 자원 반납','테라 자동 추출','인구 +8 · 건설 영향권 확장','보병 생산','지상 중장갑 생산','비행 유닛 생산','공격·장갑·실드 업그레이드','정예·마법 유닛 해금','황혼잠행자 해금','대심판선 해금','근처 비전투 아군 체력 회복','지상 방어','대공 방어 · 은신 탐지']
];
function applyBuildingRoles(data){for(let race=0;race<3;race++)for(let kind=0;kind<13;kind++)data.buildings[race][kind].description=roles[race][kind];return data;}
module.exports={applyBuildingRoles,roles};
if(require.main===module){const fs=require('node:fs'),path=require('node:path'),file=path.join(__dirname,'data/game.json');fs.writeFileSync(file,JSON.stringify(applyBuildingRoles(JSON.parse(fs.readFileSync(file,'utf8'))),null,2)+'\n');console.log('39 concise building roles applied');}
