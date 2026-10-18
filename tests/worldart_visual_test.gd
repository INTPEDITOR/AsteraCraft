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
		await capture("worldart-start-%d.png"%race)
		main.camera=Vector2(55,45);main._clamp_camera()
		await capture("worldart-ground-%d.png"%race)
		# Inspect a real authored height boundary and shoreline, away from UI edges.
		for role in [1,2]:
			for i in range(30*128,100*128):
				var x=i%128;var y=i/128
				if x>25 and x<100 and main.core.map.visual_role(i)==role:
					main.camera=Vector2(x,y);main._clamp_camera();break
			await capture("worldart-%s-%d.png"%["cliff" if role==1 else "shore",race])
		main.zoom=2.0;main._clamp_camera()
		await capture("worldart-zoom-%d.png"%race)
	print("WORLDART_VISUAL captured starts ground cliffs and shores on all three maps");quit()
