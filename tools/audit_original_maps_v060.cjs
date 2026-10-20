// Read-only source audit. Original terrain metadata is used without copying image pixels.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),mpq=require('./inspect_starcraft_maps.cjs');
const root=path.resolve(__dirname,'..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=JSON.parse(fs.readFileSync(path.join(root,'data/original_maps.json'))),detail=JSON.parse(fs.readFileSync(path.join(root,'data/source_terrain_detail.json'))),roles=JSON.parse(fs.readFileSync(path.join(root,'data/terrain_visual_roles.json')));
const cv=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.cv5')),vf=fs.readFileSync(path.join(root,'build/terrain-metadata/jungle.vf4'));let checks=0;const failures=[],maps=[];
function check(ok,label){checks++;if(!ok)failures.push(label)}
check(hash(cv)===source.cv5_sha256,'CV5 hash');check(hash(vf)===source.vf4_sha256,'VF4 hash');
for(let id=0;id<3;id++){
 const m=source.maps[id],file=path.join(root,'../original-materials',m.source),chk=mpq.extract(file,'staredit\\scenario.chk'),raw=mpq.parse(chk);check(hash(fs.readFileSync(file))===m.source_sha256,'source hash '+id);check(hash(chk)===m.chk_sha256,'CHK hash '+id);
 let water=0,cliff=0,asymmetry=0;
 for(let i=0;i<16384;i++){
  const tile=raw.terrain[i],o=(tile>>>4)*52,mega=cv.readUInt16LE(o+20+(tile&15)*2),flags=cv.readUInt16LE(o+2),type=cv.readUInt16LE(o);let walk=0,middle=0,high=0,mask=0,ramp=0;
  for(let j=0;j<16;j++){const f=vf.readUInt16LE(mega*32+j*2);if(f&1){walk++;mask|=1<<j}if(f&2)middle++;if(f&4)high++;if((f&0x11)===0x11)ramp|=1<<j}
  const terrain=walk>12?0:type===5?2:1,height=high>=12?2:middle+high>=12?1:0;
  check(tile===m.source_tiles[i],'tile '+id+':'+i);check(terrain===m.terrain[i],'water/wall/ground '+id+':'+i);check(height===m.height_map[i],'height '+id+':'+i);check((walk===16&&!(flags&0x80)?1:0)===m.buildable_map[i],'buildability '+id+':'+i);check(mask===m.walk_masks[i]&&mask===detail.maps[id].walk_masks[i]&&ramp===detail.maps[id].ramp_masks[i],'minitiles/ramp '+id+':'+i);
  if(terrain===2)water++;if(m.terrain[i]!==m.terrain[16383-i]||m.height_map[i]!==m.height_map[16383-i])asymmetry++;
 }
 const starts=raw.starts.filter(s=>s.owner<4).sort((a,b)=>a.owner-b.owner).map(s=>[s.x,s.y]);check(JSON.stringify(starts)===JSON.stringify(m.starts),'authored starts '+id);
 const resources=[...raw.minerals,...raw.gas];check(resources.length===m.resources.length,'resource count '+id);for(let i=0;i<resources.length;i++){const a=resources[i],b=m.resources[i];check(b.pos[0]===a.x-.5&&b.pos[1]===a.y-.5&&b.amount===a.amount,'resource source '+id+':'+i)}
 maps.push({id,name:m.name,source:m.source,exact_tiles:16384,water_tiles:water,ramps:detail.maps[id].ramps.length,source_intentional_rotation_mismatches:asymmetry,starts,resources:resources.length});
}
const report={checks,failures,maps,policy:'Preserve authored water/walls/heights/ramps and intentional source asymmetry; no original image pixels copied'};fs.mkdirSync(path.join(root,'build/qa-v060'),{recursive:true});fs.writeFileSync(path.join(root,'build/qa-v060/original-map-audit.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));process.exitCode=failures.length?1:0;
