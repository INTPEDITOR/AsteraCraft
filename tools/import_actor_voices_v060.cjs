const fs=require('fs'),path=require('path'),cp=require('child_process'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),io=require('./voice_audio_io_v060.cjs'),{processVoice}=require('./voice_faction_dsp.cjs');
const spec=require('../data/elevenlabs_voices_v060.json'),base=require('../data/voices_v05.json');
const records=spec.recordings,banks=spec.banks,raw=path.join(root,'build/elevenlabs-v060');fs.mkdirSync(raw,{recursive:true});
const catalog={schema:2,source:'ElevenLabs game actor recordings and newly generated VARCO biomechanical citrus creatures, faction processing v2',units:{},narration:base.narration,clips:[]};
const report={revision:'faction-radio-hive-telepathy-v2',providers:['ElevenLabs','VARCO Sound'],sample_rate:24000,clips:[],recordings:[],units:[]};
const wanted=process.argv.includes('--partial')?banks.filter(b=>records.some(r=>r.banks.includes(b.id))):banks;
for(const rec of records){
 const input=path.join(raw,rec.id+'.mp3'),wav=path.join(raw,rec.id+'.wav');
 fs.copyFileSync(rec.source,input);
 if(!fs.existsSync(wav)||fs.statSync(wav).mtimeMs<fs.statSync(input).mtimeMs){
  const p=cp.spawnSync(process.execPath,['tools_run_godot.js','--headless','--path','.','--script','tools/decode_voice_mp3_v060.gd','--',input,wav],{cwd:root,encoding:'utf8'});
  if(p.status)throw Error(p.stdout+p.stderr);
 }
 const data=io.read(wav),list=rec.banks.map(id=>banks.find(b=>b.id===id));
 const expected=list.reduce((n,b)=>n+b.clips.length,0),split=io.split(data.x,data.rate,expected);let index=0;
 report.recordings.push({id:rec.id,voice:rec.voice,source_sha256:crypto.createHash('sha256').update(fs.readFileSync(input)).digest('hex'),seconds:data.x.length/data.rate,segments:expected,gaps:split.gaps});
 for(const b of list){
  for(const c of b.clips){
   let x=io.resample(split.clips[index++],data.rate,24000);
   if(b.pitch!==1)x=io.lower(x,b.pitch);
   if(b.speed)x=io.tempo(x,b.speed);
   x=processVoice(x,{race:b.race,kind:b.kind,announcer:b.announcer,resonance:b.resonance});
   const file='assets/voices/'+c.id+'.wav';io.write(path.join(root,file),x);
   const clip={...c,race:b.race,kind:b.kind,type:'speech',pitch:b.pitch,file:'res://'+file,provider:'ElevenLabs',actor:b.voice,persona:b.persona};
   if(b.announcer){delete clip.kind;clip.announcer=true;}
   catalog.clips.push(clip);report.clips.push({id:c.id,seconds:+(x.length/24000).toFixed(3),provider:'ElevenLabs',source_bank:rec.id,pitch:b.pitch,speed:b.speed||1});
  }
  if(!b.announcer){const old=base.units[b.race+':'+b.kind]||{};catalog.units[b.race+':'+b.kind]={...old,name:b.name,normal:b.clips.filter(c=>!c.special).map(c=>c.id),special:b.clips.filter(c=>c.special).map(c=>c.id),voice_profile:{actor:b.voice,pitch:b.pitch,effect:b.race===0?'radio':'stone-telepathy',resonance:b.resonance,identity:b.race*100+b.kind}};}
 }
}
const distinct=new Set(catalog.clips.map(c=>c.id));if(distinct.size!==catalog.clips.length)throw Error('Duplicate active speech');
if(!process.argv.includes('--partial'))for(const b of wanted)if(!b.clips.every(c=>distinct.has(c.id)))throw Error('Missing voice bank '+b.id);
fs.writeFileSync(path.join(raw,'actor_catalog.json'),JSON.stringify(catalog,null,2));fs.writeFileSync(path.join(raw,'actor_report.json'),JSON.stringify(report,null,2));
console.log({recordings:report.recordings.length,spoken_clips:catalog.clips.length,units:Object.keys(catalog.units).length,max_seconds:Math.max(...report.clips.map(c=>c.seconds))});
