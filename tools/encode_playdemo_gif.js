'use strict';
// Local-only RGB332 GIF encoder. Fixed 9-bit LZW blocks avoid a codec dependency.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib');
const project=path.join(__dirname,'..'),dir=path.join(project,'build',process.argv.includes('--highlights')?'playdemo-highlights':'playdemo-frames');
const output=path.join(project,'build','AsteraCraft-v0.4-gameplay.gif');
const names=fs.readdirSync(dir).filter(n=>/^\d{5}\.png$/.test(n)).sort();
const all=process.argv.includes('--all'),width=480,height=300;
const selected=names.filter(name=>{const second=Number(name.slice(0,5))/5;return all||(second<15)||(second>=30&&second<45)||(second>=60&&second<75)||(second>=95);});
function png(file){
 const b=fs.readFileSync(file),w=b.readUInt32BE(16),h=b.readUInt32BE(20),depth=b[24],type=b[25],bpp=type===6?4:3;
 if(depth!==8||![2,6].includes(type)||b[28]!==0)throw Error('Unsupported PNG '+file);
 let offset=8,parts=[];while(offset<b.length){let n=b.readUInt32BE(offset),kind=b.toString('ascii',offset+4,offset+8);if(kind==='IDAT')parts.push(b.subarray(offset+8,offset+8+n));offset+=n+12;}
 const raw=zlib.inflateSync(Buffer.concat(parts)),pixels=Buffer.alloc(w*h*bpp);let r=0;
 for(let y=0;y<h;y++){const filter=raw[r++];for(let x=0;x<w*bpp;x++){const i=y*w*bpp+x,a=x>=bpp?pixels[i-bpp]:0,u=y?pixels[i-w*bpp]:0,c=y&&x>=bpp?pixels[i-w*bpp-bpp]:0;let v=raw[r++];if(filter===1)v+=a;else if(filter===2)v+=u;else if(filter===3)v+=Math.floor((a+u)/2);else if(filter===4){const p=a+u-c,pa=Math.abs(p-a),pb=Math.abs(p-u),pc=Math.abs(p-c);v+=pa<=pb&&pa<=pc?a:pb<=pc?u:c;}else if(filter!==0)throw Error('Bad PNG filter');pixels[i]=v&255;}}
 const indices=Buffer.alloc(width*height);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){const i=(Math.min(h-1,Math.floor(y*h/height))*w+Math.min(w-1,Math.floor(x*w/width)))*bpp;indices[y*width+x]=(pixels[i]&224)|((pixels[i+1]>>>3)&28)|(pixels[i+2]>>>6);}
 return indices;
}
function lzw(indices){
 let dict=new Map(),next=258,prefix=indices[0],bitBuffer=0,bits=0,bytes=[];
 function code(value){bitBuffer|=value<<bits;bits+=9;while(bits>=8){bytes.push(bitBuffer&255);bitBuffer>>>=8;bits-=8;}}
 code(256);
 for(let i=1;i<indices.length;i++){let value=indices[i],key=(prefix<<8)|value,known=dict.get(key);if(known!==undefined){prefix=known;continue;}code(prefix);dict.set(key,next++);prefix=value;if(next>=510){code(256);dict.clear();next=258;}}
 code(prefix);code(257);if(bits)bytes.push(bitBuffer&255);
 const raw=Buffer.from(bytes),parts=[Buffer.from([8])];for(let i=0;i<raw.length;i+=255){let chunk=raw.subarray(i,i+255);parts.push(Buffer.from([chunk.length]),chunk);}parts.push(Buffer.from([0]));return Buffer.concat(parts);
}
if(!selected.length)throw Error('No rendered PNG frames');
const fd=fs.openSync(output,'w');function write(data){fs.writeSync(fd,data);}
write(Buffer.from('GIF89a'));const screen=Buffer.alloc(7);screen.writeUInt16LE(width,0);screen.writeUInt16LE(height,2);screen[4]=247;write(screen);
const palette=Buffer.alloc(768);for(let i=0;i<256;i++){palette[i*3]=Math.round(((i>>>5)&7)*255/7);palette[i*3+1]=Math.round(((i>>>2)&7)*255/7);palette[i*3+2]=(i&3)*85;}write(palette);
write(Buffer.from([33,255,11,...Buffer.from('NETSCAPE2.0'),3,1,0,0,0]));
for(let index=0;index<selected.length;index++){
 write(Buffer.from([33,249,4,4,20,0,0,0]));
 const image=Buffer.alloc(10);image[0]=44;image.writeUInt16LE(width,5);image.writeUInt16LE(height,7);write(image);write(lzw(png(path.join(dir,selected[index]))));
 if(index%50===0)console.log('GIF_FRAME '+index+'/'+selected.length);
}
write(Buffer.from([59]));fs.closeSync(fd);
console.log(JSON.stringify({path:output,width,height,frames:selected.length,seconds:selected.length/5,source_frame_count:names.length,bytes:fs.statSync(output).size}));
