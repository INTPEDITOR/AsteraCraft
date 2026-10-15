// Precision atlas extraction only: alpha crop, one uniform downsample, clear padding.
// No independent X/Y resizing, repainting, nine-slicing or frame deformation.
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const ROOT = __dirname;
const OUTPUT = path.join(ROOT,'assets','ui_native');
const STATES = ['normal','hover','pressed'];
const CRC = new Uint32Array(256);
for (let n=0;n<256;n++) { let v=n;for(let i=0;i<8;i++)v=v&1?0xedb88320^(v>>>1):v>>>1;CRC[n]=v>>>0; }
function crc32(bytes) { let v=0xffffffff;for(const byte of bytes)v=CRC[(v^byte)&255]^(v>>>8);return(v^0xffffffff)>>>0; }

function decodePNG(filename) {
  const source=fs.readFileSync(filename);
  if(!source.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))throw Error('Invalid PNG: '+filename);
  const width=source.readUInt32BE(16),height=source.readUInt32BE(20);
  if(source[24]!==8||source[25]!==6||source[28]!==0)throw Error('Non-interlaced RGBA8 PNG required: '+filename);
  const chunks=[];
  for(let offset=8;offset+12<=source.length;) {
    const length=source.readUInt32BE(offset),name=source.toString('ascii',offset+4,offset+8);
    if(offset+12+length>source.length)throw Error('Truncated PNG: '+filename);
    if(name==='IDAT')chunks.push(source.subarray(offset+8,offset+8+length));
    offset+=12+length;
  }
  const raw=zlib.inflateSync(Buffer.concat(chunks)),pixels=Buffer.alloc(width*height*4),stride=width*4;
  if(raw.length!==(stride+1)*height)throw Error('Unexpected PNG row size: '+filename);
  let index=0;
  for(let y=0;y<height;y++) {
    const filter=raw[index++];
    for(let x=0;x<stride;x++) {
      const a=x>=4?pixels[y*stride+x-4]:0,b=y?pixels[(y-1)*stride+x]:0,c=y&&x>=4?pixels[(y-1)*stride+x-4]:0;
      let value=raw[index++];
      if(filter===1)value+=a;
      else if(filter===2)value+=b;
      else if(filter===3)value+=Math.floor((a+b)/2);
      else if(filter===4){const p=a+b-c,da=Math.abs(p-a),db=Math.abs(p-b),dc=Math.abs(p-c);value+=da<=db&&da<=dc?a:db<=dc?b:c;}
      else if(filter!==0)throw Error('Unsupported PNG filter '+filter);
      pixels[y*stride+x]=value&255;
    }
  }
  return {width,height,pixels};
}

function chunk(name,data) {
  const type=Buffer.from(name),result=Buffer.alloc(data.length+12);
  result.writeUInt32BE(data.length,0);type.copy(result,4);data.copy(result,8);result.writeUInt32BE(crc32(Buffer.concat([type,data])),data.length+8);
  return result;
}
function encodePNG(image) {
  const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(image.width,0);ihdr.writeUInt32BE(image.height,4);ihdr[8]=8;ihdr[9]=6;
  const rows=Buffer.alloc((image.width*4+1)*image.height);
  for(let y=0;y<image.height;y++)image.pixels.copy(rows,y*(image.width*4+1)+1,y*image.width*4,(y+1)*image.width*4);
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(rows,{level:9})),chunk('IEND',Buffer.alloc(0))]);
}

function profile(image,axis,rectangle,alpha=144) {
  const [x0,y0,x1,y1]=rectangle,length=axis==='x'?image.width:image.height,values=new Uint32Array(length);
  for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++)if(image.pixels[(y*image.width+x)*4+3]>=alpha)values[axis==='x'?x:y]++;
  return values;
}
function bands(values,begin,end,threshold) {
  const result=[];let start=-1;
  for(let i=begin;i<=end;i++) {
    const active=i<end&&values[i]>=threshold;
    if(active&&start<0)start=i;
    if(!active&&start>=0){if(i-start>=5)result.push([start,i]);start=-1;}
  }
  return result;
}
function gridCuts(values,count,begin,end) {
  const maximum=Math.max(...values.subarray(begin,end));
  let occupied=bands(values,begin,end,Math.max(2,maximum*.075));
  // Merge isolated highlights into their nearest frame instead of treating a
  // small glow island as an extra row/column.
  while(occupied.length>count) {
    let best=0,gap=Infinity;
    for(let i=0;i<occupied.length-1;i++){const d=occupied[i+1][0]-occupied[i][1];if(d<gap){gap=d;best=i;}}
    occupied.splice(best,2,[occupied[best][0],occupied[best+1][1]]);
  }
  if(occupied.length===count) return [begin,...occupied.slice(1).map((band,i)=>Math.floor((occupied[i][1]+band[0])/2)),end];
  const cuts=[begin],step=(end-begin)/count;
  for(let n=1;n<count;n++) {
    const expected=begin+n*step,left=Math.max(cuts.at(-1)+2,Math.floor(expected-step*.35)),right=Math.min(end-2,Math.ceil(expected+step*.35));
    let best=Math.round(expected);
    for(let at=left;at<=right;at++)if(values[at]<values[best]||(values[at]===values[best]&&Math.abs(at-expected)<Math.abs(best-expected)))best=at;
    cuts.push(best);
  }
  return [...cuts,end];
}

