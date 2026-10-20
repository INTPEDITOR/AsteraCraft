// Technical atlas packing only; all paintings are existing approved art or ImageGen outputs.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const sharp=require('C:/Users/Admin/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'..'),source=path.join(root,'build/portrait-sources'),W=256,H=320;
async function cell(file,col,row,rows=null){const meta=await sharp(file).metadata();let xs=[0,Math.round(meta.width/4),Math.round(meta.width/2),Math.round(meta.width*3/4),meta.width];let ys=rows||[0,Math.round(meta.height/4),Math.round(meta.height/2),Math.round(meta.height*3/4),meta.height];return sharp(file).extract({left:xs[col]+2,top:ys[row]+2,width:xs[col+1]-xs[col]-4,height:ys[row+1]-ys[row]-4}).resize(W,H,{fit:'cover',position:'centre'}).png().toBuffer();}
(async()=>{let report=[];
 for(let r=0;r<3;r++){
  let pieces=[];
  for(let k=0;k<16;k++){
   let input,description;
   if(r===0&&k>=13){let key=['flamer','carrier','drone'][k-13];input=await sharp(path.join(source,'portrait-'+key+'.png')).resize(W,H,{fit:'cover',position:'centre'}).png().toBuffer();description=key+' individual painting';}
   else if(r===2&&k===13){input=await sharp(path.join(source,'portrait-chaser.png')).resize(W,H,{fit:'cover',position:'centre'}).png().toBuffer();description='chaser individual painting';}
   else if(r===0&&k<12){input=await cell(path.join(source,'portrait-hyrax-repaint.png'),k%4,Math.floor(k/4),[0,351,700,1028,1402]);description='reviewed individual rectangle from hyrax repaint';}
   else if(r===1){input=await cell(path.join(source,'portrait-citrus-repaint.png'),k%4,Math.floor(k/4));description='citrus framing repair';}
   else{input=await cell(path.join(root,'assets',`portraits_${r}_faces_v059.png`),k%4,Math.floor(k/4));description='original approved faction portrait';}
   const meta=await sharp(input).metadata();if(meta.width!==W||meta.height!==H)throw Error('Nonuniform portrait');
   pieces.push({input,left:(k%4)*W,top:Math.floor(k/4)*H});report.push({race:r,kind:k,rect:[(k%4)*W,Math.floor(k/4)*H,W,H],source:description,sha256:crypto.createHash('sha256').update(input).digest('hex')});
  }
  await sharp({create:{width:W*4,height:H*4,channels:4,background:'#171716'}}).composite(pieces).png().toFile(path.join(root,'assets',`portraits_${r}_faces_v060.png`));
 }
 fs.writeFileSync(path.join(root,'data/portraits_v060.json'),JSON.stringify({schema:1,columns:4,rows:4,cell:[W,H],method:'Individual source rectangles normalized and packed on a fixed pixel grid; no generated layout coordinates used at runtime',portraits:report},null,2)+'\n');
 console.log('PORTRAIT_PACK',report.length,'cells',W,H);
})();
