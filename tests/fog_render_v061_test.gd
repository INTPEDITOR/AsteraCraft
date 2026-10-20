extends "res://tests/view_input_v03_test.gd"
func run():
	root.size=Vector2i(1440,900)
	# Verify shader mask levels before using real game visibility.
	var backdrop=ColorRect.new();backdrop.color=Color.WHITE;backdrop.size=Vector2(128,128);root.add_child(backdrop)
	var fog=ACFogCanvas.new();root.add_child(fog)
	var vis=PackedByteArray();vis.resize(16384);var seen=vis.duplicate()
	for y in range(128):
		for x in range(128):
			vis[y*128+x]=1 if x<42 else 0;seen[y*128+x]=1 if x<84 else 0
	fog.update_masks(vis,seen,1,Rect2(0,0,128,128),Rect2(0,0,128,128));await frames(4)
	var pixels=root.get_texture().get_image()
	check(pixels.get_pixel(20,60).r>.95,"visible fog pixels remain bright")
	check(pixels.get_pixel(60,60).r>.25 and pixels.get_pixel(60,60).r<.4,"explored fog pixels have correct dimming")
	check(pixels.get_pixel(110,60).r<.02,"unexplored fog pixels stay black")
	fog.update_masks(vis,seen,1,Rect2(0,0,128,128),Rect2(0,0,128,128));check(fog.uploads==1,"unchanged masks do not upload again")
	fog.queue_free();backdrop.queue_free();await frames(2)
	main=load("res://tests/render_profile_main_v061.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":611,"players":[{"race":0},{"race":1}]})
	main.paused=true;main.set_process(false);main.settings.edge_scroll=false
	var c=main.core;var home=ACData.point(c.map.starts[0]);var army=[]
	for i in range(200):
		var u=c.add_unit(i%2,1,home+Vector2((i%10)+4,i/10));u.hp=100000;u.order="hold";army.append(u.id)
	var scout=c.add_unit(0,8,home+Vector2(4,5));c.ai_clock=100000
	c._update_vision();main.state=c.snapshot(0);main._accept_visual_snapshot(main.state.units,c.time,true);main._start_simulation_worker()
	var reports=[]
	for scenario in ["player_fog_stationary","explore_and_pan","enemy_hidden"]:
		var values=[];var cpu=[];var uploads_before=main._fog_canvas.uploads;var builds_before=main.terrain_artist.cache_builds
		for frame in range(720):
			var begin=Time.get_ticks_usec()
			if scenario=="explore_and_pan":
				main.camera=home+Vector2(12+sin(frame*.02)*12,10+cos(frame*.017)*9)
				if frame%30==0:main.simulation_worker.command(0,{"type":"move","ids":[scout.id],"pos":ACData.packed(home+Vector2(10+sin(frame*.02)*12,10+cos(frame*.02)*12))})
			elif scenario=="enemy_hidden":
				main.camera=home
				if frame%30==0:main.simulation_worker.command(1,{"type":"move","ids":army.filter(func(id):return id%2==1),"pos":[90,90]})
			main._process_simulation_worker(1.0/144.0);main._update_visual_motion(1.0/144.0);main._sync_world_canvas();main.audio.process_state(main.state,0,main.camera,main.zoom)
			if frame%28==0:main._update_hud()
			cpu.append((Time.get_ticks_usec()-begin)/1000.0)
			await process_frame
			if frame>119:values.append((Time.get_ticks_usec()-begin)/1000.0)
		var sum=0.0;for value in values:sum+=value
		values.sort();cpu.sort()
		reports.append({"scenario":scenario,"mean_fps":1000/(sum/values.size()),"p95_frame_ms":values[int(values.size()*.95)],"p99_frame_ms":values[int(values.size()*.99)],"cpu_p95_ms":cpu[int(cpu.size()*.95)],"terrain_builds":main.terrain_artist.cache_builds-builds_before,"fog_uploads":main._fog_canvas.uploads-uploads_before})
		print("FOG_RENDER_V061 ",JSON.stringify(reports.back()))
		check(main.terrain_artist.cache_builds==1,"camera and fog changes never rebuild terrain mesh "+scenario)
	main._stop_simulation_worker()
	root.get_texture().get_image().save_png("res://build/qa-v061-fog-game.png")
	FileAccess.open("res://build/qa-v061-fog-render.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scenarios":reports},"  "))
	main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
