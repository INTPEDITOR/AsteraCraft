const fs=require('node:fs'),path=require('node:path');
const old=require('./tools_balance_v04.js');
const extents=[[32,30,32,38,30,54,46,30,32,52,64,60,88],[30,22,34,54,24,40,46,38,24,42,40,58,84],[30,38,36,38,34,34,30,54,54,56,36,58,88]];
const changes={
 '0:1':{hp:65,armor:0,damage:7},'0:2':{hp:100,damage:12,period:.75},
 '0:3':{hp:165},'0:5':{damage:42},'0:12':{hp:680,damage:40},
 '1:1':{hp:30,damage:4,period:.65},'1:2':{hp:70,damage:9,period:.95,range:4.2},
 '1:3':{hp:310},'1:4':{hp:40,damage:45,splash_radius:1.45},
 '1:10':{hp:70,damage:10,period:.95},'1:12':{hp:700,damage:46},
 '2:1':{hp:105,shield:60,damage:19,period:1.15},'2:7':{shield:130,damage:32}
};
function applyBalance(data){
 old.applyBalance(data);
 data.version='0.5.0';
 data.balance={...data.balance,revision:'0.5',tera_interval:2.5,tera_amount:12,energy_regeneration:.3,healers_per_patient:1,tera_headquarters_radius:14};
 for(let r=0;r<3;r++)for(let k=0;k<13;k++){
  const unit=data.units[r][k];unit.visual_extent=extents[r][k];
  Object.assign(unit,changes[r+':'+k]||{});
 }
 data.buildings[0][9].w=4;data.buildings[0][9].h=3;
 return data;
}
module.exports={applyBalance,changes,extents};
if(require.main===module){const file=path.join(__dirname,'data/game.json');fs.writeFileSync(file,JSON.stringify(applyBalance(JSON.parse(fs.readFileSync(file))),null,2)+'\n');}
