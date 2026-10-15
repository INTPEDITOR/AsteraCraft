// Stage only. The release owner exports the PCK and creates the final ZIP.
// Older deliverable directories and archives are intentionally left untouched.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = __dirname;
const VERSION = '0.4';
const OUT = path.resolve(ROOT, '..', 'deliverables');
const WINDOWS = path.join(OUT, `AsteraCraft-Windows-v${VERSION}`);
const SOURCE = path.join(OUT, `AsteraCraft-Godot-v${VERSION}`);
const WINDOWS_ZIP = path.join(OUT, `AsteraCraft-Windows-v${VERSION}.zip`);
const SOURCE_ZIP = path.join(OUT, `AsteraCraft-Godot-v${VERSION}.zip`);
const OMIT = new Set(['.godot', '.git', 'node_modules']);
const SOURCE_FOLDERS = ['assets', 'data', 'scripts', 'tests', 'docs', 'tools'];
const RUNTIME_FILES = ['node.exe', 'Node-LICENSE.txt', 'Node-VERSION.txt'];
const FONTS = [
  {file:'NotoSansKR-VF.ttf', license:'OFL-NotoSansKR.txt', notice:'NotoSansKR-OFL.txt'},
  {file:'Galmuri14.ttf', license:'OFL-Galmuri.txt', notice:'Galmuri-OFL.txt'},
  {file:'Orbitron-VF.ttf', license:'OFL-Orbitron.txt', notice:'Orbitron-OFL.txt'}
];
const REQUIRED_CATALOGS = ['asset_regions.json','building_regions_v3.json','motion_regions.json','sprite_regions.json',
  'motion_cache_v04.json','motion_roots_v04.json','aux_sprites_v04.json','cursor_regions_v04.json','construction_regions_v04.json'];
const SOURCE_GENERATORS = ['tools_make_data.js','tools_make_maps.js','tools_balance_v04.js','tools_building_roles.js','tools_footprints_v04.js','tools_update_lore.js',
  'tools_make_construction.gd','tools_make_audio.js','tools_make_native_ui.js','tools_sprite_regions.js'];

function copyFile(src, destination) {
  fs.mkdirSync(path.dirname(destination), {recursive:true});
  fs.copyFileSync(src, destination);
}

function allowed(relative) {
  const parts = relative.replace(/\\/g, '/').split('/');
  const filename = parts.at(-1);
  if (parts.some(part => /^(?:logs?|api[-_]tests?|test-user-data|user[-_]data|app_userdata)$/i.test(part))) return false;
  if (parts[0] === 'server' && parts[1] === 'data') return false;
  if (filename === 'network.json' || /^\.env(?:\.|$)/i.test(filename) || /\.(?:log|pem|key)$/i.test(filename)) return false;
  if (filename.endsWith('_mid.png')) return false;
  if (filename.endsWith('.woff2')) return false;
  if (parts[0] === 'assets' && parts[1] === 'ui_native' && /^modal_(?:480x48|1060x64|360x44|480x44)_r[012]_(?:normal|hover|pressed)\.png$/.test(filename)) return false;
  if (parts[0] === 'tests' && /\.(png|jpe?g|webp)$/i.test(filename)) return false;
  // Publish deterministic game-rule scripts, not account/API test harnesses.
  if (parts[0] === 'tests' && /\.(?:js|cjs|mjs)$/i.test(filename)) return false;
  return !parts.some(part => OMIT.has(part)) && !filename.endsWith('.b64') && !filename.endsWith('.import') && !filename.endsWith('.tmp');
}

function copyTree(src, destination, prefix = '') {
  if (!fs.existsSync(src)) return;
  for (const item of fs.readdirSync(src, {withFileTypes:true})) {
    const relative = path.posix.join(prefix, item.name);
    if (!allowed(relative)) continue;
    const source = path.join(src, item.name), target = path.join(destination, item.name);
    if (item.isDirectory()) copyTree(source, target, relative);
    else if (item.isFile()) copyFile(source, target);
  }
}

