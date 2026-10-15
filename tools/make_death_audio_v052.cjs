// Original procedural, nonverbal death cues; no external recordings.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),rate=44100,manifest=[];
for(let race=0;race<3;race++)for(let kind=0;kind<13;kind++){
  const mechanical=race===0&&[5,6,8,9,10,11,12].includes(kind);
  const duration=mechanical?1.05:race===1?1.15:race===2?1.3:.85;
  const count=Math.ceil(rate*duration),samples=new Float64Array(count);
  let seed=12345+race*311+kind*997,low=0,phase=0;
  const noise=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2147483648-1};
  for(let i=0;i<count;i++){
    const t=i/rate,u=t/duration,env=Math.min(1,t/.018)*Math.pow(1-u,1.8);
    const n=noise();low=low*.88+n*.12;
    const f=(race===0?105:race===1?76:240)*(1+kind*.017)*(1-.55*u);
    phase+=2*Math.PI*f/rate;
    const voiced=Math.sin(phase)+.32*Math.sin(phase*2)+.14*Math.sin(phase*3);
    let s;
    if(mechanical)s=low*2.1*Math.exp(-t*3)+n*.17*Math.exp(-t*8)+Math.sin(phase*.65)*.48*Math.exp(-t*5)+Math.sin(phase*7)*.13*Math.exp(-t*4);
    else if(race===1)s=voiced*.46*(.72+.28*Math.sin(2*Math.PI*31*t))+low*.95+n*.07;
    else if(race===2)s=voiced*.32+Math.sin(phase*2.76)*.17*Math.exp(-t*2)+low*.5;
    else s=voiced*.5+low*.75+n*.03;
    samples[i]=s*env;
  }
  if(race===2)for(let i=count-1;i>=Math.floor(rate*.09);i--)samples[i]+=samples[i-Math.floor(rate*.09)]*.25;
  let peak=0;for(const v of samples)peak=Math.max(peak,Math.abs(v));
  const wav=Buffer.alloc(44+count*2);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(count*2,40);
  let sum=0;for(let i=0;i<count;i++){const value=samples[i]/peak*.74;sum+=value*value;wav.writeInt16LE(Math.round(value*32767),44+i*2)}
  const file=`death_${race}_${kind}.wav`;fs.writeFileSync(path.join(root,'assets/audio',file),wav);
  manifest.push({race,kind,file,duration,peak:.74,rms:Math.sqrt(sum/count),style:mechanical?'metal break / engine shutdown':race===1?'organic growl collapse':race===2?'owl cry / sacred resonance':'low nonverbal pilot grunt'});
}
fs.writeFileSync(path.join(root,'assets/audio/death_v052.json'),JSON.stringify({origin:'Original deterministic procedural synthesis, not external voice recordings',rate,cues:manifest},null,2));
console.log('DEATH_AUDIO_V052 '+manifest.length+' cues');