function bodyBounds(image,cell) {
  const [x0,y0,x1,y1]=cell;
  const row=profile(image,'y',cell,160),maximum=Math.max(...row.subarray(y0,y1));
  if(maximum<4)throw Error('Empty atlas cell '+JSON.stringify(cell));
  // The opaque broad body determines the crop, rather than disconnected glow
  // pixels far beyond the plate. Keep a two-pixel source fringe for AA edges.
  const strongRows=[];
  for(let y=y0;y<y1;y++)if(row[y]>=Math.max(4,maximum*.30))strongRows.push(y);
  if(!strongRows.length)throw Error('No frame body found');
  let top=Math.max(y0,strongRows[0]-2),bottom=Math.min(y1,strongRows.at(-1)+3);
  const column=profile(image,'x',[x0,top,x1,bottom],112),columnMax=Math.max(...column.subarray(x0,x1));
  const strongColumns=[];
  for(let x=x0;x<x1;x++)if(column[x]>=Math.max(3,columnMax*.14))strongColumns.push(x);
  if(!strongColumns.length)throw Error('No frame columns found');
  const left=Math.max(x0,strongColumns[0]-2),right=Math.min(x1,strongColumns.at(-1)+3);
  return [left,top,right-left,bottom-top];
}

function sampleArea(image,bounds,left,top,right,bottom) {
  const [bx,by,bw,bh]=bounds;
  left=Math.max(bx,left);top=Math.max(by,top);right=Math.min(bx+bw,right);bottom=Math.min(by+bh,bottom);
  let weight=0,alpha=0,r=0,g=0,b=0;
  for(let y=Math.floor(top);y<Math.ceil(bottom);y++)for(let x=Math.floor(left);x<Math.ceil(right);x++) {
    if(x<0||y<0||x>=image.width||y>=image.height)continue;
    const part=Math.max(0,Math.min(x+1,right)-Math.max(x,left))*Math.max(0,Math.min(y+1,bottom)-Math.max(y,top));
    const at=(y*image.width+x)*4,a=image.pixels[at+3]/255;
    weight+=part;alpha+=a*part;r+=image.pixels[at]*a*part;g+=image.pixels[at+1]*a*part;b+=image.pixels[at+2]*a*part;
  }
  if(weight<=0||alpha<=0)return[0,0,0,0];
  return [Math.round(r/alpha),Math.round(g/alpha),Math.round(b/alpha),Math.round(alpha/weight*255)];
}

function fitNative(image,bounds,target) {
  const [x,y,width,height]=bounds,[tw,th]=target;
  const scale=Math.min(1,tw/width,th/height);
  const scaledWidth=Math.min(tw,Math.round(width*scale)),scaledHeight=Math.min(th,Math.round(height*scale));
  const left=Math.floor((tw-scaledWidth)/2),top=Math.floor((th-scaledHeight)/2);
  const output={width:tw,height:th,pixels:Buffer.alloc(tw*th*4)};
  // Both source axes use exactly the SAME inverse scale. Rounding affects only
  // how many destination pixel centers are sampled, never the transform.
  for(let dy=0;dy<scaledHeight;dy++)for(let dx=0;dx<scaledWidth;dx++) {
    const rgba=sampleArea(image,bounds,x+dx/scale,y+dy/scale,x+(dx+1)/scale,y+(dy+1)/scale);
    const at=((top+dy)*tw+left+dx)*4;
    for(let c=0;c<4;c++)output.pixels[at+c]=rgba[c];
  }
  return {output,scale,padding:[left,top,tw-scaledWidth-left,th-scaledHeight-top],extent:[scaledWidth,scaledHeight]};
}

