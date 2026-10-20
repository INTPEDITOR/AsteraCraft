// Register complete connected paintings, not equal grid slices that cut tracks
// and capture a neighboring pose. No painting or color changes are performed.
const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{
 const {data,info}=await sharp('assets/flamer_v060.png').ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const W=info.width,H=info.height,labels=new Int32Array(W*H),groups=[];let id=0;
 for(let p=0;p<W*H;p++){
  if(labels[p]||data[p*4+3]<90)continue;id++;labels[p]=id;const stack=[p];let l=W,t=H,r=0,b=0,count=0;
  while(stack.length){const q=stack.pop(),x=q%W,y=Math.floor(q/W);count++;l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);
   for(const n of [x>0?q-1:-1,x<W-1?q+1:-1,y>0?q-W:-1,y<H-1?q+W:-1])if(n>=0&&!labels[n]&&data[n*4+3]>=90){labels[n]=id;stack.push(n);}
  }if(count>1000)groups.push({id,count,left:l,top:t,width:r-l+1,height:b-t+1});
 }
 if(groups.length!==40)throw Error('Expected exactly 40 complete flamer paintings');
 groups.sort((a,b)=>(a.top+a.height/2)-(b.top+b.height/2));
 const frames=[];for(let y=0;y<5;y++)frames.push(...groups.slice(y*8,y*8+8).sort((a,b)=>a.left-b.left));
 const factor=220/Math.max(...frames.map(r=>Math.max(r.width,r.height))),pieces=[],records=[];
 for(let i=0;i<40;i++){
  const g=frames[i],r={left:Math.max(0,g.left-2),top:Math.max(0,g.top-2),width:g.width+4,height:g.height+4};
  r.width=Math.min(r.width,W-r.left);r.height=Math.min(r.height,H-r.top);const out=Buffer.alloc(r.width*r.height*4);
  for(let y=0;y<r.height;y++)for(let x=0;x<r.width;x++){
   const sx=r.left+x,sy=r.top+y,p=sy*W+sx;let keep=labels[p]===g.id;
   if(!keep)for(let dy=-2;dy<=2&&!keep;dy++)for(let dx=-2;dx<=2;dx++){const nx=sx+dx,ny=sy+dy;if(nx>=0&&ny>=0&&nx<W&&ny<H&&labels[ny*W+nx]===g.id){keep=true;break;}}
   if(keep)data.copy(out,(y*r.width+x)*4,p*4,p*4+4);
  }
  const w=Math.round(r.width*factor),h=Math.round(r.height*factor),left=Math.round((256-w)/2),top=224-h;
  const input=await sharp(out,{raw:{width:r.width,height:r.height,channels:4}}).resize(w,h).png().toBuffer();
  pieces.push({input,left:i%8*256+left,top:Math.floor(i/8)*256+top});records.push({source:r,draw:[left,top,w,h]});
 }
 await sharp({create:{width:2048,height:1280,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(pieces).png().toFile('assets/registered_v060/flamer.png');
 const manifest=JSON.parse(fs.readFileSync('data/new_unit_frames_v060.json'));Object.assign(manifest.units.flamer,{regions:records.map(f=>f.source),frames:records,registration:'v061 complete connected components, 2px alpha fringe, no grid cuts'});fs.writeFileSync('data/new_unit_frames_v060.json',JSON.stringify(manifest,null,2)+'\n');
 console.log('Flamer: 40 complete isolated poses registered');
})().catch(e=>{console.error(e);process.exitCode=1});
