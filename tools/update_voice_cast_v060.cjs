const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
const file=path.join(root,'data/elevenlabs_voices_v060.json'),data=JSON.parse(fs.readFileSync(file));
const cast0=['George','Brian','Adam','Roger','Daniel','Bill','Eric','Callum','Charlie','Adam','George','Roger','Bill','Callum','Daniel','Eric'];
const cast2=['Bill','Adam','Charlie','Daniel','George','Brian','Callum','Roger','Eric','Charlie','Callum','Daniel','Bill','Brian'];
const tags0=['serious','serious','angry','serious','calm','serious','serious','whispers','serious','angry','serious','calm','serious','angry','serious','serious'];
const tags2=['serious','serious','calm','serious','calm','serious','whispers','angry','serious','serious','whispers','calm','serious','angry'];
for(const b of data.banks){
 if(b.announcer){b.voice=['Brian','Matilda','Bill'][b.race];b.pitch=[.78,.97,.82][b.race];b.persona=['mature military baritone','clearly female, low and sinister hive queen','solemn ancient stone oracle'][b.race];}
 else{b.voice=(b.race===0?cast0:cast2)[b.kind];b.pitch=+(b.race===0?.74+(b.kind%8)*.018:.72+(b.kind%7)*.024).toFixed(3);b.persona=(b.race===0?'mature military baritone':'solemn male fantasy stone guardian')+', distinct role '+b.name;b.tag=(b.race===0?tags0:tags2)[b.kind];b.resonance=+(0.06+b.kind*.017).toFixed(3);}
 b.prompt='['+(b.tag||(b.race===1?'menacing':'serious'))+'] '+b.clips.map(c=>c.text).join('\n[long pause]\n');
}
data.voice_policy='Every unit has a distinct performed voice and individual pitch, pacing and resonance. Hyrax mature baritones; citrus units new nonverbal biomechanical VARCO creatures, clearly female sinister ElevenLabs narrator; owl solemn male stone fantasy voices.';
data.recordings=data.recordings||[
 {id:'r0_ann',banks:['r0_ann'],voice:'Brian',source:'C:/Users/Admin/Downloads/ElevenLabs_2026-10-20T13_25_21_Brian - Deep, Resonant and Comforting_pre_sp100_s50_sb75_v4.mp3'},
 {id:'r0_u2',banks:['r0_u2'],voice:'Adam',source:'C:/Users/Admin/Downloads/ElevenLabs_2026-10-20T13_31_50_Adam - Dominant, Firm_pre_sp100_s50_sb75_v4.mp3'},
 {id:'r2_ann',banks:['r2_ann'],voice:'Bill',source:'C:/Users/Admin/Downloads/ElevenLabs_2026-10-20T13_32_55_Bill - Wise, Mature, Balanced_pre_sp100_s50_sb75_v4.mp3'}];
