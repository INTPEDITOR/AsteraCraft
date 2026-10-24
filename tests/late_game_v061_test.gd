extends SceneTree
var main: Control
func _initialize():call_deferred("run")
func frames(n=2):
	for i in range(n):await process_frame
func run():
	print("LATE_GAME_LOAD_BEGIN")
	root.size=Vector2i(1600,900)
	main=load("res://scripts/main.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	print("LATE_GAME_ART_LOADED")
	main.settings.edge_scroll=false
	main._start_local({"map":0,"seed":611,"spawn_slots":[0,2],"players":[{"race":0},{"race":1}]})
	main.paused=true;main.set_process(false);var c=main.core;var p=Vector2(64,64)
	print("LATE_GAME_MAP_LOADED")
	for i in range(200):
		var owner=i%2;var kind=[1,2,5,6,13][i%5] if owner==0 else [1,2,3,7,10][i%5]
		var u=c.add_unit(owner,kind,p+Vector2(i%10+(0 if owner==0 else 10)-10,i/10-10));u.hp=1000000;u.order="attack_move";u.goal=ACData.packed(p)
	var viewer=0 if "--player-fog" in OS.get_cmdline_user_args() else -1
	c.ai_clock=100000;c._update_vision();main.spectator=viewer<0;main.camera=p;main.state=c.snapshot(viewer);main._accept_visual_snapshot(main.state.units,c.time,true);main._start_simulation_worker()
	var windows={};var last_report=-1;var then=Time.get_ticks_usec();var max_cache=0;var submit=0
	while float(main.state.time)<1500:
		var packet=main.simulation_worker.poll()
		if not packet.is_empty():
			main.state=packet.state;main._accept_visual_snapshot(main.state.units,float(main.state.time))
			var minute=int(float(main.state.time)/60)
			if minute!=last_report:print("LATE_GAME_MINUTE ",minute," entities ",main.state.units.size());last_report=minute
			if main.state.ended:printerr("Unexpected battle end");break
		main.simulation_worker.submit(4,viewer)
		if viewer>=0:main.camera=p+Vector2(sin(submit*.003)*9,cos(submit*.003)*7)
		main.visual_clock+=1.0/144.0;main._update_visual_motion(1.0/144.0);main._sync_world_canvas();main.audio.process_state(main.state,0,main.camera,main.zoom)
		if submit%28==0:main._update_hud()
		submit+=1
		await process_frame
		var now=Time.get_ticks_usec();var ms=float(now-then)/1000.0;then=now
		var window=int(float(main.state.time)/300)
		if not windows.has(window):windows[window]=[]
		if float(main.state.time)>10:windows[window].append(ms)
	var result=[]
	for window in windows:
		var values: Array=windows[window]
		if values.size()<100:continue
		var sum=0.0;for value in values:sum+=value
		values.sort();result.append({"simulation_minutes_from":window*5,"samples":values.size(),"mean_fps":1000/(sum/values.size()),"p95_frame_ms":values[mini(values.size()-1,int(values.size()*.95))],"p99_frame_ms":values[mini(values.size()-1,int(values.size()*.99))],"sub_60_frames":values.filter(func(ms):return ms>1000.0/60).size()})
	main._stop_simulation_worker()
	var report={"duration":main.state.time,"player_fog":viewer>=0,"entities":c.units.size(),"visible_entities":main.state.units.size(),"viewport":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"render_nodes":main._entity_canvases.size(),"path_cache":c.path_cache.size(),"effects":c.effects.size(),"replay_recording_removed":not main.has_method("_encode_replay_frame"),"terrain_builds":main.terrain_artist.cache_builds,"windows":result}
	var file=OS.get_environment("ASTERA_PERFORMANCE_REPORT")
	if file=="":file="res://build/qa-v061-late-game-final.json"
	FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("LATE_GAME_V061 ",JSON.stringify(report))
	main.queue_free();await frames(2);quit(0 if float(report.duration)>=1500 and report.replay_recording_removed and report.path_cache<=1024 else 1)
