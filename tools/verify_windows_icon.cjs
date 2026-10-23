const fs=require('node:fs'),crypto=require('node:crypto');
const b=fs.readFileSync(process.argv[2]),ico=fs.readFileSync(process.argv[3]);
const pe=b.readUInt32LE(60),opt=pe+24,n=b.readUInt16LE(pe+6),os=b.readUInt16LE(pe+20),dir=opt+(b.readUInt16LE(opt)===0x20b?112:96),rva=b.readUInt32LE(dir+16);
const sections=[];for(let i=0;i<n;i++){const s=opt+os+i*40;sections.push({rva:b.readUInt32LE(s+12),size:Math.max(b.readUInt32LE(s+8),b.readUInt32LE(s+16)),file:b.readUInt32LE(s+20)});}
function at(v){const s=sections.find(x=>v>=x.rva&&v<x.rva+x.size);if(!s)throw Error('Invalid PE resource address');return s.file+v-s.rva;}
const base=at(rva),resources=[];
function walk(off,keys=[]){const p=base+off,count=b.readUInt16LE(p+12)+b.readUInt16LE(p+14);for(let i=0;i<count;i++){const q=p+16+i*8,k=b.readUInt32LE(q),v=b.readUInt32LE(q+4),ks=keys.concat(k);if(v>>>31)walk(v&0x7fffffff,ks);else if([3,14].includes(ks[0])){const d=base+v,len=b.readUInt32LE(d+4),start=at(b.readUInt32LE(d));resources.push({keys:ks,data:b.subarray(start,start+len)});}}}walk(0);
const count=ico.readUInt16LE(4),sizes=[];
for(let i=0;i<count;i++){const p=6+i*16,length=ico.readUInt32LE(p+8),offset=ico.readUInt32LE(p+12),expected=ico.subarray(offset,offset+length),size=ico[p]||256;sizes.push(size);if(!resources.some(r=>r.keys[0]===3&&r.data.equals(expected)))throw Error('Missing or incorrect '+size+'px icon pixels');}
const groups=resources.filter(r=>r.keys[0]===14);
if(!groups.length||groups.some(g=>g.data.readUInt16LE(4)!==count))throw Error('Icon group count does not match original ICO');
for(const group of groups)for(let i=0;i<count;i++){const id=group.data.readUInt16LE(6+i*14+12);if(!resources.some(r=>r.keys[0]===3&&r.keys[1]===id))throw Error('Icon group references missing pixels');}
console.log(JSON.stringify({passed:true,resolutions:sizes,icon_groups:groups.length,source_sha256:crypto.createHash('sha256').update(ico).digest('hex')}));