function renderGameData(data) {
  let text = `# 아스테라크래프트 게임 데이터 v${VERSION}\n\n`;
  text += '가격은 아스 / 테라 순서이며, 건물 규격은 실제 배치·충돌에 사용하는 논리 격자입니다. 아래 수치는 `data/game.json`에서 생성합니다. 종족 간 밸런스는 플레이테스트에 따라 바뀔 수 있습니다.\n\n';
  text += '- 최대 인구: 200. 생산 예약 인구를 포함합니다. 한 번에 선택·명령할 수 있는 유닛은 12기입니다.\n';
  text += '- 아스: 황금색 수정. 일꾼이 채취하고 완성된 본부의 가까운 외곽에서 반납합니다. 건물 중심까지 들어가지 않습니다.\n';
  text += '- 테라: 파란색 촉매. 매장지 위 정제 건물이 완성되면 일꾼 없이 3초마다 8씩 자동 채취합니다. 매장량 소진 시 멈춥니다.\n';
  text += '- 기본 매장량: 아스 노드마다 1500, 테라 매장지마다 5000. 각 본진은 아스 8개(합계 12000)와 테라 1개로 시작합니다.\n';
  text += '- 전장: 황철 분지·과숙의 심장·적월의 성역은 서로 다른 구조의 고유 4인용 맵이며 좌우·상하 대칭으로 설계합니다.\n';
  text += '- 귤 변이 군체: 매드 사이언티스트 이귤락이 만든 생체·기계 융합 군체. 개체에 정신 제어용 기계장치가 달려 있습니다.\n\n';
  for (let race = 0; race < data.race_names.length; race++) {
    const prerequisites = ids => ids.map(id => data.buildings[race][id].name).join(', ') || '없음';
    text += `## ${data.race_names[race]}\n\n### 유닛\n\n`;
    text += '| 유닛 | HP | 실드 | 장갑 | 공격 | 가격 | 인구 | 시간(초) | 생산 건물 | 선행 건물 | 설명 |\n';
    text += '|---|---:|---:|---:|---:|---|---:|---:|---|---|---|\n';
    for (const unit of data.units[race]) {
      text += `| ${unit.name} | ${unit.hp} | ${unit.shield} | ${unit.armor} | ${unit.damage} | ${unit.as} / ${unit.tera} | ${unit.pop} | ${unit.time} | ${data.buildings[race][unit.producer].name} | ${prerequisites(unit.requires)} | ${unit.description} |\n`;
    }
    text += '\n### 건물\n\n';
    text += '| 건물 | HP | 실드 | 가격 | 규격 | 추가 인구 | 시간(초) | 선행 건물 | 설명 |\n';
    text += '|---|---:|---:|---|---|---:|---:|---|---|\n';
    for (const [kind, building] of data.buildings[race].entries()) {
      const description = building.description;
      text += `| ${building.name} | ${building.hp} | ${building.shield} | ${building.as} / ${building.tera} | ${building.w}×${building.h} | ${building.supply} | ${building.time} | ${prerequisites(building.requires)} | ${description} |\n`;
    }
    text += '\n';
  }
  return text;
}

function readData() {
  const data = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'game.json'), 'utf8'));
  if (data.units.length !== 3 || data.buildings.length !== 3 || data.units.some(rows => rows.length !== 13) || data.buildings.some(rows => rows.length !== 13)) throw Error('Expected 3 factions, 39 units and 39 buildings.');
  if (data.version !== '0.4.0') throw Error('Game data must declare version 0.4.0.');
  return data;
}

function inventory(directory, relative = '') {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, {withFileTypes:true}).flatMap(item => {
    const next = path.posix.join(relative, item.name);
    if (!allowed(next)) return [];
    if (item.isDirectory()) return inventory(path.join(directory,item.name), next);
    return item.isFile() ? [next] : [];
  });
}

function readJson(relative) {
  return JSON.parse(fs.readFileSync(path.join(ROOT,relative),'utf8'));
}

function runtimeCatalogs() {
  const catalogs=new Set(REQUIRED_CATALOGS.map(name=>'data/'+name));
  for (const filename of inventory(path.join(ROOT,'scripts'),'scripts').filter(name=>name.endsWith('.gd'))) {
    const script=fs.readFileSync(path.join(ROOT,filename),'utf8');
    for (const match of script.matchAll(/res:\/\/(data\/[A-Za-z0-9_/-]+\.json)/g)) catalogs.add(match[1]);
  }
  return [...catalogs].sort();
}

