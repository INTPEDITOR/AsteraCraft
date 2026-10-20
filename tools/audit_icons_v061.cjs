const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{
 const files=fs.readdirSync('assets').filter(n=>/^icons_(units|buildings|commands)_[012]_v060\.png$/.test(n)),results=[],failures=[];
 for(const file of files){
  const {data,info}=await sharp('assets/'+file).ensureAlpha().raw().toBuffer({resolveWithObject:true});let cells=0,painted=0;
  for(let top=0;top<info.height;top+=128)for(let left=0;left<info.width;left+=128){
   cells++;let corner=0,opaque=0,used=0;
   for(let y=0;y<128;y++)for(let x=0;x<128;x++){const a=data[((top+y)*info.width+left+x)*4+3];if(a>8)used++;if(a>240)opaque++;if((x<4||x>=124)&&(y<4||y>=124)&&a>128)corner++;}
   if(used)painted++;
   if(corner>8||opaque>128*128*.96)failures.push({file,column:left/128,row:top/128,corner,opaque});
  }
  results.push({file,cells,painted});
 }
 const report={atlases:files.length,cells:results.reduce((n,r)=>n+r.cells,0),failures,results};fs.writeFileSync('build/qa-v061-icons.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));if(failures.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
