extends "res://tests/view_input_v03_test.gd"
func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	for race in range(3):
		main._start_local({"map":race,"seed":617,"spawn_slots":[0,2],"players":[{"name":"Review","race":race},{"race":(race+1)%3}]})
		main.paused=true;main.set_process(false)
		var c=main.core
		var hq=c.entity(int(c.players[0].home))
		for fog in c.visibility:fog.fill(1)
		for fog in c.explored:fog.fill(1)
		c.add_unit(0,1,c.center(hq)+Vector2(5,5))
		c.add_unit(0,12,c.center(hq)+Vector2(10,5))
		main.state=c.snapshot();main.selected=[hq.id];main.camera=c.center(hq)+Vector2(1,2)
		main._accept_visual_snapshot(main.state.units,float(c.time),true)
		main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw();await frames(6)
		check(main.battle_hud._portrait==main.battle_hud.building_portraits[race],"building close-up portrait %d"%race)
		check(main.battle_hud._menu_rect().size.x>main.battle_hud._menu_rect().size.y*3,"single wide menu %d"%race)
		if race==1:
			var pods=ACCitrusBrood.idle_pods(c,hq)
			main.selected=[pods[0].id];main._update_hud();await frames(2)
			var button=main.battle_hud.action_buttons[0]
			c.players[0].as=1000
			button.get_meta("spec").action.call();await frames(2)
			main.state=c.snapshot();main._update_hud();await frames(2)
			check(main.battle_hud.action_buttons.size()>2,"morphing brood keeps production menu")
			main.selected=[hq.id];main.state=c.snapshot();main._update_hud();await frames(2)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/feedback-v051-r%d.png"%race)
	print("FEEDBACK_UI_V051 "+JSON.stringify({"checks":checks,"failures":failures}));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
