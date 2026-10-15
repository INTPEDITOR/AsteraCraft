extends SceneTree

var main: Control
var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func frames(count: int=3) -> void:
	for index in range(count):await process_frame

func click(point: Vector2,button: int=MOUSE_BUTTON_LEFT) -> void:
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	Input.parse_input_event(motion)
	await frames(2)
	var event=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=button
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func press(code: Key) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func resource_point(resource: Dictionary) -> Vector2:
	var area: Rect2=main._resource_screen_rect(resource)
	for sy in [.3,.45,.6,.75]:
		for sx in [.5,.35,.65]:
			var point=area.position+area.size*Vector2(sx,sy)
			var picked: Dictionary=main._resource_at(point)
			if not picked.is_empty() and int(picked.id)==int(resource.id) and main._hit_test(point)<0:return point
	return Vector2.INF

func focus_resource(resource: Dictionary) -> void:
	main.camera=ACData.point(resource.pos)+Vector2(4,0)
	main._clamp_camera()
	main._sync_world_canvas()
	await create_timer(.13).timeout

func capture(name: String) -> void:
	main._update_hud()
	main._sync_world_canvas()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name)

func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	for race in range(3):
		main._start_local({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true
		main.settings.edge_scroll=false
		var core=main.core
		var ore: Dictionary={}
		var vent: Dictionary={}
		for node in core.map.resources:
			if node.type=="as" and ore.is_empty():ore=node
			if node.type=="tera" and vent.is_empty():vent=node
		check(not ore.is_empty() and not vent.is_empty(),"both resource types exist on map %d"%race)
		if ore.is_empty() or vent.is_empty():continue
		main.spectator=true
		main.state=core.snapshot(0)
		await focus_resource(ore)
		var point=resource_point(ore)
		check(point.is_finite(),"As has a visible clickable sprite on map %d"%race)
		if not point.is_finite():continue
		await click(point)
		check(main.selected_resource==ore.id and main.selected.is_empty(),"As uses exclusive resource selection on map %d"%race)
		check(main._selected_resource_data().type=="as" and main._selected_resource_data().initial_amount==1500,"As selection retains its resource schema on map %d"%race)
		check(main.battle_hud.action_buttons.is_empty() and not main.battle_hud._resource.is_empty(),"resource HUD has deposit information and no commands on map %d"%race)
		var area: Rect2=main._resource_screen_rect(ore)
		var texture: Texture2D=main.world_resources[0]
		check(is_equal_approx(area.size.x,64*main.zoom) and is_equal_approx(area.size.y/area.size.x,float(texture.get_height())/texture.get_width()),"As renders at two tiles with its original aspect on map %d"%race)
		for code in [KEY_A,KEY_B,KEY_R]:await press(code)
		check(not main.attack_mode and main.build_kind<0 and main.pointer_order=="","resource hotkeys cannot enter unit command modes on map %d"%race)
		var hq=core.buildings[0]
		core.players[0].as=1000
		var queued=hq.queue.size()
		main._send_command({"type":"train","id":hq.id,"kind":0})
		check(hq.queue.size()==queued,"resource selection rejects a stale production command on map %d"%race)
		main.selected_resource=-1
		main.selected=[hq.id]
		main._update_hud()
		await press(KEY_R)
		await click(point)
		check(ACData.point(hq.rally).distance_to(ACData.point(ore.pos))<.001,"rally on the crystal targets its ground center on map %d"%race)
		var worker=core.units[0]
		var own_workers: Array=[]
		for unit in core.units:
			if int(unit.owner)==0 and int(unit.kind)==0:own_workers.append(unit.id)
		core.command(0,{"type":"stop","ids":own_workers})
		main.selected=[worker.id]
		main._update_hud()
		await click(point,MOUSE_BUTTON_RIGHT)
		check(worker.order=="gather" and worker.target==ore.id,"right clicking the enlarged crystal issues gather on map %d"%race)
		var before=float(ore.amount)
		for tick in range(400):
			core.step(.05)
			if float(ore.amount)<before:break
		check(float(ore.amount)<before,"actual mining reduces the selected deposit on map %d"%race)
		main.state=core.snapshot(0)
		main._select_resource(main.state.resources.filter(func(node):return node.id==ore.id)[0])
		check(main._selected_resource_data().amount==ore.amount and main.battle_hud._resource.amount==ore.amount,"remaining As updates in the live selection HUD on map %d"%race)
		await capture("resources-race%d-as.png"%race)
		await focus_resource(vent)
		point=resource_point(vent)
		check(point.is_finite(),"Tera has a visible clickable sprite on map %d"%race)
		if not point.is_finite():continue
		await click(point)
		check(main.selected_resource==vent.id and main._selected_resource_data().type=="tera","Tera supports deposit selection on map %d"%race)
		area=main._resource_screen_rect(vent)
		texture=main.world_resources[1]
		check(is_equal_approx(area.size.x,128*main.zoom) and is_equal_approx(area.size.y/area.size.x,float(texture.get_height())/texture.get_width()),"Tera renders at four tiles with its original aspect on map %d"%race)
		main.selected_resource=-1
		main.selected=[worker.id]
		main.build_kind=1
		main._update_hud()
		var expected=ACData.point(vent.pos)-Vector2(1.5,.5)
		check(main._build_position(point).distance_to(expected)<.001 and core.placement(0,1,expected)=="","refinery preview matches the exact four by two Tera footprint on map %d"%race)
		core.players[0].as=1000
		core.players[0].tera=1000
		var building_count=core.buildings.size()
		await click(point)
		check(core.buildings.size()==building_count+1,"clicking the Tera sprite places its refinery on map %d"%race)
		if core.buildings.size()!=building_count+1:continue
		var refinery=core.buildings[-1]
		check(ACData.point(refinery.pos).distance_to(expected)<.001,"refinery and deposit centers are aligned on map %d"%race)
		# Complete the placed foundation so this UI test can verify automatic
		# extraction without waiting a full construction timer for every race.
		refinery.progress=1.0
		refinery.hp=ACData.building(race,1).hp
		worker.order="idle"
		before=float(vent.amount)
		for tick in range(80):core.step(.05)
		check(float(vent.amount)<before,"completed refineries extract Tera automatically on map %d"%race)
		main.state=core.snapshot(0)
		main.selected_resource=-1
		main.selected=[refinery.id]
		main._update_hud()
		check(main.battle_hud._building_catalyst(refinery).amount==vent.amount,"refinery HUD retains the live remaining Tera amount on map %d"%race)
		await capture("resources-race%d-tera.png"%race)
	print("RESOURCES_UI_V03 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
