extends "res://tests/view_input_v03_test.gd"
func run():
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main._start_local({"map":0,"seed":617,"players":[{"race":1},{"race":0}]});main.paused=true;main.set_process(false);main.settings.edge_scroll=false
	main.state=main.core.snapshot(-1);main.spectator=true;main.camera=Vector2(64,64)
	var target=main.state.units[0];target.pos=[60,60];main.selected=[target.id];main.groups[1]=[target.id]
	await press(KEY_1);check(main.camera.distance_to(Vector2(64,64))<.1,"single group press preserves camera")
	await press(KEY_1);check(main.camera.distance_to(main._center(target))<2,"double group press centres target")
	main.camera=Vector2(64,64);main._update_hud();await frames(2)
	var portrait_point=main.battle_hud.get_global_transform_with_canvas()*main.battle_hud._portrait_rect().get_center()
	await click(root.get_final_transform()*portrait_point);check(main.camera.distance_to(main._center(target))<2,"portrait click centres target")
	main.camera=Vector2(64,64)
	for race in range(3):
		main.state.players[0].race=race
		for kind in [0,2,3,7,12]:
			main.build_kind=kind;var d=ACData.building(race,kind)
			for z in [.65,1.0,1.5]:
				main.zoom=z;var world=Vector2(60,60)+Vector2(d.w,d.h)*.5
				var screen=main._ground_point(world);var pos=main._build_position(screen)
				check(pos.distance_to(Vector2(60,60))<.01,"ghost centre equals mouse across races and zooms")
	main.build_kind=-1;main.state.players[0].race=1;main.zoom=1;main.selected=[target.id];main.camera=main._center(target);main._update_hud();main._sync_world_canvas()
	var air=main.assets.unit(1,10,Vector2.RIGHT,"move",0)
	var flap=main.assets.unit(1,10,Vector2.RIGHT,"move",.21)
	check(air.texture!=flap.texture and air.texture.atlas.resource_path.ends_with("citrus_bat_leaf_v059.png"),"new bat wing animation loaded")
	for i in range(40):main.world_canvas.queue_redraw();await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/interaction-v059.png")
	print("INTERACTION_V059 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
