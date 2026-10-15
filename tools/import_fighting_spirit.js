'use strict';
// Local-files-only map converter; no network access, no third-party packages.
// Usage: node tools/import_fighting_spirit.js map.scx jungle.cv5 jungle.vf4 output.json
// Bare scenario.chk is accepted too. The conversion preserves the original
// source masks and coordinates; it DOES NOT certify AsteraCraft's unit pathing
// and economy as identical to Brood War.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const assert = require('node:assert/strict');

const cryptTable = new Uint32Array(0x500);
let cryptSeed = 0x100001;
for (let column = 0; column < 256; column++) for (let row = 0; row < 5; row++) {
  cryptSeed = (cryptSeed * 125 + 3) % 0x2aaaab;
  const high = (cryptSeed & 65535) << 16;
  cryptSeed = (cryptSeed * 125 + 3) % 0x2aaaab;
  cryptTable[column + row * 256] = (high | (cryptSeed & 65535)) >>> 0;
}
function mpqHash(name, type) {
  let a = 0x7fed7fed, b = 0xeeeeeeee;
  for (const character of name.toUpperCase()) {
    const value = character.charCodeAt(0);
    a = (cryptTable[type * 256 + value] ^ ((a + b) >>> 0)) >>> 0;
    b = (value + a + b + ((b << 5) >>> 0) + 3) >>> 0;
  }
  return a;
}
function cryptWords(source, key, encrypt = false) {
  const result = Buffer.from(source);
  let state = 0xeeeeeeee;
  for (let offset = 0; offset + 4 <= result.length; offset += 4) {
    state = (state + cryptTable[0x400 + (key & 255)]) >>> 0;
    const input = source.readUInt32LE(offset);
    const output = (input ^ ((key + state) >>> 0)) >>> 0;
    result.writeUInt32LE(output, offset);
    key = ((((~key << 21) >>> 0) + 0x11111111) | (key >>> 11)) >>> 0;
    state = ((encrypt ? input : output) + state + ((state << 5) >>> 0) + 3) >>> 0;
  }
  return result;
}

