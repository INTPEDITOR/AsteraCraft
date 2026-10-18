// Geometry metadata only. No StarCraft image pixels are copied.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const mpq=require('./inspect_starcraft_maps.cjs');
const root=path.resolve(__dirname,'..'),catalogPath=path.join(root,'data/original_maps.json');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const catalog=JSON.parse(fs.readFileSync(catalogPath));
const cv=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.cv5'));
const vf=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.vf4'));
if(hash(cv)!==catalog.cv5_sha256||hash(vf)!==catalog.vf4_sha256)throw Error('Tileset metadata mismatch');
const maps=catalog.maps.map(m=>{
 const file=path.join(root,'../original-materials',m.source),raw=fs.readFileSync(file);
 if(hash(raw)!==m.source_sha256)throw Error('Original map changed');
 const chk=mpq.extract(file,'staredit\\scenario.chk');
 if(hash(chk)!==m.chk_sha256)throw Error('CHK mismatch');
 const parsed=mpq.parse(chk),walk=[],ramp=[],heights=[],seeds=new Set();
 for(let i=0;i<16384;i++){
  const tile=parsed.terrain[i];if(tile!==m.source_tiles[i])throw Error('MTXM mismatch');
  const mega=cv.readUInt16LE((tile>>>4)*52+20+(tile&15)*2);
  let w=0,r=0,h=0;
  for(let j=0;j<16;j++){
   const f=vf.readUInt16LE(mega*32+j*2);
   if(f&1)w|=1<<j;if((f&0x11)===0x11)r|=1<<j;
   h+=((f&4)?2:(f&2)?1:0)*2**(j*2);
  }
  if(w!==m.walk_masks[i])throw Error('VF4 walk mismatch');
  walk.push(w);ramp.push(r);heights.push(h);
  if(r)seeds.add(i);
 }
 const regions=[];
 while(seeds.size){
  const q=[seeds.values().next().value];seeds.delete(q[0]);
  // Some authored ramp end tiles have one unflagged tile between VF4 markers.
  for(let k=0;k<q.length;k++)for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){
   const x=q[k]%128+dx,y=(q[k]>>7)+dy,n=y*128+x;
   if(x>=0&&y>=0&&x<128&&y<128&&seeds.delete(n))q.push(n);
  }
  let center=[0,0],gradient=[0,0],lo=2,hi=0;
  for(const i of q){
   const x=i%128,y=i>>7;center[0]+=x+.5;center[1]+=y+.5;
   for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){
    const xx=x+dx,yy=y+dy,n=yy*128+xx;if(xx<0||yy<0||xx>=128||yy>=128||m.terrain[n])continue;
    const z=m.height_map[n];lo=Math.min(lo,z);hi=Math.max(hi,z);
    gradient[0]+=dx*z;gradient[1]+=dy*z;
   }
  }
  center=center.map(v=>v/q.length);const len=Math.hypot(...gradient);
  if(!len||hi<=lo)throw Error('Ambiguous source ramp '+m.name+' '+center);
  const direction=gradient.map(v=>-v/len),tangent=[direction[1],-direction[0]];
  let width=0,length=0;
  for(const i of q){const d=[i%128+.5-center[0],(i>>7)+.5-center[1]];width=Math.max(width,2*Math.abs(d[0]*tangent[0]+d[1]*tangent[1]));length=Math.max(length,2*Math.abs(d[0]*direction[0]+d[1]*direction[1]));}
  regions.push({center,direction,width:width+1.5,length:length+2,low:lo,high:hi,cells:q});
 }
 console.log(m.name,regions.map(r=>({center:r.center,width:r.width,length:r.length,cells:r.cells.length})));
 return {name:m.name,walk_masks:walk,ramp_masks:ramp,height_bits:heights,ramps:regions};
});
fs.writeFileSync(path.join(root,'data/source_terrain_detail.json'),JSON.stringify({schema:1,source_sha256:hash(fs.readFileSync(catalogPath)),resolution:8,maps}));