function pngSize(relative) {
  const header=Buffer.alloc(24),file=fs.openSync(path.join(ROOT,relative),'r');
  try { if (fs.readSync(file,header,0,24,0)!==24 || header.toString('hex',0,8)!=='89504e470d0a1a0a') throw Error('Invalid PNG: '+relative); }
  finally { fs.closeSync(file); }
  const width=header.readUInt32BE(16),height=header.readUInt32BE(20);
  if (!width || !height) throw Error('Empty PNG: '+relative);
  return {width,height};
}

function matchesFilter(relative,pattern) {
  // Godot wildcard filters match the complete resource path (including '/').
  const escaped=pattern.replace(/[.+^${}()|[\]\\]/g,'\\$&').replace(/\*/g,'.*').replace(/\?/g,'.');
  return new RegExp('^'+escaped+'$','i').test(relative.replace(/\\/g,'/'));
}

function exportPolicy() {
  const config=fs.readFileSync(path.join(ROOT,'export_presets.cfg'),'utf8');
  const values=key=>(config.match(new RegExp('^'+key+'="([^"]*)"','m'))?.[1] || '').split(',').map(value=>value.trim()).filter(Boolean);
  const policy={include:values('include_filter'),exclude:values('exclude_filter')};
  for (const filter of ['assets/motion/*.png','assets/motion_cache/*.png','assets/registered_motion/*.png',
    'assets/construction_v4/*.png','assets/audio/*.wav','assets/audio/*.json','assets/music/*.wav','assets/music/*.ogg','assets/music/*.mp3','assets/music/*.json','assets/fonts/*.ttf','assets/fonts/*.txt','data/*.json']) {
    if (!policy.include.includes(filter)) throw Error('Missing export filter: '+filter);
  }
  for (const relative of ['tools_package.js','tools_make_construction.gd','tools/native.js','build/private.json',
    'tests/private.gd','server/server.js','runtime/node.exe','network.json','assets/raw.b64',
    'assets/motion/raw.b64','assets/construction_v4/raw.b64','assets/fonts/Galmuri14.woff2']) {
    if (!policy.exclude.some(pattern=>matchesFilter(relative,pattern))) throw Error('Export would include a development/private file: '+relative);
  }
  return policy;
}

function validateAsset(relative,policy) {
  if (relative.includes('..') || path.isAbsolute(relative) || !relative.startsWith('assets/')) throw Error('Unsafe asset path: '+relative);
  if (!fs.existsSync(path.join(ROOT,relative))) throw Error('Game metadata references missing art: '+relative);
  if (!allowed(relative)) throw Error('Runtime art would be omitted from editable source: '+relative);
  if (!policy.include.some(pattern=>matchesFilter(relative,pattern)) || policy.exclude.some(pattern=>matchesFilter(relative,pattern))) throw Error('Runtime asset would be omitted from PCK: '+relative);
  if (relative.endsWith('.png')) pngSize(relative);
}

function validateFonts(policy) {
  for (const font of FONTS) {
    for (const name of [font.file,font.license]) validateAsset('assets/fonts/'+name,policy);
    const bytes=fs.readFileSync(path.join(ROOT,'assets','fonts',font.file));
    if (bytes.length<10000 || !['00010000','4f54544f'].includes(bytes.toString('hex',0,4))) throw Error('Invalid bundled OpenType/TrueType font: '+font.file);
    if (!/SIL OPEN FONT LICENSE|SIL Open Font License/i.test(fs.readFileSync(path.join(ROOT,'assets','fonts',font.license),'utf8'))) throw Error('Incomplete font license: '+font.license);
  }
  return FONTS.length;
}

