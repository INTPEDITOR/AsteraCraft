const fs=require('fs'),z=require('zlib');
for(const name of fs.readdirSync('assets').filter(n=>/^air_.*png$/.test(n))){
 const b=fs.readFileSync('assets/'+name),w=b.readUInt32BE(16),h=b.readUInt32BE(20),type=b[25],bpp=type===6?4:3;let off=8,parts=[];while(off<b.length){let n=b.readUInt32BE(off),t=b.toString('ascii',off+4,off+8);if(t==='IDAT')parts.push(b.subarray(off+8,off+8+n));off+=n+12;}
 const raw=z.inflateSync(Buffer.concat(parts)),pixels=Buffer.alloc(w*h*bpp);let ri=0;for(let y=0;y<h;y++){let f=raw[ri++];for(let x=0;x<w*bpp;x++){let a=x>=bpp?pixels[y*w*bpp+x-bpp]:0,u=y?pixels[(y-1)*w*bpp+x]:0,c=y&&x>=bpp?pixels[(y-1)*w*bpp+x-bpp]:0,v=raw[ri++];if(f===1)v+=a;else if(f===2)v+=u;else if(f===3)v+=Math.floor((a+u)/2);else if(f===4){let p=a+u-c,pa=Math.abs(p-a),pb=Math.abs(p-u),pc=Math.abs(p-c);v+=pa<=pb&&pa<=pc?a:pb<=pc?u:c;}pixels[y*w*bpp+x]=v&255;}}
 const rows=name==='air_1.png'?2:4;let results=[];for(let row=0;row<rows;row++){const counts=[];for(let x=0;x<w;x++){let n=0;for(let y=Math.floor(row*h/rows);y<Math.floor((row+1)*h/rows);y++){let q=(y*w+x)*bpp;if((bpp===4?pixels[q+3]:255)>80)n++;}counts.push(n);}let gaps=[];let start=-1;for(let x=0;x<=w;x++){if(x<w&&counts[x]<=1){if(start<0)start=x;}else if(start>=0){if(x-start>=2)gaps.push([start,x]);start=-1;}}results.push(gaps);}
 console.log(name,w,h,type,JSON.stringify(results));
}
