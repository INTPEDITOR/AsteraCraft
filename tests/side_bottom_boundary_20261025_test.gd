extends "res://tests/view_input_v03_test.gd"
var records=[]
func run():
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.set_process(false);main.set_process_input(false);main.set_process_unhandled_input(false)
	for connection in root.mouse_exited.get_connections():
		if connection.callable.get_object()==main:root.mouse_exited.disconnect(connection.callable)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(3)
	var out="res://build/camera-side-bottom-20261025/";DirAccess.make_dir_recursive_absolute(out)
	for map_id in range(3):
		for race in range(3):
			main._start_local({"map":map_id,"players":[{"race":race},{"race":(race+1)%3}]});main._stop_simulation_worker();main.set_process(false);main.paused=true;main.spectator=true;main.settings.edge_scroll=false
			main.state=main.core.snapshot();main._accept_visual_snapshot(main.state.units,main.core.time,true)
			for zoom in [1.0,1.75,2.5]:
				main.zoom=zoom
				for side in ["left","right","bottom","bottom_left","bottom_right"]:
					main.camera=Vector2(-10000 if side in ["left","bottom_left"] else 10000 if side in ["right","bottom_right"] else 64,10000 if side.begins_with("bottom") else 64)
					main._clamp_camera();main.battle_hud.update_hud(true);main._sync_world_canvas();main.queue_redraw();await frames(3)
					var origin=main.world_to_screen(Vector2.ZERO);var end=main.world_to_screen(Vector2.ONE*128);var bottom=main._camera_view_bottom()
					check(origin.x<=.01 and end.x>=main.size.x-.01,"no horizontal map void map%d race%d zoom%.1f %s"%[map_id,race,zoom,side])
					if side.begins_with("bottom"):
						check(end.y>=bottom+1.9 and end.y<=bottom+2.1,"bottom limit is two pixels behind HUD valley")
					var sampled=0;var black=0
					if is_equal_approx(zoom,1.0):
						await RenderingServer.frame_post_draw;var pixels=root.get_texture().get_image();var scale_value=Vector2(pixels.get_size())/main.size
						if side in ["left","right"]:
							var x=2 if side=="left" else main.size.x-3
							for y in range(60,490,16):
								var color=pixels.get_pixelv(Vector2i(Vector2(x,y)*scale_value));sampled+=1
								if maxf(color.r,maxf(color.g,color.b))<.002:black+=1
						else:
							for x in range(12,int(main.size.x)-12,24):
								var y=main.battle_hud.body_top_at(x)-3
								var color=pixels.get_pixelv(Vector2i(Vector2(x,y)*scale_value));sampled+=1
								if maxf(color.r,maxf(color.g,color.b))<.002:black+=1
						check(black==0,"native boundary pixels have terrain, map%d race%d %s black%d/%d"%[map_id,race,side,black,sampled])
						pixels.save_png(out+"map%d-race%d-%s.png"%[map_id,race,side])
					records.append({"map":map_id,"race":race,"zoom":zoom,"side":side,"map_left":origin.x,"map_right":end.x,"map_bottom":end.y,"hud_valley":bottom,"black":black,"samples":sampled})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records.size(),"records":records}
	FileAccess.open(out+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SIDE_BOTTOM_BOUNDARY ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures}));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
