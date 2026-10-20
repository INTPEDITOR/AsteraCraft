const fs=require('fs'),path=require('path'),rate=44100;
const d=JSON.parse(fs.readFileSync(path.join(__dirname,'../data/game.json'))),manifest=[];
const jobs=d.abilities.map((s,i)=>({name:'skill_'+s.id,race:s.race,seed:59+i,fall:false}));
jobs.push({name:'nuclear_ascent',race:0,seed:211,fall:false},{name:'nuclear_descent',race:0,seed:221,fall:true});
for(let r=0;r<3;r++)for(const action of ['board','unboard'])jobs.push({name:action+'_'+r,race:r,seed:171+r,fall:action==='unboard'});
for(const job of jobs){let seed=job.seed,phase=0,low=0;const nuclear=job.name==='skill_nuclear',flight=job.name.startsWith('nuclear_');const duration=nuclear?8:flight?(job.fall?3:4):job.name.startsWith('skill')?.65:.48,n=Math.ceil(duration*rate),pcm=new Float64Array(n);let peak=0;
 for(let i=0;i<n;i++){let t=i/rate,u=t/duration;seed=(Math.imul(seed,1664525)+1013904223)>>>0;let noise=seed/2147483648-1;low=low*.92+noise*.08;let f=(job.race===0?190:job.race===1?105:340)+(job.fall?-150:360)*u+job.seed%13*17;phase+=2*Math.PI*f/rate;let env=Math.sin(Math.PI*u)*Math.exp(-u*2);let v=(Math.sin(phase)*.34+Math.sin(phase*1.5)*.13+low*(job.race===0?1.3:.65))*env;
 if(nuclear){const attack=Math.min(1,t/.012);v=attack*(noise*.7*Math.exp(-t*8)+low*3.2*Math.exp(-t*.65)+Math.sin(2*Math.PI*(48*t+22*(1-Math.exp(-t*3))))*.35*Math.exp(-t*.8))*Math.min(1,(duration-t)*2);}
 else if(flight){phase+=2*Math.PI*(job.fall?1500-1100*u:60+180*u)/rate;v=(low*(job.fall?.4:2.2)+Math.sin(phase)*(job.fall?.2:.1))*Math.min(1,t/.1)*Math.min(1,(duration-t)/.2);}
 pcm[i]=v;peak=Math.max(peak,Math.abs(v));}
 const wav=Buffer.alloc(44+n*2);wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(n*2,40);
 for(let i=0;i<n;i++)wav.writeInt16LE(Math.round(pcm[i]/peak*.65*32767),44+i*2);
 fs.writeFileSync(path.join(__dirname,'../assets/audio',job.name+'.wav'),wav);manifest.push({...job,duration});
}
fs.writeFileSync(path.join(__dirname,'../assets/audio/manifest_v060.json'),JSON.stringify({origin:'Original deterministic procedural synthesis, no external recordings',cues:manifest},null,2));
console.log('AUDIO_V060',manifest.length);
