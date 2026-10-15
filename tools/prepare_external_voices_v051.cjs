const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),catalog=JSON.parse(fs.readFileSync(path.join(root,'data/voices_v05.json')));
const directions=[
 'Korean, masculine low baritone or bass, thick resonant chest voice, mature rock hyrax soldier. Short crisp military delivery, controlled grit. No comic squeak. Dry recording; radio filtering will be applied in the game pipeline.',
 'Korean female infected hive narrator. Clearly feminine, ominous controlled breath and slight vocal fry, calm predatory authority. Clear fast articulation, not a slow male demon. Dry recording; subtle biomechanical modulation will be applied later.',
 'Korean majestic ancient owl telepath. Dignified resonant voice, sacred aura and composed authority, concise articulation. No long pauses or booming reverb; a short subtle halo echo will be applied later.'
];
const clips=catalog.clips.filter(c=>c.type==='speech').map(c=>({id:c.id,file:c.id+'.wav',text:c.text,race:c.race,kind:c.kind,announcer:!!c.announcer,direction:directions[c.race]}));
const manifest={status:'awaiting_external_recordings',external_recordings_imported:0,format:'PCM WAV, mono preferred, 24000 or 48000 Hz',directions,clips,citrus_units:'140 non-verbal robotic citrus monster roars remain separate from the female narrator. No spoken dialogue.',notice:'No external TTS audio has been generated or imported by this manifest.'};
fs.writeFileSync(path.join(root,'data/external_voices_v051.json'),JSON.stringify(manifest,null,2)+'\n');
const quote=s=>'"'+String(s).replaceAll('"','""')+'"';
fs.writeFileSync(path.join(root,'docs/external_tts_lines_v051.csv'),'\ufeff'+['filename,race,kind,announcer,text,direction',...clips.map(c=>[c.file,c.race,c.kind,c.announcer,c.text,c.direction].map(quote).join(','))].join('\r\n'));
console.log(JSON.stringify({speech_lines:clips.length,status:manifest.status}));
