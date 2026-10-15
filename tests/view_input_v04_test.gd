extends "res://tests/view_input_v03_test.gd"

func right_click(point: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await frames()

func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate();root.add_child(main)
	await frames(4)
	main._start_local({"map":0,"seed":223,"players":[{"race":0},{"race":1}]})
	main.paused=true;main.settings.edge_scroll=false;main.spectator=true
	await frames(3)
	var c=main.core
	var hq=c.buildings[0]
	var home=c.center(hq)
	var soldier=c.add_unit(0,1,home+Vector2(5,3))
	var destination=ACData.point(soldier.pos)+Vector2(3,1)
	main.state=c.snapshot();main.selected=[soldier.id];main._update_hud()
	await move_pointer(main._ground_point(destination));await press(KEY_A)
	check(main.attack_mode,"physical A arms attack")
	await click(main._ground_point(destination))
	check(soldier.order=="attack_move" and not main.attack_mode and not main.dragging,"A ground single click consumes target and issues attack move")
	main.selected=[hq.id];main._update_hud();await press(KEY_R)
	check(main.pointer_order=="rally","physical R arms rally")
	await click(main._ground_point(destination))
	check(ACData.point(hq.rally).distance_to(destination)<.03 and main.pointer_order=="","R ground single click exact rally")
	var second=destination+Vector2(-1,1)
	await right_click(main._ground_point(second))
	check(ACData.point(hq.rally).distance_to(second)<.03,"production building native right ground click sets rally")
	var mini=main._mini_rect()
	var mini_point=mini.position+mini.size*Vector2(.35,.6)
	var expected=Vector2(.35,.6)*128
	main.selected=[soldier.id];main._update_hud();await press(KEY_A);await click(mini_point)
	check(soldier.order=="attack_move" and ACData.point(soldier.goal).distance_to(expected)<.03,"A minimap single click issues exact attack move")
	check(not main.attack_mode and not main.dragging,"minimap attack consumes click")
	main.selected=[hq.id];main._update_hud();await press(KEY_R);await click(mini_point)
	check(ACData.point(hq.rally).distance_to(expected)<.03,"R minimap single click sets exact rally")
	await right_click(mini.position+mini.size*Vector2(.6,.35))
	check(ACData.point(hq.rally).distance_to(Vector2(.6,.35)*128)<.03,"production minimap right click sets rally")
	main.selected=[];await click(mini_point)
	check(main.camera.distance_to(expected)<.03,"normal minimap left click still moves camera")
	main._focus_home();main._sync_world_canvas();await frames(3)
	check(main._world_render_rect().position.y==0 and main.world_clip.get_global_rect().position.y==0,"world canvas includes former top black banner")
	await move_pointer(Vector2(500,20))
	check(main._can_point_world(Vector2(500,20)),"top terrain accepts world input outside resource counters")
	check(not main._can_point_world(Vector2(main.size.x-50,20)),"upper-right resource counters retain UI ownership")
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_cache_v04.json"))
	var roots=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_roots_v04.json"))
	check(roots.units["2:3"].source_columns[0]==10,"owl source actual ten columns are identified")
	var poses=0
	for race in range(3):
		for kind in range(13):
			var key="%d:%d"%[race,kind]
			var registered=ACData.point(catalog.units[key].packed_root)
			var cell=ACData.point(roots.units[key].packed_cell)
			var hint=-1.0
			for row in main.assets.motion_frames[key]:
				for frame in row:
					poses+=1
					var region: Rect2=frame.texture.region
					var in_cell=Vector2(fposmod(region.position.x,cell.x),fposmod(region.position.y,cell.y))
					check((frame.anchor+in_cell).distance_to(registered)<.01,"fixed body root survives alpha trim "+key)
					if hint<0:hint=frame.scale_hint
					check(is_equal_approx(hint,float(frame.scale_hint)),"frame scale stays constant "+key)
	check(poses==3510,"all39 units have90 registered cached poses")
	check(main.assets.brood_frames.size()==2 and main.assets.unit(1,13,Vector2.DOWN,"morph",.3).action=="morph","real brood idle/morph artwork loads")
	check(main.assets.cursor_frames.size()==9,"nine faction native cursor textures load")
	check(main.assets.tera_plumes.size()==8 and main.assets.citrus_fx.size()==6,"eight blue plume frames and six citrus projectile images load")
	var medical: Texture2D=main.assets.building(0,7)
	check(medical!=null and medical.get_width()>40 and medical.get_height()>40,"field medical building has a complete visible body texture")
	var max_error=0.0
	var occluded=0
	for map_index in range(3):
		main.draw_map.make(map_index)
		for y in range(6,123,5):
			for x in range(6,123,5):
				var point=Vector2(x+.17,y+.29)
				var screen: Vector2=main._ground_point(point)
				var hit: Vector2=main.screen_to_world(screen)
				max_error=maxf(max_error,main._ground_point(hit).distance_to(screen))
				if hit.distance_to(point)>.04:
					occluded+=1
					check(hit.y>point.y,"overlapping cliff rays choose the renderer's frontmost surface")
	check(max_error<.04,"shared elevated triangle inverse matches exact screen surface (max %.5f pixels)"%max_error)
	main.draw_map.make(0)
	var medic=c.add_unit(0,4,home+Vector2(2,4));medic.energy=84;medic.healing=true;medic.heal_started=c.time
	var field=c.add_building(0,7,home+Vector2(6,-2),true)
	main.state=c.snapshot();main.selected=[medic.id];main._update_hud();main._sync_world_canvas()
	await create_timer(.15).timeout;await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/view-input-v04.png")
	print("VIEW_INPUT_V04 checks=",checks," failures=",failures.size()," root_poses=",poses," inverse_error=",max_error," occluded_surface_points=",occluded)
	quit(0 if failures.is_empty() else 1)
