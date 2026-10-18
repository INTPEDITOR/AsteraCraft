const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),cat=JSON.parse(fs.readFileSync(path.join(root,'data/voices_v05.json'))),rate=24000;
const {processVoice}=require('./voice_faction_dsp.cjs');
const out=path.join(root,'assets/voices');fs.mkdirSync(out,{recursive:true});
function readWav(file){const b=fs.readFileSync(file);let sr,channels,bits,data,format;for(let p=12;p+8<=b.length;){const id=b.toString('ascii',p,p+4),n=b.readUInt32LE(p+4);if(id==='fmt '){format=b.readUInt16LE(p+8);channels=b.readUInt16LE(p+10);sr=b.readUInt32LE(p+12);bits=b.readUInt16LE(p+22)}if(id==='data')data=b.subarray(p+8,p+8+n);p+=8+n+(n%2)}if(format!==1||bits!==16||!data)throw Error('Unsupported WAV '+file);const x=new Float32Array(data.length/2/channels);for(let i=0;i<x.length;i++)for(let c=0;c<channels;c++)x[i]+=data.readInt16LE((i*channels+c)*2)/32768/channels;return{x,sr}}
function writeWav(file,x){let peak=0;for(const v of x)peak=Math.max(peak,Math.abs(v));if(peak<.0001)throw Error('Silent '+file);const gain=.79/peak,b=Buffer.alloc(44+x.length*2);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(x.length*2,40);for(let i=0;i<x.length;i++)b.writeInt16LE(Math.round(Math.max(-1,Math.min(1,x[i]*gain))*32767),44+i*2);fs.writeFileSync(file,b)}
function resample(x,sr,pitch){let first=0,last=x.length-1;while(first<last&&Math.abs(x[first])<.009)first++;while(last>first&&Math.abs(x[last])<.009)last--;first=Math.max(0,first-Math.round(sr*.035));last=Math.min(x.length-1,last+sr*.06);const step=sr/rate*pitch,y=new Float32Array(Math.ceil((last-first)/step)+rate*.07);for(let i=0;i<y.length;i++){const p=first+i*step,j=Math.floor(p);if(j>=last)break;y[i]=x[j]*(1-(p-j))+x[j+1]*(p-j)}return y}
// Waveform similarity overlap-add: recover articulation speed independently
// of the character's pitch. Low voices must not take twice as long to speak.
function tempo(x,speed){
 const hop=240,win=480,search=180,n=Math.max(win,Math.round(x.length/speed)),y=new Float32Array(n+win),weight=new Float32Array(n+win);
 let previous=0;
 for(let dst=0;dst<n;dst+=hop){
  const expected=Math.round(dst*speed);let best=Math.min(expected,Math.max(0,x.length-win));
  if(dst>0){let score=-Infinity;const ref=previous+hop;
   for(let src=Math.max(0,best-search);src<=Math.min(x.length-win,best+search);src+=4){let dot=0,a=0,b=0;
    for(let j=0;j<hop;j+=4){const u=x[ref+j]||0,v=x[src+j]||0;dot+=u*v;a+=u*u;b+=v*v}
    const value=dot/Math.sqrt(a*b+1e-12)-Math.abs(src-expected)*.00002;if(value>score){score=value;best=src}
   }
  }
  for(let j=0;j<win&&dst+j<y.length;j++){const w=.5-.5*Math.cos(2*Math.PI*j/(win-1));y[dst+j]+=(x[best+j]||0)*w;weight[dst+j]+=w}
  previous=best;
 }
 for(let i=0;i<y.length;i++)if(weight[i]>.001)y[i]/=weight[i];
 return y.subarray(0,n);
}
let seed=1749;function noise(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2147483648-1}
function roar(c){seed=1000+c.kind*111+(c.special?900:0)+Number(c.id.slice(-1))*37;const n=Number(c.id.slice(-1)),duration=(c.special?1.6:1.0)+n*.12+(c.kind===12?.5:0),x=new Float32Array(Math.ceil(duration*rate));let phase=0,low=0;const base=(72+c.kind*5)*c.pitch;for(let i=0;i<x.length;i++){const t=i/rate,u=t/duration,env=Math.pow(Math.sin(Math.PI*u),.7)*(.6+.4*Math.pow(Math.sin(t*(7+n)*Math.PI),2)),freq=base*(1+.18*Math.sin(t*(3+n))+ .3*(1-u));phase+=freq/rate*2*Math.PI;low+=.15*(noise()-low);const rasp=Math.sin(phase+2.4*Math.sin(phase*.5))*.4+Math.sin(phase*2.01)*.15+low*.9;const circuit=.08*Math.sin(phase*5.7)*(Math.sin(t*49)>0?1:.4);x[i]=(rasp+circuit)*env;}return x}
const report=[];
for(const c of cat.clips){let y;if(c.type==='roar')y=roar(c);else{const src=readWav(path.join(root,'build/voice-raw',c.id+'.wav'));y=tempo(resample(src.x,src.sr,c.pitch),1.15/c.pitch);}y=processVoice(y,c);for(let i=0;i<Math.min(160,y.length/2);i++){y[i]*=i/160;y[y.length-1-i]*=i/160}writeWav(path.join(out,c.id+'.wav'),y);report.push({id:c.id,seconds:y.length/rate,type:c.type,effect:["radio","hive","telepathy"][c.race],announcer:!!c.announcer});}
fs.writeFileSync(path.join(root,'build/voice-render-report.json'),JSON.stringify(report,null,2));console.log(`Rendered ${report.length} normalized mono PCM WAV clips`);

fs.writeFileSync(path.join(root,"data/voice_effects_v058.json"),JSON.stringify({revision:"faction-radio-hive-telepathy-v1",profiles:["radio","hive","telepathy"],clips:report},null,2)+"\n");
