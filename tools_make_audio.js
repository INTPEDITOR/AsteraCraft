// Original AsteraCraft sound effects. No samples or external sound libraries.
// Deterministic layered synthesis: transients, filtered noise, resonant bodies,
// mechanical cycles, fluid bubbles, tuned energy and short diffusion tails.
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const destination = path.join(root, 'assets', 'audio');
const rate = 44100;
fs.mkdirSync(destination, { recursive: true });
const game = JSON.parse(fs.readFileSync(path.join(root, 'data', 'game.json'), 'utf8'));
const manifest = { sample_rate: rate, channels: 1, bits: 16, original: true, synthesis: 'Layered procedural sound design; no sampled recordings.', sounds: [] };

function random(seed) {
  let value = seed >>> 0 || 1;
  return () => { value ^= value << 13; value ^= value >>> 17; value ^= value << 5; return (value >>> 0) / 4294967296; };
}

class Sound {
  constructor(seconds, seed) { this.samples = new Float64Array(Math.ceil(seconds * rate)); this.rng = random(seed); }
  noise(start, duration, volume, cutoff = 1200, highpass = 0, decay = 6, attack = .001) {
    const begin = Math.floor(start * rate), length = Math.floor(duration * rate);
    const alpha = 1 - Math.exp(-2 * Math.PI * cutoff / rate);
    const highAlpha = 1 - Math.exp(-2 * Math.PI * highpass / rate);
    let low = 0, highLow = 0;
    for (let i = 0; i < length && begin + i < this.samples.length; i++) {
      const t = i / rate, raw = this.rng() * 2 - 1;
      low += alpha * (raw - low); highLow += highAlpha * (low - highLow);
      const envelope = Math.min(1, t / attack) * Math.exp(-t / duration * decay);
      this.samples[begin + i] += (low - highLow) * volume * envelope;
    }
    return this;
  }
  tone(start, duration, volume, from, to = from, decay = 6, harmonics = .0, attack = .001) {
    const begin = Math.floor(start * rate), length = Math.floor(duration * rate);
    let phase = this.rng() * .7;
    for (let i = 0; i < length && begin + i < this.samples.length; i++) {
      const t = i / rate, x = i / Math.max(1, length - 1);
      const frequency = from * Math.pow(Math.max(1, to) / Math.max(1, from), x);
      phase += 2 * Math.PI * frequency / rate;
      const shape = Math.sin(phase) + harmonics * Math.sin(phase * 2.017) + harmonics * .45 * Math.sin(phase * 3.013);
      this.samples[begin + i] += shape * volume * Math.min(1, t / attack) * Math.exp(-decay * x) * Math.min(1, (1 - x) * 25);
    }
    return this;
  }
  metal(start, strength, scale = 1) {
    this.noise(start, .038, strength * 1.4, 11500, 1200, 7);
    for (const [f, gain, seconds] of [[431,.16,.17],[713,.13,.22],[1169,.08,.13],[2497,.05,.09]]) {
      this.tone(start, seconds, strength * gain, f * scale, f * scale * .97, 7);
    }
    return this;
  }
  boom(start, strength, size = 1) {
    this.tone(start, .31 * size, strength * .5, 152 / size, 37 / size, 5, .25);
    this.noise(start, .42 * size, strength * 1.4, 830 / size, 25, 6);
    this.noise(start + .009, .065, strength * .9, 10200, 1700, 7);
    return this;
  }
  fluid(start, strength, pitch = 1, count = 15) {
    this.noise(start, .27, strength * .75, 2400 * pitch, 180 * pitch, 3.3, .008);
    for (let i = 0; i < count; i++) {
      const offset = start + .008 + this.rng() * .21;
      const f = (220 + this.rng() * 1050) * pitch;
      this.tone(offset, .023 + this.rng() * .035, strength * (.04 + this.rng() * .12), f, f * (1.25 + this.rng()), 5, .2);
    }
    return this;
  }
  coil(start, strength, pitch = 1, length = .3) {
    this.noise(start, length, strength * .48, 11000, 1900, 5, .006);
    this.tone(start, length, strength * .12, 1740 * pitch, 520 * pitch, 5, .7, .005);
    this.tone(start + .008, length * .8, strength * .07, 2871 * pitch, 930 * pitch, 5, .45, .003);
    for (let i = 0; i < 5; i++) this.noise(start + i * .012, .009, strength * .6, 12500, 3000, 5);
    return this;
  }
  crystal(start, strength, pitch = 1, duration = .5) {
    this.noise(start, .045, strength * .9, 14800, 3800, 6);
    for (const [f, gain] of [[779,.13],[1173,.18],[1783,.14],[2711,.08],[3847,.035]]) {
      this.tone(start, duration * (1.1 - gain), strength * gain, f * pitch, f * pitch * .985, 6, .03);
    }
    this.noise(start + .02, duration, strength * .23, 6500, 1700, 6, .015);
    return this;
  }
  servo(start, strength, pitch = 1, duration = .2) {
    this.tone(start, duration, strength * .15, 115 * pitch, 250 * pitch, 3, .7, .012);
    this.noise(start, duration, strength * .5, 3600, 600, 4, .006);
    this.metal(start + duration * .8, strength * .25, pitch);
    return this;
  }
  diffuse(amount = .12, large = false) {
    const source = this.samples.slice();
    const taps = large ? [[.067,.6],[.121,.37],[.181,.22],[.257,.1]] : [[.021,.6],[.043,.35],[.079,.19],[.113,.09]];
    for (const [time, gain] of taps) {
      const lag = Math.round(time * rate); let low = 0;
      for (let i = lag; i < source.length; i++) {
        low += .37 * (source[i-lag] - low);
        this.samples[i] += low * gain * amount;
      }
    }
    return this;
  }
  write(name, target = .82, metadata = {}) {
    let peak = 0;
    for (let i = 0; i < this.samples.length; i++) { this.samples[i] = Math.tanh(this.samples[i] * 1.15); peak = Math.max(peak, Math.abs(this.samples[i])); }
    const gain = target / Math.max(.0001, peak);
    const output = Buffer.alloc(44 + this.samples.length * 2);
    output.write('RIFF',0); output.writeUInt32LE(output.length-8,4); output.write('WAVEfmt ',8); output.writeUInt32LE(16,16);
    output.writeUInt16LE(1,20); output.writeUInt16LE(1,22); output.writeUInt32LE(rate,24); output.writeUInt32LE(rate*2,28);
    output.writeUInt16LE(2,32); output.writeUInt16LE(16,34); output.write('data',36); output.writeUInt32LE(this.samples.length*2,40);
    let square = 0;
    for (let i = 0; i < this.samples.length; i++) {
      const fade = Math.min(1, i / 100, (this.samples.length - 1 - i) / 350);
      const value = this.samples[i] * gain * fade; square += value * value;
      output.writeInt16LE(Math.round(Math.max(-1, Math.min(1, value)) * 32767), 44+i*2);
    }
    fs.writeFileSync(path.join(destination, name + '.wav'), output);
    manifest.sounds.push({file:name+'.wav', seconds:Number((this.samples.length/rate).toFixed(3)),peak:target,rms:Number(Math.sqrt(square/this.samples.length).toFixed(4)),...metadata});
  }
}

