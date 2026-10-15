// Authored, mirrored adaptations of the reference map structures, not CHK copies.
const fs=require('fs'),path=require('path');
const p=path.join(__dirname,'data/maps.json'),d=JSON.parse(fs.readFileSync(p));
const north=[[-6.5,-2],[-5.5,-4],[-3.5,-5],[-1.5,-5],[.5,-5],[2.5,-5],[4.5,-4],[6.5,-2]];
const west=[[-5.5,-7],[-6.5,-5],[-6.5,-3],[-6.5,-1],[-6.5,1],[-6.5,3],[-5.5,5],[-3.5,7]];
const south=north.map(([x,y])=>[x,-y]);
const line=[[-7.5,-5],[-5.5,-5],[-3.5,-5],[-1.5,-5],[.5,-5],[2.5,-5],[4.5,-5],[6.5,-5]];
function base(kind,center,radii,height,minerals,gas,access='ground'){
 return {kind,center,radii,height,mineral_count:minerals.length,tera_count:gas?1:0,mineral_offsets:minerals,tera_offset:gas,access};
}
const specs=[
 {name:'황철 분지',reference:'Fighting Spirit 1.3',layout:'fighting_spirit_adaptation',start:[18,18.5],gate:{center:[31,31],width:8},
 description:'투혼 구조 참고: 모서리 고지 본진, 앞마당, 외곽 확장과 넓은 중앙. 네 진영의 자원과 통로는 좌우·상하 대칭.',
 bases:[base('main',[18,18],[16,15],1,north,[-9.5,5.5]),base('natural',[39,39],[13,12],0,west,[6.5,-6.5]),base('third',[16,55],[14,8],1,line,[8.5,2.5])],
 lanes:[[[27,27],[40,40],8,1],[[44,44],[63.5,63.5],12,0],[[24,53],[37,47],8,0],[[22,58],[37,63.5],9,0],[[43,34],[63.5,30],9,0]]},
 {name:'과숙의 심장',reference:'Python 1.3',layout:'python_adaptation',start:[20,29.5],gate:{center:[35,28],width:9},
 description:'파이썬 구조 참고: 측면에 치우친 본진, 가로 앞마당, 외곽 우회로와 열린 중앙 교차 전장. 뿌리 절벽이 측면 진입로를 구분.',
 bases:[base('main',[20,29],[17,15],1,west,[5.5,-9.5]),base('natural',[44,25],[14,12],0,north,[8.5,4.5]),base('third',[17,56],[14,7],0,south,[-9.5,-2.5])],
 lanes:[[[31,28],[46,26],9,1],[[46,33],[58,52],13,0],[[27,53],[48,47],10,0],[[19,43],[19,56],8,0],[[46,15],[63.5,15],8,0],[[27,59],[50,63.5],9,0]]},
 {name:'적월의 성역',reference:'The Lost Temple',layout:'lost_temple_adaptation',start:[24,35.5],gate:{center:[39,43],width:7},
 description:'로스트템플 구조 참고: 절벽 본진과 가까운 앞마당, 중앙 고대 성역, 아스 전용 확장과 수송선이 필요한 외곽 섬. 원본의 위치 불균형은 대칭 배치로 조정.',
 bases:[base('main',[24,35],[17,13],2,north,[-9.5,4.5]),base('natural',[43,46],[13,11],0,south,[-8.5,-4.5]),base('third',[54,19],[8,12],1,west.slice(1,7),null),base('island',[12,10],[10,8],1,line,[6.5,3.5],'air')],
 lanes:[[[34,40],[45,47],7,1],[[48,48],[59,59],9,1],[[49,36],[54,22],7,0],[[54,28],[63.5,37],9,1]]}
];
d.schema=5;d.origin='reference_inspired_original';d.maps=specs.map((v,id)=>({id,...v}));
d.mineral_layout={revision:'0.5',shape:'per_base_authored_arcs',symmetry:'mirror_xy',footprint:[2,1]};
fs.writeFileSync(p,JSON.stringify(d,null,2)+'\n');
const gp=path.join(__dirname,'data/game.json'),game=JSON.parse(fs.readFileSync(gp));
for(let i=0;i<3;i++){if(typeof game.maps[i]==='string')game.maps[i]=specs[i].name;else {game.maps[i].name=specs[i].name;game.maps[i].description=specs[i].description;}}
fs.writeFileSync(gp,JSON.stringify(game,null,2)+'\n');
