// Technical registration and atlas packing of the generated industrial redesigns.
// Hull paintings remain unrotated. All five canonical headings are actual views.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir=path.resolve(__dirname,'../build/redesign-sources-v060'),clear={r:0,g:0,b:0,alpha:0};
const cache={};
async function source(name){if(!cache[name]){const file=path.join(dir,name+'.png'),raw=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});cache[name]={file,...raw};}return cache[name];}
function bounds(src,rect){const {data,info}=src;let l=rect.left+rect.width,t=rect.top+rect.height,r=-1,b=-1;for(let y=rect.top;y<rect.top+rect.height;y++)for(let x=rect.left;x<rect.left+rect.width;x++)if(data[(y*info.width+x)*4+3]>90){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}if(r<=l||b<=t)throw Error('Empty region');return {left:l,top:t,width:r-l+1,height:b-t+1};}
function roi(src,col,row,cols,rows){const w=src.info.width,h=src.info.height;return {left:Math.round(col*w/cols),top:Math.round(row*h/rows),width:Math.round((col+1)*w/cols)-Math.round(col*w/cols),height:Math.round((row+1)*h/rows)-Math.round(row*h/rows)};}
function principalBounds(src,rect){
 const W=rect.width,H=rect.height,seen=new Uint8Array(W*H),groups=[];
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const start=y*W+x;if(seen[start]||src.data[((rect.top+y)*src.info.width+rect.left+x)*4+3]<=90)continue;
  const stack=[start];seen[start]=1;let l=x,t=y,r=x,b=y,count=0;
  while(stack.length){const p=stack.pop(),px=p%W,py=Math.floor(p/W);count++;l=Math.min(l,px);r=Math.max(r,px);t=Math.min(t,py);b=Math.max(b,py);
   for(const [nx,ny]of [[px-1,py],[px+1,py],[px,py-1],[px,py+1]]){if(nx<0||ny<0||nx>=W||ny>=H)continue;const q=ny*W+nx;if(!seen[q]&&src.data[((rect.top+ny)*src.info.width+rect.left+nx)*4+3]>90){seen[q]=1;stack.push(q);}}
  }groups.push({l,t,r,b,count});
 }
 groups.sort((a,b)=>b.count-a.count);if(!groups.length)throw Error('Empty sprite');
 const kept=groups.slice(0,1);
 const l=Math.min(...kept.map(g=>g.l)),t=Math.min(...kept.map(g=>g.t)),r=Math.max(...kept.map(g=>g.r)),b=Math.max(...kept.map(g=>g.b));
 return {left:rect.left+l,top:rect.top+t,width:r-l+1,height:b-t+1};
}
function splitComponents(src,expected=8){
 const W=src.info.width,H=src.info.height,labels=new Int32Array(W*H),groups=[];let id=0;
 for(let p=0;p<W*H;p++){
  if(labels[p]||src.data[p*4+3]<=90)continue;id++;labels[p]=id;const stack=[p];let l=W,t=H,r=0,b=0,count=0;
  while(stack.length){const q=stack.pop(),x=q%W,y=Math.floor(q/W);count++;l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);
   for(const n of [x>0?q-1:-1,x<W-1?q+1:-1,y>0?q-W:-1,y<H-1?q+W:-1])if(n>=0&&!labels[n]&&src.data[n*4+3]>90){labels[n]=id;stack.push(n);}
  }groups.push({id,count,left:l,top:t,width:r-l+1,height:b-t+1});
 }
 groups.sort((a,b)=>b.count-a.count);const main=expected?groups.slice(0,expected):groups.filter(g=>g.count>groups[0].count*.4);if(main.length<2||(expected&&main.length!==expected)||main.at(-1).count<main[0].count*.4)throw Error('Expected complete walking sprites');
 main.sort((a,b)=>(a.top+a.height/2)-(b.top+b.height/2));const frames=[];for(let row=0;row<main.length/2;row++)frames.push(...main.slice(row*2,row*2+2).sort((a,b)=>a.left-b.left));
 return {labels,frames};
}
async function frame(name,col,row,cols,rows){const src=await source(name);
 if(['fortress_N','fortress_NE','fortress_E','fortress_SE','fortress_gait'].includes(name)){
  if(!src.components)src.components=splitComponents(src,name==='fortress_gait'?0:8);const g=src.components.frames[row*2+col];if(!g)throw Error('Missing complete pose '+name+':'+row);return {name,source:src,rect:{left:g.left,top:g.top,width:g.width,height:g.height},component:g.id};
 }
 const region=roi(src,col,row,cols,rows);return {name,source:src,rect:principalBounds(src,region)};
}
function footSpan(v){let l=Infinity,r=-1;const {data,info}=v.source,b=v.rect;
 for(let y=b.top+Math.floor(b.height*.55);y<b.top+b.height;y++)for(let x=b.left;x<b.left+b.width;x++){const p=y*info.width+x;if(data[p*4+3]>90&&(!v.component||v.source.components.labels[p]===v.component)){l=Math.min(l,x);r=Math.max(r,x);}}
 if(r<=l)throw Error('Missing chassis registration');return r-l+1;
}
async function painting(v){
 if(!v.component)return sharp(v.source.file).extract(v.rect).png().toBuffer();
 // Isolate the chosen atlas sprite where neighboring row bounding boxes overlap.
 const {data,info,components}=v.source,r=v.rect,out=Buffer.alloc(r.width*r.height*4);
 for(let y=0;y<r.height;y++)for(let x=0;x<r.width;x++){
  const sx=r.left+x,sy=r.top+y,p=sy*info.width+sx;let belongs=components.labels[p]===v.component;
  if(!belongs)for(let dy=-2;dy<=2&&!belongs;dy++)for(let dx=-2;dx<=2;dx++){const nx=sx+dx,ny=sy+dy;if(nx>=0&&ny>=0&&nx<info.width&&ny<info.height&&components.labels[ny*info.width+nx]===v.component){belongs=true;break;}}
  if(belongs)data.copy(out,(y*r.width+x)*4,p*4,p*4+4);
 }
 return sharp(out,{raw:{width:r.width,height:r.height,channels:4}}).png().toBuffer();
}
async function main(){
 fs.mkdirSync('assets/registered_v060',{recursive:true});
 const report={schema:1,cell:[256,256],columns:8,rows:5,headings:['N','NE','E','SE','S'],generator:'Built-in ImageGen; technical alpha registration and atlas packing only',brief:'Distinct rugged angular mustard-yellow and charcoal military designs, cyan instruments. True front/rear views and down-pointing triple cannon. Eight walking phases; aircraft rigid hull plus eight animated propulsion phases.',units:{}};
 for(const [name,kind,air]of [['interceptor',9,true],['bomber',10,true],['fortress',12,false],['drone',15,true]]){
  let views=[];
  if(name==='interceptor')views=[await frame('interceptor_pair',0,0,2,1),await frame(name,1,0,5,8),await frame(name,2,0,5,8),await frame(name,3,0,5,8),await frame('interceptor_pair',1,0,2,1)];
  if(name==='bomber')views=[await frame(name,0,0,5,8),await frame(name,3,0,5,8),await frame(name,2,0,5,8),await frame('bomber_pair',1,0,2,1),await frame('bomber_pair',0,0,2,1)];
  if(name==='drone')views=[await frame('drone_pair',0,0,2,1),await frame('drone_pair',1,0,2,1),await frame(name,2,0,5,8),await frame(name,1,0,5,8),await frame(name,0,0,5,8)];
  const pieces=[],records=[],icons=[];
  for(let heading=0;heading<5;heading++)for(let phase=0;phase<8;phase++){
   const side=heading<=3?'fortress_'+['N','NE','E','SE'][heading]:null;
   let v=air?views[heading]:side?await frame(side,phase%2,Math.floor(phase/2),2,4):heading===0?await frame(name,0,phase,5,8):phase===0?await frame('fortress_pair',0,0,2,1):await frame('fortress_gait',0,phase-1,2,7);
   // Normalize each heading by its rigid hull extent. Exhaust animation is external.
   const ref=air?views[heading]:side?await frame(side,0,0,2,4):heading===0?await frame(name,0,0,5,8):await frame('fortress_pair',0,0,2,1);
   const scaleRef=!air&&heading===4&&phase>0?await frame('fortress_gait',0,0,2,7):ref;
   const factor=air?224/Math.max(scaleRef.rect.width,scaleRef.rect.height):200/footSpan(scaleRef),w=Math.round(v.rect.width*factor),h=Math.round(v.rect.height*factor);
   if(w>250||h>250)throw Error(`${name} frame exceeds padded cell ${heading}:${phase} ${w}x${h}`);
   const input=await sharp(await painting(v)).resize(w,h).png().toBuffer();
   const left=Math.round((256-w)/2),top=air?Math.round((256-h)/2):224-h;
   pieces.push({input,left:phase*256+left,top:heading*256+top});
   records.push({heading,phase,source:v.name,rect:v.rect,draw:[left,top,w,h]});
   if(phase===0)icons.push({input,left,top});
  }
  const file=`assets/registered_v060/${name}_industrial.png`;
  await sharp({create:{width:2048,height:1280,channels:4,background:clear}}).composite(pieces).png().toFile(file);
  report.units['0:'+kind]={name,file:'res://'+file,anchor:air?[128,128]:[128,224],scale_hint:224,rigid_hull:air,propulsion_phases:air?8:0,walking_phases:air?0:8,frames:records};
  const preview=await sharp(file).extract({left:0,top:3*256,width:256,height:256}).png().toBuffer();
  const icon=await sharp(preview).trim().resize(112,112,{fit:'inside'}).png().toBuffer(),im=await sharp(icon).metadata();
  const old=await sharp('assets/icons_units_0_v060.png').png().toBuffer();
  const blank=await sharp({create:{width:128,height:128,channels:4,background:clear}}).composite([{input:icon,left:Math.round((128-im.width)/2),top:Math.round((128-im.height)/2)}]).png().toBuffer();
  // 'over' cannot erase an old opaque backdrop. Clear the destination cell.
  const atlas=await sharp(old).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  for(let y=0;y<128;y++)atlas.data.fill(0,((Math.floor(kind/4)*128+y)*atlas.info.width+(kind%4)*128)*4,((Math.floor(kind/4)*128+y)*atlas.info.width+(kind%4+1)*128)*4);
  await sharp(atlas.data,{raw:{width:atlas.info.width,height:atlas.info.height,channels:4}}).composite([{input:blank,left:(kind%4)*128,top:Math.floor(kind/4)*128}]).png().toFile('assets/icons_units_0_v060.png');
  console.log('Packed industrial unit',name,'canonical headings',5,'frames',40);
 }
 report.sources=Object.fromEntries(await Promise.all(Object.keys(cache).map(async name=>[name,{sha256:crypto.createHash('sha256').update(fs.readFileSync(cache[name].file)).digest('hex')}])));
 fs.writeFileSync('data/industrial_units_v060.json',JSON.stringify(report,null,2)+'\n');
 const image=await sharp('assets/portraits_0_faces_v060.png').png().toBuffer(),portrait=await sharp(path.join(dir,'drone_portrait.png')).resize(256,320,{fit:'cover'}).png().toBuffer();
 await sharp(image).composite([{input:portrait,left:768,top:960}]).png().toFile('assets/portraits_0_faces_v060.png');
 const portraits=JSON.parse(fs.readFileSync('data/portraits_v060.json'));Object.assign(portraits.portraits.find(p=>p.race===0&&p.kind===15),{source:'Round industrial drone individual ImageGen portrait, complete cyan sensor and hangar background',sha256:crypto.createHash('sha256').update(portrait).digest('hex')});fs.writeFileSync('data/portraits_v060.json',JSON.stringify(portraits,null,2)+'\n');
 const commands=JSON.parse(fs.readFileSync('data/command_icons_v060.json'));commands.industrial_unit_icons={race:0,kinds:[9,10,12,15],source:'Matching painted industrial unit silhouettes, normalized into 128px slots',file:'assets/icons_units_0_v060.png'};fs.writeFileSync('data/command_icons_v060.json',JSON.stringify(commands,null,2)+'\n');
}
main().catch(e=>{console.error(e);process.exitCode=1});
