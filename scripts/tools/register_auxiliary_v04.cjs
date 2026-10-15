const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),utility=fs.readFileSync(path.join(__dirname,'sprite_pivots.cjs'),'utf8').split('const regions=')[0];
const {png,components,writePNG,measure}=new Function('require','__dirname',utility+'\nreturn {png,components,writePNG,measure};')(require,__dirname);
const catalog=JSON.parse(fs.readFileSync(path.join(root,'data/aux_sprites_v04.json')));
function registered(name,cols,rows,scale_hint){
 const im=png(path.join(root,'assets',name+'.png')),poses=[],all=components(im);let left=0,right=0,up=0,down=0;
 for(let row=0;row<rows;row++)for(let col=0;col<cols;col++){
  const x=Math.floor(col*im.w/cols),y=Math.floor(row*im.h/rows),box=[x,y,Math.floor((col+1)*im.w/cols)-x,Math.floor((row+1)*im.h/rows)-y],m=measure(im,box);
  const contact=m.anchor,body=all.filter(c=>Math.floor(c.cx/(im.w/cols))===col&&Math.floor(c.cy/(im.h/rows))===row).sort((a,b)=>b.area-a.area)[0];
  contact[1]=body.box[1]+body.box[3]-1;
  const clean=[Math.max(0,body.box[0]-2),Math.max(0,body.box[1]-2),Math.min(im.w,body.box[0]+body.box[2]+2),Math.min(im.h,body.box[1]+body.box[3]+2)];clean[2]-=clean[0];clean[3]-=clean[1];
  const mask=new Uint8Array(im.w*im.h);for(const p of body.pixels){const px=p%im.w,py=Math.floor(p/im.w);for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const xx=px+dx,yy=py+dy;if(xx>=0&&xx<im.w&&yy>=0&&yy<im.h)mask[yy*im.w+xx]=1;}}
  left=Math.max(left,contact[0]-clean[0]+3);right=Math.max(right,clean[0]+clean[2]-contact[0]+3);up=Math.max(up,contact[1]-clean[1]+3);down=Math.max(down,clean[1]+clean[3]-contact[1]+3);
  poses.push({box:clean,root:contact,mask});
 }
 const cw=Math.ceil((left+right)/8)*8,ch=Math.ceil((up+down)/8)*8,W=cw*cols,H=ch*rows,out=Buffer.alloc(W*H*4);
 for(let i=0;i<poses.length;i++){
  const p=poses[i],col=i%cols,row=Math.floor(i/cols),dx=Math.round(left-p.root[0]),dy=Math.round(up-p.root[1]);
  for(let y=p.box[1];y<p.box[1]+p.box[3];y++)for(let x=p.box[0];x<p.box[0]+p.box[2];x++){
   const a=(y*im.w+x)*4,tx=x+dx,ty=y+dy;if(tx<0||tx>=cw||ty<0||ty>=ch||!p.mask[y*im.w+x]||im.pixels[a+3]<36)continue;
   const q=((row*ch+ty)*W+col*cw+tx)*4;im.pixels.copy(out,q,a,a+4);
  }
 }
 const file='assets/'+name+'_registered.png';writePNG(path.join(root,file),W,H,out);
 return {file:'res://'+file,columns:cols,rows,root:[left,up],scale_hint,source_roots:poses.map(p=>p.root)};
}
catalog.brood=registered('citrus_brood_growth_v4',4,2,324);
catalog.medic_heal=registered('medic_heal_v4',9,4,168);catalog.medic_heal.reverse_columns=true;
const vehicleSpecs={
 '0:5':{kind:5,reverse:false,mounts:[[111,201],[312,205],[511,213],[720,218],[950,229],[1158,218],[1374,220],[1568,216],[1774,207]],turrets:[[110,693],[311,693],[510,695],[718,696],[932,697],[1158,697],[1372,695],[1571,693],[1771,691]],pilot_y:-90},
 '0:6':{kind:6,reverse:true,mounts:[[117,248],[310,251],[519,258],[734,258],[942,262],[1155,263],[1356,256],[1566,251],[1770,250]],turrets:[[111,688],[310,688],[520,689],[729,690],[934,692],[1149,690],[1354,689],[1565,688],[1774,689]],embedded_pilot:true},
 '0:12':{kind:12,reverse:true,mounts:[[111,167],[323,170],[527,170],[737,168],[947,167],[1151,168],[1359,168],[1565,167],[1773,169]],turrets:[[111,688],[322,688],[527,688],[736,688],[944,688],[1153,688],[1362,688],[1571,688],[1777,688]],pilot_y:-98}
};
catalog.vehicles={};
for(const [key,spec] of Object.entries(vehicleSpecs)){
 const name=`vehicle_layers_r0_u${String(spec.kind).padStart(2,'0')}_v4`,im=png(path.join(root,'assets',name+'.png')),frames=[];
 for(let col=0;col<9;col++){
  const x=Math.floor(col*im.w/9),w=Math.floor((col+1)*im.w/9)-x,half=Math.floor(im.h/2),body=measure(im,[x,0,w,half]);
  const part=components(im).filter(c=>c.cy<half&&Math.floor(c.cx/(im.w/9))===col).sort((a,b)=>b.area-a.area)[0];
  body.anchor[1]=part.box[1]+part.box[3]-1;
  const turret=measure(im,[x,half,w,im.h-half]);
  frames.push({chassis_region:[x,0,w,half],chassis_root:[body.anchor[0]-x,body.anchor[1]],mount:[spec.mounts[col][0]-body.anchor[0],spec.mounts[col][1]-body.anchor[1]],turret_region:[x,half,w,im.h-half],turret_root:[turret.core[0]-x,spec.turrets[col][1]-half],pilot_mount:[0,spec.pilot_y||0]});
 }
 catalog.vehicles[key]={file:'res://assets/'+name+'.png',scale_hint:175.56,turret_scale:spec.kind===5?.48:spec.kind===6?.52:.40,reverse_columns:spec.reverse,embedded_pilot:!!spec.embedded_pilot,frames};
}
catalog.pilots={file:'res://assets/hyrax_pilot_v4.png',columns:9,rows:2,root:[104.5,370],air_root:[104.5,310],scale_hint:209};
catalog.air_pilots={
 '0:8':{mounts:[[83,94],[96,96],[105,99],[101,99],[101,98],[104,98],[101,100],[97,99],[84,111]],width:28},
 '0:9':{mounts:[[87,65],[88,64],[96,68],[88,69],[98,68],[99,68],[100,73],[109,77],[88,68]],width:32},
 '0:10':{mounts:[[88,61],[90,60],[94,62],[95,67],[97,65],[102,67],[96,70],[96,72],[88,66]],width:32},
 '0:11':{mounts:[[92,91],[83,95],[87,97],[79,100],[66,95],[68,96],[60,94],[78,100],[94,105]],width:36}
};
const roots=JSON.parse(fs.readFileSync(path.join(root,'data/motion_roots_v04.json')));
for(const [key,entry] of Object.entries(catalog.air_pilots))entry.root=roots.units[key].packed_root;
catalog.rally={file:'res://assets/rally_markers_v4.png',columns:3,rows:2};
const rally=png(path.join(root,'assets/rally_markers_v4.png')),rallyClean=Buffer.alloc(rally.pixels.length),rallyParts=components(rally);
for(let row=0;row<2;row++)for(let col=0;col<3;col++){
 const body=rallyParts.filter(c=>Math.floor(c.cx/512)===col&&Math.floor(c.cy/512)===row).sort((a,b)=>b.area-a.area)[0];
 for(const p of body.pixels){const x=p%rally.w,y=Math.floor(p/rally.w);for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const xx=x+dx,yy=y+dy;if(xx<0||xx>=rally.w||yy<0||yy>=rally.h)continue;const q=(yy*rally.w+xx)*4;rally.pixels.copy(rallyClean,q,q,q+4);}}
}
writePNG(path.join(root,'assets/rally_markers_clean_v4.png'),rally.w,rally.h,rallyClean);catalog.rally.file='res://assets/rally_markers_clean_v4.png';
fs.writeFileSync(path.join(root,'data/aux_sprites_v04.json'),JSON.stringify(catalog,null,2));
console.log(JSON.stringify({brood:catalog.brood,medic:catalog.medic_heal,vehicles:Object.keys(catalog.vehicles)}));
