extends SceneTree
func _initialize():call_deferred("run")
func run():
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(4):await process_frame
	main._start_local({"map":0,"spawn_slots":[1,0],"players":[{"race":1},{"race":0}]});main.paused=true;main.set_process(false);main.spectator=true;main.settings.edge_scroll=false
	var h=main.core.buildings.filter(func(b):return b.owner==0 and b.kind==0)[0]
	var n=main.core.add_building(0,3,ACData.point(h.pos)+Vector2(7,3),true)
	main.core.add_building(0,12,ACData.point(h.pos)+Vector2(8,9),true)
	ACCitrusBrood.producer(main.core,n);main.state=main.core.snapshot(-1);main.selected=[h.id];main.camera=main.core.center(h)+Vector2(5,5);main.zoom=.85
	main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw()
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/colony-root-ground.png")
	print("COLONY_ROOT_VISUAL tiles=",main.root_tile_cache.size()," pooled=",h.larva)
	main.queue_free();await process_frame;quit()
