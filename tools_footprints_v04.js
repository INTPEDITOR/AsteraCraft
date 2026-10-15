const fs=require('node:fs'),path=require('node:path');
const references=[
  [
    "Terran_Command_Center",
    "Terran_Refinery",
    "Terran_Supply_Depot",
    "Terran_Barracks",
    "Terran_Factory",
    "Terran_Starport",
    "Terran_Armory",
    "Terran_Academy",
    "Terran_Covert_Ops",
    "Terran_Machine_Shop",
    "Terran_Science_Facility",
    "Terran_Bunker",
    "Terran_Missile_Turret"
  ],
  [
    "Zerg_Hatchery",
    "Zerg_Extractor",
    null,
    "Zerg_Queens_Nest",
    "Zerg_Spawning_Pool",
    "Zerg_Evolution_Chamber",
    "Zerg_Ultralisk_Cavern",
    "Zerg_Spire",
    "Zerg_Queens_Nest",
    "Zerg_Ultralisk_Cavern",
    "Zerg_Sunken_Colony",
    "Zerg_Spore_Colony",
    "Zerg_Nydus_Canal"
  ],
  [
    "Protoss_Nexus",
    "Protoss_Assimilator",
    "Protoss_Pylon",
    "Protoss_Gateway",
    "Protoss_Robotics_Facility",
    "Protoss_Stargate",
    "Protoss_Forge",
    "Protoss_Cybernetics_Core",
    "Protoss_Templar_Archives",
    "Protoss_Fleet_Beacon",
    "Protoss_Shield_Battery",
    "Protoss_Photon_Cannon",
    "Protoss_Photon_Cannon"
  ]
];
function applyFootprints(data){
 const source=JSON.parse(fs.readFileSync(path.join(__dirname,'data/reference_footprints_v04.json'),'utf8'));
 const byName=new Map(source.units.map(x=>[x.name,x]));
 for(let race=0;race<3;race++)for(let kind=0;kind<13;kind++){
  const b=data.buildings[race][kind],name=references[race][kind],ref=byName.get(name);
  if(!('previous_w' in b)){b.previous_w=b.w;b.previous_h=b.h;}
  b.w=ref?ref.w:2;b.h=ref?ref.h:2;
  b.footprint_reference=name||'AsteraCraft supply fruit store';
 }
 return data;
}
module.exports={applyFootprints,references};
if(require.main===module){const file=path.join(__dirname,'data/game.json'),data=applyFootprints(JSON.parse(fs.readFileSync(file,'utf8')));fs.writeFileSync(file,JSON.stringify(data,null,2)+'\n');console.log(JSON.stringify(data.buildings.map((list,race)=>({race,buildings:list.map(b=>({id:b.id,name:b.name,previous:[b.previous_w,b.previous_h],tiles:[b.w,b.h]}))})),null,2));}
