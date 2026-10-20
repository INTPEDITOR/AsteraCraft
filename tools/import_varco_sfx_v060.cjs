const fs=require('fs'),path=require('path'),io=require('./voice_audio_io_v060.cjs');
const root=path.resolve(__dirname,'..'),ledger=require('../data/varco_sounds_v060.json'),game=require('../data/game.json'),rate=24000;
const banks={},sources={},cues=[];
for(const rec of ledger.requests){if(rec.id.startsWith('citrus_'))continue;const d=io.read(path.join(root,rec.file));banks[rec.id]=io.trim(io.resample(d.x,d.rate,rate),rate);sources[rec.id]=rec;}
function fade(x){x=x.slice();const lead=Math.min(96,x.length/8),tail=Math.min(1680,x.length/4);for(let i=0;i<lead;i++)x[i]*=i/lead;for(let i=0;i<tail;i++)x[x.length-1-i]*=i/tail;return x;}
function lowpass(x,hz){const y=new Float32Array(x.length),a=1-Math.exp(-2*Math.PI*hz/rate);let z=0;for(let i=0;i<x.length;i++){z+=a*(x[i]-z);y[i]=z;}return y;}
function cut(x,seconds){return fade(x.subarray(0,Math.min(x.length,Math.round(seconds*rate))));}
function emit(name,bank,{duration=1,pitch=1,secondary=null,reverse=false,low=0,exact=false,category='effect',race=null,kind=null,part=null}={}){
 if(!banks[bank])throw Error('Missing source '+bank);let x=part||banks[bank];
 if(reverse)x=Float32Array.from(x).reverse();
 if(pitch!==1)x=io.resample(x,rate*pitch,rate);
 if(low)x=lowpass(x,low);
 if(secondary){const b=banks[secondary],y=new Float32Array(Math.max(x.length,b.length));y.set(x);for(let i=0;i<b.length;i++)y[i]+=b[i]*.38;x=y;}
 if(exact)x=io.tempo(x,x.length/(duration*rate));else x=cut(x,duration);
 x=fade(x);const file=name+'.wav';io.write(path.join(root,'assets/audio',file),x);
 cues.push({name,file,duration:+(x.length/rate).toFixed(4),sample_rate:rate,provider:'VARCO Sound',source_bank:bank,source_project:sources[bank].project,source_sha256:sources[bank].source_sha256,secondary_bank:secondary,pitch,reverse,lowpass_hz:low,category,race,kind,derivative:!!(secondary||pitch!==1||reverse||low||part||duration<x.length/rate)});
}
const weapons={tool:['melee',.75,.9],bullet:['rifle',.72,1],shotgun:['rifle',.85,.76],bash:['melee',.8,.76],shell:['cannon',1.18,1],missile:['missile',1.45,1],laser:['electric',.65,1.25],bomb:['nuclear',1.5,1.35],cannon:['cannon',1.45,.78],flame:['flame',1.2,1],drill:['melee',.65,1.25],claw:['melee',.7,1.1],acid:['acid',.95,1],slam:['roots',1.0,.75],explosion:['nuclear',1.1,1.7],vine:['roots',.85,1.1],seed:['seed',1.0,1],thorn:['seed',.7,1.4],spore:['hive',.8,1.2],spark:['electric',.65,1.45],slash:['melee',.7,1.2],bolt:['electric',.75,1.08],blade:['melee',.7,1.35],spell:['hive',.75,1.2],plasma:['electric',1.05,.77],beam:['beam',1.25,1]};
for(let race=0;race<3;race++)for(let kind=0;kind<game.units[race].length;kind++){
 const unit=game.units[race][kind],w=weapons[unit.weapon]||[unit.role==='healer'||kind===4?'heal':'transport',.8,1];
 emit(`unit_${race}_${kind}`,w[0],{duration:w[1],pitch:w[2]*(.97+(kind%4)*.02),category:unit.damage>0?'weapon':'support',race,kind});
 const mechanical=unit.material==='mechanical';
 emit(`death_${race}_${kind}`,mechanical?'cannon':race===1?'acid':race===2?'electric':'acid',{duration:mechanical?.95:.65,pitch:mechanical?.8+(kind%3)*.1:race===2?1.1:.76,low:race===0&&!mechanical?1600:0,category:'death',race,kind});
}
emit('heal_medic','heal',{duration:1,category:'healing',race:0});
const skills={stim:['heal',.78,'electric'],smoke:['flame',.8],nuclear:['nuclear',5.6],scan:['electric',.9],overcharge:['electric',1.1,'shield'],field_repair:['transport',1,'heal'],neural:['hive',1.2],mind_control:['hive',1.7,'electric'],shed:['organic',1,'heal'],sap_heal:['heal',1],sap_reclaim:['acid',1.1,'roots'],sap_bloom:['heal',1.2,'organic'],carapace:['shield',1.2,'roots'],scatter:['seed',1.0],root_surge:['roots',1.5],judgment:['beam',1.6],silence:['hive',1.2],bind:['roots',1.3,'arcane'],discipline:['shield',1],march:['transport',1.0,'electric'],barrier:['shield',1.4],purify:['heal',1.1,'electric'],shockwave:['cannon',1.3,'arcane'],pierce:['beam',1.1],verdict:['beam',1.7,'electric']};
for(const [index,skill] of game.abilities.entries()){const s=skills[skill.id];if(!s)throw Error('Unmapped skill '+skill.id);emit('skill_'+skill.id,s[0],{duration:s[1],secondary:s[2],pitch:skill.id==='nuclear'?1:.94+(index%7)*.025,category:'skill',race:skill.race});}
emit('nuclear_ascent','nuclear_ascent',{duration:4,exact:true,category:'nuclear'});
emit('nuclear_descent','nuclear_descent',{duration:3,exact:true,category:'nuclear'});
const transport=io.split(banks.transport,rate,3).clips;
for(let race=0;race<3;race++)for(const action of ['board','unboard'])emit(`${action}_${race}`,'transport',{duration:1.1,part:transport[race],reverse:action==='unboard',pitch:action==='board'?1:1.08,secondary:race===1?'organic':race===2?'shield':null,category:'transport',race});
for(let race=0;race<3;race++)emit('explosion_'+race,race===0?'cannon':race===1?'acid':'electric',{duration:1.1,pitch:.78+race*.13,category:'destruction',race});
const manifest={schema:2,origin:'New VARCO Sound generations with documented offline editing, pitch, layering and tails. UI/mining procedural cues retained.',sample_rate:rate,approved_credits:1700,actual_credits:1700,account_remaining:[0,300],cues};
fs.writeFileSync(path.join(root,'assets/audio/manifest_v060.json'),JSON.stringify(manifest,null,2));
const old=require('../assets/audio/manifest.json');old.original=false;old.synthesis='VARCO recordings for weapons and abilities; original procedural UI and mining retained.';
for(const cue of cues){const entry=old.sounds.find(x=>x.file===cue.file);const pcm=io.read(path.join(root,'assets/audio',cue.file)).x;let peak=0,sum=0;for(const v of pcm){peak=Math.max(peak,Math.abs(v));sum+=v*v;}const facts={seconds:cue.duration,sample_rate:rate,peak:+peak.toFixed(4),rms:+Math.sqrt(sum/pcm.length).toFixed(4),provider:cue.provider,source_bank:cue.source_bank};if(entry)Object.assign(entry,facts);else old.sounds.push({file:cue.file,...facts,category:cue.category,race:cue.race,kind:cue.kind});}
fs.writeFileSync(path.join(root,'assets/audio/manifest.json'),JSON.stringify(old,null,2));
const deaths={schema:2,origin:'New VARCO-derived biological, mechanical and arcane destruction sounds',cues:cues.filter(c=>c.category==='death').map(c=>({...c,seconds:c.duration}))};fs.writeFileSync(path.join(root,'assets/audio/death_v052.json'),JSON.stringify(deaths,null,2));
console.log({varco_sources:Object.keys(banks).length,runtime_cues:cues.length,weapons:43,skills:game.abilities.length,transport:6,death:deaths.cues.length});