// Industrial hyrax: sharp kinetic weapons, heavy moving mechanisms and air pressure.
function hyrax(kind) {
  const sound = new Sound(kind===5 || kind===12 || kind===10 ? 1.15 : .68, 103 + kind*79);
  const p = 1 + (kind % 4) * .07;
  switch (kind) {
    case 0: sound.servo(0,.8,1.7,.15).metal(.045,1.2,1.8).noise(.075,.12,.4,5600,800,6); break;
    case 1: for (const t of [0,.065,.13]) sound.boom(t,.55,.3).metal(t+.022,.35,1.8); break;
    case 2: sound.noise(0,.12,.55,4500,250,3,.015).metal(.058,1.1,.65).boom(.06,.45,.45); break;
    case 3: sound.servo(0,.5,.65,.08).metal(.045,1.6,.48).boom(.045,.65,.55); break;
    case 4: sound.noise(0,.24,.6,4200,300,3,.01).coil(.08,.25,1.8,.2).servo(.28,.3,2,.1); break;
    case 5: sound.servo(0,.6,.65,.07).boom(.05,2.1,1.45).metal(.07,.6,.55).noise(.28,.38,.25,2500,250,5); break;
    case 6: sound.boom(0,.6,.45).noise(.02,.39,1.2,7400,280,3,.02).tone(.03,.34,.22,720,190,5,.4).metal(.07,.45,1.2); break;
    case 7: sound.noise(0,.025,2,13800,2100,8).boom(.003,.7,.7).metal(.09,.4,1.4); break;
    case 8: sound.servo(0,.28,2.3,.21).noise(.06,.21,.5,7400,3100,5).coil(.04,.2,2.2,.16); break;
    case 9: for (const t of [0,.07]) sound.boom(t,.8,.5).coil(t+.02,.2,.7,.19); break;
    case 10: sound.noise(0,.22,.8,2400,110,3,.03).boom(.13,1.7,1.45).metal(.19,.35,.55); break;
    case 11: sound.servo(0,.9,.65,.24).noise(.12,.28,.5,2400,100,4,.02).metal(.25,.5,.65); break;
    case 12: for (const t of [0,.09]) sound.boom(t,1.15,1.0).metal(t+.035,.55,.7); break;
  }
  return sound.diffuse(.16, kind===5 || kind===10 || kind===12);
}

