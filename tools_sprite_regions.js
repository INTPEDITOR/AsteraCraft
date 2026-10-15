const fs=require('node:fs'),z=require('node:zlib');
function png(file){
 const b=fs.readFileSync(file),w=b.readUInt32BE(16),h=b.readUInt32BE(20),type=b[25];if(type!==6)throw Error('RGBA required');let off=8,parts=[];
 while(off<b.length){const n=b.readUInt32BE(off),t=b.toString('ascii',off+4,off+8);if(t==='IDAT')parts.push(b.subarray(off+8,off+8+n));off+=n+12;}
 const raw=z.inflateSync(Buffer.concat(parts)),p=Buffer.alloc(w*h*4);let ri=0;
 for(let y=0;y<h;y++){const f=raw[ri++];for(let x=0;x<w*4;x++){const a=x>=4?p[y*w*4+x-4]:0,u=y?p[(y-1)*w*4+x]:0,c=y&&x>=4?p[(y-1)*w*4+x-4]:0;let v=raw[ri++];if(f===1)v+=a;else if(f===2)v+=u;else if(f===3)v+=Math.floor((a+u)/2);else if(f===4){const v0=a+u-c,pa=Math.abs(v0-a),pb=Math.abs(v0-u),pc=Math.abs(v0-c);v+=pa<=pb&&pa<=pc?a:pb<=pc?u:c;}p[y*w*4+x]=v&255;}}
 return {w,h,p};
}
const data=JSON.parse(fs.readFileSync('data/game.json','utf8')),metadata={};
for(let race=0;race<3;race++)for(const name of ['ground','air']){
 const file=name+'_'+race,{w,h,p}=png('assets/'+file+'.png'),rows=data.sprite_rows[name][race].length,cols=name==='air'?19:9;
 const yc=Array(h).fill(0);for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(p[(y*w+x)*4+3]>80)yc[y]++;
 const ycSmooth=yc.map((v,y)=>{let a=0;for(let d=-2;d<=2;d++)a+=yc[Math.max(0,Math.min(h-1,y+d))];return a/5;});
 let ycuts=[0];
 for(let r=1;r<rows;r++){
  const expected=r*h/rows,lo=Math.max(ycuts.at(-1)+10,Math.floor(expected-h/rows*.45)),hi=Math.min(h-1,Math.ceil(expected+h/rows*.45));
  let best=lo;for(let y=lo;y<=hi;y++)if(ycSmooth[y]<ycSmooth[best]-.001||(Math.abs(ycSmooth[y]-ycSmooth[best])<.001&&Math.abs(y-expected)<Math.abs(best-expected)))best=y;
  ycuts.push(best);
 }ycuts.push(h);
 // Generated sprites have variable row heights; verified source row boundaries.
 const verified={ground_1:[0,92,179,269,360,469,589,698,814,895,1010,1163],air_0:[0,200,350,522,745],air_2:[0,140,287,445,736]};
 if(verified[file])ycuts=verified[file];
 const cells=[];
 for(let r=0;r<rows;r++){
  const y0=ycuts[r],y1=ycuts[r+1],xc=Array(w).fill(0);
  for(let x=0;x<w;x++)for(let y=y0;y<y1;y++)if(p[(y*w+x)*4+3]>80)xc[x]++;
  const xcuts=[0];for(let c=1;c<cols;c++){
   const expected=c*w/cols,lo=Math.floor(expected-w/cols*.38),hi=Math.ceil(expected+w/cols*.38);let best=lo;
   for(let x=lo;x<=hi;x++)if(xc[x]<xc[best]||(xc[x]===xc[best]&&Math.abs(x-expected)<Math.abs(best-expected)))best=x;
   xcuts.push(best);
  }xcuts.push(w);
  cells.push(Array.from({length:cols},(_,c)=>[xcuts[c],y0,xcuts[c+1]-xcuts[c],y1-y0]));
 }
 metadata[file]=cells;console.log(file,w,h,'y boundaries',ycuts.join(','));
}
fs.writeFileSync('data/sprite_regions.json',JSON.stringify(metadata));
