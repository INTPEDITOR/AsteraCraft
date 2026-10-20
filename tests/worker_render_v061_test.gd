extends "res://tests/view_input_v03_test.gd"
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/render_profile_main_v061.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	main._start_local({"map":0,"seed":611,"spawn_slots":[0,2],"players":[{"race":0},{"race":1}]})
	main.paused=true;main.set_process(false);var c=main.core
	var p=Vector2(64,64)
	for i in range(200):
		var owner=i%2;var kind=[1,2,5,6,13][i%5] if owner==0 else [1,2,3,7,10][i%5]
		var u=c.add_unit(owner,kind,p+Vector2((i%10)+(0 if owner==0 else 10)-10,i/10-10));u.hp=100000;u.order="attack_move";u.goal=ACData.packed(p)
	c._update_vision();main.spectator=true;main.camera=p;main.state=c.snapshot(-1);main._accept_visual_snapshot(main.state.units,c.time,true)
	main._start_simulation_worker();var samples=[];var cpu=[];var reports=[]
	for scenario in ["battle","click_spam"]:
		samples=[];cpu=[];main.draw_timings.clear()
		for frame in range(300):
			var begin=Time.get_ticks_usec()
			if scenario=="click_spam" and frame%2==0:
				main.simulation_worker.command(0,{"type":"move","ids":main.state.units.filter(func(u):return int(u.owner)==0).slice(0,12).map(func(u):return u.id),"pos":ACData.packed(p+Vector2(sin(frame)*8,cos(frame)*8)),"target":-1,"formation":true})
			main._process_simulation_worker(1.0/144.0)
			main._update_visual_motion(1.0/144.0);main._sync_world_canvas();main.audio.process_state(main.state,0,main.camera,main.zoom)
			if frame%28==0:main._update_hud()
			cpu.append((Time.get_ticks_usec()-begin)/1000.0)
			await process_frame
			if frame>59:samples.append((Time.get_ticks_usec()-begin)/1000.0)
		var sum=0.0;for value in samples:sum+=value
		samples.sort();cpu.sort();reports.append({"scenario":scenario,"mean_frame_ms":sum/samples.size(),"p95_frame_ms":samples[227],"cpu_p95_ms":cpu[284],"draw":main.draw_timings.duplicate(true)})
		print("WORKER_RENDER ",JSON.stringify(reports.back()))
	main._stop_simulation_worker();FileAccess.open("res://build/qa-v061-worker-render.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	main.queue_free();await frames(2);quit()
