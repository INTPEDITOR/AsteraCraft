// Register each COMPLETE freshly generated HUD to the same measured aperture grid.
// This continuously resamples one image: never compose panels or add menu art.
const fs=require('fs'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const targetX=[0,52,294,350,1200,1248,1426,1486,1580,1596,1690,1706,1800,1816,1910,1963];
const sourceX=[[0,48,298,348,1196,1246,1430,1490,1582,1599,1690,1707,1798,1815,1907,1963],[0,48,293,368,1193,1253,1423,1486,1579,1598,1691,1710,1803,1822,1915,1963],[0,52,290,350,1189,1244,1417,1473,1567,1585,1679,1697,1791,1809,1904,1963]];
const targetY=[[0,55,288,330],[0,79,292,330],[0,38,73,91,295,330],[0,62,130,146,214,230,298,330]];
const sourceY=[[[0,51,293,330],[0,72,293,330],[0,34,70,91,293,330],[0,63,129,147,213,231,298,330]],[[0,63,288,330],[0,88,292,330],[0,40,75,92,297,330],[0,63,131,147,216,232,301,330]],[[0,52,285,330],[0,72,283,330],[0,34,64,84,287,330],[0,59,127,142,209,223,291,330]]];
function map(v,from,to){let i=0;while(i<from.length-2&&v>from[i+1])i++;return to[i]+(v-from[i])/(from[i+1]-from[i])*(to[i+1]-to[i]);}
function ymap(x,y,r){let a=0,b=0,t=0;if(x<294)a=b=0;else if(x<350){a=0;b=1;t=(x-294)/56;}else if(x<1200)a=b=1;else if(x<1248){a=1;b=2;t=(x-1200)/48;}else if(x<1426)a=b=2;else if(x<1486){a=2;b=3;t=(x-1426)/60;}else a=b=3;return map(y,targetY[a],sourceY[r][a])*(1-t)+map(y,targetY[b],sourceY[r][b])*t;}
(async()=>{for(let r=0;r<3;r++){
 const file=`assets/ui_hud_${r}_complete_v060.png`,backup=`build/hud-complete-unregistered-r${r}.png`;if(!fs.existsSync(backup))fs.copyFileSync(file,backup);
 const {data,info}=await sharp(backup).ensureAlpha().raw().toBuffer({resolveWithObject:true}),out=Buffer.alloc(data.length),W=info.width,H=info.height;
 for(let y=0;y<H;y++)for(let x=0;x<W;x++){
  const sx=Math.max(0,Math.min(W-1,map(x,targetX,sourceX[r]))),sy=Math.max(0,Math.min(H-1,ymap(x,y,r))),x0=Math.floor(sx),y0=Math.floor(sy),fx=sx-x0,fy=sy-y0;
  const samples=[[x0,y0,(1-fx)*(1-fy)],[Math.min(W-1,x0+1),y0,fx*(1-fy)],[x0,Math.min(H-1,y0+1),(1-fx)*fy],[Math.min(W-1,x0+1),Math.min(H-1,y0+1),fx*fy]];let rgba=[0,0,0,0];
  for(const [xx,yy,w]of samples){const i=(yy*W+xx)*4,a=data[i+3]/255;for(let c=0;c<3;c++)rgba[c]+=data[i+c]*a*w;rgba[3]+=a*w;}
  const i=(y*W+x)*4;for(let c=0;c<3;c++)out[i+c]=rgba[3]>0?Math.round(rgba[c]/rgba[3]):0;out[i+3]=Math.round(rgba[3]*255);
 }
 await sharp(out,{raw:{width:W,height:H,channels:4}}).png().toFile(file);
 }fs.writeFileSync('data/hud_layout_v060.json',JSON.stringify({canvas:[1963,330],method:'Whole newly painted frame registered continuously to one common aperture grid. No overlays or panel collage.',targetX,targetY,sourceX,sourceY},null,2));console.log('Three whole HUDs registered to identical aperture proportions');})();
