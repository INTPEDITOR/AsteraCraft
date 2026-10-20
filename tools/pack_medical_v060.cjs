const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'),a=require('../build/sprite-repaint-sources-v060.json');
async function override(file,index,cols,input){const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true}),w=info.width/cols,h=w,x=(index%cols)*w,y=Math.floor(index/cols)*h;for(let yy=y;yy<y+h;yy++)data.fill(0,(yy*info.width+x)*4,(yy*info.width+x+w)*4);const out=await sharp(data,{raw:{width:info.width,height:info.height,channels:4}}).composite([{input,left:x,top:y}]).png().toBuffer();fs.writeFileSync(file,out);}
(async()=>{
 const m=await sharp(a['medic-icons']).metadata(),cuts=[0,560,1070,1710,2172].map(x=>Math.round(x*m.width/2172)),icons=[];
 for(let i=0;i<4;i++){const part=await sharp(a['medic-icons']).extract({left:cuts[i],top:0,width:cuts[i+1]-cuts[i],height:m.height}).png().toBuffer();icons.push(await sharp(part).trim().resize(112,112,{fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).extend({left:8,right:8,top:8,bottom:8,background:{r:0,g:0,b:0,alpha:0}}).png().toBuffer());}
 await override('assets/icons_units_0_v060.png',4,4,icons[0]);await override('assets/icons_commands_0_v060.png',16,8,icons[1]);await override('assets/icons_buildings_0_v060.png',7,4,icons[2]);
 const portrait=await sharp(a['medic-portrait']).resize(256,320).png().toBuffer(),atlas=await sharp('assets/portraits_0_faces_v060.png').composite([{input:portrait,left:0,top:320}]).png().toBuffer();fs.writeFileSync('assets/portraits_0_faces_v060.png',atlas);
 console.log('Medical crosses replaced: unit icon, syringe, facility icon, portrait, actual20-frame sprite registered separately');
})();