// Citrus monsters carry Gyoollock's control coils, rivets and fluid reservoirs.
function citrus(kind) {
  const sound = new Sound(kind===4 || kind===6 || kind===12 ? 1.1 : .75, 5801+kind*101);
  const p = .85 + (kind % 5) * .14;
  sound.coil(0,.25,p,.16);
  switch(kind) {
    case 0: sound.servo(.01,.6,1.8,.12).metal(.055,.6,1.3).fluid(.04,.55,1.7,8); break;
    case 1: sound.noise(.015,.1,.8,9200,1000,4).fluid(.035,.85,1.5,12).metal(.045,.35,2.1); break;
    case 2: sound.fluid(.02,1.3,.9,23).noise(.03,.18,.75,6800,800,4).tone(.015,.16,.25,310,95,5,.3); break;
    case 3: sound.servo(0,.75,.55,.09).boom(.055,.95,.8).fluid(.065,.75,.5,10).metal(.06,.8,.5); break;
    case 4: sound.coil(0,.8,.45,.19).boom(.07,1.8,1.3).fluid(.075,1.2,.65,29).metal(.09,.35,.65); break;
    case 5: sound.noise(0,.16,1.1,4600,330,4,.005).fluid(.07,.95,.7,16).metal(.085,.35,.85); break;
    case 6: sound.tone(0,.18,.27,94,280,3,.6).boom(.09,1.2,.95).fluid(.105,1.0,.75,22).metal(.15,.45,.8); break;
    case 7: for (const t of [0,.045,.09]) sound.metal(t,.4,2.0).noise(t,.08,.65,12300,2300,6).fluid(t,.25,2,4); break;
    case 8: sound.servo(.01,.55,2,.15).fluid(.045,.8,1.8,14).noise(.03,.09,.6,8200,1200,5); break;
    case 9: sound.fluid(.02,.7,.65,26).coil(.03,.45,1.6,.32).servo(.22,.25,1.7,.13); break;
    case 10: sound.noise(0,.12,.7,10000,1700,5).fluid(.03,1.1,1.4,18).coil(.035,.4,1.4,.23); break;
    case 11: sound.fluid(.02,.85,.45,24).servo(.03,.8,.7,.26).coil(.1,.28,.7,.3); break;
    case 12: sound.servo(0,.6,.45,.16).boom(.09,1.3,1.15).fluid(.08,1.25,.45,28).coil(.1,.5,.5,.48); break;
  }
  return sound.diffuse(.14, kind===4 || kind===6 || kind===12);
}

// Ancient owls: hard resonant ivory metal, crimson plasma and glassy harmonics.
function owl(kind) {
  const sound = new Sound([5,8,12].includes(kind)?1.3:.85, 17183+kind*113);
  const p = 1 + (kind % 3) * .14;
  switch(kind) {
    case 0: sound.crystal(0,.65,1.7,.22).noise(.015,.14,.5,10500,1300,4).coil(0,.2,2.2,.15); break;
    case 1: sound.noise(0,.13,.9,6200,850,3).metal(.045,.6,1.1).crystal(.05,.8,1.3,.4).tone(.04,.19,.18,190,70,4,.25); break;
    case 2: sound.tone(0,.12,.16,370,1600,3,.6).noise(.04,.16,.8,12000,1800,5).crystal(.05,.7,1.8,.34); break;
    case 3: sound.coil(0,.55,.8,.27).crystal(.03,.9,.85,.48).boom(.02,.28,.55); break;
    case 4: sound.crystal(0,.9,1.25,.64).tone(.02,.35,.16,233,466,3,.5,.018).noise(.025,.3,.4,5200,1600,4,.02); break;
    case 5: sound.tone(0,.21,.25,135,380,2,.6,.02).coil(.05,.7,.55,.5).crystal(.12,1.05,.6,.75).boom(.12,.5,.8); break;
    case 6: sound.crystal(0,.5,2.0,.32).servo(0,.15,2.4,.19).noise(.01,.23,.55,12800,4000,4,.012); break;
    case 7: sound.metal(0,1.2,.6).boom(.012,.85,.7).crystal(.025,.85,.65,.55); break;
    case 8: sound.tone(0,.19,.3,80,490,3,.5).coil(.04,.7,.45,.5).boom(.16,1.6,1.0).crystal(.16,1.3,.7,.75); break;
    case 9: for (const t of [0,.07]) sound.noise(t,.13,.75,10500,1800,4).crystal(t,.6,1.55,.35).coil(t,.3,1.15,.2); break;
    case 10: sound.noise(0,.12,1.0,7000,1000,3).crystal(.045,.75,1.8,.38).tone(.02,.14,.14,430,95,4,.5); break;
    case 11: sound.crystal(.03,.8,.9,.56).tone(0,.33,.2,130,390,3,.45,.02).servo(.02,.3,.9,.2); break;
    case 12: sound.tone(0,.22,.35,65,240,2,.75,.02).coil(.02,.75,.4,.6).boom(.15,1.5,1.35).crystal(.13,1.7,.55,.85); break;
  }
  return sound.diffuse(.2, [5,8,12].includes(kind));
}

