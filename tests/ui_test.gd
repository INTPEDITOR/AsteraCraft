extends SceneTree

var main: Control
var failures: Array=[]
var checks=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func frames(n: int=3) -> void:
	for i in range(n):await process_frame

func click(point: Vector2, button: int=MOUSE_BUTTON_LEFT) -> void:
	var e=InputEventMouseButton.new()
	e.position=point
	e.global_position=point
	e.button_index=button
	e.pressed=true
	Input.parse_input_event(e)
	await frames(2)
	e=e.duplicate()
	e.pressed=false
	Input.parse_input_event(e)
	await frames(2)

func keypress(code: Key) -> void:
	var e=InputEventKey.new()
	e.keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	await frames(2)
	e=e.duplicate()
	e.pressed=false
	Input.parse_input_event(e)
	await frames(2)

func visible_cells(near: Vector2, margin: float=30) -> Array:
	var cells: Array=[]
	var view: Rect2=main._view_rect().grow(-margin)
	for y in range(1,ACMap.SIZE-1):
		for x in range(1,ACMap.SIZE-1):
			var p=Vector2(x,y)
			if main.core.map.walkable(Vector2i(p)) and view.has_point(main._ground_point(p)):
				cells.append(p)
	cells.sort_custom(func(a,b):return a.distance_squared_to(near)<b.distance_squared_to(near))
	return cells

func empty_click_target(near: Vector2) -> Vector2:
	for cell in visible_cells(near):
		var screen: Vector2=main._ground_point(cell)
		var actual: Vector2=main.screen_to_world(screen)
		var tile=Vector2i(actual.round())
		if not main.core.map.walkable(tile):continue
		if main._fog_value(tile.y*ACMap.SIZE+tile.x)!=2:continue
		if main._context_target(screen,actual)>=0:continue
		if actual.distance_to(ACData.point(main.core.units[0].pos))<2:continue
		return screen
	return Vector2.INF

func stage_building(kind: int, near: Vector2) -> Dictionary:
	var c=main.core
	var definition=ACData.building(int(c.players[0].race),kind)
	for pos in visible_cells(near,40):
		var footprint=Rect2(pos,Vector2(definition.w,definition.h))
		var valid=true
		for x in range(int(pos.x),int(footprint.end.x)):
			for y in range(int(pos.y),int(footprint.end.y)):
				var tile=Vector2i(x,y)
				if not c.map.walkable(tile) or not c.map.buildable(tile):valid=false
				if not main._view_rect().grow(-20).has_point(main._ground_point(Vector2(tile))):valid=false
		if not valid:continue
		for resource in c.map.resources:
			if footprint.grow(1.4).has_point(ACData.point(resource.pos)):valid=false
		for unit in c.units:
			if unit.owner==0 and footprint.grow(.8).has_point(ACData.point(unit.pos)):valid=false
		if not valid:continue
		var building=c.add_building(0,kind,pos,true)
		c.map.reset_solids(c.buildings)
		return building
	return {}

func stage_unit(kind: int, near: Vector2) -> Dictionary:
	var c=main.core
	var definition=ACData.unit(int(c.players[0].race),kind)
	for pos in visible_cells(near,35):
		var valid=true
		for resource in c.map.resources:
			if pos.distance_to(ACData.point(resource.pos))<1.8:valid=false
		for other in c.units:
			var od=ACData.unit(int(other.race),int(other.kind))
			var spacing=maxf(2.1,float(definition.size)*(.95 if definition.air else .72)+float(od.size)*(.95 if od.air else .72))
			if other.owner==0 and pos.distance_to(ACData.point(other.pos))<spacing:valid=false
		for building in c.buildings:
			if c.footprint_distance(building,pos)<float(definition.size)*.4:valid=false
		if not valid:continue
		var unit=c.add_unit(0,kind,pos)
		unit.order="hold"
		return unit
	return {}

func capture(file: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)

