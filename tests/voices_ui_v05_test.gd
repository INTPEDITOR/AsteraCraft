extends "res://tests/view_input_v03_test.gd"

func viewport_click(point: Vector2) -> void:
	# Control rectangles are viewport coordinates, independent of OS window scaling.
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true);await frames()
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await frames()
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	for race in range(3):
		main._start_local({"map":race,"seed":617,"players":[{"name":"Review","race":race},{"name":"Target","race":(race+1)%3}]})
		main.paused=true;main.set_process(false);main.audio.set_paused(false)
		var c=main.core
		var low=c.add_unit(0,1,Vector2(60,60))
		var high=c.add_unit(0,12,Vector2(63,60))
		main.state=c.snapshot();main.selected=[low.id,high.id];main.camera=Vector2(62,60)
		main._update_hud();await frames(2)
		check(main._portrait_entity().id==high.id,"high-tier mixed portrait representative")
		check(main.battle_hud._portrait==main.battle_hud.portraits["%d:12"%race],"HUD actually uses high-tier portrait")
		main._selection_voice()
		check(main.audio.director.last_played=="r%d_u12_n0"%race,"selection voice matches visible portrait")
		var v=main.audio.director;v.reset()
		var hq=c.buildings.filter(func(b):return int(b.owner)==0 and int(b.kind)==0)[0]
		c.players[0].as=0;c.players[0].tera=0
		main.state=c.snapshot();main.selected=[hq.id];main._update_hud();await frames(2)
		var button: Button
		for item in main.battle_hud.action_buttons:
			if item.get_meta("spec").cost.get("as",0)>0:button=item;break
		check(button!=null and button.disabled,"insufficient-resource production button disabled")
		if button!=null:
			await viewport_click(button.get_global_rect().get_center())
			check(v.last_played=="r%d_ann_as"%race,"real disabled-button click announces As")
			v.reset()
			var event=InputEventKey.new();event.pressed=true;event.keycode=int(button.get_meta("spec").key)
			main.battle_hud.handle_hotkey(event)
			check(v.last_played=="r%d_ann_as"%race,"disabled-button hotkey announces As")
		v.reset();main._server_notice("테라가 부족합니다")
		check(v.last_played=="r%d_ann_tera"%race,"multiplayer rejection uses local faction voice")
		v.reset();v.add_ping(Vector2(64,64),float(main.state.time)-.7)
		main.selected=[low.id,high.id];main._update_hud()
		main._sync_world_canvas();main.queue_redraw();await frames(3)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/voice-hud-r%d.png"%race)
	main.audio.clear();main.queue_free();await frames(3)
	print("VOICE_UI_V05 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
