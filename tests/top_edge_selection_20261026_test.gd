extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/top-edge-selection-20261026/"
var records=[]

func refresh_view() -> void:
	main.state=main.core.snapshot(0)
	main._accept_visual_snapshot(main.state.units,main.core.time,true)
	main.battle_hud.update_hud(true)
	main._sync_world_canvas();main.queue_redraw()
	await frames(5)

func double_click(point: Vector2) -> void:
	await move_pointer(point)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.double_click=true
	Input.parse_input_event(event);await frames(2)
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(2)

func unit_at(owner: int,kind: int,point: Vector2) -> Dictionary:
	var unit=main.core.add_unit(owner,kind,point)
	# The fixture deliberately places artwork at the perimeter, independently
	# of unrelated pathfinding/terrain collision. No simulation step is run.
	unit.pos=ACData.packed(point);unit.goal=unit.pos.duplicate()
	return unit

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	if DisplayServer.get_name()=="headless":
		check(false,"rendered edge selection fixture needs a graphical renderer");finish();return
	main=load("res://main.tscn").instantiate();root.add_child(main)
	await frames(4)
	main.set_process(false);main.settings.edge_scroll=false
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect();await frames(3)
	for race in range(3):
		main._start_local({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		main._stop_simulation_worker();main.set_process(false);main.paused=true;main.settings.edge_scroll=false
		var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		for mask in c.visibility:mask.fill(2)
		for mask in c.explored:mask.fill(2)
		var x=64.0;var highest=-INF
		for candidate in [28.0,40.0,52.0,64.0,76.0,88.0,100.0]:
			var height=c.map.visual_elevation(Vector2(candidate,.55))
			if height>highest:x=candidate;highest=height
		var first=unit_at(0,1,Vector2(x-2,.2))
		var second=unit_at(0,1,Vector2(x+2,.2))
		var enemy=unit_at(1,1,Vector2(x+6,.2))
		for zoom_value in [1.0,1.75]:
			var label="race%d map%d zoom%.2f"%[race,race,zoom_value]
			main.zoom=zoom_value;main.camera=Vector2(x,-10000);main._clamp_camera()
			main.render_rects.clear();main._selection_bodies.clear();main.selected=[]
			await refresh_view()
			# First render gives camera the true sprite hull/health-bar overhang.
			main.camera.y=-10000;main._clamp_camera();await refresh_view()
			var first_point=main._selection_center(first)
			var second_point=main._selection_center(second)
			var enemy_point=main._selection_center(enemy)
			var flat_north=main.world_to_screen(Vector2.ZERO).y
			check(first_point.y<flat_north,"body lies above old flat input boundary "+label)
			check(main._world_render_rect().has_point(first_point) and main.render_rects.has(int(first.id)),"actual rendered top body is inside the viewport "+label)
			await move_pointer(first_point)
			check(main._can_point_world(first_point),"visible top body accepts world input "+label)
			await click(first_point)
			check(main.selected==[first.id],"actual left click selects northern body "+label)
			main.selected=[]
			var from=first_point+Vector2(-5,-5)
			var to=first_point+Vector2(6,6)
			await move_pointer(from);await drag(from,to)
			check(first.id in main.selected,"actual drag overlap selects northern body "+label)
			main.selected=[];await double_click(first_point)
			check(first.id in main.selected and second.id in main.selected and enemy.id not in main.selected,"double click includes both own top units and excludes enemy "+label)
			main.selected=[first.id];main.selected_resource=-1;main.attack_mode=true;main.pointer_order=""
			await move_pointer(enemy_point);await click(enemy_point)
			check(first.order=="attack" and int(first.target)==int(enemy.id) and not main.attack_mode,"actual attack click targets northern enemy "+label)
			main.selected=[]
			var bottom=Vector2(main.size.x*.5,main.size.y-4)
			await move_pointer(bottom)
			check(not main._can_point_world(bottom),"bottom painted HUD still blocks world input "+label)
			records.append({"race":race,"map":race,"zoom":zoom_value,"flat_north_y":flat_north,"body_center":ACData.packed(first_point),"elevation":c.map.visual_elevation(ACData.point(first.pos))})
			if zoom_value==1.75:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"race%d-north.png"%race)
		# Display-only upper resource counters must not consume unit selection.
		var centre=main._selection_center(first)
		var desired=Vector2(main.size.x-250,20)
		main.camera+=(centre-desired)/(32*main.zoom)
		await refresh_view();centre=main._selection_center(first)
		await move_pointer(centre)
		check(centre.y<42 and centre.x>main.size.x-470 and main._can_point_world(centre),"resource readout passes input through to visible unit race%d"%race)
		await click(centre)
		check(main.selected==[first.id],"actual click below resource readout selects unit race%d"%race)
		# Shift the central body just above the viewport while retaining a
		# visible strip; drag selection must use the visible overlap.
		main.camera.y+=(centre.y+1)/(32*main.zoom)
		await refresh_view()
		centre=main._selection_center(first)
		var body: Rect2=main._selection_bodies.get(first.id,main.render_rects.get(first.id,Rect2()))
		var visible_centre=Rect2(centre-body.size*.3,body.size*.6).intersection(main._world_render_rect())
		check(centre.y<0 and visible_centre.has_area(),"partial top body fixture has offscreen center and visible body race%d"%race)
		check(main._drag_hits_unit(visible_centre,first),"drag includes partial visible body with offscreen center race%d"%race)
		main.selected=[]
		var start=Vector2(centre.x-5,1)
		var end=Vector2(centre.x+6,minf(visible_centre.end.y-.2,12))
		await move_pointer(start);await drag(start,end)
		check(first.id in main.selected,"actual drag selects partial top body race%d"%race)
		# Hidden opponents stay unselectable even if stale render bounds exist.
		for mask in c.visibility:mask.fill(0)
		for mask in c.aerial_visibility:mask.fill(0)
		main.state=c.snapshot();main.spectator=false
		check(not main._visible(enemy) and main._hit_test(main._selection_center(enemy))!=enemy.id,"hidden enemy cannot be selected by overhang fallback race%d"%race)
		check(not main._drag_hits_unit(main._world_render_rect(),enemy),"hidden enemy cannot enter drag or double selection race%d"%race)
		# Deliberately expose side void, independently of camera clamping.
		main.camera=Vector2(0,20);main._sync_world_canvas();await frames(2)
		var outside=Vector2(main.world_to_screen(Vector2.ZERO).x-5,150)
		check(main._world_render_rect().has_point(outside) and not main._world_visible_at(outside),"left map void remains unclickable race%d"%race)
	finish()

func finish() -> void:
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records,"scope":"Actual rendered faction sprites and HUD, native input events, three original maps, two zoom levels, controlled stationary perimeter placement; no movement simulation"}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TOP_EDGE_SELECTION ",JSON.stringify(result))
	if is_instance_valid(main):main._release_pointer()
	quit(0 if failures.is_empty() else 1)