function validateMotion(policy) {
  const cache=readJson('data/motion_cache_v04.json');
  if (Object.keys(cache.units || {}).length!==39) throw Error('Expected 39 registered runtime motion-cache entries.');
  const files=new Set();
  for (let race=0;race<3;race++) for (let kind=0;kind<13;kind++) {
    const key=`${race}:${kind}`,info=cache.units[key];
    if (!info || typeof info.file!=='string' || !info.file.startsWith('res://assets/motion_cache/')) throw Error('Missing motion cache: '+key);
    const relative=info.file.slice(6);validateAsset(relative,policy);files.add(relative);
    const size=pngSize(relative);
    if (![9,17].includes(info.columns) || info.rows<10 || size.width%info.columns || size.height%info.rows) throw Error('Invalid motion-cache frame grid: '+key);
    if (!Array.isArray(info.packed_root) || info.packed_root.length!==2 || info.packed_root.some(value=>!Number.isFinite(value)) || info.packed_root[0]<0 || info.packed_root[1]<0 || info.packed_root[0]>size.width/info.columns || info.packed_root[1]>size.height/info.rows) throw Error('Invalid registered motion root: '+key);
  }
  const pngs=inventory(path.join(ROOT,'assets','motion_cache'),'assets/motion_cache').filter(name=>name.endsWith('.png'));
  if (files.size!==39 || pngs.length!==39) throw Error('Expected exactly 39 unique runtime motion-cache PNGs.');
  return files.size;
}

function validateConstruction(policy) {
  const catalog=readJson('data/construction_regions_v04.json');
  if (catalog.stages!==3 || catalog.render_mode!=='baked_composite' || Object.keys(catalog.entries || {}).length!==39) throw Error('Expected 39 buildings with three baked construction phases.');
  const files=new Set(),hashes=new Set();
  for (let race=0;race<3;race++) for (let kind=0;kind<13;kind++) {
    const key=`${race}:${kind}`,stages=catalog.entries[key];
    if (!Array.isArray(stages) || stages.length!==3) throw Error('Missing construction phases: '+key);
    let canvas='';
    for (let phase=0;phase<3;phase++) {
      const frame=stages[phase],relative=`assets/construction_v4/building_${race}_${String(kind).padStart(2,'0')}_stage${phase}.png`;
      if (frame.file!=='res://'+relative || frame.composite!==true) throw Error('Wrong construction phase identity: '+key+'/'+phase);
      validateAsset(relative,policy);files.add(relative);
      const dimensions=pngSize(relative),signature=dimensions.width+'x'+dimensions.height;
      if (canvas && canvas!==signature) throw Error('Construction phases change the original canvas: '+key);
      canvas=signature;
      if (JSON.stringify(frame.region)!==JSON.stringify([0,0,dimensions.width,dimensions.height])) throw Error('Construction region must cover its unchanged original canvas: '+relative);
      hashes.add(crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,relative))).digest('hex'));
    }
  }
  const pngs=inventory(path.join(ROOT,'assets','construction_v4'),'assets/construction_v4').filter(name=>name.endsWith('.png'));
  if (files.size!==117 || pngs.length!==117 || hashes.size!==117) throw Error('Expected 117 distinct per-building construction PNGs.');
  return files.size;
}

function validateAudio(policy) {
  const manifest=readJson('assets/audio/manifest.json');
  const files=inventory(path.join(ROOT,'assets','audio'),'assets/audio').filter(name=>name.endsWith('.wav'));
  const expected=['heal_medic.wav',...['build','confirm','error','ready','select'].map(name=>'ui_'+name+'.wav')];
  for (let race=0;race<3;race++) {
    expected.push(`mine_${race}.wav`,`explosion_${race}.wav`);
    for (let kind=0;kind<13;kind++) expected.push(`unit_${race}_${kind}.wav`);
  }
  const listed=new Set((manifest.sounds || []).map(sound=>sound.file));
  if (files.length!==51 || manifest.sounds?.length!==51 || listed.size!==51 || expected.some(name=>!listed.has(name))) throw Error('Expected exactly 51 catalogued WAV cues (39 unit, 3 mining, 3 explosion, 5 UI, 1 medic heal).');
  validateAsset('assets/audio/manifest.json',policy);
  for (const name of expected) {
    const relative='assets/audio/'+name;validateAsset(relative,policy);
    const bytes=fs.readFileSync(path.join(ROOT,relative));
    if (bytes.length<44 || bytes.toString('ascii',0,4)!=='RIFF' || bytes.toString('ascii',8,12)!=='WAVE') throw Error('Invalid WAV cue: '+relative);
  }
  return files.length;
}