func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	check(main.page=="main","initial menu")
	await capture("preview-menu.png")
	main._start_local({"map":0,"players":[{"race":0},{"race":1,"bot":true}]})
	main.paused=true
	main.settings.edge_scroll=false
	await frames()
	var worker=main.core.units[0]
	var wp=main._ground_point(ACData.point(worker.pos))
	await click(wp)
	check(worker.id in main.selected,"mouse selects worker at its ground-contact anchor")
	var target=empty_click_target(ACData.point(worker.pos)+Vector2(5,1))
	check(target.is_finite(),"visible empty walkable command destination exists")
	if not target.is_finite():quit(1);return
	var expected_goal: Vector2=main.screen_to_world(target)
	await click(target,MOUSE_BUTTON_RIGHT)
	check(worker.order=="move","right click issues move")
	check(ACData.point(worker.goal).distance_to(expected_goal)<.01,"right click maps to the intended ground destination")
	main.selected=[worker.id]
	await keypress(KEY_B)
	check(main.build_panel,"B opens construction")
	var hq=main.core.buildings[0]
	main.build_panel=false
	main.pointer_order=""
	await click(main._ground_point(main.core.center(hq)))
	check(hq.id in main.selected,"mouse selects headquarters")
	main.core.players[0].as=1000
	main._send_command({"type":"train","id":hq.id,"kind":0})
	check(hq.queue.size()==1,"production command through UI")
	for race in range(3):
		main._start_local({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true
		main.settings.edge_scroll=false
		var c=main.core
		var start=ACData.point(c.map.starts[0])
		main.camera=start+Vector2(4,1)
		# Stage a populated base on valid ground without changing production data.
		# Four ordinary supply structures keep every showcased army below its cap.
		var kinds=[2,2,2,2,3,4,11]
		var offsets=[Vector2(-6,-4),Vector2(-6,-1),Vector2(-6,3),Vector2(-3,6),Vector2(4,-4),Vector2(7,5),Vector2(11,-1)]
		for i in range(kinds.size()):
			var building=stage_building(kinds[i],start+offsets[i])
			check(not building.is_empty(),"valid preview building %d, race %d"%[i,race])
		var army: Array=[]
		for kind in range(1,13):
			var preferred=start+Vector2(4+(kind%4)*2.6,2+int(kind/4)*2.3)
			var unit=stage_unit(kind,preferred)
			check(not unit.is_empty(),"valid preview unit %d, race %d"%[kind,race])
			if not unit.is_empty():army.append(int(unit.id))
		c._update_vision()
		c._recalculate_supply()
		main.state=c.snapshot()
		check(c.players[0].used<=c.players[0].cap,"preview population has real supply capacity, race %d"%race)
		check(main.state.units.filter(func(u):return u.owner==0 and u.kind!=0 and u.container<0 and not bool(ACData.unit(int(u.race),int(u.kind)).get("technical",false))).size()==12,"all twelve staged combat units exist, excluding attached brood entities")
		await frames(3)
		main.battle_hud.menu_button.focus_mode=Control.FOCUS_ALL
		main.battle_hud.menu_button.grab_focus()
		check(main.battle_hud.menu_button.has_focus(),"F2 regression fixture holds actual GUI keyboard focus")
		await keypress(KEY_F2)
		check(main.selected.size()==12,"F2 selects twelve actual army units while a HUD button has focus, race %d"%race)
		check(main.selected.all(func(id):return int(id) in army),"preview selection contains only valid staged army ids")
		main.selected=[army[0]] if not army.is_empty() else []
		await keypress(KEY_F2)
		check(main.selected.size()==12 and main.selected.all(func(id):return int(id) in army),"repeated F2 restores the actual twelve-unit selection")
		main.battle_hud.menu_button.focus_mode=Control.FOCUS_NONE
		check(main.battle_hud.action_buttons.all(func(button):return button.focus_mode==Control.FOCUS_NONE) and main.battle_hud.selection_buttons.all(func(button):return button.focus_mode==Control.FOCUS_NONE),"battle command and selection buttons cannot consume camera hotkeys")
		# Each faction capture shows one unit's detailed information and portrait.
		main.selected=[army[0]] if not army.is_empty() else []
		main.hud_signature=""
		main._update_hud()
		main.queue_redraw()
		await capture("preview-race%d.png"%race)
	print("UI_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
