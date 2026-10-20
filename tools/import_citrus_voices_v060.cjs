const fs=require('fs'),path=require('path'),crypto=require('crypto'),io=require('./voice_audio_io_v060.cjs');
const root=path.resolve(__dirname,'..'),ledger=require('../data/varco_sounds_v060.json'),old=require('../data/voices_v05.json');
const catalog=JSON.parse(fs.readFileSync(path.join(root,'build/elevenlabs-v060/actor_catalog.json'))),report=JSON.parse(fs.readFileSync(path.join(root,'build/elevenlabs-v060/actor_report.json')));
function fade(x){x=x.slice();const lead=Math.min(240,x.length/4),tail=Math.min(1440,x.length/3);for(let i=0;i<lead;i++)x[i]*=i/lead;for(let i=0;i<tail;i++)x[x.length-1-i]*=i/tail;return x;}
function window(x,index,max=1.55){
 const n=Math.min(x.length,Math.round(max*24000));if(n===x.length)return fade(x);
 const expected=Math.round((x.length-n)*index/2),radius=Math.round(.15*24000);let best=Math.max(0,expected-radius),score=-1;
 for(let a=Math.max(0,expected-radius);a<=Math.min(x.length-n,expected+radius);a+=240){let energy=0;for(let j=0;j<n;j+=24)energy+=x[a+j]**2;if(energy>score){best=a;score=energy;}}
 return fade(x.slice(best,best+n));
}
for(let kind=0;kind<14;kind++){
 const id='citrus_u'+kind,source=ledger.requests.find(r=>r.id===id);if(!source?.file)throw Error('Missing VARCO '+id);
 const input=path.join(root,source.file),data=io.read(input),x=io.trim(io.resample(data.x,data.rate,24000),24000);let parts,method;
 try{parts=io.split(x,24000,3).clips.map((p,i)=>window(p,i));method='three detected responses, trimmed with short fades';}
 catch{parts=[0,1,2].map(i=>window(x,i,1.15+(kind%3)*.13));method='three expressive short excerpts derived from the continuous generated call';}
 const normal=[],special=[];
 for(let i=0;i<5;i++){
  const clip_id=`r1_u${kind}_${i<3?'n'+i:'s'+(i-3)}`,part=parts[i%3];
  const pitch=i<3?[.98,1,1.025][i]:[.91,1.075][i-3];let voiced=io.lower(part,pitch),y=new Float32Array(voiced.length+6000);
  for(let j=0;j<voiced.length;j++){
   y[j]+=voiced[j]*(.86+.14*Math.sin(2*Math.PI*(31+kind*2)*j/24000));
   if(j+360<y.length)y[j+360]+=voiced[j]*.16;
   if(j+2520<y.length)y[j+2520]+=voiced[j]*.10;
  }
  y=fade(y);const file='assets/voices/'+clip_id+'.wav';io.write(path.join(root,file),y);
  catalog.clips.push({id:clip_id,text:kind===13?'배양체의 기계 생체 반응':'괴물과 기계음이 융합된 '+old.units['1:'+kind].name+' 반응',race:1,kind,type:'roar',special:i>=3,file:'res://'+file,provider:'VARCO Sound',source_project:source.project});
  (i<3?normal:special).push(clip_id);report.clips.push({id:clip_id,seconds:+(y.length/24000).toFixed(3),provider:'VARCO Sound',source_bank:id,pitch,derivative:method});
 }
 catalog.units['1:'+kind]={...old.units['1:'+kind],normal,special,voice_profile:{provider:'VARCO Sound',identity:100+kind,effect:'biomechanical-monster',source_project:source.project}};
 report.recordings.push({id,provider:'VARCO Sound',project:source.project,source_sha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex'),seconds:data.x.length/data.rate,method});
}
if(Object.keys(catalog.units).length!==44||catalog.clips.length!==265)throw Error('Incomplete active voice coverage');
const hashes=new Set();for(const c of catalog.clips){const h=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,c.file.slice(6)))).digest('hex');if(hashes.has(h))throw Error('Duplicate active waveform '+c.id);hashes.add(h);}
report.units=Object.entries(catalog.units).map(([id,u])=>({id,name:u.name,...u.voice_profile}));
fs.writeFileSync(path.join(root,'data/voices_v05.json'),JSON.stringify(catalog,null,2));fs.writeFileSync(path.join(root,'data/voice_effects_v058.json'),JSON.stringify(report,null,2));
fs.writeFileSync(path.join(root,'data/external_voices_v051.json'),JSON.stringify({schema:2,status:'generated_imported_and_verified',speech_provider:'ElevenLabs',monster_provider:'VARCO Sound',unit_count:44,active_clips:265,speech_clips:195,monster_clips:70,manifest:'data/voice_effects_v058.json',narrator_policy:'Citrus female villainess, unchanged approved timbre, 10 percent faster delivery; faction-specific nuclear messages'},null,2));
console.log({units:44,active_clips:265,unique_waveforms:hashes.size,max_seconds:Math.max(...report.clips.map(c=>c.seconds))});
