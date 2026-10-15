const fs=require('fs'),path=require('path'),m=require('./inspect_starcraft_maps.cjs');
const file=path.join(__dirname,'inspect_starcraft_maps.cjs');let source=fs.readFileSync(file,'utf8');
source=source.replace("if(i+8+n>chk.length)throw Error('invalid CHK section '+tag);","if(i+8+n>chk.length){if(sections.MTXM&&sections.UNIT)break;throw Error('invalid CHK section '+tag)}");
fs.writeFileSync(file,source);
