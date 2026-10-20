extends "res://tests/view_input_v03_test.gd"
func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	main._start_local({"map":0,"seed":617,"spawn_slots":[0,2],"players":[{"race":1},{"race":0}]})
	main.paused=true;main.set_process(false)
	var c=main.core;var hq=c.entity(int(c.players[0].home));var origin=c.center(hq)+Vector2(4,5)
	var support=c.add_unit(0,9,origin);var soldier=c.add_unit(0,7,origin+Vector2(2,0));soldier.hp-=60
	support.energy=150;c.players[0].technologies={"sap_reclaim":1,"sap_bloom":1}
	c._rebuild_collision_index();c._update_vision()
	check(ACAbilities.use(c,support,"sap_bloom",origin)=="","bloom effect created")
	c._support(support,support._definition,.5)
	main.state=c.snapshot();main.selected=[support.id];main.camera=origin+Vector2(1,1)
	main._accept_visual_snapshot(main.state.units,float(c.time),true)
	main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw();await frames(12)
	var hud=main.battle_hud;var skills=[]
	for spec in hud.action_specs:
		if spec.cost.has("skill"):
			skills.append(spec.cost.skill)
			check(spec.texture!=null,"painted support skill icon "+str(spec.cost.skill))
	check(skills==["sap_heal","sap_reclaim","sap_bloom"],"three new support abilities in HUD")
	check(hud.detail_label.text.contains("자동 치료 켜짐") and not hud.detail_label.text.contains("과육"),"mana-only support info")
	for key in skills:check(main.assets.skill_texture(key,.5)!=null,"new dedicated effect "+key)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/citrus-support-v060-preview.png")
	print("CITRUS_SUPPORT_PREVIEW ",JSON.stringify({"checks":checks,"failures":failures}))
	main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
