extends SceneTree
var main: Control
var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func frames(n: int=2) -> void:
	for i in range(n):await process_frame

func move_pointer(point: Vector2) -> void:
	# Inject viewport motion so concurrent desktop preview windows cannot steal
	# OS cursor focus from this input regression.
	var event=InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	Input.parse_input_event(event)
	await frames()

func press(code: Key) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames()

func click(point: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames()

func drag(from: Vector2,to: Vector2) -> void:
	var event=InputEventMouseButton.new()
	event.position=from
	event.global_position=from
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	Input.parse_input_event(event)
	await frames()
	await move_pointer(to)
	event=event.duplicate()
	event.position=to
	event.global_position=to
	event.pressed=false
	Input.parse_input_event(event)
	await frames()

func cutout_points() -> Array:
	for y in range(int(main._view_rect().end.y)+2,int(main.size.y)-30,4):
		for x in range(80,int(main.size.x)-120,16):
			var point=Vector2(x,y)
			var target=point+Vector2(48,0)
			if not main._world_visible_at(point) or not main._world_visible_at(target):continue
			var safe=true
			for offset in [-24,0,24,48]:
				if main.battle_hud.body_top_at(x+offset)<y+2:safe=false
			for sample in [point,target]:
				if not main.core.map.walkable(Vector2i(main.screen_to_world(sample))):safe=false
			if safe:return [point,target]
	return []

func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	main._start_local({"map":0,"players":[{"race":0},{"race":1}]})
	main.paused=true
	main.settings.edge_scroll=false
	await frames(3)
	var c=main.core
	var start=ACData.point(c.map.starts[0])
	var soldier=c.add_unit(0,1,start+Vector2(6,3))
	main.state=c.snapshot()
	main.selected=[soldier.id]
	main._update_hud()
	var destination=ACData.point(soldier.pos)+Vector2(3,1)
	for y in range(-2,4):
		for x in range(3,7):
			var candidate=ACData.point(soldier.pos)+Vector2(x,y)
			var sp=main._ground_point(candidate)
			if c.map.walkable(Vector2i(candidate)) and main._view_rect().grow(-30).has_point(sp) and main._context_target(sp,candidate)<0:destination=candidate
	await move_pointer(main._ground_point(destination))
	await press(KEY_A)
	check(main.attack_mode and main.pointer_order=="","A arms exactly one attack target mode")
	await click(main._ground_point(destination))
	check(soldier.order=="attack_move","A then one left click issues attack move")
	check(not main.attack_mode and main.pointer_order=="" and not main.dragging,"attack target consumes its click")
	check(main.selected==[soldier.id],"attack click preserves unit selection")
	var hq=c.buildings[0]
	main.selected=[hq.id]
	main._update_hud()
	await press(KEY_R)
	check(main.pointer_order=="rally" and not main.attack_mode,"R arms exactly one rally target mode")
	await click(main._ground_point(destination))
	check(ACData.point(hq.rally).distance_to(destination)<.025,"R then one click sets the exact terrain rally point")
	check(main.pointer_order=="" and not main.dragging and main.selected==[hq.id],"rally click preserves selection and disarms")
	main.set_process(false)
	main.settings.edge_scroll=true
	main.camera=Vector2(64,64)
	main.camera_velocity=Vector2.ZERO
	await move_pointer(Vector2(720,main._view_rect().end.y-2))
	main._camera_input(.05)
	check(main.camera_velocity.length()<.01,"HUD seam is not a screen edge")
	await move_pointer(Vector2(720,main.size.y-2))
	main._camera_input(.05)
	check(main.camera_velocity.y>0 and main.camera_velocity.y<500,"actual window bottom begins smooth downward acceleration")
	var speed=main.camera_velocity.y
	await move_pointer(Vector2(720,340))
	main._camera_input(.05)
	check(main.camera_velocity.y>0 and main.camera_velocity.y<speed,"edge scrolling decelerates smoothly after leaving the edge")
	main.camera_velocity=Vector2.ZERO
	var mouse=Vector2(860,300)
	await move_pointer(mouse)
	var before: Vector2=main.screen_to_world(mouse)
	var wheel=InputEventMouseButton.new()
	wheel.position=mouse
	wheel.global_position=mouse
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	Input.parse_input_event(wheel)
	await frames()
	check(main.screen_to_world(mouse).distance_to(before)<.025,"wheel zoom keeps terrain under the mouse")
	check(main.world_clip.clip_contents and main.world_canvas.get_parent()==main.world_clip,"world sprites have an actual parent canvas clipping boundary")
	# Use real authoritative states while deliberately sampling halfway visually.
	var current=ACData.point(soldier.pos)
	main._accept_visual_snapshot([soldier],1.0,true)
	soldier.pos=ACData.packed(current+Vector2(1,0))
	main._accept_visual_snapshot([soldier],1.05)
	main.visual_clock=.025
	main.paused=false
	check(main._visual_position(soldier).distance_to(current+Vector2(.5,0))<.001,"twenty Hz state samples render at an intermediate position")
	check(ACData.point(soldier.pos)==current+Vector2(1,0),"render interpolation does not mutate authoritative positions")
	main._sync_world_canvas()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var top=image.get_pixel(500,20)
	check(top.r<.08 and top.g<.08 and top.b<.08,"world artwork does not leak into the upper HUD strip")
	# Each faction's original HUD shell has a different measured aperture.
	# Input and map geometry must share that aperture, regardless of its size.
	for race in range(3):
		main.set_process(true)
		main._start_local({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true
		main.settings.edge_scroll=false
		await frames(3)
		var mini: Rect2=main._mini_rect()
		check(mini==main.battle_hud.minimap_rect() and is_equal_approx(mini.size.x,mini.size.y),"minimap shares the faction HUD square aperture, race %d"%race)
		await click(mini.position+mini.size*Vector2(.25,.75))
		check(main.camera.distance_to(Vector2(32,96))<.01,"minimap click uses the full map extent at its actual size, race %d"%race)
		# Original maps have different central lakes/ridges. Stage a walking
		# unit beside the open home base rather than inside a central obstacle.
		main.camera=ACData.point(main.core.map.starts[0])+Vector2(5,1)
		main._clamp_camera()
		main.spectator=true
		main._sync_world_canvas()
		var points=cutout_points()
		check(not points.is_empty(),"original HUD has a real playable upper cutout, race %d"%race)
		if points.is_empty():continue
		var point: Vector2=points[0]
		var target: Vector2=points[1]
		var unit=main.core.add_unit(0,1,main.screen_to_world(point))
		main.state=main.core.snapshot()
		# Terrain visibility refreshes at 10Hz while render frames continue.
		await create_timer(.12).timeout
		await move_pointer(point)
		check(main._can_point_world(point) and not main._can_point_world(Vector2(720,main.size.y-5)),"HUD cutout allows world input while its body blocks it, race %d"%race)
		await click(point)
		check(unit.id in main.selected,"a unit inside the transparent HUD cutout can be clicked, race %d"%race)
		main.selected=[]
		await drag(point-Vector2(16,8),point+Vector2(16,8))
		check(unit.id in main.selected,"drag selection includes visible units in the HUD cutout, race %d"%race)
		var right=InputEventMouseButton.new()
		right.position=target
		right.global_position=target
		right.button_index=MOUSE_BUTTON_RIGHT
		right.pressed=true
		Input.parse_input_event(right)
		await frames()
		check(unit.order=="move" and ACData.point(unit.goal).distance_to(main.screen_to_world(target))<.025,"the HUD cutout accepts an exact world command, race %d"%race)
		await RenderingServer.frame_post_draw
		var capture=root.get_texture().get_image()
		capture.save_png("res://build/cutout-input-race%d.png"%race)
		var rendered=capture.get_pixelv(Vector2i(target))
		print("CUTOUT_GPU race=",race," point=",point," target=",target," color=",rendered," body_y=",main.battle_hud.body_top_at(target.x))
		check(main.world_clip.get_global_rect().has_point(target) and maxf(rendered.r,maxf(rendered.g,rendered.b))>.1,"actual terrain is rendered through the HUD cutout, race %d"%race)
	print("VIEW_INPUT_V03 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
