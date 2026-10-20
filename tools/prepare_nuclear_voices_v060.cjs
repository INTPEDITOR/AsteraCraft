const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
const file=path.join(root,'data/voices_v05.json'),catalog=JSON.parse(fs.readFileSync(file));
const texts=['핵 발사가 감지되었습니다. 전 병력, 위험 지역에서 대피하십시오.','핵 발사가 감지되었다. 군체를 흩어라.','핵 발사가 감지되었습니다. 동족들이여, 폭심지에서 벗어나십시오.'];
const clips=texts.map((text,race)=>({id:`r${race}_ann_nuclear`,text,race,kind:12,type:'speech',announcer:true,pitch:[.88,.65,.82][race],file:`res://assets/voices/r${race}_ann_nuclear.wav`}));
for(const clip of clips){catalog.clips=catalog.clips.filter(c=>c.id!==clip.id);catalog.clips.push(clip);catalog.narration[clip.race].nuclear=clip.id;}
fs.writeFileSync(file,JSON.stringify(catalog,null,2)+'\n');
fs.writeFileSync(path.join(root,'build/nuclear-voice-catalog.json'),JSON.stringify({clips},null,2));
let render=fs.readFileSync(path.join(__dirname,'render_voice_effects_v05.cjs'),'utf8');
if(!render.includes('ASTERA_VOICE_FILTER')){
 render=render.replace('const report=[];','const selected=(process.env.ASTERA_VOICE_FILTER||\'\').split(\',\').filter(Boolean);\nconst previous=path.join(root,\'build/voice-render-report.json\');\nconst report=selected.length&&fs.existsSync(previous)?JSON.parse(fs.readFileSync(previous)).filter(c=>!selected.includes(c.id)):[];');
 render=render.replace('for(const c of cat.clips){','for(const c of cat.clips.filter(c=>!selected.length||selected.includes(c.id))){');
 fs.writeFileSync(path.join(__dirname,'render_voice_effects_v05.cjs'),render);
}
console.log(clips.map(c=>c.id).join(','));
