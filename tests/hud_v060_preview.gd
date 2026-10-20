extends "res://tests/view_input_v03_test.gd"
func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	var portrait_sizes=[]
	var layouts=[]
	for race in range(3):
		main._start_local({"map":race,"seed":617,"spawn_slots":[0,2],"players":[{"name":"HUD 검토","race":race},{"race":(race+1)%3}]})
		main.paused=true;main.set_process(false)
		var c=main.core;var hq=c.entity(int(c.players[0].home));var u=c.units.filter(func(unit):return int(unit.owner)==0 and int(unit.kind)==0)[0]
		for fog in c.visibility:fog.fill(1)
		for fog in c.explored:fog.fill(1)
		main.state=c.snapshot();main.selected=[u.id];main.camera=c.center(hq)+Vector2(1,3)
		main._accept_visual_snapshot(main.state.units,float(c.time),true)
		main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw();await frames(10)
		portrait_sizes.append(main.battle_hud._portrait_rect().size)
		layouts.append([main.battle_hud.minimap_rect(),main.battle_hud._detail_content_rect(),main.battle_hud._portrait_rect(),main.battle_hud.command_slot_rect(0),main.battle_hud._menu_rect()])
		check(main.battle_hud._complete_shells[race],"newly painted one-piece full HUD %d"%race)
		check(main.battle_hud._portrait!=null,"portrait loaded %d"%race)
		check(main.battle_hud.action_buttons.size()>=5,"worker commands %d"%race)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/hud-v060-r%d.png"%race)
	check(portrait_sizes[0].is_equal_approx(portrait_sizes[1]) and portrait_sizes[1].is_equal_approx(portrait_sizes[2]),"identical portrait viewport across races")
	for panel in range(5):check(layouts[0][panel].is_equal_approx(layouts[1][panel]) and layouts[1][panel].is_equal_approx(layouts[2][panel]),"identical panel position and proportions %d"%panel)
	print("HUD_V060_PREVIEW ",JSON.stringify({"checks":checks,"failures":failures,"portrait_sizes":portrait_sizes}));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
