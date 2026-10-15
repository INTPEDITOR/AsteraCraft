extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func run():
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(4):await process_frame
	main.settings.edge_scroll=false
	var checks=0
	for theme in range(3):
		main._start_local({"map":theme,"spawn_slots":[0,1],"players":[{"race":theme},{"race":(theme+1)%3}]})
		main.paused=true;main.set_process(false);main.spectator=true;main.state=main.core.snapshot(-1)
		var hq=main.core.buildings.filter(func(b):return b.owner==0 and b.kind==0)[0]
		main.camera=main.core.center(hq)+Vector2(0,3);main.zoom=2.0;main.selected=[hq.id];main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw()
		for i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/starting-row-%d.png"%theme)
		main.build_kind=1
		for vent in main.core.map.resources:
			if vent.type!="tera":continue
			main.camera=ACData.point(vent.pos);main._sync_world_canvas()
			var mouse=main._ground_point(ACData.point(vent.pos))
			var actual=main._build_position(mouse);var expected=main.core.refinery_anchor(vent)
			checks+=1
			if not actual.is_equal_approx(expected):failures.append([theme,vent.id,str(actual),str(expected)])
	print("TERA_POINTER ",JSON.stringify({"checks":checks,"failures":failures}))
	main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
