// Audit every runtime motion, vehicle layer and new-unit frame. Isolate the
// complete principal painting in the source atlas, restoring over-cut edges.
const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const clear={r:0,g:0,b:0,alpha:0};
(async()=>{
 const entries=JSON.parse(fs.readFileSync('build/live-frame-sources-v061/frames.json')),cache={},repairs={},details=[];
 for(const file of new Set(entries.map(e=>e.source))){
  const {data,info}=await sharp(file.replace('res://','')).ensureAlpha().raw().toBuffer({resolveWithObject:true}),W=info.width,H=info.height,labels=new Int32Array(W*H),groups=[null];let id=0;
  for(let p=0;p<W*H;p++){
   if(labels[p]||data[p*4+3]<90)continue;id++;labels[p]=id;const stack=[p];let l=W,t=H,r=0,b=0,count=0;
   while(stack.length){const q=stack.pop(),x=q%W,y=Math.floor(q/W);count++;l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);
    for(const n of [x>0?q-1:-1,x<W-1?q+1:-1,y>0?q-W:-1,y<H-1?q+W:-1])if(n>=0&&!labels[n]&&data[n*4+3]>=90){labels[n]=id;stack.push(n);}
   }groups.push({id,count,l,t,r,b});
  }cache[file]={data,info,labels,groups};
 }
 const existing=process.argv.includes('--append')?JSON.parse(fs.readFileSync('data/frame_cleanup_v061.json')).repairs:{};
 fs.mkdirSync('assets/verified_v061',{recursive:true});let atlas=process.argv.includes('--append')?1+Math.max(-1,...Object.values(existing).map(e=>Number(e.file.match(/frames_(\d+)/)[1]))):0,pieces=[],height=0,width=2048;
 async function flush(){if(!pieces.length)return;await sharp({create:{width,height,channels:4,background:clear}}).composite(pieces).png().toFile(`assets/verified_v061/frames_${atlas}.png`);atlas++;pieces=[];height=0;}
 let x=0,y=0,rowHeight=0;
 for(const e of entries){
  const s=cache[e.source],W=s.info.width,H=s.info.height,[rx,ry,rw,rh]=e.region,counts=new Map();
  for(let yy=ry;yy<ry+rh;yy++)for(let xx=rx;xx<rx+rw;xx++){const id=s.labels[yy*W+xx];if(id)counts.set(id,(counts.get(id)||0)+1);}
  const sorted=[...counts].sort((a,b)=>b[1]-a[1]);if(!sorted.length)throw Error('Empty frame '+e.key);
  const main=s.groups[sorted[0][0]],kept=new Set([main.id]);
  // Preserve a detached substantial limb or nearby lens/glow, while rejecting
  // small, distant pieces of a different sprite.
  for(const [id,count]of sorted.slice(1)){const g=s.groups[id],dx=Math.max(0,main.l-g.r,g.l-main.r),dy=Math.max(0,main.t-g.b,g.t-main.b);if(Math.hypot(dx,dy)<=3||(count>sorted[0][1]*.15&&Math.hypot(dx,dy)<10))kept.add(id);}
  const removed=sorted.filter(([id,c])=>!kept.has(id)&&c>8).reduce((n,a)=>n+a[1],0);
  let l=main.l,t=main.t,r=main.r,b=main.b;for(const id of kept){const g=s.groups[id];l=Math.min(l,g.l);r=Math.max(r,g.r);t=Math.min(t,g.t);b=Math.max(b,g.b);}
  const recovered=l<rx-1||t<ry-1||r>=rx+rw+1||b>=ry+rh+1;
  if(process.argv.includes('--audit')){details.push({key:e.key,status:removed||recovered?'needs_review':'clean',removed,recovered});continue;}
  if(r-l>rw*1.6||b-t>rh*1.6){details.push({key:e.key,status:'review_connected_painting',removed});continue;}
  if(!removed&&!recovered){details.push({key:e.key,status:'clean'});continue;}
  l=Math.max(0,l-3);t=Math.max(0,t-3);r=Math.min(W-1,r+3);b=Math.min(H-1,b+3);
  const fw=r-l+1,fh=b-t+1,out=Buffer.alloc(fw*fh*4);
  for(let yy=t;yy<=b;yy++)for(let xx=l;xx<=r;xx++){
   const p=yy*W+xx;let keep=kept.has(s.labels[p]);
   if(!keep&&s.data[p*4+3]<90)for(let dy=-2;dy<=2&&!keep;dy++)for(let dx=-2;dx<=2;dx++){const nx=xx+dx,ny=yy+dy;if(nx>=0&&ny>=0&&nx<W&&ny<H&&kept.has(s.labels[ny*W+nx])){keep=true;break;}}
   if(keep)s.data.copy(out,((yy-t)*fw+xx-l)*4,p*4,p*4+4);
  }
  if(x+fw+4>width){x=0;y+=rowHeight+4;rowHeight=0;}
  if(y+fh+4>4096){height=Math.max(height,y+rowHeight);await flush();x=0;y=0;rowHeight=0;}
  const input=await sharp(out,{raw:{width:fw,height:fh,channels:4}}).png().toBuffer();pieces.push({input,left:x,top:y});height=Math.max(height,y+fh);
  repairs[e.key]={file:`res://assets/verified_v061/frames_${atlas}.png`,region:[x,y,fw,fh],anchor_delta:[rx-l,ry-t],bounds:[3,3,fw-6,fh-6]};
  details.push({key:e.key,status:'repaired',removed,recovered});x+=fw+4;rowHeight=Math.max(rowHeight,fh);
 }
 await flush();
 const report={frames:entries.length,repaired:Object.keys(repairs).length,unresolved:details.filter(e=>e.status==='review_connected_painting'),details};
 if(!process.argv.includes('--audit'))fs.writeFileSync('data/frame_cleanup_v061.json',JSON.stringify({repairs:{...existing,...repairs}},null,2)+'\n');
 if(process.argv.includes('--audit'))report.unresolved=details.filter(e=>e.status!=='clean');
 fs.writeFileSync(process.argv.includes('--audit')?'build/qa-v061-active-frame-audit.json':'build/qa-v061-live-frames.json',JSON.stringify(report,null,2));
 console.log({frames:report.frames,repaired:report.repaired,unresolved:report.unresolved.length,atlases:atlas});
})().catch(e=>{console.error(e);process.exitCode=1});
