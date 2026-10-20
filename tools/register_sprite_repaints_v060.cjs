// Register edited sprite artwork back to original per-cell silhouettes/pivots.
const fs=require('fs'),path=require('path'),sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),a=JSON.parse(fs.readFileSync(path.join(root,'build/sprite-repaint-sources-v060.json'))),clear={r:0,g:0,b:0,alpha:0};
function bbox(data,W,H,rect){let l=rect.left+rect.width,t=rect.top+rect.height,r=-1,b=-1;for(let y=rect.top;y<rect.top+rect.height;y++)for(let x=rect.left;x<rect.left+rect.width;x++)if(data[(y*W+x)*4+3]>80){l=Math.min(l,x);t=Math.min(t,y);r=Math.max(r,x);b=Math.max(b,y);}if(r<l||b<t)throw Error('Empty sprite');return {left:l,top:t,width:r-l+1,height:b-t+1};}
function rowBands(data,W,H,rows){let bands=[],begin=-1;for(let y=0;y<=H;y++){let n=0;if(y<H)for(let x=0;x<W;x++)if(data[(y*W+x)*4+3]>100)n++;let on=n>W*.018;if(on&&begin<0)begin=y;if(!on&&begin>=0){if(y-begin>12)bands.push([begin,y]);begin=-1;}}if(bands.length!==rows)throw Error(`Expected ${rows} row bands, got ${bands.length}: ${JSON.stringify(bands)}`);return bands.map((b,i)=>[i===0?0:Math.round((bands[i-1][1]+b[0])/2),i===rows-1?H:Math.round((b[1]+bands[i+1][0])/2)]);}
async function register(original,edited,cols,rows,out){
 const old=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true}),fresh=await sharp(edited).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const bands=rowBands(fresh.data,fresh.info.width,fresh.info.height,rows),pieces=[];let report=[];
 for(let y=0;y<rows;y++)for(let x=0;x<cols;x++){
  const ow=old.info.width/cols,oh=old.info.height/rows;const oldcell={left:Math.round(x*ow),top:Math.round(y*oh),width:Math.round((x+1)*ow)-Math.round(x*ow),height:Math.round((y+1)*oh)-Math.round(y*oh)};
  const nw=fresh.info.width/cols;const cell={left:Math.round(x*nw),top:bands[y][0],width:Math.round((x+1)*nw)-Math.round(x*nw),height:bands[y][1]-bands[y][0]};
  const b=bbox(old.data,old.info.width,old.info.height,oldcell),n=bbox(fresh.data,fresh.info.width,fresh.info.height,cell);
  const input=await sharp(edited).extract(n).resize(b.width,b.height).png().toBuffer();pieces.push({input,left:b.left,top:b.top});report.push({column:x,row:y,source:n,target:b});
 }
 await sharp({create:{width:old.info.width,height:old.info.height,channels:4,background:clear}}).composite(pieces).png().toFile(out);return report;
}
(async()=>{let report={schema:1,method:'Repainted complete poses individually registered to original cell bounds, existing animation counts/pivots retained',units:{}};fs.mkdirSync(path.join(root,'assets/citrus_palette_v060'),{recursive:true});
 for(let kind of [0,1,2,3,4,5,6,7,8,9,12]){const name=`r1_u${String(kind).padStart(2,'0')}.png`;report.units['1:'+kind]=await register(path.join(root,'assets/motion_cache',name),a['citrus_'+kind],9,10,path.join(root,'assets/citrus_palette_v060',name));console.log('Citrus registered',kind,90);}
 report.units['0:4']=await register(path.join(root,'assets/medic_registered_v05.png'),a.medic,5,4,path.join(root,'assets/medic_registered_v060.png'));
 fs.writeFileSync(path.join(root,'data/sprite_repaints_v060.json'),JSON.stringify(report,null,2));console.log('Registered',Object.values(report.units).reduce((n,v)=>n+v.length,0),'poses');
})();
