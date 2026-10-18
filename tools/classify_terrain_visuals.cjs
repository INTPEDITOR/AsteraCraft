// Visual roles only. Source collision, height, resources and buildability stay intact.
// CV5 terrain links and doodad records: https://docs.scmjs.dev/api/tileset/
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'data/original_maps.json'));
const data=JSON.parse(source),cv=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.cv5'));
if(crypto.createHash('sha256').update(cv).digest('hex')!==data.cv5_sha256)throw Error('Unexpected source tileset metadata');
const maps=data.maps.map(m=>{
 const roles=m.terrain.map((t,i)=>{
  if(t===2)return 2;
  if(t!==1)return 0;
  const offset=(m.source_tiles[i]>>>4)*52;
  if(cv.readUInt16LE(offset)===1)return 3; // A doodad record is NOT a cliff edge record.
  const links=[4,6,8,10].map(n=>cv.readUInt16LE(offset+n));
  if(links.every(n=>n===links[0]))return 3; // Flat rocky/unwalkable ground.
  const x=i%128,y=i>>7;let high=m.height_map[i],low=high,water=false;
  for(let dy=-3;dy<=3;dy++)for(let dx=-3;dx<=3;dx++){
   const xx=x+dx,yy=y+dy;if(xx<0||yy<0||xx>=128||yy>=128)continue;
   const j=yy*128+xx;
   if(m.terrain[j]===2){if(Math.abs(dx)<=2&&Math.abs(dy)<=2)water=true;continue;}
   if(cv.readUInt16LE((m.source_tiles[j]>>>4)*52)===1)continue;
   high=Math.max(high,m.height_map[j]);low=Math.min(low,m.height_map[j]);
  }
  // Height boundaries form cliffs; shores are a separate family. Remaining
  // impassable patches are visible low obstacles rather than cliff fragments.
  return high>low?1:water?2:3;
 });
 const counts=[0,1,2,3].map(role=>roles.filter(x=>x===role).length);
 console.log(m.name,{flat:counts[0],cliff:counts[1],shore:counts[2],obstacle:counts[3]});
 return {name:m.name,roles};
});
fs.writeFileSync(path.join(root,'data/terrain_visual_roles.json'),JSON.stringify({schema:1,legend:['ground','cliff','shore','obstacle'],source_sha256:crypto.createHash('sha256').update(source).digest('hex'),maps}));
