const fs=require('fs'),path=require('path');const root=path.resolve(__dirname,'..');
const g=JSON.parse(fs.readFileSync(path.join(root,'data/game.json')));g.version='0.5.1';Object.assign(g.balance,{revision:'0.5.1',as_interval:2.2,as_amount:5,tera_interval:3.5,tera_amount:8});fs.writeFileSync(path.join(root,'data/game.json'),JSON.stringify(g,null,2)+'\n');
const project=path.join(root,'project.godot');fs.writeFileSync(project,fs.readFileSync(project,'utf8').replace('config/version="0.5.0"','config/version="0.5.1"'));
for(const [from,to]of [['tools/package_release_v05.cjs','tools/package_release_v051.cjs'],['tools/run_release_v05_checks.cjs','tools/run_release_v051_checks.cjs'],['tests/release_v05_pack_test.gd','tests/release_v051_pack_test.gd']]){
let s=fs.readFileSync(path.join(root,from),'utf8').replaceAll('v0.5-20261016','v0.5.1-20261016').replaceAll('release-v05','release-v051').replaceAll('0.5.0','0.5.1').replaceAll('release_v05_pack_test','release_v051_pack_test').replace('v0.5 /','v0.5.1 /');
if(from.includes('package_release'))s=s.replace("'이번 빌드는 현재 작업본의 그래픽 수정과 혼합 초상화 우선순위, 일반·특수 대사, 종족별 상황 안내를 포함합니다.',","'0.5.1: 일귤 소모, 배양체 전방 생성/연속 변태, 그림자 깊이, 아이콘 분리, 단일 메뉴와 얼굴 초상화 수정.',\n'AI 확장 위치와 난이도, 자원 수급(아스 5/2.2초, 테라 8/3.5초), 화면 안 공격 음성 억제 수정.',\n'외부 TTS 교체는 미완료입니다. 기존 로컬 TTS의 발화 속도와 응답을 조정한 임시 음성이 포함됩니다.',\n'제공된 SCM/SCX는 분석했지만 게임 맵은 아직 원본 지형으로 교체되지 않았습니다.',");
fs.writeFileSync(path.join(root,to),s);
}
fs.mkdirSync(path.join(root,'build/release-v051'),{recursive:true});
const summary=[];
for(const id of ['fighting-spirit','lost-temple','python']){const d=JSON.parse(fs.readFileSync(path.join(root,'build/reference-maps',id+'.json')));summary.push({id,source:d.source,width:d.width,height:d.height,tileset:d.tileset,terrain_tiles:d.terrain.length,playable_starts:d.starts.filter(s=>s.owner<4),observer_starts:d.starts.filter(s=>s.owner>=4),minerals:d.minerals.length,gas:d.gas.length,mineral_amounts:[...new Set(d.minerals.map(n=>n.amount))],gas_amounts:[...new Set(d.gas.map(n=>n.amount))],runtime_imported:false});}
fs.writeFileSync(path.join(root,'docs/reference_maps_20261016.json'),JSON.stringify({maps:summary,notes:'MTXM tile indices and UNIT coordinates extracted locally. Height/walkability still require tileset metadata mapping; current runtime layouts are unchanged.'},null,2));
console.log('Prepared version 0.5.1 and reference map audit');
