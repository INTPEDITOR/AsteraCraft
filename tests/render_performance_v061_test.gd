extends "res://tests/view_input_v03_test.gd"
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/render_profile_main_v061.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	main._start_local({"map":0,"seed":611,"spawn_slots":[0,2],"players":[{"race":0},{"race":1}]})
	main.set_process(false);main.paused=false
	var c=main.core;var home=c.center(c.entity(c.players[0].home));var enemy_home=c.center(c.entity(c.players[1].home))
	var reports=[]
	for scenario in ["small","hidden_200","visible_200","battle_200"]:
		if scenario=="hidden_200":
			for i in range(200):
				var u=c.add_unit(1,[1,2,3,7,10][i%5],enemy_home+Vector2(i%15-7,8+i/15));u.hp=100000
		if scenario=="visible_200":main.spectator=true;main.camera=enemy_home+Vector2(0,10)
		if scenario=="battle_200":
			var p=Vector2(64,64)
			for i in range(100):
				var u=c.add_unit(0,[1,2,5,6,13][i%5],p+Vector2(i%10-10,i/10));u.hp=100000;u.order="attack_move";u.goal=[66,64]
			var n=0
			for u in c.units:
				if int(u.owner)==1 and int(u.kind)!=0:
					u.pos=ACData.packed(c.unit_free_position(1,int(u.kind),p+Vector2(3+n%10,n/10),int(u.id)));u.order="attack_move";u.goal=[62,64];n+=1
			main.camera=p;c.collision_index_valid=false
		c._update_vision();main.draw_timings.clear();var timings=[];var simulation=[];var presentation=[];var terrain=[]
		for frame in range(150):
			var begin=Time.get_ticks_usec();var sim=begin
			if frame%3==0:c.step(.05);c.resolve_spells()
			simulation.append((Time.get_ticks_usec()-sim)/1000.0)
			var present=Time.get_ticks_usec()
			main.state=c.snapshot(-1 if main.spectator else 0,true);main._accept_visual_snapshot(main.state.units,c.time)
			main.audio.process_state(main.state,0,main.camera,main.zoom);main._update_visual_motion(.0167);main._sync_world_canvas()
			if frame%12==0:main._update_hud()
			presentation.append((Time.get_ticks_usec()-present)/1000.0)
			await process_frame
			if frame>29:
				timings.append((Time.get_ticks_usec()-begin)/1000.0);terrain.append(float(main.terrain_artist.last_stats.get("draw_cpu_ms",0)))
		var total=0.0;for t in timings:total+=t
		timings.sort();simulation.sort();presentation.sort();terrain.sort()
		reports.append({"scenario":scenario,"units":c.units.size(),"mean_frame_ms":total/timings.size(),"p95_frame_ms":timings[113],"sim_p95_ms":simulation[142],"presentation_p95_ms":presentation[142],"terrain_p95_ms":terrain[113],"draw":main.draw_timings.duplicate(true)})
		print("RENDER_CASE ",JSON.stringify(reports.back()))
	FileAccess.open("res://build/qa-v061-render-performance.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	main.queue_free();await frames(2);quit()