// PKWARE DCL stream decoding. Protocol constants and canonical-code ordering
// were checked against Mark Adler's blast.c (zlib/contrib/blast, version 1.3).
// This is an independent JavaScript implementation, not copied C source.
function explode(input, limit = 32 * 1024 * 1024) {
  let cursor = 0, bits = 0, available = 0;
  const read = count => {
    while (available < count) {
      if (cursor >= input.length) throw Error('Truncated PKWARE stream');
      bits |= input[cursor++] << available;
      available += 8;
    }
    const value = bits & ((1 << count) - 1);
    bits >>>= count; available -= count;
    return value;
  };
  const table = runs => {
    const lengths = runs.flatMap(value => Array((value >> 4) + 1).fill(value & 15));
    const counts = Array(14).fill(0);
    for (const length of lengths) counts[length]++;
    const symbols = lengths.map((length, symbol) => ({length,symbol})).filter(item=>item.length).sort((a,b)=>a.length-b.length || a.symbol-b.symbol).map(item=>item.symbol);
    return {counts,symbols};
  };
  const decode = tree => {
    let code = 0, first = 0, index = 0;
    for (let length = 1; length <= 13; length++) {
      code |= read(1) ^ 1;
      const count = tree.counts[length];
      if (code < first + count) return tree.symbols[index + code - first];
      index += count; first = (first + count) << 1; code <<= 1;
    }
    throw Error('Invalid PKWARE Huffman code');
  };
  const literalTree = table([11,124,8,7,28,7,188,13,76,4,10,8,12,10,12,10,8,23,8,9,7,6,7,8,7,6,55,8,23,24,12,11,7,9,11,12,6,7,22,5,7,24,6,11,9,6,7,22,7,11,38,7,9,8,25,11,8,11,9,12,8,12,5,38,5,38,5,11,7,5,6,21,6,10,53,8,7,24,10,27,44,253,253,253,252,252,252,13,12,45,12,45,12,61,12,45,44,173]);
  const lengthTree = table([2,35,36,53,38,23]);
  const distanceTree = table([2,20,53,230,247,151,248]);
  const base = [3,2,4,5,6,7,8,9,10,12,16,24,40,72,136,264];
  const extra = [0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8];
  const codedLiterals = read(8), dictionary = read(8), output = [];
  if (codedLiterals > 1 || dictionary < 4 || dictionary > 6) throw Error('Invalid PKWARE header');
  while (true) {
    if (read(1)) {
      const symbol = decode(lengthTree), length = base[symbol] + read(extra[symbol]);
      if (length === 519) break;
      const shift = length === 2 ? 2 : dictionary;
      const distance = (decode(distanceTree) << shift) + read(shift) + 1;
      if (distance > output.length) throw Error('Invalid PKWARE distance');
      for (let copy = 0; copy < length; copy++) output.push(output[output.length-distance]);
    } else output.push(codedLiterals ? decode(literalTree) : read(8));
    if (output.length > limit) throw Error('PKWARE output limit exceeded');
  }
  return Buffer.from(output);
}
function decompressSector(bytes, expected, flags) {
  if (bytes.length === expected) return bytes;
  if (flags & 0x200) {
    const mask = bytes[0];
    if (mask === 2) return zlib.inflateSync(bytes.subarray(1));
    if (mask === 8) return explode(bytes.subarray(1),expected);
    throw Error(`Unsupported MPQ compression mask 0x${mask.toString(16)}`);
  }
  if (flags & 0x100) return explode(bytes,expected);
  throw Error('Unexpected compressed MPQ member');
}
function extractMPQ(archive, filename = 'staredit\\scenario.chk') {
  const start = archive.indexOf(Buffer.from([0x4d,0x50,0x51,0x1a]));
  if (start < 0) throw Error('MPQ header not found');
  const header = archive.subarray(start);
  if (header.readUInt16LE(12) !== 0) throw Error('Only MPQ version 0 is supported');
  const hashOffset = header.readUInt32LE(16), blockOffset = header.readUInt32LE(20);
  const hashCount = header.readUInt32LE(24), blockCount = header.readUInt32LE(28);
  if (hashCount > 1048576 || blockCount > 1048576) throw Error('Invalid MPQ table size');
  const hashes = cryptWords(header.subarray(hashOffset,hashOffset+hashCount*16),mpqHash('(hash table)',3));
  const blocks = cryptWords(header.subarray(blockOffset,blockOffset+blockCount*16),mpqHash('(block table)',3));
  let block = -1;
  for (let i=0;i<hashCount;i++) if (hashes.readUInt32LE(i*16)===mpqHash(filename,1) && hashes.readUInt32LE(i*16+4)===mpqHash(filename,2)) {block=hashes.readUInt32LE(i*16+12);break;}
  if (block<0 || block>=blockCount) throw Error(`MPQ member not found: ${filename}`);
  const at=block*16, offset=blocks.readUInt32LE(at), compressedSize=blocks.readUInt32LE(at+4), size=blocks.readUInt32LE(at+8), flags=blocks.readUInt32LE(at+12);
  if (size > 32*1024*1024) throw Error('Scenario exceeds 32 MiB limit');
  const bytes=header.subarray(offset,offset+compressedSize);
  let key=mpqHash(filename.split('\\').at(-1),3);
  if(flags&0x20000)key=((key+offset)^size)>>>0;
  if(flags&0x1000000) return decompressSector(flags&0x10000?cryptWords(bytes,key):bytes,size,flags);
  const sectorSize=512<<header.readUInt16LE(14), sectorCount=Math.ceil(size/sectorSize), sectors=[];
  if(!(flags&0x300)) return flags&0x10000?cryptWords(bytes,key):bytes;
  const tableSize=(sectorCount+1+((flags&0x4000000)?1:0))*4;
  const offsets=flags&0x10000?cryptWords(bytes.subarray(0,tableSize),(key-1)>>>0):bytes.subarray(0,tableSize);
  for(let i=0;i<sectorCount;i++){
    const begin=offsets.readUInt32LE(i*4),end=offsets.readUInt32LE(i*4+4);
    if(begin>end || end>bytes.length)throw Error('Invalid MPQ sector offsets');
    let data=bytes.subarray(begin,end);
    if(flags&0x10000)data=cryptWords(data,(key+i)>>>0);
    const expected=Math.min(sectorSize,size-i*sectorSize);
    const sector=decompressSector(data,expected,flags);
    if(sector.length!==expected)throw Error('MPQ sector size mismatch');
    sectors.push(sector);
  }
  return Buffer.concat(sectors,size);
}
function readCHK(bytes) {
  const sections=new Map();
  for(let offset=0;offset+8<=bytes.length;){
    const name=bytes.toString('ascii',offset,offset+4), length=bytes.readInt32LE(offset+4);
    if(length<0 || offset+8+length>bytes.length)throw Error(`Unsupported malformed/protected CHK section ${name}`);
    if(!sections.has(name))sections.set(name,[]);
    sections.get(name).push(bytes.subarray(offset+8,offset+8+length));
    offset+=8+length;
  }
  const dimension=sections.get('DIM ')?.at(-1);
  if(!dimension || dimension.length<4)throw Error('Missing CHK dimensions');
  const width=dimension.readUInt16LE(0),height=dimension.readUInt16LE(2);
  if(width!==128 || height!==128)throw Error('Fighting Spirit import requires 128×128');
  const tiles=Buffer.alloc(width*height*2);
  for(const copy of sections.get('MTXM')??[])copy.copy(tiles,0,0,tiles.length);
  const starts=[],resources=[];
  for(const units of sections.get('UNIT')??[])for(let at=0;at+36<=units.length;at+=36){
    const type=units.readUInt16LE(at+8),pos=[units.readUInt16LE(at+4)/32,units.readUInt16LE(at+6)/32];
    if(type===214)starts.push({owner:units[at+16],pos});
    else if([176,177,178,188].includes(type))resources.push({pos,type:type===188?'tera':'as',amount:units.readUInt16LE(at+14)&0x10?units.readUInt32LE(at+20):(type===188?5000:1500),source_unit_type:type});
  }
  starts.sort((a,b)=>a.owner-b.owner);
  return {width,height,tiles,starts:starts.map(start=>start.pos),resources,tileset:(sections.get('ERA ')?.at(-1)?.readUInt16LE(0)??0)&7};
}
function convert(chk, cv5, vf4) {
  const map=readCHK(chk), terrainRows=[],heightRows=[],buildableRows=[],fineRows=Array.from({length:512},()=>Array(512).fill('0'));
  for(let y=0;y<128;y++){
    let terrain='',heights='',buildable='';
    for(let x=0;x<128;x++){
      const tile=map.tiles.readUInt16LE((y*128+x)*2),group=(tile>>>4)*52;
      if(group+52>cv5.length)throw Error(`Missing CV5 group ${tile>>>4}`);
      const mega=cv5.readUInt16LE(group+20+(tile&15)*2), flags=cv5.readUInt16LE(group+2);
      if(mega*32+32>vf4.length)throw Error(`Missing VF4 megatile ${mega}`);
      let walk=0,maxHeight=0;
      for(let mini=0;mini<16;mini++){
        const bits=vf4.readUInt16LE(mega*32+mini*2),passable=!!(bits&1);
        fineRows[y*4+(mini>>>2)][x*4+(mini&3)]=passable?'1':'0';
        walk+=Number(passable);maxHeight=Math.max(maxHeight,bits&4?2:(bits&2?1:0));
      }
      terrain+=walk?'0':'1';heights+=String(maxHeight);buildable+=(flags&0x80)||walk!==16?'0':'1';
    }
    terrainRows.push(terrain);heightRows.push(heights);buildableRows.push(buildable);
  }
  return {schema:2,name:'황철 분지',reference:'Fighting Spirit source import',source_status:'original_chk_import',exact_source:true,collision_verified_against_original:false,note:'Original positions and 8px VF4 mask preserved. Runtime uses coarse 32px navigation until fine_walk_rows integration and unit-footprint checks are implemented; this is not certification of equivalent gameplay.',size:128,tile_pixels:32,tileset:map.tileset,starts:map.starts,resources:map.resources,terrain_rows:terrainRows,height_rows:heightRows,buildable_rows:buildableRows,fine_walk_rows:fineRows.map(row=>row.join('')),chk_sha256:crypto.createHash('sha256').update(chk).digest('hex'),cv5_sha256:crypto.createHash('sha256').update(cv5).digest('hex'),vf4_sha256:crypto.createHash('sha256').update(vf4).digest('hex')};
}
function selftest(){
  assert.equal(mpqHash('(hash table)',3),0xc3af3770);
  assert.equal(mpqHash('(block table)',3),0xec83b3a3);
  const original=Buffer.from('0123456789abcdef');
  assert.deepEqual(cryptWords(cryptWords(original,123456,true),123456),original);
  assert.equal(explode(Buffer.from('00048224258f807f','hex')).toString(),'AIAIAIAIAIAIA');
  const section=(name,data)=>{const b=Buffer.alloc(8+data.length);b.write(name,0,'ascii');b.writeUInt32LE(data.length,4);data.copy(b,8);return b;};
  const dimension=Buffer.from([128,0,128,0]),unit=Buffer.alloc(36);unit.writeUInt16LE(214,8);unit.writeUInt16LE(320,4);unit.writeUInt16LE(640,6);
  const chk=Buffer.concat([section('DIM ',dimension),section('ERA ',Buffer.from([4,0])),section('MTXM',Buffer.alloc(32768)),section('UNIT',unit)]);
  const cv5=Buffer.alloc(52),vf4=Buffer.alloc(32);for(let i=0;i<16;i++)vf4.writeUInt16LE(1,i*2);
  const converted=convert(chk,cv5,vf4);
  assert.deepEqual(converted.starts,[[10,20]]);assert.equal(converted.fine_walk_rows[0],'1'.repeat(512));assert.equal(converted.terrain_rows[0],'0'.repeat(128));
  // Exercise real archive tables and both common MPQ storage arrangements,
  // including sector-table decryption rather than only cipher round-trips.
  function archiveFixture(single) {
    const member='staredit\\scenario.chk', key=mpqHash('scenario.chk',3);
    const header=Buffer.alloc(32),hashes=Buffer.alloc(16),blocks=Buffer.alloc(16);
    header.writeUInt32LE(0x1a51504d,0);header.writeUInt32LE(32,4);header.writeUInt16LE(3,14);
    header.writeUInt32LE(32,16);header.writeUInt32LE(48,20);header.writeUInt32LE(1,24);header.writeUInt32LE(1,28);
    hashes.writeUInt32LE(mpqHash(member,1),0);hashes.writeUInt32LE(mpqHash(member,2),4);
    let bytes;
    if(single)bytes=cryptWords(Buffer.concat([Buffer.from([2]),zlib.deflateSync(chk)]),key,true);
    else{
      const sectors=[];
      for(let offset=0;offset<chk.length;offset+=4096){
        const original=chk.subarray(offset,offset+4096), compressed=Buffer.concat([Buffer.from([2]),zlib.deflateSync(original)]);
        sectors.push(cryptWords(compressed.length<original.length?compressed:original,(key+sectors.length)>>>0,true));
      }
      const table=Buffer.alloc((sectors.length+1)*4);let offset=table.length;
      table.writeUInt32LE(offset,0);
      sectors.forEach((sector,index)=>{offset+=sector.length;table.writeUInt32LE(offset,(index+1)*4);});
      bytes=Buffer.concat([cryptWords(table,(key-1)>>>0,true),...sectors]);
    }
    blocks.writeUInt32LE(64,0);blocks.writeUInt32LE(bytes.length,4);blocks.writeUInt32LE(chk.length,8);blocks.writeUInt32LE((0x80010200|(single?0x1000000:0))>>>0,12);
    header.writeUInt32LE(64+bytes.length,8);
    return Buffer.concat([header,cryptWords(hashes,mpqHash('(hash table)',3),true),cryptWords(blocks,mpqHash('(block table)',3),true),bytes]);
  }
  assert.deepEqual(extractMPQ(archiveFixture(true)),chk);
  assert.deepEqual(extractMPQ(archiveFixture(false)),chk);
  console.log('IMPORT_MAP_TEST passed: MPQ keys, single/sector encrypted archive extraction, PKWARE known vector, CHK coordinates, 8px mask conversion');
}
if(require.main===module){
  if(process.argv.includes('--selftest'))selftest();
  else{
    const [input,cv5File,vf4File,output]=process.argv.slice(2);
    if(!output)throw Error('Usage: node tools/import_fighting_spirit.js map.scx jungle.cv5 jungle.vf4 output.json');
    const archive=fs.readFileSync(input),chk=path.extname(input).toLowerCase()==='.chk'?archive:extractMPQ(archive);
    const result=convert(chk,fs.readFileSync(cv5File),fs.readFileSync(vf4File));
    result.source_file_sha256=crypto.createHash('sha256').update(archive).digest('hex');
    fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
    console.log(`Imported ${result.starts.length} starts and ${result.resources.length} resources to ${output}. Gameplay equivalence remains unverified.`);
  }
}
module.exports={mpqHash,cryptWords,explode,extractMPQ,readCHK,convert,selftest};
