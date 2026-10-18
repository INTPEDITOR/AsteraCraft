extends "res://tests/view_input_v03_test.gd"
func capture(file):
	main._sync_world_canvas();main.queue_redraw();await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)
func run():
	root.size=Vector2i(1600,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	for race in range(3):
		main._start_local({"map":race,"seed":413,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true;main.set_process(false);main.spectator=true;main.state=main.core.snapshot();main._update_hud()
		await capture("v058-map-r%d.png"%race)
		main.camera=Vector2(55,45);main._clamp_camera()
		await capture("v058-scenery-r%d.png"%race)
		main.core.units.clear();main.core.buildings.clear();main.core.map.reset_solids([])
		main.zoom=1.1;main.camera=Vector2(64,63);main._clamp_camera()
		for kind in range(13):
			var u=main.core.add_unit(0,kind,Vector2(51+kind%7*4,60+int(kind/7)*7));u.moving=true;u.action="walk";u.facing=[1,.5]
		main.state=main.core.snapshot()
		for phase in range(3):
			main.elapsed=phase*.07;main.visual_motion.clear()
			for u in main.state.units:main.visual_motion[int(u.id)]={"walking":true,"phase":float(phase),"pos":ACData.point(u.pos)}
			await capture("v058-motion-r%d-f%d.png"%[race,phase])
	print("VISUAL_V058 captured 3 maps and 9 movement frames");quit()