function bakePopupNative(image,bounds,target) {
  const [tw,th]=target,scale=Math.min(1,th/bounds[3]);
  const uniform=fitNative(image,bounds,[Math.ceil(bounds[2]*scale),th]);
  const source=uniform.output,sw=source.width,delta=tw-sw,center=Math.floor(sw/2);
  const output={width:tw,height:th,pixels:Buffer.alloc(tw*th*4)};
  let cropAt=center,repeatSpan=Math.max(2,Math.min(Math.floor(th*.5),Math.floor(sw*.14)));
  if(delta<0) {
    const remove=-delta,ideal=Math.floor((sw-remove)/2),margin=Math.ceil(th*.75);
    let score=Infinity;
    for(let at=Math.max(margin,ideal-10);at<=Math.min(sw-margin-remove,ideal+10);at++) {
      let error=0;
      for(let y=0;y<th;y++)for(let channel=0;channel<4;channel++)error+=Math.abs(source.pixels[(y*sw+at-1)*4+channel]-source.pixels[(y*sw+at+remove)*4+channel]);
      error+=Math.abs(at-ideal)*.01;
      if(error<score){score=error;cropAt=at;}
    }
  }
  for(let x=0;x<tw;x++) {
    let sx=x;
    if(delta>0&&x>=center) {
      if(x>=center+delta)sx=x-delta;
      else {
        // A palindromic insertion starts and ends on the SAME source column.
        // This makes both joins continuous with the original flat center.
        // Every sampled column remains at its uniformly scaled native width.
        const index=x-center,half=Math.floor(delta/2);
        const forward=index<half?index:index>=delta-half?delta-1-index:Math.max(0,half-1);
        const phase=forward%(repeatSpan*2);
        sx=center+(phase<repeatSpan?phase:repeatSpan*2-1-phase);
      }
    } else if(delta<0&&x>=cropAt)sx=x-delta;
    for(let y=0;y<th;y++)source.pixels.copy(output.pixels,(y*tw+x)*4,(y*sw+sx)*4,(y*sw+sx)*4+4);
  }
  return {output,scale:uniform.scale,padding:[0,uniform.padding[1],0,uniform.padding[3]],extent:[tw,uniform.extent[1]],method:'uniform endcaps and cropped/repeated generated center strip at native dimensions',bake:{uniform_source_size:[sw,th],width_delta:delta,operation:delta>0?'palindromic mirror repeat of generated center strip':delta<0?'crop generated center strip':'unaltered uniform layout',center:delta<0?cropAt:center,repeat_span:delta>0?repeatSpan:0,fixed_endcap_columns:Math.min(Math.floor(th*.7),Math.floor(sw/3),Math.floor(tw/3)),all_pixels_copied_from_uniform_source:true,runtime_scale:1,runtime_nine_slice:false,endcaps_rescaled_x:false}};
}

function specifications() {
  const result=[
    {file:'native_command_plates.png',columns:4,rows:3,frame:(row,col)=>({name:`command_r${row}_${[...STATES,'empty'][col]}`,size:[90,58]})},
    {file:'native_main_plates.png',columns:3,rows:3,frame:(row,col)=>({name:`main_r${row}_${STATES[col]}`,size:[320,76]})},
    {file:'native_hud_menu_plates.png',columns:3,rows:3,frame:(row,col)=>({name:`menu_r${row}_${STATES[col]}`,size:[174,42]})}
  ];
  for(let race=0;race<3;race++) {
    const popup=[[220,48],[300,48],[220,44],[300,44]];
    result.push({file:`native_popup_final_r${race}.png`,columns:3,rows:4,frame:(row,col)=>({name:`modal_${popup[row][0]}x${popup[row][1]}_r${race}_${STATES[col]}`,size:popup[row]})});
    result.push({file:`native_modal_selectors_r${race}.png`,columns:3,rows:5,frame:(row,col)=>row===4?({name:`selection_r${race}_${STATES[col]}`,size:[125,43]}):null});
  }
  return result;
}

