// Exact per-frame packing of new painted sprites. Retain all40 source poses.
const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const clear={r:0,g:0,b:0,alpha:0};
(async()=>{let report={columns:8,rows:5,cell:[256,256],units:{}};fs.mkdirSync('assets/registered_v060',{recursive:true});
 for(const name of ['flamer','carrier','drone','chaser']){
  const source=name==='chaser'?require('../build/chaser-final-source-v060.json').path:`assets/${name}_v060.png`,{data,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let bands=[],begin=-1;for(let y=0;y<=info.height;y++){let n=0;if(y<info.height)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>100)n++;const on=n>info.width*.018;if(on&&begin<0)begin=y;if(!on&&begin>=0){if(y-begin>12)bands.push([begin,y]);begin=-1;}}
  if(bands.length!==5)throw Error(`${name}: expected5 rows, got${bands.length}`);
  const regions=[];for(let row=0;row<5;row++)for(let col=0;col<8;col++){
   const x0=Math.round(col*info.width/8),x1=Math.round((col+1)*info.width/8),y0=row?Math.round((bands[row-1][1]+bands[row][0])/2):0,y1=row===4?info.height:Math.round((bands[row][1]+bands[row+1][0])/2);let l=x1,t=y1,r=-1,b=-1;
   for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++)if(data[(y*info.width+x)*4+3]>80){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}
   if(r<=l||b<=t)throw Error(`${name} empty frame ${row}:${col}`);regions.push({left:l,top:t,width:r-l+1,height:b-t+1});
  }
  const factor=224/Math.max(...regions.map(r=>Math.max(r.width,r.height))),air=['carrier','drone'].includes(name),pieces=[];
  for(let i=0;i<40;i++){let r=regions[i],w=Math.max(1,Math.round(r.width*factor)),h=Math.max(1,Math.round(r.height*factor));let input=await sharp(source).extract(r).resize(w,h).png().toBuffer();pieces.push({input,left:(i%8)*256+Math.round((256-w)/2),top:Math.floor(i/8)*256+(air?Math.round((256-h)/2):224-h)});}
  await sharp({create:{width:2048,height:1280,channels:4,background:clear}}).composite(pieces).png().toFile(`assets/registered_v060/${name}.png`);report.units[name]={anchor:air?[128,128]:[128,224],scale_hint:224,regions};console.log('Registered new unit',name,40);
 }
 fs.writeFileSync('data/new_unit_frames_v060.json',JSON.stringify(report,null,2));
})();
