const fs=require('fs'),p=require('path').join(__dirname,'../data/varco_sounds_v060.json'),v=JSON.parse(fs.readFileSync(p));
const sounds=[
 ['nuclear_descent','A massive missile plunging rapidly from the sky: threatening accelerating air whistle, dense wind shear rushing downward, rising intensity for 3 seconds, stop just before impact. No explosion.'],
 ['rifle','One powerful military rifle shot. Sharp dry muzzle crack, punchy mechanical bolt cycling, a subtle shell casing clink, a compact gritty tail. Realistic close firearm sound, about 0.6 seconds.'],
 ['cannon','One heavy armored tank cannon shot: sudden chest-punching low boom, metallic recoil mechanism, gritty shell blast and a short debris tail. Powerful compact 1.5-second game effect.'],
 ['missile','One guided missile firing from a vehicle: hard launcher clunk, sharp rocket ignition and fast fiery whoosh, ending in a compact distant explosive impact. Realistic layered 2-second weapon effect.'],
 ['flame','One military flamethrower burst: mechanical ignition click, forceful liquid-fuel whoosh, roaring pressurized flame and crackling fire. Intense close 1.5-second effect.'],
 ['melee','One heavy claw tearing through metal armor: rapid physical air swish, a fierce sharp metallic slash, thick tearing material and a weighty impact. Close detailed 0.7-second melee game sound.'],
 ['acid','One organic acid-spitting creature attack: forceful wet pressurized spit, a short liquid projectile hiss, thick corrosive splatter and brief sizzling surface reaction. Dense realistic 1-second biological effect.'],
 ['seed','One giant organic seed cannon firing: woody chamber tension, a deep hollow organic thump, fast thorn projectile swish and brittle seed-shell impact. Crisp close 1-second fantasy creature weapon sound.'],
 ['roots','One burst of massive living tree roots tearing upward: deep woody flexing, snapping fibrous roots, cracking soil, heavy earth impact and falling grit. Powerful compact 1.5-second root magic effect.'],
 ['hive','One ominous psychic mind-control pulse: layered alien organic resonance, tense low chitinous vibration, a focused neural snap and unsettling hollow echo. Detailed 1.5-second game magic effect. No speech or chanting.'],
 ['heal','One concentrated healing activation: tactile liquid droplets and soft organic pulses, a clean restorative energy shimmer and gentle resonant release. Clear compact 1-second restorative game ability sound, not a melody.'],
 ['shield','One forceful protective energy shield switching on: dense low activation thump, crystalline energy surface expanding, bright electrical shimmer and a brief protective hum. Solid 1-second ability sound.'],
 ['electric','One electrical combat discharge: a hard capacitor click, violent electrical crackle, a short high-voltage arc and grounded bass thump. Compact 1-second effect, no musical notes.'],
 ['beam','One massive science-fiction judgment beam: a brief deep energy swell, piercing laser release, broad roaring energy surge and sizzling shock impact. Monumental 2-second effect.']
];
v.budget=1700;v.account_batches=[{batch:1,starting_credits:1000,approved_spend:1000,confirmed_remaining:0},{batch:2,starting_credits:1000,approved_spend:700,authorization:'User approved an additional 700 credits and confirmed account switch.'}];
for(const [id,prompt] of sounds)if(!v.banks.some(b=>b.id===id))v.banks.push({id,ordinal:v.banks.length+1,credits:50,account_batch:2,prompt:'Isolated high-quality RTS game sound effect. No music, no talking, no ambience or constant background noise. Start immediately. '+prompt});
fs.writeFileSync(p,JSON.stringify(v,null,2));console.log({banks:v.banks.length,approved_total:v.budget,additional:700});
