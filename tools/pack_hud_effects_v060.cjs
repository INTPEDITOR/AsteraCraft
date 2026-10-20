// Technical normalization of reviewed ImageGen outputs. Preserve original paints.
const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),a=JSON.parse(fs.readFileSync(path.join(root,'build/v060-art-sources.json')));
const clear={r:0,g:0,b:0,alpha:0};
async function bounds(file,rect=null,threshold=64){let s=sharp(file);if(rect)s=s.extract(rect);const {data,info}=await s.ensureAlpha().raw().toBuffer({resolveWithObject:true});let l=info.width,t=info.height,r=-1,b=-1;for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]>threshold){l=Math.min(l,x);r=Math.max(r,x);t=Math.min(t,y);b=Math.max(b,y);}return {left:l+(rect?.left||0),top:t+(rect?.top||0),width:r-l+1,height:b-t+1};}
(async()=>{
 const hb=await bounds(a.angular);console.log('Angular bounds',hb);
 const angular=await sharp(a.angular).extract(hb).resize(1963,330).extend({left:10,right:10,top:237,bottom:226,background:clear}).png().toBuffer();
 const menuRegions=[{left:25,top:60,width:1485,height:268},{left:25,top:360,width:1485,height:290},{left:25,top:677,width:1485,height:287}];
 for(let race=0;race<3;race++){
  const base=race===0?angular:path.join(root,'assets',`ui_hud_${race}_native_v3.png`);
  const pos=race===2?[1203,271,178,46]:[1263,288,185,50];
  const bar=await sharp(a.menu).extract(menuRegions[race]).resize(pos[2],pos[3]).png().toBuffer();
  await sharp(base).composite([{input:bar,left:pos[0],top:pos[1]}]).png().toFile(path.join(root,'assets',`ui_hud_${race}_native_v060.png`));
 }
 // Rubble is organized 6x3, but the large HQ uses extra width. Source boundaries
 // are individually measured instead of slicing every row into equal columns.
 const rubbleRows=[[0,395,610,820,1060,1305,1536],[0,395,610,820,1060,1305,1536],[0,395,610,820,1060,1305,1536]],pieces=[];
 for(let row=0;row<3;row++)for(let col=0;col<6;col++){
  const ys=[0,365,660,1024],xs=rubbleRows[row];const region=await bounds(a.rubble,{left:xs[col],top:ys[row],width:xs[col+1]-xs[col],height:ys[row+1]-ys[row]});
  const input=await sharp(a.rubble).extract(region).resize(240,220,{fit:'contain',background:clear}).extend({left:8,right:8,top:18,bottom:18,background:clear}).png().toBuffer();pieces.push({input,left:col*256,top:row*256});
 }
 await sharp({create:{width:1536,height:768,channels:4,background:clear}}).composite(pieces).png().toFile(path.join(root,'assets/rubble_v060.png'));
 console.log('Three HUD shells, single menu bars and18 rubble cells packed');
})();
