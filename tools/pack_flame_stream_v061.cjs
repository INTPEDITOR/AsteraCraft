const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{
 const {data,info}=await sharp('assets/flame_stream_v061_source.png').ensureAlpha().raw().toBuffer({resolveWithObject:true}),W=info.width,H=info.height,pieces=[],frames=[];
 for(let row=0;row<8;row++){
  const y0=Math.round(row*H/8),y1=Math.round((row+1)*H/8);let l=W,t=y1,r=0,b=y0;
  for(let y=y0;y<y1;y++)for(let x=0;x<W;x++)if(data[(y*W+x)*4+3]>10){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);}
  if(t<=y0||b>=y1-1)throw Error('Flame touches row boundary '+row);
  l=Math.max(0,l-2);r=Math.min(W-1,r+2);t=Math.max(y0,t-2);b=Math.min(y1-1,b+2);
  const w=r-l+1,h=b-t+1,out=Buffer.alloc(w*h*4);
  for(let y=t;y<=b;y++)for(let x=l;x<=r;x++){const p=(y*W+x)*4;if(data[p+3])data.copy(out,((y-t)*w+x-l)*4,p,p+4);}
  const width=504,height=Math.round(h*width/w),top=Math.round((128-height)/2);
  if(height>120)throw Error('Flame is not a narrow jet');
  const input=await sharp(out,{raw:{width:w,height:h,channels:4}}).resize(width,height).png().toBuffer();pieces.push({input,left:row*512+4,top});frames.push({region:[row*512+4,top,width,height],source:[l,t,w,h]});
 }
 await sharp({create:{width:4096,height:128,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(pieces).png().toFile('assets/registered_v060/flame_stream_v061.png');
 fs.writeFileSync('data/flame_stream_v061.json',JSON.stringify({file:'res://assets/registered_v060/flame_stream_v061.png',frames},null,2)+'\n');console.log('8 isolated continuous flame frames, transparent gutters verified');
})().catch(e=>{console.error(e);process.exitCode=1});
