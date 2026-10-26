const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback13_20261026'),driver=path.join(out,'pack-probe.gd'),log=path.join(out,'pack-probe.log');
const debug='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';fs.mkdirSync(path.dirname(path.join(out,debug)),{recursive:true});fs.copyFileSync(path.join(root,debug),path.join(out,debug));
fs.writeFileSync(driver,`extends SceneTree
func _initialize():
 var d=ACData.get_data()
 assert(d.version=="0.6.7")
 assert(JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json")).tag=="feedback13-20261026")
 assert(ACData.unit(0,13).damage==10 and ACData.unit(1,3).hp==290 and is_equal_approx(ACData.unit(1,7).range,6.3) and ACData.unit(2,1).as==110)
 var difficulty=load("res://scripts/bot_difficulty.gd")
 assert(difficulty.APM==[50,100,150,200,250,300] and difficulty.SUPPLY==[50,80,120,160,180,200])
 assert(difficulty.workers(0,16,1)==8 and difficulty.workers(5,16,1)==16)
 assert(ACCore.AS_AMOUNT==8 and ACCore.TERA_AMOUNT==12 and ACCore.TERA_INTERVAL==2.5)
 assert(ACData.unit(2,7).hp==100 and ACData.unit(2,7).shield==280 and ACData.unit(2,7).max_shield_hit_damage==25)
 assert(ACData.unit(0,3).ranged_damage_reduction==5)
 var c=ACCore.new()
 c.setup({"map":0,"players":[{"race":0},{"race":2}]})
 assert(c.units.size()>=8 and c.buildings.size()>=2)
 assert(load("res://scripts/bot_ai.gd").get_script_method_list().any(func(m):return str(m.name)=="research_infrastructure"))
 print("FEEDBACK13_PACK_READY")
 quit()
`);
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const r=cp.spawnSync(engine,['--headless','--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',log,'--script',driver],{cwd:out,windowsHide:true,timeout:90000,encoding:'utf8',env:{...process.env,APPDATA:path.join(out,'pack-appdata')}});
const text=String(r.stdout||'')+String(r.stderr||'');fs.writeFileSync(path.join(out,'pack-probe-output.txt'),text);
const passed=r.status===0&&text.includes('FEEDBACK13_PACK_READY')&&!/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed/.test(text);
fs.writeFileSync(path.join(out,'pack-result.json'),JSON.stringify({passed,exit_code:r.status,scope:'Final exported PCK loaded from its own folder; checks version, balances, difficulty goals, economy, shield mechanics and original-map core startup without source fallback.'},null,2));
console.log(JSON.stringify({passed,exit_code:r.status}));if(!passed){console.error(text.slice(-5000));process.exitCode=1;}