function validateMusic(policy) {
  // SUNO/user music is optional. Development DSP previews live under build/
  // and are never staged. The release is valid with no bundled BGM files.
  const manifestFile=path.join(ROOT,'assets','music','manifest.json');
  const manifest=fs.existsSync(manifestFile)?readJson('assets/music/manifest.json'):{};
  const entries=Array.isArray(manifest.tracks)?manifest.tracks:[];
  const files=inventory(path.join(ROOT,'assets','music'),'assets/music').filter(name=>/\.(?:wav|ogg|mp3)$/i.test(name));
  if (fs.existsSync(manifestFile)) validateAsset('assets/music/manifest.json',policy);
  for (const entry of entries) {
    if (typeof entry.file!=='string' || entry.file.includes('/') || entry.file.includes('\\') || !files.includes('assets/music/'+entry.file)) throw Error('Optional music catalog references a missing or unsafe audio file.');
  }
  const details=[];
  for (const relative of files) {
    const name=path.basename(relative);validateAsset(relative,policy);
    const bytes=fs.readFileSync(path.join(ROOT,relative));
    if (/\.ogg$/i.test(name)) {
      if (bytes.length<28 || bytes.toString('ascii',0,4)!=='OggS') throw Error('Invalid optional OGG music: '+name);
      details.push({file:name,format:'ogg',bytes:bytes.length});continue;
    }
    if (/\.mp3$/i.test(name)) {
      if (bytes.length<4 || !(bytes.toString('ascii',0,3)==='ID3' || (bytes[0]===255 && (bytes[1]&224)===224))) throw Error('Invalid optional MP3 music: '+name);
      details.push({file:name,format:'mp3',bytes:bytes.length});continue;
    }
    if (bytes.toString('ascii',0,4)!=='RIFF' || bytes.toString('ascii',8,12)!=='WAVE') throw Error('Invalid music WAV: '+name);
    let format=null,loop=null,dataBytes=0;
    for (let cursor=12;cursor+8<=bytes.length;) {
      const id=bytes.toString('ascii',cursor,cursor+4),size=bytes.readUInt32LE(cursor+4),begin=cursor+8;
      if (begin+size>bytes.length) throw Error('Truncated music WAV chunk: '+name);
      if (id==='fmt ' && size>=16) format={pcm:bytes.readUInt16LE(begin),channels:bytes.readUInt16LE(begin+2),rate:bytes.readUInt32LE(begin+4),align:bytes.readUInt16LE(begin+12),bits:bytes.readUInt16LE(begin+14)};
      if (id==='smpl' && size>=60 && bytes.readUInt32LE(begin+28)>0) loop={type:bytes.readUInt32LE(begin+40),begin:bytes.readUInt32LE(begin+44),end:bytes.readUInt32LE(begin+48)};
      if (id==='data') dataBytes+=size;
      cursor=begin+size+(size%2);
    }
    if (!format || ![1,3].includes(format.pcm) || ![1,2].includes(format.channels) || format.rate<8000 || format.rate>192000 || ![8,16,24,32].includes(format.bits) || format.align!==format.channels*format.bits/8 || !dataBytes) throw Error('Unsupported optional WAV music format: '+name);
    const seconds=dataBytes/(format.rate*format.align),entry=entries.find(track=>track.file===name);
    if (!(seconds>0) || (entry?.seconds!==undefined && (!Number.isFinite(entry.seconds) || Math.abs(entry.seconds-seconds)>.1))) throw Error('Optional music duration/catalog mismatch: '+name);
    const frames=dataBytes/format.align;
    if (loop && (loop.begin<0 || loop.end<loop.begin || loop.end>=frames)) throw Error('Optional WAV loop lies outside its audio samples: '+name);
    if (entry?.sha256 && entry.sha256!==crypto.createHash('sha256').update(bytes).digest('hex')) throw Error('Optional music digest disagrees with its manifest: '+name);
    details.push({file:name,format:'wav',seconds,bytes:bytes.length});
  }
  return details;
}

