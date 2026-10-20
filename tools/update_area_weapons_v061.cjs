const fs=require('fs');
const path='data/game.json',d=JSON.parse(fs.readFileSync(path));
// Radius in world tiles; secondary damage is a fraction of direct damage.
const weapons=[[0,5,1.4,.4],[0,6,.85,.35],[0,10,1.3,.4],[0,12,1.25,.4],
 [1,2,.9,.55],[1,3,1,.35],[1,6,1.5,.45],[1,12,1.6,.4],
 [2,7,1.3,.4],[2,8,1.3,.4],[2,12,1.5,.35]];
for(const [race,kind,radius,factor] of weapons)Object.assign(d.units[race][kind],{splash_radius:radius,splash_factor:factor});
Object.assign(d.units[0][13],{flame_half_angle:18,description:'전방 부채꼴 안의 지상 적에게 지속 화염 피해를 줍니다.'});
delete d.units[0][13].splash_radius;delete d.units[0][13].splash_factor;
fs.writeFileSync(path,JSON.stringify(d,null,2)+'\n');
