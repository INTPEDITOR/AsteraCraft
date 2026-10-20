// Normalize each newly painted COMPLETE HUD as a single image. No overlays,
// panel compositing, old HUD pixels, menu patches, or colour replacements.
const fs=require('fs'),path=require('path'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),sources=JSON.parse(fs.readFileSync(path.join(root,'build/hud-complete-sources-v060.json')));
(async()=>{for(let race=0;race<3;race++){
 const file=sources[race],{data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});let l=info.width,t=info.height,r=0,b=0;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>64){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}
 await sharp(file).extract({left:l,top:t,width:r-l+1,height:b-t+1}).resize(1963,330).png().toFile(path.join(root,'assets',`ui_hud_${race}_complete_v060.png`));
 console.log('Complete HUD',race,[l,t,r-l+1,b-t+1]);
 }})();