function validate() {
  const data = readData();
  const policy=exportPolicy();
  const fonts=validateFonts(policy);
  const catalogs=runtimeCatalogs();
  for (const name of ['README.md','GAME_DATA.md','RELEASE_NOTES.md','main.tscn','project.godot','server/server.js','data/maps.json',
    'data/reference_footprints_v04.json',...catalogs,...SOURCE_GENERATORS]) if (!fs.existsSync(path.join(ROOT,name))) throw Error('Missing source: ' + name);
  for (const name of catalogs) if (!allowed(name) || !policy.include.some(pattern=>matchesFilter(name,pattern)) || policy.exclude.some(pattern=>matchesFilter(name,pattern))) throw Error('Runtime catalog would be omitted: '+name);
  for (const name of SOURCE_GENERATORS) {
    if (!allowed(name)) throw Error('Required regeneration source would be omitted: '+name);
    if (fs.statSync(path.join(ROOT,name)).size<64) throw Error('Regeneration source is still an incomplete placeholder: '+name);
  }
  const {applyBalance}=require('./tools_balance_v04.js');
  const balanced=applyBalance(JSON.parse(JSON.stringify(data)));
  if (JSON.stringify(balanced.units)!==JSON.stringify(data.units) || JSON.stringify(applyBalance(JSON.parse(JSON.stringify(balanced))))!==JSON.stringify(balanced)) throw Error('Balance data does not match the idempotent v0.4 generator.');
  const {applyBuildingRoles}=require('./tools_building_roles.js');
  if (JSON.stringify(applyBuildingRoles(JSON.parse(JSON.stringify(data))).buildings)!==JSON.stringify(data.buildings)) throw Error('Building roles do not match their regeneration source.');
  const {applyFootprints}=require('./tools_footprints_v04.js');
  const footprintData=applyFootprints(JSON.parse(JSON.stringify(data)));
  if (JSON.stringify(footprintData.buildings)!==JSON.stringify(data.buildings) || JSON.stringify(applyFootprints(JSON.parse(JSON.stringify(footprintData))))!==JSON.stringify(footprintData)) throw Error('Building dimensions do not match their idempotent footprint generator.');
  if (!fs.readFileSync(path.join(ROOT,'project.godot'),'utf8').includes('config/version="0.4.0"')) throw Error('Godot project version must be 0.4.0.');
  const maps = JSON.parse(fs.readFileSync(path.join(ROOT,'data','maps.json'),'utf8'));
  const {applyCompactMinerals}=require('./tools_make_maps.js');
  if (JSON.stringify(applyCompactMinerals(JSON.parse(JSON.stringify(maps))))!==JSON.stringify(maps)) throw Error('Compact mineral positions disagree with their idempotent map generator.');
  if (!Array.isArray(maps.maps) || maps.maps.length!==3 || maps.size!==128 || maps.symmetry!=='mirror_xy') throw Error('Expected 3 original 128x128 maps with mirror_xy symmetry.');
  if (maps.resources?.as?.initial_amount!==1500 || maps.resources?.tera?.initial_amount!==5000) throw Error('Map resource defaults must be As 1500 / Tera 5000.');
  for (let map=0;map<3;map++) if (maps.maps[map].name!==data.maps[map].name) throw Error('Game map names and map layout metadata disagree.');
  for (const name of ['title_logo_correct.png','ui_hud_0.png','ui_hud_1_native_v3.png','ui_hud_2_native_v3.png','hud_materials_v3.png','resources_v2.png','resource_icons_v3.png']) if (!fs.existsSync(path.join(ROOT,'assets',name))) throw Error('Missing approved runtime art: '+name);
  // New native popups are baked at each exact pixel size. Source atlases remain
  // in the editable project; their generated output is used by the runtime.
  for (const size of ['220x48','300x48','220x44','300x44']) for (let race=0;race<3;race++) for (const state of ['normal','hover','pressed']) {
    const name=`assets/ui_native/modal_${size}_r${race}_${state}.png`;
    if (!fs.existsSync(path.join(ROOT,name))) throw Error('Missing native popup button: '+name);
    const header=Buffer.alloc(24),file=fs.openSync(path.join(ROOT,name),'r');
    fs.readSync(file,header,0,24,0);fs.closeSync(file);
    const dimensions=size.split('x').map(Number);
    if (header.toString('ascii',1,4)!=='PNG' || header.readUInt32BE(16)!==dimensions[0] || header.readUInt32BE(20)!==dimensions[1]) throw Error('Wrong native popup PNG dimensions: '+name);
  }
  const artPaths = new Set();
  function visitArt(value) {
    if (typeof value === 'string' && value.startsWith('res://assets/')) artPaths.add(value.slice(6));
    else if (Array.isArray(value)) value.forEach(visitArt);
    else if (value && typeof value === 'object') Object.values(value).forEach(visitArt);
  }
  for (const name of fs.readdirSync(path.join(ROOT,'data')).filter(name=>name.endsWith('.json'))) visitArt(JSON.parse(fs.readFileSync(path.join(ROOT,'data',name),'utf8')));
  for (const relative of artPaths) validateAsset(relative,policy);
  const audio=validateAudio(policy),music=validateMusic(policy),motionCache=validateMotion(policy),construction=validateConstruction(policy);
  for (const name of RUNTIME_FILES) if (!fs.existsSync(path.join(ROOT,'runtime',name))) throw Error('Missing bundled Node runtime file: ' + name);
  const node = fs.openSync(path.join(ROOT,'runtime','node.exe'),'r');
  const magic = Buffer.alloc(2);
  fs.readSync(node,magic,0,2,0);
  fs.closeSync(node);
  if (magic.toString('ascii') !== 'MZ') throw Error('Bundled Node executable is not a Windows PE binary.');
  if (!fs.readFileSync(path.join(ROOT,'runtime','Node-LICENSE.txt'),'utf8').startsWith('Node.js is licensed for use as follows:')) throw Error('Missing complete Node.js license notice.');
  for (const name of ['README.md', 'GAME_DATA.md']) {
    if (fs.existsSync(path.join(ROOT,name)) && fs.readFileSync(path.join(ROOT,name),'utf8').includes('\uFFFD')) throw Error('Invalid UTF-8 text: '+name);
  }
  const motion = inventory(path.join(ROOT,'assets','motion')).filter(name=>name.endsWith('.png'));
  const registered=inventory(path.join(ROOT,'assets','registered_motion'),'assets/registered_motion').filter(name=>name.endsWith('.png'));
  for (const relative of registered) validateAsset(relative,policy);
  return {version:VERSION, windows:WINDOWS, godot:SOURCE, windows_zip:WINDOWS_ZIP, godot_zip:SOURCE_ZIP, units:data.units.flat().length, technical_citrus_brood:1, buildings:data.buildings.flat().length, maps:data.maps.length, default_resources:{as:maps.resources.as.initial_amount,tera:maps.resources.tera.initial_amount}, metadata_art_paths:artPaths.size, catalogs:catalogs.length, native_popup_frames:36, audio, music_tracks:music.length, music, motion:motion.length, motion_cache:motionCache, registered_motion:registered.length, construction_frames:construction, fonts, font_licenses:FONTS.map(font=>font.notice), node:fs.readFileSync(path.join(ROOT,'runtime','Node-VERSION.txt'),'utf8').split(/\r?\n/)[0]};
}

