// Idempotent movement/range tuning. The source values stay available for review.
const fs=require('node:fs'),path=require('node:path');
function applyBalance(data){
 data.version='0.4.0';
 data.balance={revision:'0.4',movement_multiplier:1.20,ranged_multiplier:1.08,range_threshold:1.5};
 for(const faction of data.units)for(const u of faction){
  u.base_speed??=u.speed;u.base_range??=u.range;
  u.speed=Math.round(u.base_speed*1.20*100)/100;
  u.range=u.damage>0&&u.base_range>1.5?Math.round(u.base_range*1.08*10)/10:u.base_range;
 }
 return data;
}
module.exports={applyBalance};
if(require.main===module){const file=path.join(__dirname,'data/game.json'),d=applyBalance(JSON.parse(fs.readFileSync(file,'utf8')));fs.writeFileSync(file,JSON.stringify(d,null,2)+'\n');console.log(JSON.stringify({units:d.units.flat().length,ranged:d.units.flat().filter(u=>u.range!==u.base_range).length,hyrax:d.units[0][1],citrus_aa:d.units[1][7]},null,2));}
