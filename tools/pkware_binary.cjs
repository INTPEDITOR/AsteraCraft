// PKWARE DCL binary stream decoder, implementing the format documented by
// Mark Adler's blast (zlib/contrib/blast, 2003-2013). No executable map content.
// Only binary literals are needed by these SCM/SCX archives.
function makeTable(repeats){const lengths=[];for(const value of repeats)for(let n=0;n<(value>>4)+1;n++)lengths.push(value&15);const result=new Map();let code=0;for(let size=1;size<=13;size++){for(let symbol=0;symbol<lengths.length;symbol++)if(lengths[symbol]===size){result.set(size+':'+code,symbol);code++}code<<=1}return result}
const lengths=makeTable([2,35,36,53,38,23]),distances=makeTable([2,20,53,230,247,151,248]);
const bases=[3,2,4,5,6,7,8,9,10,12,16,24,40,72,136,264],extra=[0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8];
module.exports=function decode(data,expected){let cursor=0,buffer=0,available=0;function bits(n){while(available<n){if(cursor>=data.length)throw Error('truncated DCL');buffer|=data[cursor++]<<available;available+=8}const value=buffer&((1<<n)-1);buffer>>>=n;available-=n;return value}function symbol(table){let code=0;for(let size=1;size<=13;size++){code=(code<<1)|(bits(1)^1);const value=table.get(size+':'+code);if(value!==undefined)return value}throw Error('invalid DCL code')}
if(bits(8)!==0)throw Error('ASCII DCL not supported');const dictionary=bits(8);if(dictionary<4||dictionary>6)throw Error('invalid DCL dictionary');const out=Buffer.alloc(expected);let at=0;
for(;;){if(!bits(1)){if(at>=expected)throw Error('DCL overflow');out[at++]=bits(8);continue}const code=symbol(lengths),length=bases[code]+bits(extra[code]);if(length===519)break;const width=length===2?2:dictionary,distance=(symbol(distances)<<width)+bits(width)+1;if(distance>at||at+length>expected)throw Error('invalid DCL backreference');for(let i=0;i<length;i++){out[at]=out[at-distance];at++}}
if(at!==expected)throw Error('DCL size mismatch '+at+'/'+expected);return out};