function validateReleaseTree(directory) {
  if (!fs.existsSync(directory)) return;
  function visit(current, prefix = '') {
    for (const item of fs.readdirSync(current,{withFileTypes:true})) {
      const relative = path.posix.join(prefix,item.name);
      if (!allowed(relative)) throw Error('Private data or generated output found in release stage: ' + relative);
      if (/^(?:assets\/)?music\/.*\.(?:wav|ogg|mp3)$/i.test(relative) && !fs.existsSync(path.join(ROOT,'assets','music',path.basename(relative)))) throw Error('Stale staged music is absent from the approved source: '+relative);
      if (item.isSymbolicLink()) throw Error('Release stage must not contain links: ' + relative);
      if (item.isDirectory()) visit(path.join(current,item.name),relative);
    }
  }
  visit(directory);
}

function stage() {
  const description = validate();
  for (const name of ['AsteraCraft.exe', 'AsteraCraft.pck']) if (!fs.existsSync(path.join(ROOT,'build',name))) throw Error('Export the game before staging: build/' + name);
  fs.mkdirSync(OUT,{recursive:true});
  validateReleaseTree(WINDOWS);
  validateReleaseTree(SOURCE);
  // The release owner reviews GAME_DATA.md before staging. Do not silently
  // regenerate and overwrite that reviewed document during a file copy.
  fs.mkdirSync(WINDOWS,{recursive:true});
  fs.mkdirSync(SOURCE,{recursive:true});
  for (const name of ['README.md', 'GAME_DATA.md', 'RELEASE_NOTES.md', 'Start_Server.cmd', 'network.example.json']) {
    copyFile(path.join(ROOT,name),path.join(WINDOWS,name));
    copyFile(path.join(ROOT,name),path.join(SOURCE,name));
  }
  for (const name of ['AsteraCraft.exe', 'AsteraCraft.pck']) copyFile(path.join(ROOT,'build',name),path.join(WINDOWS,name));
  copyFile(path.join(ROOT,'server','server.js'),path.join(WINDOWS,'server','server.js'));
  for (const name of RUNTIME_FILES) {
    copyFile(path.join(ROOT,'runtime',name),path.join(WINDOWS,'runtime',name));
    copyFile(path.join(ROOT,'runtime',name),path.join(SOURCE,'runtime',name));
  }
  copyTree(path.join(ROOT,'build','licenses'),path.join(WINDOWS,'licenses'));
  copyTree(path.join(ROOT,'build','licenses'),path.join(SOURCE,'licenses'));
  for (const font of FONTS) for (const destination of [WINDOWS,SOURCE]) copyFile(path.join(ROOT,'assets','fonts',font.license),path.join(destination,'licenses',font.notice));
  const musicInstructions=path.join(ROOT,'assets','music','README.txt');
  if (fs.existsSync(musicInstructions)) copyFile(musicInstructions,path.join(WINDOWS,'music','README.txt'));
  for (const name of fs.readdirSync(ROOT)) {
    if (['project.godot','main.tscn','export_presets.cfg','.gitignore'].includes(name) || /^tools_.*\.(?:js|cjs|mjs|gd|gd\.uid)$/.test(name)) copyFile(path.join(ROOT,name),path.join(SOURCE,name));
  }
  for (const folder of SOURCE_FOLDERS) copyTree(path.join(ROOT,folder),path.join(SOURCE,folder),folder);
  // Never stage live account records, active match configs, passwords or tokens.
  copyFile(path.join(ROOT,'server','server.js'),path.join(SOURCE,'server','server.js'));
  validateReleaseTree(WINDOWS);
  validateReleaseTree(SOURCE);
  for (const name of fs.readdirSync(path.join(ROOT,'build'))) if (/^preview-.*\.png$/.test(name)) copyFile(path.join(ROOT,'build',name),path.join(OUT,`v${VERSION}-${name}`));
  // Resource captures reflect the final backplate-only HUD; older UI fixtures
  // can have the superseded material overlay inside the information windows.
  for (let race=0;race<3;race++) {
    const current=path.join(ROOT,'build',`resources-race${race}-as.png`);
    if (fs.existsSync(current)) copyFile(current,path.join(OUT,`v${VERSION}-preview-race${race}.png`));
    const overview=path.join(ROOT,'build',`map-overview-${race}.png`);
    if (fs.existsSync(overview)) copyFile(overview,path.join(OUT,`v${VERSION}-map-overview-${race}.png`));
  }
  console.log(JSON.stringify({...description, staged:true},null,2));
}

if (require.main === module) {
  if (process.argv.includes('--check')) console.log(JSON.stringify(validate(),null,2));
  else if (process.argv.includes('--data-only')) {
    fs.writeFileSync(path.join(ROOT,'GAME_DATA.md'),renderGameData(readData()),'utf8');
    console.log(`Updated GAME_DATA.md v${VERSION}`);
  } else stage();
}
module.exports = {VERSION, allowed, inventory, renderGameData, matchesFilter, exportPolicy, runtimeCatalogs, validateAsset, validateFonts, validateMotion, validateConstruction, validateAudio, validateMusic, validate, validateReleaseTree, stage};
