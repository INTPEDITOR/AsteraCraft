const fs=require('node:fs'),zlib=require('node:zlib'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
function png(file){
 const bytes=fs.readFileSync(file),w=bytes.readUInt32BE(16),h=bytes.readUInt32BE(20),bpp=bytes[25]===6?4:3;
 if(bytes[24]!==8||![2,6].includes(bytes[25]))throw Error('Unsupported PNG '+file);
 let offset=8,parts=[];while(offset<bytes.length){const n=bytes.readUInt32BE(offset),tag=bytes.toString('ascii',offset+4,offset+8);if(tag==='IDAT')parts.push(bytes.subarray(offset+8,offset+8+n));offset+=n+12;}
 const raw=zlib.inflateSync(Buffer.concat(parts)),pixels=Buffer.alloc(w*h*bpp);let at=0;
 for(let y=0;y<h;y++){const filter=raw[at++];for(let x=0;x<w*bpp;x++){const a=x>=bpp?pixels[y*w*bpp+x-bpp]:0,b=y?pixels[(y-1)*w*bpp+x]:0,c=y&&x>=bpp?pixels[(y-1)*w*bpp+x-bpp]:0;let v=raw[at++];if(filter===1)v+=a;else if(filter===2)v+=b;else if(filter===3)v+=Math.floor((a+b)/2);else if(filter===4){const p=a+b-c,da=Math.abs(p-a),db=Math.abs(p-b),dc=Math.abs(p-c);v+=da<=db&&da<=dc?a:db<=dc?b:c;}pixels[y*w*bpp+x]=v&255;}}
 return {w,h,bpp,pixels};
}
function measure(image,box){
 const [ox,oy,w,h]=box,mark=new Uint8Array(w*h),queue=new Int32Array(w*h),components=[];
 for(let y=0;y<h;y++)for(let x=0;x<w;x++)mark[y*w+x]=image.bpp===3||image.pixels[((oy+y)*image.w+ox+x)*4+3]>=100?1:0;
 for(let p=0;p<mark.length;p++){if(mark[p]!==1)continue;let read=0,n=1;queue[0]=p;mark[p]=2;while(read<n){const q=queue[read++],x=q%w,y=Math.floor(q/w);for(const neighbor of [x?q-1:-1,x<w-1?q+1:-1,y?q-w:-1,y<h-1?q+w:-1])if(neighbor>=0&&mark[neighbor]===1){mark[neighbor]=2;queue[n++]=neighbor;}}components.push(Array.from(queue.subarray(0,n)));}
 components.sort((a,b)=>b.length-a.length);if(!components.length)throw Error('Empty sprite '+box);
 const body=components[0],mask=new Uint8Array(w*h),dist=new Float32Array(w*h);for(const p of body)mask[p]=1;
 for(let p=0;p<mask.length;p++)dist[p]=mask[p]?1e5:0;
 for(let y=0;y<h;y++)for(let x=0;x<w;x++){const p=y*w+x;if(!mask[p])continue;dist[p]=Math.min(dist[p],x?dist[p-1]+1:1,y?dist[p-w]+1:1,x&&y?dist[p-w-1]+1.414:1,x<w-1&&y?dist[p-w+1]+1.414:1);}
 for(let y=h-1;y>=0;y--)for(let x=w-1;x>=0;x--){const p=y*w+x;if(!mask[p])continue;dist[p]=Math.min(dist[p],x<w-1?dist[p+1]+1:1,y<h-1?dist[p+w]+1:1,x<w-1&&y<h-1?dist[p+w+1]+1.414:1,x&&y<h-1?dist[p+w-1]+1.414:1);}
 let radius=0;for(const p of body)radius=Math.max(radius,dist[p]);let sx=0,sy=0,weight=0,seed=body[0];
 for(const p of body)if(dist[p]>=radius*.72){const k=dist[p]*dist[p];sx+=(p%w)*k;sy+=Math.floor(p/w)*k;weight+=k;if(dist[p]>dist[seed])seed=p;}
 const cx=sx/weight,cy=sy/weight,ys=[];
 for(const p of body){const x=p%w,y=Math.floor(p/w);if(y>=cy&&Math.abs(x-cx)<=Math.max(9,radius*1.65))ys.push(y);}
 ys.sort((a,b)=>a-b);const contact=ys[Math.min(ys.length-1,Math.floor(ys.length*.997))];
 const foreign=components.slice(1).reduce((sum,c)=>sum+(c.length>=8?c.length:0),0);
 return {core:[ox+cx,oy+cy],anchor:[ox+cx,oy+contact],radius,foreign,seed:[ox+seed%w,oy+Math.floor(seed/w)],area:body.length};
}
function components(image){
 const {w,h,pixels}=image,mark=new Uint8Array(w*h),queue=new Int32Array(w*h),found=[];
 for(let p=0;p<mark.length;p++)mark[p]=pixels[p*4+3]>=100?1:0;
 for(let p=0;p<mark.length;p++){if(mark[p]!==1)continue;let read=0,n=1,sx=0,sy=0,x0=w,y0=h,x1=0,y1=0;queue[0]=p;mark[p]=2;
  while(read<n){const q=queue[read++],x=q%w,y=Math.floor(q/w);sx+=x;sy+=y;x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);for(const a of [x?q-1:-1,x<w-1?q+1:-1,y?q-w:-1,y<h-1?q+w:-1])if(a>=0&&mark[a]===1){mark[a]=2;queue[n++]=a;}}
  if(n>=8)found.push({cx:sx/n,cy:sy/n,area:n,pixels:Int32Array.from(queue.subarray(0,n)),box:[x0,y0,x1-x0+1,y1-y0+1]});
 }return found;
}
const crcTable=new Uint32Array(256);for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;crcTable[n]=c>>>0;}
function chunk(tag,data){const t=Buffer.from(tag),crcBytes=Buffer.concat([t,data]);let crc=0xffffffff;for(const b of crcBytes)crc=crcTable[(crc^b)&255]^(crc>>>8);const out=Buffer.alloc(data.length+12);out.writeUInt32BE(data.length);t.copy(out,4);data.copy(out,8);out.writeUInt32BE((crc^0xffffffff)>>>0,data.length+8);return out;}
function writePNG(file,w,h,pixels){const header=Buffer.alloc(13);header.writeUInt32BE(w);header.writeUInt32BE(h,4);header[8]=8;header[9]=6;const raw=Buffer.alloc(h*(w*4+1));for(let y=0;y<h;y++)pixels.copy(raw,y*(w*4+1)+1,y*w*4,(y+1)*w*4);fs.writeFileSync(file,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(raw,{level:6})),chunk('IEND',Buffer.alloc(0))]));}
function blend(a,b){const out=Buffer.alloc(a.length);for(let p=0;p<a.length;p+=4){const aa=a[p+3],ba=b[p+3],sum=aa+ba;if(!sum)continue;out[p+3]=Math.round(sum*.5);for(let c=0;c<3;c++)out[p+c]=Math.round((a[p+c]*aa+b[p+c]*ba)/sum);}return out;}
const regions=JSON.parse(fs.readFileSync(path.join(root,'data/asset_regions.json'))),catalog=JSON.parse(fs.readFileSync(path.join(root,'data/motion_regions.json'))),game=JSON.parse(fs.readFileSync(path.join(root,'data/game.json')));
const output={schema:2,anchor_space:'source_pixels',algorithm:'actual body columns; thick body core root; owned detached ornaments; transparent halo isolation',units:{}};
const packed={schema:1,derived_cache:true,source_angles:16,walk_phase_count:8,actions:{idle:[0],move:[1,6,0,7,2,8,0,9],walk:[1,6,0,7,2,8,0,9],attack:[3,4,5],harvest:[3,5,4,5],gather:[3,5,4,5]},action_fps:{move:18,walk:18},units:{}};
const stats=[];let count=0;fs.mkdirSync(path.join(root,'assets/motion_cache'),{recursive:true});
for(const [key,info] of Object.entries(catalog.units)){
 const image=png(path.join(root,info.file.replace('res://',''))),measured=regions.motions[key],[race,kind]=key.split(':').map(Number),air=!!game.units[race][kind].air,all=components(image);
 const sourceRows=Array.from({length:6},(_,row)=>{const parts=all.filter(p=>Math.min(5,Math.floor(p.cy/image.h*6))===row),largest=Math.max(...parts.map(p=>p.area));const candidates=parts.filter(p=>p.area>=Math.max(600,largest*.24)).sort((a,b)=>b.area-a.area),bodies=[];
  for(const p of candidates)if(!bodies.some(q=>Math.abs(q.cx-p.cx)<image.w/9*.48))bodies.push(p);bodies.sort((a,b)=>a.cx-b.cx);
  if(bodies.length<8||bodies.length>11)throw Error(`Unexpected body columns ${key} row${row}: ${bodies.length}`);
  return {parts,bodies};});
 const rows=Array.from({length:6},(_,row)=>Array.from({length:9},(_,col)=>{const [sourceRow,sourceCol]=measured.poses[row][col],entry=sourceRows[sourceRow];let primary;
  if(entry.bodies.length>=9)primary=entry.bodies[Math.round(sourceCol*(entry.bodies.length-1)/8)];
  else {const old=measured.regions[row][col],cx=old[0]+old[2]*.5;primary=entry.bodies.reduce((a,b)=>Math.abs(a.cx-cx)<Math.abs(b.cx-cx)?a:b);}
  const owned=entry.parts.filter(p=>entry.bodies.reduce((a,b)=>Math.abs(a.cx-p.cx)<Math.abs(b.cx-p.cx)?a:b)===primary),body=measure(image,primary.box);
  const pixels=owned.flatMap(p=>Array.from(p.pixels)),mask=new Uint8Array(image.w*image.h);for(const p of pixels)for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const x=p%image.w+dx,y=Math.floor(p/image.w)+dy;if(x>=0&&x<image.w&&y>=0&&y<image.h)mask[y*image.w+x]=1;}
  let x0=image.w,y0=image.h,x1=0,y1=0;for(const p of pixels){const x=p%image.w,y=Math.floor(p/image.w);x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}x0=Math.max(0,x0-2);y0=Math.max(0,y0-2);x1=Math.min(image.w-1,x1+2);y1=Math.min(image.h-1,y1+2);
  return {...body,ground_y:primary.box[1]+primary.box[3]-1,box:[x0,y0,x1-x0+1,y1-y0+1],mask,sourceRow,sourceCol};}));
 const flat=rows.flat(),offsets=flat.map(p=>p.anchor[1]-p.core[1]).sort((a,b)=>a-b),airOffset=offsets[Math.floor(offsets.length/2)];
 for(let row=0;row<6;row++)for(let col=0;col<9;col++){const p=rows[row][col],idle=rows[0][col];p.root=[p.core[0],p.core[1]+(air?airOffset:idle.ground_y-idle.core[1])];}
 const left=Math.ceil(Math.max(...flat.map(p=>p.root[0]-p.box[0])))+4,right=Math.ceil(Math.max(...flat.map(p=>p.box[0]+p.box[2]-p.root[0])))+4,up=Math.ceil(Math.max(...flat.map(p=>p.root[1]-p.box[1])))+4,down=Math.ceil(Math.max(...flat.map(p=>p.box[1]+p.box[3]-p.root[1])))+4;
 const cw=Math.ceil((left+right)/8)*8,ch=Math.ceil((up+down)/8)*8,W=cw*9,H=ch*10,sheet=Buffer.alloc(W*H*4),frames=[];
 for(let row=0;row<6;row++){frames[row]=[];for(let col=0;col<9;col++){const p=rows[row][col],frame=Buffer.alloc(cw*ch*4),shiftX=Math.round(left-p.root[0]),shiftY=Math.round(up-p.root[1]);for(let y=p.box[1];y<p.box[1]+p.box[3];y++)for(let x=p.box[0];x<p.box[0]+p.box[2];x++){const q=y*image.w+x,tx=x+shiftX,ty=y+shiftY;if(!p.mask[q]||tx<0||tx>=cw||ty<0||ty>=ch)continue;image.pixels.copy(frame,(ty*cw+tx)*4,q*4,q*4+4);}frames[row][col]=frame;}}
 for(let col=0;col<9;col++){frames[6]??=[];frames[7]??=[];frames[8]??=[];frames[9]??=[];frames[6][col]=blend(frames[1][col],frames[0][col]);frames[7][col]=blend(frames[0][col],frames[2][col]);frames[8][col]=blend(frames[2][col],frames[0][col]);frames[9][col]=blend(frames[0][col],frames[1][col]);}
 for(let row=0;row<10;row++)for(let col=0;col<9;col++)for(let y=0;y<ch;y++)frames[row][col].copy(sheet,((row*ch+y)*W+col*cw)*4,y*cw*4,(y+1)*cw*4);
 const file=`assets/motion_cache/r${race}_u${String(kind).padStart(2,'0')}.png`;writePNG(path.join(root,file),W,H,sheet);
 packed.units[key]={...info,file:'res://'+file,columns:9,rows:10,packed_root:[left,up],scale_hint:Math.max(image.w/9,image.h/6)*Number(info.scale_width||.84)};
 output.units[key]={anchors:rows.map(row=>row.map(p=>p.root.map(v=>+v.toFixed(3)))),body_centers:rows.map(row=>row.map(p=>p.core.map(v=>+v.toFixed(3)))),source_columns:sourceRows.map(r=>r.bodies.length),packed_root:[left,up],packed_cell:[cw,ch]};
 count+=54;stats.push({key,air,poses:54,source_columns:sourceRows.map(r=>r.bodies.length),cell:[cw,ch],registered_root:[left,up]});
 console.log(JSON.stringify({unit:key,source_columns:sourceRows.map(r=>r.bodies.length),cache:[W,H]}));
}
fs.writeFileSync(path.join(root,'data/motion_roots_v04.json'),JSON.stringify(output));
fs.writeFileSync(path.join(root,'data/motion_cache_v04.json'),JSON.stringify(packed));
fs.writeFileSync(path.join(root,'build/motion-root-audit-v04.json'),JSON.stringify({poses:count,units:stats},null,2));
console.log(JSON.stringify({units:stats.length,source_poses:count,registered_cache_poses:39*90,walk_phases:8}));
