const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {processVoice,RATE}=require('../tools/voice_faction_dsp.cjs');
let checks=0;const check=(ok,msg)=>{assert.ok(ok,msg);checks++};
const impulse=new Float32Array(RATE);impulse[100]=.5;
for(let race=0;race<3;race++){
 const a=processVoice(impulse,{race}),b=processVoice(impulse,{race});
 check(a.every((x,i)=>Number.isFinite(x)&&x===b[i]),'finite deterministic effect');
 const silence=processVoice(new Float32Array(RATE),{race,announcer:true});
 check(silence.every(x=>x===0),'no constant hiss on announcements');
 check(a.length<=RATE*1.3,'bounded response tail');
 if(race>0)check(a[100]===.5&&a.slice(100+RATE*.05).some(x=>Math.abs(x)>.00001),'dry attack plus audible delayed response');
}
const root=path.resolve(__dirname,'..'),cat=JSON.parse(fs.readFileSync(path.join(root,'data/voices_v05.json')));
for(const c of cat.clips){
 const b=fs.readFileSync(path.join(root,c.file.replace('res://','')));let peak=0,sum=0;
 for(let i=44;i<b.length;i+=2){const x=b.readInt16LE(i)/32768;peak=Math.max(peak,Math.abs(x));sum+=x*x;}
 check(peak>.1&&peak<.80&&sum>1,c.id+' non-silent with peak headroom');
}
console.log(JSON.stringify({checks,clips:cat.clips.length,failures:0}));
