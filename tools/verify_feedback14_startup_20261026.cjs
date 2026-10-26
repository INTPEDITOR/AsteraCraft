const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'build/feedback14_20261026'),driver=path.join(out,'startup-updater-probe.gd');
const debug='addons/webrtc_native/lib/libwebrtc_native.windows.template_debug.x86_64.dll';fs.mkdirSync(path.dirname(path.join(out,debug)),{recursive:true});if(!fs.existsSync(path.join(out,debug)))fs.copyFileSync(path.join(root,debug),path.join(out,debug));
fs.writeFileSync(driver,`extends SceneTree
func _initialize():call_deferred("run")
func run():
 var started=Time.get_ticks_msec()
 var screen=load("res://startup.tscn").instantiate()
 root.add_child(screen);current_scene=screen
 while not screen.ready_to_start and Time.get_ticks_msec()-started<90000:await process_frame
 if not screen.ready_to_start:push_error("Title preparation timeout");quit(1);return
 var main=screen.prepared_main
 var service=main.game_updater
 var idle_before_activation=service!=null and service.state=="idle" and service.request==null and not service.checked
 service.install_enabled=true;service._auto_check_pending=true
 var hub=main.ui.get_node_or_null("MainHub")
 if hub.update_panel==null:hub._build_update_panel();hub._layout()
 screen._enter_main()
 var entered=Time.get_ticks_msec()
 while service.state in ["idle","checking"] and Time.get_ticks_msec()-entered<30000:await process_frame
 var result={"passed":idle_before_activation and current_scene==main and service.state=="current" and service.request==null and hub.update_button.text=="최신 버전" and not hub.update_button.disabled,"version":ProjectSettings.get_setting("application/config/version"),"idle_before_activation":idle_before_activation,"state":service.state,"button":hub.update_button.text,"check_msec":Time.get_ticks_msec()-entered,"total_msec":Time.get_ticks_msec()-started,"scope":"Final exported PCK in same-version editor-capable engine, normal logo/title preparation and reparent, Windows updater gate enabled, live public HTTPS feed and real hub button. Shipping EXE checked separately; no skip-intro shortcut in this test."}
 print("STARTUP_UPDATER ",JSON.stringify(result));quit(0 if result.passed else 1)
`);
const started=Date.now();
const engine=path.resolve(root,'../tools/godot/Godot_v4.6-stable_win64_console.exe');
const p=cp.spawn(engine,['--headless','--path',out,'--main-pack',path.join(out,'AsteraCraft.pck'),'--log-file',path.join(out,'startup-updater.log'),'--script',driver],{cwd:out,windowsHide:true,env:{...process.env,APPDATA:path.join(out,'startup-appdata')},stdio:['ignore','pipe','pipe']});
let output='';p.stdout.on('data',d=>output+=d);p.stderr.on('data',d=>output+=d);
const timer=setTimeout(()=>{p.kill();console.error('Startup/update probe timed out');},125000);
p.on('error',e=>{clearTimeout(timer);console.error(e.message);process.exitCode=1;});
p.on('exit',code=>{
 clearTimeout(timer);fs.writeFileSync(path.join(out,'startup-updater-output.txt'),output);
 const match=output.match(/STARTUP_UPDATER (\{[^\r\n]+\})/);const report=match?JSON.parse(match[1]):{passed:false};
 report.passed=report.passed&&code===0&&!/SCRIPT ERROR|Parse Error|ERROR:/.test(output);report.exit_code=code;report.elapsed_ms=Date.now()-started;
 fs.writeFileSync(path.join(out,'startup-result.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
 if(!report.passed){console.error(output.slice(-5000));process.exitCode=1;}
});