const done=new Set(data.recordings.flatMap(r=>r.banks));
data.generation_groups=[];
for(const voice of [...new Set(data.banks.filter(b=>!b.announcer).map(b=>b.voice))]){
 const banks=data.banks.filter(b=>!b.announcer&&b.voice===voice&&!done.has(b.id));
 if(banks.length)data.generation_groups.push({id:'actor_'+voice,voice,banks:banks.map(b=>b.id),prompt:banks.map(b=>b.prompt).join('\n[long pause]\n')});
}
fs.writeFileSync(file,JSON.stringify(data,null,2));
const vf=path.join(root,'data/varco_sounds_v060.json'),v=JSON.parse(fs.readFileSync(vf));
if(!v.requests.some(r=>r.id==='nuclear_ascent'))v.requests.push({id:'nuclear_ascent',credits:50,project:'9e8d84c3-810b-49f4-a3ed-a20431ff9a45',source:'C:/Users/Admin/Downloads/Rocket_ignition.wav',file:'build/varco-v060/nuclear_ascent.wav',status:'downloaded'});
const game=require('../data/game.json');
const timbres=['small busy woody worker chirps with hydraulic ratchets','aggressive rapid claw creature chattering with serrated metallic clicks','wet gurgling acid-spitter croak with a deep pump and resonant steel throat','colossal thick-skinned beast bass growls with slow grinding armor servos','unstable swollen explosive creature bubbling cackles with ticking mechanical clicks','predatory vine serpent rasp and leafy hiss with a twisting metal resonator','hollow woody seed-cannon creature hoots with clacking chamber mechanisms','sharp thorn-flower insect calls with crystalline metallic ringing','sinister parasitic insect whispers and chittering with alien electronic modulation','low nurturing but threatening organic queen hum with liquid resonance and a mechanical undertone','piercing flying leaf-bat shrieks with fluttering membranes and rapidly pulsing electronic chirps','deep inflated flying transport creature calls with pneumatic breathing and creaking metallic cartilage','enormous ancient tree monster seismic groan with deep grinding machinery and crackling roots'];
const fixed=v.banks.slice(0,2);
const added=[['nuclear_descent','A massive missile plunging rapidly from the sky: threatening accelerating air whistle, dense wind shear rushing downward, rising intensity for 3 seconds, stop just before impact. No explosion.'],['ballistic','Three isolated heavy sci-fi weapon attacks with clear silence between: a sharp automatic rifle burst and bolt cycle; a heavy tank cannon boom with metallic recoil; a flame jet ignition and pressurized fiery whoosh. No speech.'],['arcane','Three isolated majestic fantasy spell activations with silence between: a sharp high-voltage plasma crack and energy impact; a deep crystalline protective shield activation and shimmer; a huge resonant judgment beam with an ancient hollow energy roar. No chanting.'],['organic','Three isolated biological game abilities with silence between: a wet acid spit and corrosive splatter; giant tree roots snapping up through earth; a concentrated healing pulse of liquid droplets and alien organic resonance. No speech.'],['transport','Three isolated realistic transport events with silence between: heavy hydraulic metal boarding hatch opening and locking; woody organic creature pouch opening with wet valves and closing; ancient stone portal opening with a low magical chime and grinding stone. No speech.']];
for(const [id,p] of added)fixed.push({id,prompt:'High-quality isolated RTS game sound effects. No music, no ambience, no constant noise. Start immediately. '+p});
for(let kind=0;kind<game.units[1].length;kind++)fixed.push({id:'citrus_u'+kind,kind,race:1,name:game.units[1][kind].name,prompt:'Isolated RTS alien unit voice, a unique biomechanical citrus monster. '+timbres[kind]+'. Perform three different short nonverbal responses, about one second each, separated by complete silence. The organic monster voice and machinery must sound fused into one living creature. Detailed expressive threatening game voice, not human speech, not words, no music, no environment, no weapon impacts.'});
fixed.splice(fixed.findIndex(b=>b.id==='nuclear_descent'),1);
fixed.push({id:'citrus_u13',kind:13,race:1,name:'배양체',prompt:'Isolated RTS alien unit voice, a delicate newborn biomechanical citrus larva. Soft wet larval squeaks and curious insect trills fused with tiny servo chirps, springy woody shell clicks and subtle liquid bubbles. Perform three different short nonverbal responses, about one second each, separated by complete silence. One living monster, not human speech, no words, no music, no environment, no weapon impacts.'});
v.banks=fixed.map((b,i)=>({...b,ordinal:i+1,credits:50}));
if(v.banks.length!==20)throw Error('Budget mismatch '+v.banks.length);
v.policy='User updated: all 13 citrus unit voices must be newly generated biomechanical monsters in VARCO; narration exclusively ElevenLabs. Remaining seven effect banks have multiple isolated events/variations for weapon and spell derivatives.';
fs.writeFileSync(vf,JSON.stringify(v,null,2));
console.log({groups:data.generation_groups.map(g=>({id:g.id,voice:g.voice,banks:g.banks})),varco_banks:v.banks.length,credits_committed:v.requests.reduce((n,r)=>n+r.credits,0)});
