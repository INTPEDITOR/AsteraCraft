// Convert source CHK terrain using local Jungle CV5/VF4 metadata.
// Flag decoding matches OpenBW bwgame.h load_tile_stuff (MIT).
const fs=require('fs'),path=require('path'),crypto=require('crypto'),mpq=require('./inspect_starcraft_maps.cjs');
const root=path.resolve(__dirname,'..'),source=path.resolve(root,'../original-materials');
const cv=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.cv5')),vf=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.vf4'));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const files=fs.readdirSync(source).filter(n=>/\.sc[mx]$/i.test(n));
const names=['투혼 1.4','파이썬 1.3','로스트템플 2.4'];
const ordered=[files.find(n=>n.includes('투혼')),files.find(n=>n.includes('Python')),files.find(n=>n.includes('Temple'))];
const maps=ordered.map((file,id)=>{
 const raw=fs.readFileSync(path.join(source,file)),chk=mpq.extract(path.join(source,file),'staredit\\scenario.chk'),d=mpq.parse(chk);
 if(d.width!==128||d.height!==128||d.tileset!==4)throw Error('Unexpected map dimensions/tileset');
 const terrain=[],height=[],surface=[],buildable=[],walkMasks=[];
 for(const tile of d.terrain){
  const group=tile>>>4,offset=group*52,mega=cv.readUInt16LE(offset+20+(tile&15)*2),flags=cv.readUInt16LE(offset+2),type=cv.readUInt16LE(offset);
  let walk=0,middle=0,high=0,mask=0;
  for(let j=0;j<16;j++){let f=vf.readUInt16LE(mega*32+j*2);if(f&1){walk++;mask|=1<<j}if(f&2)middle++;if(f&4)high++;}
  let h=high>=12?2:middle+high>=12?1:0;
  let t=walk>12?0:type===5?2:1;
  terrain.push(t);height.push(h);surface.push(t===2?7:t===1?6:h?1:0);
  buildable.push(walk===16&&!(flags&0x80)?1:0);walkMasks.push(mask);
 }
 // Python's central observer markers occupy owner slots 4..7.
 const starts=d.starts.filter(s=>s.owner<4).sort((a,b)=>a.owner-b.owner).map(s=>[s.x,s.y]);
 if(starts.length!==4)throw Error('Expected four actual player starts');
 const resources=[...d.minerals.map(n=>({...n,type:'as'})),...d.gas.map(n=>({...n,type:'tera'}))].map((n,i)=>({id:100000+i,pos:[n.x-.5,n.y-.5],source_pos:[n.x,n.y],type:n.type,amount:n.amount,initial_amount:n.amount,busy:0,base:-1,slot:-1,collision_size:n.type==='as'?[2,1]:[4,2]}));
 const dist=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
 const groups=[];
 for(const r of resources.filter(r=>r.type==='as')){
  const nearby=groups.filter(g=>g.some(n=>dist(n.pos,r.pos)<7));
  if(!nearby.length)groups.push([r]);else{nearby[0].push(r);for(const other of nearby.slice(1)){nearby[0].push(...other);groups.splice(groups.indexOf(other),1)}}
 }
 for(const r of resources.filter(r=>r.type==='tera')){let g=groups.reduce((a,b)=>Math.min(...a.map(n=>dist(n.pos,r.pos)))<Math.min(...b.map(n=>dist(n.pos,r.pos)))?a:b);g.push(r)}
 const fits=(x,y)=>{
  if(x<1||y<1||x+4>=128||y+3>=128)return false;
  for(let yy=y;yy<y+3;yy++)for(let xx=x;xx<x+4;xx++)if(!buildable[yy*128+xx])return false;
  return resources.every(r=>{let w=r.collision_size[0],h=r.collision_size[1];return x+4<=r.pos[0]-w/2-.4||x>=r.pos[0]+w/2+.4||y+3<=r.pos[1]-h/2-.4||y>=r.pos[1]+h/2+.4});
 };
 const bases=groups.map((g,i)=>{
  const centroid=[g.reduce((s,n)=>s+n.pos[0],0)/g.length,g.reduce((s,n)=>s+n.pos[1],0)/g.length];
  let slot=starts.findIndex(p=>dist(p,centroid)<13),pos=slot>=0?starts[slot]:null,score=Infinity;
  if(!pos)for(let y=Math.max(1,Math.floor(centroid[1]-12));y<Math.min(124,centroid[1]+12);y++)for(let x=Math.max(1,Math.floor(centroid[0]-12));x<Math.min(123,centroid[0]+12);x++){
   if(!fits(x,y))continue;let p=[x+2,y+1.5],s=g.reduce((sum,n)=>sum+dist(p,n.pos)**2,0)/g.length;
   if(s<score){score=s;pos=p;}
  }
  if(!pos)throw Error('No expansion placement '+file+' '+i);
  for(const n of g){n.base=i;n.slot=slot;}
  return {kind:slot>=0?'main':'expansion',main:slot>=0,slot,turn:slot,pos,grid_center:pos,resources:g.map(n=>n.id),access:'ground'};
 });
 // Mark island expansions by terrain flood-fill, not by geometric symmetry.
 const labels=new Int32Array(16384).fill(-1);let label=0;
 for(let n=0;n<labels.length;n++){if(terrain[n]||labels[n]>=0)continue;const q=[n];labels[n]=label;for(let k=0;k<q.length;k++){let p=q[k],x=p%128,y=p>>7;for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){let xx=x+dx,yy=y+dy,j=yy*128+xx;if(xx>=0&&xx<128&&yy>=0&&yy<128&&!terrain[j]&&labels[j]<0){labels[j]=label;q.push(j)}}}label++;}
 const region=p=>labels[Math.floor(p[1])*128+Math.floor(p[0])];
 const mainland=new Set(starts.map(region));for(const b of bases)if(!mainland.has(region(b.pos)))b.access='air';
 console.log(names[id],{starts,resources:resources.length,bases:bases.length,islands:bases.filter(b=>b.access==='air').length,walkable:terrain.filter(t=>!t).length});
 return {name:names[id],source:file,source_sha256:hash(raw),chk_sha256:hash(chk),tileset:4,width:128,height:128,starts,resources,bases,terrain,height_map:height,surface_map:surface,buildable_map:buildable,walk_masks:walkMasks,source_tiles:d.terrain};
});
fs.writeFileSync(path.join(root,'data/original_maps.json'),JSON.stringify({schema:1,grid_policy:'32px build tiles; walkable when >12 of 16 VF4 minitiles are walkable; buildable only when all 16 are walkable and CV5 permits building',cv5_sha256:hash(cv),vf4_sha256:hash(vf),maps}));
const gamePath=path.join(root,'data/game.json'),game=JSON.parse(fs.readFileSync(gamePath));
game.maps=maps.map((m,i)=>({name:m.name,theme:i,description:'제공된 '+m.source+'의 지형·시작 위치·자원 배치 적용. 원본의 비대칭과 섬 확장을 유지합니다.'}));
fs.writeFileSync(gamePath,JSON.stringify(game,null,2)+'\n');
