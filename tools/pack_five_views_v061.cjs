// Register five actual generated headings without cutting source paintings.
const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
async function pack(name){
 const file=`assets/${name}_v061_source.png`,{data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const W=info.width,H=info.height,seen=new Uint8Array(W*H),groups=[],centres=[[1/6,1/4],[.5,.25],[5/6,.25],[1/6,.75],[.5,.75]];
 for(let p=0;p<W*H;p++){
  if(seen[p]||data[p*4+3]<90)continue;seen[p]=1;let stack=[p],pixels=[],l=W,t=H,r=0,b=0;
  while(stack.length){let q=stack.pop(),x=q%W,y=Math.floor(q/W);pixels.push(q);l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);
   for(let n of [x>0?q-1:-1,x<W-1?q+1:-1,y>0?q-W:-1,y<H-1?q+W:-1])if(n>=0&&!seen[n]&&data[n*4+3]>=90){seen[n]=1;stack.push(n);}
  }if(pixels.length>12)groups.push({pixels,l,t,r,b});
 }
 const paintings=centres.map(()=>({pixels:[],l:W,t:H,r:0,b:0}));
 for(const g of groups){const cx=(g.l+g.r)/2/W,cy=(g.t+g.b)/2/H;const distances=centres.map(([x,y])=>(cx-x)**2+(cy-y)**2);let index=distances.indexOf(Math.min(...distances));const v=paintings[index];v.pixels.push(...g.pixels);v.l=Math.min(v.l,g.l);v.r=Math.max(v.r,g.r);v.t=Math.min(v.t,g.t);v.b=Math.max(v.b,g.b);}
 const factor=220/Math.max(...paintings.map(v=>Math.max(v.r-v.l+7,v.b-v.t+7))),pieces=[],records=[];
 for(let heading=0;heading<5;heading++){
  const v=paintings[heading];if(v.pixels.length<1000)throw Error(`Missing ${name} heading ${heading}`);
  const l=Math.max(0,v.l-3),t=Math.max(0,v.t-3),w=Math.min(W-1,v.r+3)-l+1,h=Math.min(H-1,v.b+3)-t+1,out=Buffer.alloc(w*h*4),mask=new Uint8Array(W*H);for(const p of v.pixels)mask[p]=1;
  for(let y=t;y<t+h;y++)for(let x=l;x<l+w;x++){let p=y*W+x,keep=mask[p];if(!keep&&data[p*4+3]<90)for(let dy=-2;dy<=2&&!keep;dy++)for(let dx=-2;dx<=2;dx++){let nx=x+dx,ny=y+dy;if(nx>=0&&ny>=0&&nx<W&&ny<H&&mask[ny*W+nx]){keep=1;break;}}if(keep)data.copy(out,((y-t)*w+x-l)*4,p*4,p*4+4);}
  const width=Math.round(w*factor),height=Math.round(h*factor),left=Math.round((256-width)/2),top=name==='carrier'?Math.round((256-height)/2):224-height;
  const input=await sharp(out,{raw:{width:w,height:h,channels:4}}).resize(width,height).png().toBuffer();
  for(let phase=0;phase<8;phase++){pieces.push({input,left:phase*256+left,top:heading*256+top});records.push({heading,phase,draw:[left,top,width,height],source:[l,t,w,h]});}
 }
 const target=`assets/registered_v060/${name}_v061.png`;
 await sharp({create:{width:2048,height:1280,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(pieces).png().toFile(target);
 return {file:'res://'+target,anchor:name==='carrier'?[128,128]:[128,224],scale_hint:224,frames:records};
}
(async()=>{const units={carrier:await pack('carrier')};fs.writeFileSync('data/units_art_v061.json',JSON.stringify({units},null,2)+'\n');console.log('Registered new carrier: 40 complete poses');})().catch(e=>{console.error(e);process.exitCode=1});