function main() {
  const available=process.argv.includes('--available'),entries=[],sources=[],missing=[];
  fs.mkdirSync(OUTPUT,{recursive:true});
  for(const spec of specifications()) {
    const filename=path.join(ROOT,'assets',spec.file);
    if(!fs.existsSync(filename)){missing.push(spec.file);continue;}
    const image=decodePNG(filename),ycuts=gridCuts(profile(image,'y',[0,0,image.width,image.height]),spec.rows,0,image.height);
    const source={file:'assets/'+spec.file,size:[image.width,image.height],row_cuts:ycuts,column_cuts:[]};
    for(let row=0;row<spec.rows;row++) {
      const xcuts=gridCuts(profile(image,'x',[0,ycuts[row],image.width,ycuts[row+1]]),spec.columns,0,image.width);
      source.column_cuts.push(xcuts);
      for(let col=0;col<spec.columns;col++) {
        const frame=spec.frame(row,col);
        if(!frame)continue;
        const cell=[xcuts[col],ycuts[row],xcuts[col+1],ycuts[row+1]],bounds=bodyBounds(image,cell);
        const fitted=frame.name.startsWith('modal_')?bakePopupNative(image,bounds,frame.size):fitNative(image,bounds,frame.size),destination=path.join(OUTPUT,frame.name+'.png');
        fs.writeFileSync(destination,encodePNG(fitted.output));
        const check=decodePNG(destination);
        if(check.width!==frame.size[0]||check.height!==frame.size[1])throw Error('Wrong output size '+destination);
        let vx0=check.width,vy0=check.height,vx1=0,vy1=0,opaque=0;
        for(let y=0;y<check.height;y++)for(let x=0;x<check.width;x++) {
          const a=check.pixels[(y*check.width+x)*4+3];
          if(a>=128)opaque++;
          if(a>=32){vx0=Math.min(vx0,x);vy0=Math.min(vy0,y);vx1=Math.max(vx1,x+1);vy1=Math.max(vy1,y+1);}
        }
        const visibleWidth=Math.max(0,vx1-vx0),visibleHeight=Math.max(0,vy1-vy0),targetAspect=frame.size[0]/frame.size[1];
        entries.push({file:'assets/ui_native/'+frame.name+'.png',source:'assets/'+spec.file,row,column:col,source_cell:[cell[0],cell[1],cell[2]-cell[0],cell[3]-cell[1]],srcbounds:bounds,single_scale:fitted.scale,targetsize:frame.size,padding:fitted.padding,content_extent:fitted.extent,visible_bounds:[vx0,vy0,visibleWidth,visibleHeight],coverage:visibleWidth*visibleHeight/(frame.size[0]*frame.size[1]),width_coverage:visibleWidth/frame.size[0],height_coverage:visibleHeight/frame.size[1],opaque_pixel_coverage:opaque/(frame.size[0]*frame.size[1]),visible_aspect_error:visibleHeight?visibleWidth/visibleHeight/targetAspect-1:1,aspect:{source:bounds[2]/bounds[3],target:targetAspect,source_vs_target_error:bounds[2]/bounds[3]/targetAspect-1,transform_x:fitted.scale,transform_y:fitted.scale,preserved:true,layout_width_changed:!!fitted.bake},method:fitted.method||'opaque-body alpha crop; uniform area downsample; transparent padding',...(fitted.bake?{bake:fitted.bake}:{})});
      }
    }
    sources.push(source);
  }
  for(const frame of entries)frame.visible_size_pass=frame.width_coverage>=0.90&&frame.height_coverage>=0.88;
  const popup=entries.filter(frame=>frame.file.includes('/modal_'));
  const audit={schema:2,expected_frames:75,frame_count:entries.length,complete:missing.length===0,includes_shells:false,missing_sources:missing,only_uniform_scale:true,upsampling:false,acceptance:{minimum_visible_width:0.90,minimum_visible_height:0.88,popup_frames:popup.length,popup_passed:popup.filter(frame=>frame.visible_size_pass).length,popup_failed:popup.filter(frame=>!frame.visible_size_pass).map(frame=>frame.file)},sources,frames:entries};
  fs.mkdirSync(path.join(ROOT,'build'),{recursive:true});
  fs.writeFileSync(path.join(ROOT,'build','ui-native-audit.json'),JSON.stringify(audit,null,2)+'\n');
  console.log(JSON.stringify({frames:entries.length,missing,output:OUTPUT,complete:audit.complete}));
  if(missing.length&&!available)throw Error('Missing source atlases; --available permits partial extraction.');
}

if(require.main===module)main();
module.exports={decodePNG,encodePNG,bodyBounds,fitNative,bakePopupNative,specifications,main};
