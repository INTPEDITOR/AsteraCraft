extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/camera-edges-20261024/"
func photograph(name: String) -> Image:
	main._sync_world_canvas();main.battle_hud.update_hud(true);await frames(3);await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();image.save_png(OUT+name+".png");return image
func legacy_limit(x: float,south: bool) -> Vector2:
	var centre=main._view_rect().get_center();var low=centre/(32*main.zoom)
	var high=Vector2.ONE*ACMap.SIZE-(main.size-centre)/(32*main.zoom)
	high.y=ACMap.SIZE-(main.battle_hud.shell_draw_rect().position.y-centre.y)/(32*main.zoom)
	return Vector2(x,10000 if south else -10000).clamp(low,high)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect();main.set_process(false);await frames(3)
	var report=[]
	for map_index in range(3):
		for race in range(3):
			main._start_local({"map":map_index,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false);main.spectator=true;main.state=main.core.snapshot();main.settings.edge_scroll=false
			main.status_text="";main.status_until=-1;main._update_hud()
			for south in [false,true]:
				main.zoom=1.75;main.camera=legacy_limit(103,south)
				var prefix="m%d-r%d-%s"%[map_index,race,"south" if south else "north"]
				if map_index==0 and race==0:await photograph(prefix+"-before")
				main.camera=Vector2(103,10000 if south else -10000);main._clamp_camera()
				var image=await photograph(prefix+"-after");var black=0;var samples=0;var black_points=[]
				for x in range(4,1596,4):
					var y=floori(main.battle_hud.body_top_at(x))-3 if south else 1
					if y<0 or y>=image.get_height():continue
					var pixel=image.get_pixel(x,y);samples+=1
					if maxf(pixel.r,maxf(pixel.g,pixel.b))<.001:
						black+=1
						if black_points.size()<16:black_points.append(Vector2i(x,y))
				check(black==0,"no exposed black perimeter "+prefix+" pixels="+str(black))
				report.append({"map":map_index,"race":race,"south":south,"black_pixels":black,"black_points":black_points,"samples":samples,"camera":str(main.camera)})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screens":report}
	FileAccess.open(OUT+"visual.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("CAMERA_EDGES_VISUAL ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
