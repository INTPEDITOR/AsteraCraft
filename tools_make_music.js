// Developer reference only; rejected preview music is excluded from releases.
// Original AsteraCraft scores. Deterministic composition and instrument synthesis;
// no recordings, existing melodies, soundfont samples or third-party music.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const RATE=22050,OUT=path.join(__dirname,'build','dev_music_preview');
fs.mkdirSync(OUT,{recursive:true});
let seed=1;
function rand(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296;}
const noise=()=>rand()*2-1,TAU=Math.PI*2,midi=n=>440*2**((n-69)/12);
const clamp=(v,a,b)=>Math.min(b,Math.max(a,v));
const tracks=[
 {name:'music_r0',bpm:104,key:'D minor',seed:82919,style:0,roots:[38,38,34,34,36,36,33,33],description:'Yellow-steel frontier: doubled electric power riffs, picked bass, acoustic-style drums and analogue keys.'},
 {name:'music_r1',bpm:96,key:'C phrygian',seed:47173,style:1,roots:[36,36,37,37,32,32,31,31],description:'Citrus neural grove: asymmetric organic percussion, distorted bass ostinato, unstable synth and evolving minor harmony.'},
 {name:'music_r2',bpm:112,key:'E minor',seed:59243,style:2,roots:[40,40,36,36,43,43,38,38],description:'Ivory-red covenant: strict rhythmic guitar, synthesized vowel choir, strings, bell keys and rock drums.'},
 {name:'music_menu',bpm:80,key:'B minor',seed:18773,style:3,roots:[35,35,31,31,38,38,33,33],description:'Orbital chronicle: slow cinematic harmonic arc, string and choir-like pads, low pulse, clean guitar and restrained drums.'}
];
function render(def){
 seed=def.seed;
 const beat=60/def.bpm,bars=32,N=Math.round(bars*4*beat*RATE),L=new Float32Array(N),R=new Float32Array(N);
 const add=(index,value,pan=0)=>{let i=index%N;if(i<0)i+=N;L[i]+=value*Math.sqrt((1-pan)*.5);R[i]+=value*Math.sqrt((1+pan)*.5);};
 function instrument(at,duration,pan,fn,gain=1){const start=Math.round(at*RATE),count=Math.ceil(duration*RATE);for(let i=0;i<count;i++)add(start+i,fn(i/RATE,i,count)*gain,pan);}
 function kick(t,gain=1){let phase=0,lp=0;instrument(t,.52,0,(x)=>{let f=43+92*Math.exp(-x*47);phase+=TAU*f/RATE;lp+=.12*(noise()-lp);return(Math.sin(phase)*Math.exp(-x*9.5)+lp*.32*Math.exp(-x*100))*Math.min(1,x*700);},.56*gain);}
 function snare(t,gain=1){let low=0,body=0;instrument(t,.34,.07,x=>{let w=noise();low+=.19*(w-low);body+=TAU*186/RATE;return((w-low)*.61*Math.exp(-x*16)+Math.sin(body)*.31*Math.exp(-x*24)+Math.sin(body*.61)*.12*Math.exp(-x*32))*Math.min(1,x*1000);},.34*gain);}
 function hat(t,open=false,gain=1){let low=0;const length=open?.34:.095;instrument(t,length,.32,x=>{let w=noise();low+=.36*(w-low);let metallic=Math.sin(TAU*6890*x)*Math.sin(TAU*4217*x)*.18;return((w-low)*.78+metallic)*Math.exp(-x*(open?13:53))*Math.min(1,x*1600);},.105*gain);}
 function cymbal(t,gain=1){let low=0;instrument(t,2.1,-.25,x=>{let w=noise();low+=.28*(w-low);return(w-low)*Math.exp(-x*2.8)*Math.min(1,x*350);},.105*gain);}
 function tom(t,note=48,gain=1,pan=-.2){let phase=0;instrument(t,.44,pan,x=>{phase+=TAU*midi(note)*(1+.28*Math.exp(-x*21))/RATE;return(Math.sin(phase)*Math.exp(-x*10)+noise()*.1*Math.exp(-x*55))*Math.min(1,x*900);},.27*gain);}
 function wood(t,note=67,gain=1,pan=0){let low=0;instrument(t,.24,pan,x=>{let w=noise();low+=.3*(w-low);return(Math.sin(TAU*midi(note)*x)*Math.exp(-x*26)+Math.sin(TAU*midi(note)*2.13*x)*.4*Math.exp(-x*39)+(w-low)*.25*Math.exp(-x*70))*Math.min(1,x*900);},.19*gain);}
 function bass(t,note,length,gain=1,dirty=false){let p=0,low=0;const f=midi(note),a=1-Math.exp(-TAU*(dirty?1150:760)/RATE);instrument(t,length+.08,-.03,(x)=>{p+=f/RATE;let frac=p%1,saw=2*frac-1;low+=a*(saw-low);let env=Math.min(1,x/.006)*Math.min(1,(length+.08-x)/.08)*Math.exp(-x*.65);return Math.tanh((Math.sin(TAU*p)*.8+low*.28)*(dirty?2.3:1.4))*env;},.22*gain);}
 function guitar(t,note,length,gain=1,pan=0,clean=false){
  const freq=midi(note),periods=[freq,freq*1.4983,freq*2.003],buffers=periods.map(f=>{let n=Math.max(2,Math.round(RATE/f)),b=new Float32Array(n);for(let i=0;i<n;i++)b[i]=noise()*.6+Math.sin(TAU*i/n)*.3;return b;}),cursors=[0,0,0];
  let cabinet=0,hp=0,last=0;const decay=clean?.9972:.9938;
  instrument(t,length+.09,pan,(x)=>{let v=0;for(let s=0;s<3;s++){let b=buffers[s],p=cursors[s],next=(p+1)%b.length,sample=b[p];b[p]=(sample+b[next])*.5*decay;cursors[s]=next;v+=sample*[1,.61,.39][s];}v=Math.tanh(v*(clean?1.25:5.4));cabinet+=.51*(v-cabinet);hp=.978*(hp+cabinet-last);last=cabinet;const env=Math.min(1,x/.002)*Math.min(1,(length+.09-x)/.09);return hp*env;},(clean?.15:.175)*gain);
 }
 function key(t,note,length,gain=1,pan=0,bright=false){const f=midi(note);instrument(t,length+.6,pan,x=>{let env=Math.min(1,x/.009)*Math.exp(-x*(bright?2.3:1.1))*Math.min(1,(length+.6-x)/.35);return(Math.sin(TAU*f*x)+.26*Math.sin(TAU*f*2.005*x)+.13*Math.sin(TAU*f*3*x))*env;},.15*gain);}
 function pad(t,notes,length,gain=1,choir=false){for(let voice=0;voice<notes.length;voice++){let f=midi(notes[voice]),pan=(voice/(notes.length-1)-.5)*1.2,phase=rand()*TAU;instrument(t,length+1.7,pan,x=>{let env=Math.min(1,x/.55)*Math.min(1,(length+1.7-x)/1.7);env=env*env*(3-2*env);let v=Math.sin(TAU*f*x+phase)*.64+Math.sin(TAU*f*1.0031*x+phase+.4)*.25+Math.sin(TAU*f*.9981*x+phase-.5)*.25;for(let h=2;h<=8;h++){let weight=choir?(Math.exp(-(((f*h-720)/310)**2))+.6*Math.exp(-(((f*h-1230)/420)**2)))*.17:.22/h;v+=Math.sin(TAU*f*h*x+phase)*weight;}return v*env*(.94+.06*Math.sin(TAU*.19*x+voice));},.075*gain/Math.sqrt(notes.length));}}
 const riff0=[0,0,12,0,7,0,3,5,0,0,10,7,3,0,5,7];
 const riff1=[0,0,1,0,7,0,10,8,0,3,1,0,7,8,3,1];
 const lead0=[12,15,19,17,22,19,15,14,12,10,15,17,19,17,14,10];
 const lead2=[12,19,15,22,17,19,24,22,19,15,17,14,12,15,19,17];
 for(let bar=0;bar<bars;bar++){
  const root=def.roots[bar%8],t=bar*4*beat,section=Math.floor(bar/8),bridge=section===2,menu=def.style===3;
  const quality=(bar%8>=6&&def.style===0)?[0,4,7,11]:[0,3,7,10],chord=quality.map(x=>root+x+12);
  const band=menu?(.55+.12*section):(section===0?.65:section===2?.77:1);
  pad(t,chord,4*beat,menu?1.45:def.style===2?1.45:.65,def.style===2||menu);
  if((menu&&section>0)||def.style===2)pad(t,[root+24,root+31],4*beat,menu?.32:.39,false);
  for(let step=0;step<8;step++){
   const off=step*.5,jitter=(rand()-.5)*.012*beat;
   if(!menu||section===1||section===2)hat(t+off*beat+jitter,step===7&&bar%2===1,band*(.72+rand()*.28));
   if(!menu||step%2===0){let index=(step+bar*3)%16,note=root+(def.style===1?riff1[index]:riff0[index])%12;let len=(step===7?.43:.46)*beat;bass(t+off*beat,note,len,(menu?.46:.9)*band,def.style===1);}
  }
  if(menu){
   if(section===1||section===2){kick(t,.36);kick(t+2.5*beat,.25);tom(t+3*beat,42,.24,.1);hat(t+3.5*beat,true,.26);}
   for(let n=0;n<4;n++){const note=chord[(n+bar)%chord.length]+12;key(t+(n+.25)*beat,note,1.7*beat,.42,n%2?-.3:.3);}
   if(bar%2===0)guitar(t,root+24,2.6*beat,.43,-.35,true);
  } else {
   for(const off of def.style===1?[0,1.5,2.75,3.5]:bridge?[0,2.5,3.5]:[0,.75,2,2.75])kick(t+off*beat,band*(.83+rand()*.17));
   snare(t+beat,band);snare(t+3*beat,band*.96);
   if(bar%4===3){snare(t+2.75*beat,.2*band);snare(t+3.75*beat,.34*band);}
   if(bar%8===0)cymbal(t,band*.85);
   if(def.style===1){for(let n=0;n<6;n++)wood(t+(n*2/3+(bar%2)*.125)*beat,59+(n%3)*5,.45+rand()*.35,(n%3-1)*.48);for(const off of [.5,2.25,3.25])tom(t+off*beat,43+bar%5,.35,(bar%3-1)*.4);}
   if(def.style===0||def.style===2){
    const pattern=def.style===0?riff0:[0,7,12,7,3,7,10,7,0,12,7,15,10,7,3,7];
    for(let step=0;step<8;step++){if(bridge&&step%2===1)continue;let note=root+12+(pattern[(step+bar*2)%16]===0?0:pattern[(step+bar*2)%16]);let len=(step%4===3?.7:.36)*beat;guitar(t+step*.5*beat,note,len,band,-.57);guitar(t+step*.5*beat+.009,note+.035,len,band*.9,.57);}
   }
   if(def.style===1){for(let n=0;n<6;n++)key(t+([0,.75,1.5,2.25,3,3.5][n])*beat,root+24+riff1[(n+bar*2)%16],.5*beat,bridge?.57:.3,(n%3-1)*.4,true);}
   else if(section===1||section===3){let motif=def.style===2?lead2:lead0;for(let n=0;n<4;n++)key(t+(n+.25)*beat,root+12+motif[(bar*4+n)%motif.length],.95*beat,.52,n%2?-.22:.22,def.style===2);}
   if(bar%8===7){for(let n=0;n<4;n++)tom(t+(3+n*.25)*beat,50-n*3,.72,(-.6+n*.4));hat(t+3.75*beat,true,.9);}
  }
 }
 // Periodic stereo room/echo processing: tails wrap into the first bar, keeping
 // the loop continuous without a silent fade or duplicated musical bar.
 const dryL=L.slice(),dryR=R.slice(),wet=def.style===3?.25:def.style===2?.19:.14;
 for(const [seconds,level,cross]of [[.071,.34,false],[.113,.27,true],[.179,.23,false],[.293,.18,true],[.431,.13,false],[.677,.09,true]]){let d=Math.round(seconds*RATE);for(let i=0;i<N;i++){let j=i-d;if(j<0)j+=N;L[i]+=(cross?dryR[j]:dryL[j])*level*wet;R[i]+=(cross?dryL[j]:dryR[j])*level*wet;}}
 let meanL=0,meanR=0;for(let i=0;i<N;i++){meanL+=L[i];meanR+=R[i];}meanL/=N;meanR/=N;
 let peak=0,sum=0;for(let i=0;i<N;i++){L[i]-=meanL;R[i]-=meanR;peak=Math.max(peak,Math.abs(L[i]),Math.abs(R[i]));sum+=L[i]*L[i]+R[i]*R[i];}
 let rms=Math.sqrt(sum/(2*N)),gain=Math.min(.89/peak,.16/rms),pcm=Buffer.alloc(N*4);for(let i=0;i<N;i++){pcm.writeInt16LE(Math.round(clamp(L[i]*gain,-1,1)*32767),i*4);pcm.writeInt16LE(Math.round(clamp(R[i]*gain,-1,1)*32767),i*4+2);}
 const header=Buffer.alloc(44),smpl=Buffer.alloc(68);header.write('RIFF');header.writeUInt32LE(36+pcm.length+smpl.length,4);header.write('WAVEfmt ',8);header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(2,22);header.writeUInt32LE(RATE,24);header.writeUInt32LE(RATE*4,28);header.writeUInt16LE(4,32);header.writeUInt16LE(16,34);header.write('data',36);header.writeUInt32LE(pcm.length,40);smpl.write('smpl');smpl.writeUInt32LE(60,4);smpl.writeUInt32LE(Math.round(1e9/RATE),16);smpl.writeUInt32LE(60,20);smpl.writeUInt32LE(1,36);smpl.writeUInt32LE(N-1,56);
 const wav=Buffer.concat([header,pcm,smpl]),file=def.name+'.wav';fs.writeFileSync(path.join(OUT,file),wav);
 let seam=Math.max(Math.abs(L[0]-L[N-1]),Math.abs(R[0]-R[N-1]))*gain;
 console.log(`${file}: ${(N/RATE).toFixed(2)}s, ${(wav.length/1048576).toFixed(2)} MiB, peak ${(peak*gain).toFixed(3)}, rms ${(rms*gain).toFixed(3)}, seam ${seam.toFixed(5)}`);
 return{file,original:true,loop:true,bpm:def.bpm,bars,key:def.key,frames:N,seconds:N/RATE,loop_begin:0,loop_end:N,peak:Number((peak*gain).toFixed(5)),rms:Number((rms*gain).toFixed(5)),seam_delta:Number(seam.toFixed(7)),description:def.description,sections:['8 bars: establish motif','8 bars: full arrangement','8 bars: harmonic and rhythmic variation','8 bars: reprise and turnaround'],sha256:crypto.createHash('sha256').update(wav).digest('hex')};
}
const manifest={sample_rate:RATE,channels:2,bits:16,original:true,composition:'Original riffs, harmony, motifs and arrangements created for AsteraCraft; synthesized instruments only; no sampled or copied music.',loop_method:'Periodic arrangement and circular stereo reverberation with WAV smpl forward-loop metadata',tracks:tracks.map(render)};
fs.writeFileSync(path.join(OUT,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
