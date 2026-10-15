const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const utility=fs.readFileSync(path.join(__dirname,'sprite_pivots.cjs'),'utf8').split('const regions=')[0];
const {png,components,writePNG,measure}=new Function('require','__dirname',utility+'\nreturn {png,components,writePNG,measure};')(require,__dirname);
for(const name of ['citrus_brood_v4','citrus_projectiles_v4','faction_cursors_v4','tera_vent_v4']){
 const file=path.join(root,'assets',name+'.png');if(!fs.existsSync(file))continue;
 const im=png(file),hist=[0,0,0];for(let i=3;i<im.pixels.length;i+=4)hist[im.pixels[i]===0?0:im.pixels[i]===255?2:1]++;
 const cs=components(im).filter(c=>c.area>80);console.log(JSON.stringify({name,size:[im.w,im.h],alpha:hist,components:cs.map(c=>({area:c.area,box:c.box}))}));
}
if(process.argv.includes('--preview')){
 for(const key of ['r0_u05','r0_u06','r2_u03','r2_u07']){
  const im=png(path.join(root,'assets/motion_cache',key+'.png')),cw=im.w/9,ch=im.h/10,W=cw*5,H=ch*4,out=Buffer.alloc(W*H*4);
  for(let row=0;row<4;row++)for(let col=0;col<5;col++)for(let y=0;y<ch;y++)im.pixels.copy(out,((row*ch+y)*W+col*cw)*4,((row*im.h/10+y)*im.w+col*cw)*4,((row*im.h/10+y)*im.w+(col+1)*cw)*4);
  writePNG(path.join(root,'build',key+'-root-preview.png'),W,H,out);
 }
}
if(process.argv.includes('--build')){
 const source=png(path.join(root,'assets/faction_cursors_v4.png')),cursors=[];
 for(let race=0;race<3;race++)for(let row=0;row<3;row++){
  const cs=components(source).filter(c=>c.area>80&&Math.floor(c.cx/418)===race&&Math.floor(c.cy/418)===row);
  const x=Math.max(0,Math.min(...cs.map(c=>c.box[0]))-2),y=Math.max(0,Math.min(...cs.map(c=>c.box[1]))-2),w=Math.min(source.w,Math.max(...cs.map(c=>c.box[0]+c.box[2]))+2)-x,h=Math.min(source.h,Math.max(...cs.map(c=>c.box[1]+c.box[3]))+2)-y;
  cursors.push({race,mode:['default','move','attack'][row],file:'res://assets/faction_cursors_v4.png',region:[x,y,w,h],hotspot:row?[w/2,h/2]:[2,2],display_size:row?46:42});
 }
 fs.writeFileSync(path.join(root,'data/cursor_regions_v04.json'),JSON.stringify({cursors},null,2));
 const fx=png(path.join(root,'assets/citrus_projectiles_v4.png'));
 for(let p=0;p<fx.pixels.length;p+=4){const a=fx.pixels[p+3],t=Math.max(0,Math.min(1,(a-92)/112));fx.pixels[p+3]=Math.round(255*t*t*(3-2*t));if(!fx.pixels[p+3])fx.pixels.fill(0,p,p+4);}
 writePNG(path.join(root,'assets/citrus_projectiles_clean_v4.png'),fx.w,fx.h,fx.pixels);
 const vent=png(path.join(root,'assets/tera_vent_v4.png')),W=320,H=480,pixels=Buffer.alloc(W*4*H*2*4),anchors=[];
 for(let frame=0;frame<8;frame++){
  const col=frame%4,row=Math.floor(frame/4),cs=components(vent).filter(c=>c.area>300&&Math.floor(c.cx/384)===col&&Math.floor(c.cy/512)===row).sort((a,b)=>b.area-a.area),body=cs[0];
  const bottom=body.box[1]+body.box[3]-1,near=Array.from(body.pixels).filter(p=>Math.floor(p/vent.w)>bottom-12),rootx=near.reduce((s,p)=>s+p%vent.w,0)/near.length,rooty=bottom;
  anchors.push([rootx,rooty]);
  for(let y=row*512;y<(row+1)*512;y++)for(let x=col*384;x<(col+1)*384;x++){
   const tx=Math.round(x-rootx+W/2),ty=Math.round(y-rooty+H-8);if(tx<0||tx>=W||ty<0||ty>=H)continue;
   const p=(y*vent.w+x)*4,q=((row*H+ty)*W*4+col*W+tx)*4,a=vent.pixels[p+3],t=Math.max(0,Math.min(1,(a-96)/112));if(!t)continue;
   vent.pixels.copy(pixels,q,p,p+3);pixels[q+3]=Math.round(255*t*t*(3-2*t));
  }
 }
 writePNG(path.join(root,'assets/tera_plume_clean_v4.png'),W*4,H*2,pixels);
 fs.writeFileSync(path.join(root,'data/aux_sprites_v04.json'),JSON.stringify({brood:{file:'res://assets/citrus_brood_v4.png',columns:4,rows:2,root:[221.75,427],scale_hint:324},citrus_projectiles:{file:'res://assets/citrus_projectiles_clean_v4.png',columns:3,rows:2},tera_plume:{file:'res://assets/tera_plume_clean_v4.png',columns:4,rows:2,root:[160,472],scale_hint:320,source_anchors:anchors}},null,2));
 console.log('Auxiliary sprite catalogs written.');
}
if(process.argv.includes('--directions')){
 const W=1440,H=1120,out=Buffer.alloc(W*H*4),labels=[];
 for(let race=0;race<3;race++)for(let kind=0;kind<13;kind++){
  const i=race*13+kind,im=png(path.join(root,'assets/motion_cache',`r${race}_u${String(kind).padStart(2,'0')}.png`)),cw=im.w/9,ch=im.h/10,scale=Math.min(105/cw,142/ch),oy=Math.floor(i/6)*160,ox=(i%6)*240;
  for(let side=0;side<2;side++)for(let y=0;y<Math.floor(ch*scale);y++)for(let x=0;x<Math.floor(cw*scale);x++){
   const sx=Math.floor(x/scale)+(side?8:0)*cw,sy=Math.floor(y/scale),p=(sy*im.w+sx)*4,q=((oy+y+8)*W+ox+side*115+x)*4;im.pixels.copy(out,q,p,p+4);
  }labels.push({index:i,key:`${race}:${kind}`,box:[ox,oy,240,160]});
 }
 writePNG(path.join(root,'build/direction-first-last-v04.png'),W,H,out);fs.writeFileSync(path.join(root,'build/direction-first-last-v04.json'),JSON.stringify(labels));
}
