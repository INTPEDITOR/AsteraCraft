// Original deterministic PCM construction cues; no external recordings.
const fs=require('fs'),path=require('path'),rate=44100,root=path.resolve(__dirname,'..');
const manifest=[];
for(let race=0;race<3;race++)for(const complete of [false,true]){
 const duration=complete?.85:1.25,n=Math.ceil(duration*rate),pcm=new Float64Array(n);let seed=12017+race*911+(complete?67:0),low=0,peak=0;
 for(let i=0;i<n;i++){
  const t=i/rate,u=t/duration;seed=(Math.imul(seed,1664525)+1013904223)>>>0;const noise=seed/2147483648-1;low=.965*low+.035*noise;
  const fade=Math.min(1,t/.035)*Math.min(1,(duration-t)/.16);let v=0;
  if(race===0){
   v=low*.7*Math.sin(Math.PI*u);
   for(const [at,f] of (complete?[[.04,470],[.17,740]]:[[.07,640],[.34,910],[.72,520]])){
    const q=t-at;if(q>=0)v+=(Math.sin(2*Math.PI*f*q)*.23+Math.sin(2*Math.PI*f*1.53*q)*.10+noise*.06)*Math.exp(-q*23);
   }
   v+=Math.sin(2*Math.PI*(68*t+8*t*t))*.035*Math.sin(Math.PI*u);
  }else if(race===1){
   v=low*.42*Math.sin(Math.PI*u);
   for(const [at,f] of (complete?[[.08,310],[.29,420]]:[[.07,155],[.40,205],[.78,245]])){
    const q=t-at;if(q>=0)v+=Math.sin(2*Math.PI*(f*q+38*q*q))*.16*Math.exp(-q*9)*Math.min(1,q/.04);
   }
   v+=Math.sin(2*Math.PI*(82*t+7*Math.sin(t*2)))*.035*Math.sin(Math.PI*u);
  }else{
   const swell=Math.pow(Math.sin(Math.PI*u),1.6);v=low*.15*swell;
   for(const f of (complete?[440,660,880]:[220,330,493.88]))v+=Math.sin(2*Math.PI*f*t)*.055*swell;
   const q=t-.10;if(q>=0)v+=(Math.sin(2*Math.PI*1318.5*q)*.075+Math.sin(2*Math.PI*1977.8*q)*.025)*Math.exp(-q*4)*Math.min(1,q/.03);
  }
  pcm[i]=v*fade;peak=Math.max(peak,Math.abs(pcm[i]));
 }
 const file=`construct_${complete?'complete_':''}${race}.wav`,out=Buffer.alloc(44+n*2);
 out.write('RIFF');out.writeUInt32LE(out.length-8,4);out.write('WAVEfmt ',8);out.writeUInt32LE(16,16);out.writeUInt16LE(1,20);out.writeUInt16LE(1,22);out.writeUInt32LE(rate,24);out.writeUInt32LE(rate*2,28);out.writeUInt16LE(2,32);out.writeUInt16LE(16,34);out.write('data',36);out.writeUInt32LE(n*2,40);
 for(let i=0;i<n;i++)out.writeInt16LE(Math.round(pcm[i]/peak*.48*32767),44+i*2);
 fs.writeFileSync(path.join(root,'assets/audio',file),out);manifest.push({file,race,complete,duration,description:['restrained mechanical assembly and ratchets','soft plant growth, rustle and sap resonance','calm crystalline summoning resonance'][race]});
}
fs.writeFileSync(path.join(root,'assets/audio/construction_manifest_20261024.json'),JSON.stringify({origin:'Original deterministic PCM synthesis',rate,channels:1,cues:manifest},null,2)+'\n');
console.log('Created',manifest.length,'race-specific construction/work and completion cues.');
