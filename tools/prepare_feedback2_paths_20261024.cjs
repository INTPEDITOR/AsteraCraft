const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback2_20261024');
const tracked=new Set(cp.execFileSync('git',['ls-files'],{cwd:root,encoding:'utf8'}).trim().split(/\r?\n/));
const selected=new Set(cp.execFileSync('git',['diff','--name-only'],{cwd:root,encoding:'utf8'}).trim().split(/\r?\n/).filter(Boolean));
function add(file){if(!fs.existsSync(path.join(root,file)))throw Error('Missing required source: '+file);selected.add(file);for(const suffix of ['.uid','.import'])if(fs.existsSync(path.join(root,file+suffix)))selected.add(file+suffix);}
function folder(file){for(const item of fs.readdirSync(path.join(root,file),{withFileTypes:true})){const name=file+'/'+item.name;if(item.isDirectory())folder(name);else if(!name.endsWith('.import'))add(name);}}
function read(file){return JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));}
function refs(value){if(typeof value==='string'&&value.startsWith('res://assets/'))add(value.slice(6));else if(Array.isArray(value))value.forEach(refs);else if(value&&typeof value==='object')for(const [key,item]of Object.entries(value))if(!['provenance','integration_provenance','sources','source','references','prompt','authoring'].includes(key))refs(item);}
const runtime={units:{},buildings:{},effects:{}};
for(let race=0;race<3;race++){const catalog=read('data/art_v062_race'+race+'.json');for(const section of ['units','buildings'])for(const [key,item]of Object.entries(catalog[section]||{}))if((item.status||'accepted')==='accepted')runtime[section][key]=item;}
for(const [key,item]of Object.entries(read('data/art_staged16_units.json').units))if(['accepted','applied_unreviewed'].includes(item.status))runtime.units[key]=item;
refs(runtime);refs(read('data/art_sprite_display_corrections_20261024.json'));refs(read('data/art_building_construction5.json'));refs(read('data/loading_art_20261024.json'));
for(const file of ['scripts/player_colors.gd','scripts/player_palette.gd','scripts/battle_loader.gd','scripts/loading_screen.gd','scripts/race_ui.gd','data/loading_art_20261024.json','docs/FEEDBACK_FIXES2_20261024.md','docs/balance-adjustments-20261024.json','docs/building-balance-20261024.json','tools/audit_expansion_spacing_20261024.cjs','tools/calibrate_worker_size_20261024.py','tools/calibrate_spitter_size_20261024.py','tools/clean_command_icon_cells_20261024.py','tools/review_loading_art_20261024.py','tools/register_approved_citrus_loading_art_20261024.py','tools/register_approved_loading_faction_20261024.py','tools/publish_feedback2_20261024.cjs','tools/prepare_feedback2_paths_20261024.cjs'])add(file);
for(const name of ['navigation_feedback','melee_follow','latest_visual_feedback','command_layout','balance_feedback','player_colors','highground_beam','icon_isolation','latest_ui_polish','loading_ui_feedback','loading_art_selection'])add('tests/'+name+'_20261024_test.gd');
add('tests/flame_palette_20261024_preview.gd');
add('tests/catalyst_fusion_20261024_preview.gd');
for(const file of fs.readdirSync(path.join(root,'docs')))if(/^loading-art-.*20261024\.json$/.test(file))add('docs/'+file);
folder('assets/ui/clean_icons_20261024');folder('assets/loading_art_20261024');folder('docs/verification_feedback2_20261024');
// Existing tracked dependencies need not be restaged unless modified.
const changed=new Set(cp.execFileSync('git',['diff','--name-only'],{cwd:root,encoding:'utf8'}).trim().split(/\r?\n/));
const paths=[...selected].filter(file=>!tracked.has(file)||changed.has(file)).sort();
fs.writeFileSync(path.join(out,'git-stage-paths.txt'),paths.join('\0')+'\0');
console.log(JSON.stringify({paths:paths.length,new_paths:paths.filter(file=>!tracked.has(file)).length,selected_runtime_dependencies:true,unrelated_drafts_excluded:true}));
