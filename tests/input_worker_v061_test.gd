extends "res://tests/view_input_v03_test.gd"
func click(point: Vector2) -> void:
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await frames(2);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(2)
func drag(from: Vector2,to: Vector2) -> void:
	var event=InputEventMouseButton.new();event.position=from;event.global_position=from;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await frames(2)
	var motion=InputEventMouseMotion.new();motion.position=to;motion.global_position=to;root.push_input(motion,true);await frames(2)
	event=event.duplicate();event.position=to;event.global_position=to;event.pressed=false;root.push_input(event,true);await frames(2)
func run():
	root.size=Vector2i(1440,900);main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":611,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false);main.settings.edge_scroll=false
	var c=main.core;var position=ACData.point(c.map.starts[0]);var u=c.add_unit(0,6,position+Vector2(5,4))
	main.state=c.snapshot(0);main.selected=[u.id];main._update_hud();main._sync_world_canvas();await frames(3)
	var mini=main._mini_rect();await click(mini.position+mini.size*.6)
	check(main.camera.distance_to(Vector2(76.8,76.8))<.5 and not main.minimap_drag,"minimap left click centers camera and releases drag")
	await drag(mini.position+mini.size*.5,mini.position+mini.size*.7)
	check(main.camera.distance_to(Vector2(89.6,89.6))<.5 and not main.minimap_drag,"minimap camera drag follows pointer and ends on release")
	main._start_simulation_worker()
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;event.position=mini.position+mini.size*.62;event.global_position=event.position
	root.push_input(event,true);await frames(2)
	main.simulation_worker.submit(1,0);var packet={}
	for i in range(500):
		packet=main.simulation_worker.poll()
		if not packet.is_empty():break
		await process_frame
	check(not packet.is_empty() and packet.errors.is_empty(),"minimap right click reaches asynchronous simulation without errors")
	main._stop_simulation_worker()
	check(u.order=="move" and ACData.point(u.goal).distance_to(Vector2.ONE*(128*.62))<1,"minimap right click issues movement to correct world position")
	# A second match must not reuse renderer nodes or placement feedback.
	main._placement_requested="old";main._placement_result={"key":"old","valid":true}
	main._start_local({"map":0,"seed":612,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false)
	check(main._placement_requested=="" and main._placement_result.is_empty(),"new match clears asynchronous placement feedback")
	check(main._entity_canvases.is_empty(),"new match clears retained entity nodes before reused IDs are drawn")
	print("INPUT_WORKER_V061 ",JSON.stringify({"checks":checks,"failures":failures}));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
