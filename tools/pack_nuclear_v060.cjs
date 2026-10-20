const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),a=JSON.parse(fs.readFileSync(path.join(root,'build/v060-art-sources.json'))),out=path.join(root,'assets/nuclear32_v060.png'),src=path.join(root,'build/nuclear28-source.png'),clear={r:0,g:0,b:0,alpha:0};
(async()=>{
 if(!fs.existsSync(src))fs.copyFileSync(out,src);
 const sequences=[];for(let i=0;i<28;i++){sequences.push({file:src,index:i,cols:4,rows:7});const extra={9:0,12:1,15:2,18:3}[i];if(extra!==undefined)sequences.push({file:a.nuclear_extra,index:extra,cols:4,rows:1});}
 const pieces=[];
 for(let i=0;i<sequences.length;i++){
  const q=sequences[i],m=await sharp(q.file).metadata(),x=Math.round((q.index%q.cols)*m.width/q.cols),y=Math.round(Math.floor(q.index/q.cols)*m.height/q.rows),endX=Math.round((q.index%q.cols+1)*m.width/q.cols),endY=Math.round((Math.floor(q.index/q.cols)+1)*m.height/q.rows);
  const cell={left:x,top:y,width:endX-x,height:endY-y};const {data,info}=await sharp(q.file).extract(cell).ensureAlpha().raw().toBuffer({resolveWithObject:true});let l=info.width,t=info.height,r=-1,b=-1;
  for(let yy=0;yy<info.height;yy++)for(let xx=0;xx<info.width;xx++)if(data[(yy*info.width+xx)*4+3]>24){l=Math.min(l,xx);r=Math.max(r,xx);t=Math.min(t,yy);b=Math.max(b,yy);}
  const frame=await sharp(q.file).extract({left:x+l,top:y+t,width:r-l+1,height:b-t+1}).resize(352,330,{fit:'inside'}).png().toBuffer(),fm=await sharp(frame).metadata();
  pieces.push({input:frame,left:(i%4)*384+Math.round((384-fm.width)/2),top:Math.floor(i/4)*384+330-fm.height});
 }
 await sharp({create:{width:1536,height:3072,channels:4,background:clear}}).composite(pieces).png().toFile(out);
 fs.writeFileSync(path.join(root,'data/nuclear_frames_v060.json'),JSON.stringify({columns:4,rows:8,cell:[384,384],ground_anchor:[192,330],frames:sequences.map(q=>({...q,file:path.basename(q.file)}))},null,2));
 console.log('NUCLEAR32 packed',sequences.length,'complete frames');
})();
