const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const maps=JSON.parse(fs.readFileSync(path.join(root,'data/original_maps.json'))).maps;
const roles=JSON.parse(fs.readFileSync(path.join(root,'data/terrain_visual_roles.json'))).maps;
const results=[];
const minimumGap=Number(fs.readFileSync(path.join(root,'scripts/world_map.gd'),'utf8').match(/HQ_MINERAL_GAP := ([\d.]+)/)[1]);
function rect(p,s){return [p[0]-s[0]/2,p[1]-s[1]/2,p[0]+s[0]/2,p[1]+s[1]/2]}
function gap(a,b){return Math.max(a[0]-b[2],b[0]-a[2],a[1]-b[3],b[1]-a[3])}
function overlap(a,b,pad=0){return a[0]<b[2]+pad&&a[2]>b[0]-pad&&a[1]<b[3]+pad&&a[3]>b[1]-pad}
for(let theme=0;theme<3;theme++){
 const map=maps[theme], obstacles=map.resources.map(r=>({r,box:rect(r.pos,r.collision_size)}));
 for(let index=0;index<map.bases.length;index++){
  const base=map.bases[index],ore=obstacles.filter(o=>base.resources.includes(o.r.id)&&o.r.type==='as'&&o.r.amount>1);
  if(ore.length<3)continue; // Single blocking mineral is not an expansion.
  const center=ore.reduce((p,o)=>[p[0]+o.r.pos[0]/ore.length,p[1]+o.r.pos[1]/ore.length],[0,0]);
  let best=null;
  for(let y=Math.max(0,Math.floor(center[1])-16);y<Math.min(125,center[1]+17);y++)for(let x=Math.max(0,Math.floor(center[0])-16);x<Math.min(124,center[0]+17);x++){
   let valid=true;
   for(let yy=y;yy<y+3&&valid;yy++)for(let xx=x;xx<x+4;xx++){
    const i=yy*128+xx;
    if(!map.buildable_map[i]||(map.terrain[i]!==0&&roles[theme].roles[i]!==3)||map.height_map[i]!==map.height_map[y*128+x]){valid=false;break}
   }
   if(!valid)continue;
   const box=[x-.5,y-.5,x+3.5,y+2.5];
   if(obstacles.some(o=>overlap(box,o.box,o.r.type==='as'&&o.r.amount>0?minimumGap:0)))continue;
   const nearest=Math.min(...ore.map(o=>gap(box,o.box)));
   const average=ore.reduce((s,o)=>s+Math.hypot(o.r.pos[0]-(x+1.5),o.r.pos[1]-(y+1)),0)/ore.length;
   const score=nearest*10000+average;
   if(!best||score<best.score)best={anchor:[x,y],gap:nearest,average,score};
  }
  results.push({map:theme,base:index,kind:base.kind,access:base.access,minerals:ore.length,mineral_center:center,...best});
 }
}
const output={bases:results.length,minimumGap,far:results.filter(b=>!b.anchor||b.gap>=minimumGap+1),results};
const file=path.join(root,'build/player_colors_20261024/expansion-spacing.json');fs.writeFileSync(file,JSON.stringify(output,null,2));
console.log(JSON.stringify(output,null,2));