for(let race=0;race<3;race++) for(let kind=0;kind<13;kind++) {
  const unit = game.units[race][kind];
  [hyrax,citrus,owl][race](kind).write(`unit_${race}_${kind}`, unit.damage===0?.64:.82, {race,kind,name:unit.name,category:unit.damage>0?'attack':'ability'});
}

for(let race=0;race<3;race++) {
  const sound = new Sound(.78, 61120+race*331);
  if(race===0) for(let i=0;i<5;i++) sound.servo(i*.1,.32,1.5,.08).metal(i*.1+.035,.45,1.8+i*.1).noise(i*.1,.075,.4,7800,1100,5);
  if(race===1) {
    sound.coil(0,.22,1.7,.39);
    for(let i=0;i<4;i++) sound.servo(i*.105,.32,1.6,.09).metal(i*.105+.04,.28,2).fluid(i*.105+.035,.4,1.7,4);
  }
  if(race===2) for(let i=0;i<4;i++) sound.crystal(i*.11,.35,1.8+i*.12,.2).noise(i*.11,.08,.45,12400,2200,5).coil(i*.11,.1,2,.1);
  sound.diffuse(.08).write(`mine_${race}`,.62,{race,category:'mining'});
  const blast = new Sound(1.3,78042+race*977);
  if(race===0) blast.boom(0,1.6,1.2).metal(.015,.8,.55).noise(.12,.5,.5,2400,120,5);
  if(race===1) blast.boom(0,1.1,1.1).fluid(.015,1.6,.65,40).metal(.04,.6,.7).coil(.02,.35,.6,.45);
  if(race===2) blast.boom(.005,1.0,1.2).crystal(0,1.6,.8,.85).coil(.02,.5,.65,.55);
  blast.diffuse(.23,true).write(`explosion_${race}`,.78,{race,category:'destruction'});
}

new Sound(.17,773).metal(0,.32,2.1).tone(0,.1,.07,400,230,6,.2).diffuse(.06).write('ui_confirm',.39,{category:'interface'});
new Sound(.21,774).metal(0,.24,2.5).servo(0,.17,2.2,.08).diffuse(.05).write('ui_select',.32,{category:'interface'});
new Sound(.31,775).metal(0,.3,.7).metal(.065,.22,.6).noise(0,.16,.3,1600,70,4).diffuse(.04).write('ui_error',.4,{category:'interface'});
new Sound(.24,776).servo(0,.4,1.7,.1).metal(.055,.3,2.2).crystal(.06,.15,2,.16).diffuse(.07).write('ui_ready',.36,{category:'interface'});
new Sound(.44,777).metal(0,.45,1.3).servo(.01,.5,.8,.15).crystal(.08,.32,1.3,.3).diffuse(.12).write('ui_build',.43,{category:'interface'});
// A soft medical emitter: warm filtered air and a slow harmonic halo.
// No gun transient, impact, rapid coil discharge or ammunition mechanism.
new Sound(.64,78031)
  .noise(.006,.49,.28,2300,140,2.8,.032)
  .noise(.035,.43,.11,6500,1700,3.5,.045)
  .tone(0,.53,.032,196,207,2.8,.16,.03)
  .tone(.012,.52,.021,392,414,3.1,.10,.035)
  .tone(.03,.48,.011,784,807,3.5,.04,.045)
  .diffuse(.20)
  .write('heal_medic',.32,{race:0,kind:4,category:'healing',name:'야전의무병 의료 치유'});
fs.writeFileSync(path.join(destination,'manifest.json'), JSON.stringify(manifest,null,2)+'\n');
console.log(`Created ${manifest.sounds.length} original PCM WAV effects in ${destination}`);
