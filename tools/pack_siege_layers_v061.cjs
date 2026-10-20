const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
async function read(file,columns){
 const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true}),W=info.width,H=info.height,seen=new Uint8Array(W*H),cells=Array.from({length:columns*8},()=>({l:W,t:H,r:0,b:0,pixels:[]}));
 for(let p=0;p<W*H;p++){
  if(seen[p]||data[p*4+3]<90)continue;seen[p]=1;const stack=[p],g={l:W,t:H,r:0,b:0,pixels:[]};
  while(stack.length){const q=stack.pop(),x=q%W,y=Math.floor(q/W);g.pixels.push(q);g.l=Math.min(g.l,x);g.r=Math.max(g.r,x);g.t=Math.min(g.t,y);g.b=Math.max(g.b,y);
   for(const n of [x>0?q-1:-1,x<W-1?q+1:-1,y>0?q-W:-1,y<H-1?q+W:-1])if(n>=0&&!seen[n]&&data[n*4+3]>=90){seen[n]=1;stack.push(n);}
  }if(g.pixels.length<30)continue;
  const col=Math.min(columns-1,Math.floor((g.l+g.r)/2/W*columns)),row=Math.min(7,Math.floor((g.t+g.b)/2/H*8)),c=cells[row*columns+col];
  c.l=Math.min(c.l,g.l);c.t=Math.min(c.t,g.t);c.r=Math.max(c.r,g.r);c.b=Math.max(c.b,g.b);c.pixels.push(...g.pixels);
 }
 for(const c of cells)if(c.pixels.length<1000)throw Error('Missing complete layer in '+file);
 return {data,W,H,cells};
}
(async()=>{
 const north=await read('assets/siege_layers_v061_source.png',5),south=await read('assets/siege_south_layers_v061_source.png',2),pieces=[],chassis=[],turrets=[];
 const sourceFor=h=>h<3?north:south,colFor=h=>h<3?h:h-3;
 const scales=[];
 const baseScale=210/Math.max(...north.cells.slice(0,35).map(c=>c.r-c.l+1));
 for(let h=0;h<5;h++){
  const src=sourceFor(h),col=colFor(h),reference=north.cells[h===3?1:h===4?0:h];
  scales[h]=h<3?baseScale:baseScale*(reference.r-reference.l+1)/(src.cells[col].r-src.cells[col].l+1);
 }
 for(let row=0;row<8;row++)for(let h=0;h<5;h++){
  const src=sourceFor(h),columns=h<3?5:2,g=src.cells[row*columns+colFor(h)],pad=3,l=Math.max(0,g.l-pad),t=Math.max(0,g.t-pad),w=Math.min(src.W,g.r+pad+1)-l,ht=Math.min(src.H,g.b+pad+1)-t;
  const mask=new Uint8Array(src.W*src.H);for(const p of g.pixels)mask[p]=1;
  const out=Buffer.alloc(w*ht*4);
  for(let y=t;y<t+ht;y++)for(let x=l;x<l+w;x++){
   const p=y*src.W+x;let keep=mask[p];
   if(!keep&&src.data[p*4+3]<90)for(let dy=-2;dy<=2&&!keep;dy++)for(let dx=-2;dx<=2;dx++){const nx=x+dx,ny=y+dy;if(nx>=0&&ny>=0&&nx<src.W&&ny<src.H&&mask[ny*src.W+nx]){keep=1;break;}}
   if(keep&&src.data[p*4+3])src.data.copy(out,((y-t)*w+x-l)*4,p*4,p*4+4);
  }
  const scale=scales[h],width=Math.round(w*scale),height=Math.round(ht*scale),left=Math.round((256-width)/2),top=row<7?224-height:Math.round((256-height)/2);
  if(width>250||height>250)throw Error('Layer exceeds safe cell');
  const input=await sharp(out,{raw:{width:w,height:ht,channels:4}}).resize(width,height).png().toBuffer();
  pieces.push({input,left:h*256+left,top:row*256+top});
  // Hand-reviewed mounting circles and turret turntable centres in each view.
  const bodyMount=[[.5,.32],[.52,.34],[.50,.36],[.50,.34],[.50,.31]][h];
  const turretPivot=[[.50,.72],[.34,.72],[.31,.58],[.35,.34],[.50,.28]][h];
  const muzzle=[[.5,.025],[.97,.025],[.99,.44],[.99,.95],[.5,.99]][h];
  const entry={heading:h,stage:row,draw:[left,top,width,height],source:[l,t,w,ht],anchor:row<7?[128,224]:[left+width*turretPivot[0],top+height*turretPivot[1]]};
  if(row<7){entry.mount=[left+width*bodyMount[0]-128,top+height*bodyMount[1]-224];chassis.push(entry);}
  else{entry.muzzle=[left+width*muzzle[0]-entry.anchor[0],top+height*muzzle[1]-entry.anchor[1]];turrets.push(entry);}
 }
 const file='assets/registered_v060/siege_layers_v061.png';
 await sharp({create:{width:1280,height:2048,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(pieces).png().toFile(file);
 fs.writeFileSync('data/siege_layers_v061.json',JSON.stringify({file:'res://'+file,stages:7,scale_hint:160,turret_scale:160/224,chassis,turrets},null,2)+'\n');
 console.log('SIEGE_LAYERS_V061 35 independent chassis stages, 5 independent turrets, complete 8 compass headings');
})().catch(e=>{console.error(e);process.exitCode=1});
