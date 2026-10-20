const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{const catalog=require('../data/industrial_units_v060.json'),failures=[],frames=[];
 for(const [key,unit]of Object.entries(catalog.units)){
  const file=unit.file.replace('res://','');
  for(let heading=0;heading<5;heading++)for(let phase=0;phase<8;phase++){
   const {data}=await sharp(file).extract({left:phase*256,top:heading*256,width:256,height:256}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
   const labels=new Uint8Array(65536),groups=[];let l=256,t=256,r=0,b=0;
   for(let p=0;p<65536;p++){if(labels[p]||data[p*4+3]<90)continue;const todo=[p];labels[p]=1;let count=0;
    while(todo.length){const q=todo.pop(),x=q%256,y=Math.floor(q/256);count++;l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);for(const n of [x>0?q-1:-1,x<255?q+1:-1,y>0?q-256:-1,y<255?q+256:-1])if(n>=0&&!labels[n]&&data[n*4+3]>=90){labels[n]=1;todo.push(n);}}
    if(count>8)groups.push(count);
   }
   const gutter=Math.min(l,t,255-r,255-b);if(gutter<8)failures.push(`${key} ${heading}/${phase} clipped or insufficient gutter`);
   if(groups.length!==1)failures.push(`${key} ${heading}/${phase} has ${groups.length} separate opaque pieces`);
   frames.push({key,heading,phase,gutter,opaque_components:groups.length});
  }
 }
 const report={frames:frames.length,failures,details:frames};fs.writeFileSync('build/qa-v060/sprite-crop-audit.json',JSON.stringify(report,null,2));console.log({frames:frames.length,failures});process.exitCode=failures.length?1:0;
})().catch(e=>{console.error(e);process.exitCode=1});
