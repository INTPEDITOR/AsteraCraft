const fs=require('node:fs'),path=require('node:path');
const file=path.join(__dirname,'../data/game.json'),data=JSON.parse(fs.readFileSync(file,'utf8'));
const definitions=[
 {id:'frontline_vitality',name:'전열사수 강화 전투복',description:'전열사수 최대 체력15 증가(70→85).',race:0,unit_kind:1,building:7,stat:'hp',add:15,as:100,tera:100,time:45,requires:[]},
 {id:'missile_autoloader',name:'자동 장전기',description:'추적미사일 차륜차 공격 주기1.2초→0.9초.',race:0,unit_kind:6,building:9,stat:'period',multiply:.75,as:150,tera:150,time:75,requires:[10]},
 {id:'transport_thrusters',name:'고출력 추진기',description:'장갑수송정 이동 속도50% 증가.',race:0,unit_kind:11,building:10,stat:'speed',multiply:1.5,as:150,tera:100,time:60,requires:[]},
 {id:'claw_overdrive',name:'과활성 신경절',description:'껍질발톱 공격 속도50% 증가(공격 간격0.65→약0.43초).',race:1,unit_kind:1,building:4,stat:'period',multiply:2/3,as:200,tera:200,time:90,requires:[9]},
 {id:'root_range',name:'장축 덩굴',description:'덩굴포식자 사거리3.5→5.0.',race:1,unit_kind:5,building:6,stat:'range',add:1.5,as:150,tera:150,time:75,requires:[]},
 {id:'guardian_march',name:'신속 행군',description:'서약수호자 이동 속도50% 증가.',race:2,unit_kind:1,building:6,stat:'speed',multiply:1.5,as:150,tera:150,time:75,requires:[7]},
 {id:'golem_range',name:'장거리 결정포',description:'고대석익병 사거리2.8→4.3.',race:2,unit_kind:7,building:6,stat:'range',add:1.5,as:150,tera:150,time:75,requires:[4,7]},
 {id:'flamer_range',name:'장축 화염노즐',description:'화염돌파차 사거리3.2→4.5.',race:0,unit_kind:13,building:9,stat:'range',add:1.3,as:150,tera:150,time:60,requires:[]},
 {id:'bomb_shell',name:'과숙 보호외피',description:'과숙폭탄 최대 체력40→65.',race:1,unit_kind:4,building:4,stat:'hp',add:25,as:150,tera:150,time:60,requires:[6]},
 {id:'bat_range',name:'익막 표적감각',description:'귤박쥐 사거리4.1→5.1.',race:1,unit_kind:10,building:7,stat:'range',add:1,as:150,tera:150,time:75,requires:[8]}
].map(item=>({...item,max_level:1}));
const ids=new Set(definitions.map(item=>item.id));
data.research=[...definitions,...data.research.filter(item=>!ids.has(item.id))];
if(new Set(definitions.map(item=>item.race+':'+item.unit_kind)).size!==10)throw Error('Each unit must have exactly one passive');
fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');
fs.writeFileSync(path.join(__dirname,'../docs/passive-research-20261024.json'),JSON.stringify({status:'approved_for_implementation',units:10,excluded:['medic','parasite','archer','siege','capital'],research:definitions},null,2)+'\n');
console.log('PASSIVE_RESEARCH_DEFINED units=10 one_effect_each');
