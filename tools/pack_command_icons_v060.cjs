// Normalize ImageGen-painted icons into exact runtime cells; no art is synthesized here.
const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),sources=JSON.parse(fs.readFileSync(path.join(root,'build/v060-art-sources.json'))),cell=128;
const data=JSON.parse(fs.readFileSync(path.join(root,'data/game.json')));
const commands=['move','attack','stop','hold','build','gather','repair','ability','unload','cancel','research','train','as','tera','population','rally'];
async function pack(file,cols,rows,out){
 const {data:raw,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});let pieces=[],regions=[];
 for(let row=0;row<rows;row++)for(let col=0;col<cols;col++){
  const x0=Math.round(col*info.width/cols)+2,y0=Math.round(row*info.height/rows)+2,x1=Math.round((col+1)*info.width/cols)-2,y1=Math.round((row+1)*info.height/rows)-2;
  let l=x1,t=y1,r=x0,b=y0;
  for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++)if(raw[(y*info.width+x)*4+3]>64){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);}
  if(r<=l||b<=t)throw Error('Empty icon '+out+' '+col+','+row);
  const region={left:l,top:t,width:r-l+1,height:b-t+1};regions.push(region);
  const input=await sharp(file).extract(region).resize(cell-16,cell-16,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).extend({left:8,right:8,top:8,bottom:8,background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer();
  pieces.push({input,left:col*cell,top:row*cell});
 }
 await sharp({create:{width:cols*cell,height:rows*cell,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(pieces).png().toFile(path.join(root,'assets',out));return regions;
}
(async()=>{let report={cell,commands,skills:[],atlases:[]};
 for(let race=0;race<3;race++){
  // Painted source slots are stable; the three redesigned support icons use a separate atlas.
  const skills=race===1?['neural','mind_control','shed','sap_reclaim','sap_bloom','carapace','scatter','root_surge']:data.abilities.filter(s=>s.race===race).map(s=>s.id);report.skills.push(skills);
  for(const kind of ['commands','buildings','units']){
   const key=kind+'_'+race,file=sources[key+'_color']||sources[key],cols=kind==='commands'?8:4;
   const output=`icons_${kind}_${race}_v060.png`,regions=await pack(file,cols,4,output);
   report.atlases.push({race,kind,file:'res://assets/'+output,columns:cols,rows:4,source:path.basename(file),regions});
  }
 }
 fs.writeFileSync(path.join(root,'data/command_icons_v060.json'),JSON.stringify(report,null,2)+'\n');
 console.log('Packed 192 original faction icons into 9 exact atlases');
})();
