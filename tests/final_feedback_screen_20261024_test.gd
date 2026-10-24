extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/visual_feedback_20261024/"
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+label+".png")
func redraw() -> void:
	main.state=main.core.snapshot(-1);main.state.surrender_requests=main.core.surrender_requests.duplicate(true)
	main.battle_hud.update_hud(true);main.battle_hud._process(0);main._sync_world_canvas();main.queue_redraw();await frames(4)
func run() -> void:
	root.content_scale_size=Vector2i(1440,900);root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":413,"players":[{"race":1},{"race":2,"bot":true},{"race":0}]})
	main.paused=true;main.set_process(false);main.settings.edge_scroll=false;main.spectator=true
	var c=main.core;c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.resource_obstacles.clear();c.collision_index_valid=false
	main.camera=Vector2(64,64);main.zoom=1.75
	var hq=c.add_building(0,0,Vector2(62,62),true);ACCitrusBrood.producer(c,hq)
	for index in range(40):c.time+=.5;c.roots.update(c)
	await redraw()
	for frame in range(100):
		if main.root_artist.pending.is_empty():break
		main._root_canvas.queue_redraw();await frames(2)
	check(main.root_artist.tile_count>0 and main.root_artist.chunks.values().any(func(chunk):return chunk.display_mesh!=null),"grown citrus ground is actually visible in the renderer")
	await shot("citrus-readable-ground-and-complete-hud")
	check("hud_citrus_wood_new_20261024" in main.battle_hud._frame_art[1].resource_path,"citrus HUD uses newly drawn dark wood skin")
	var shell=main.battle_hud.shell_draw_rect()
	var source_rect=main.battle_hud._minimap_frame_rect()
	check(shell.encloses(source_rect) and source_rect.encloses(main._mini_rect()),"new wood artwork and minimap stay inside measured safe openings")
	for index in [29,30]:
		var icon=main.battle_hud.command_art.texture(1,"commands",index)
		check("page_icons_20261024" in icon.resource_path,"page arrow uses clean isolated source crop")
	var pod=ACCitrusBrood.idle_pods(c,hq)[0];c.players[0].as=1000;c.players[0].tera=1000
	c.command(0,{"type":"morph","id":pod.id,"kind":0});main.selected=[pod.id];await redraw()
	var commands=main.battle_hud.action_specs.filter(func(spec):return not spec.is_empty())
	check(commands.size()==1 and commands[0].title=="배양 취소" and main.battle_hud.action_specs[11].title=="배양 취소","morphing brood shows only cancel in the bottom right slot")
	await shot("brood-cancel-only")
	c.surrender_requests=[{"bot":1,"recipient":0,"started":c.time}];main.selected=[];await redraw()
	check(main.battle_hud.surrender_panel.visible,"computer surrender request is shown")
	check(main.battle_hud.surrender_panel.get_global_rect().end.y<main.battle_hud._minimap_frame_rect().position.y,"surrender request is above left minimap")
	await shot("computer-surrender-above-minimap")
	main.spectator=false;main.selected_resource=-1
	var buttons=main.battle_hud.surrender_panel.get_child(0).get_child(2)
	buttons.get_child(1).pressed.emit()
	check(c.surrender_requests.is_empty() and not c.players[1].lost,"actual reject button continues the match")
	main.spectator=true;c.surrender_requests.clear()
	# A viewport expansion at the eastern boundary used to retain the old
	# camera limit and expose an outside-map black strip.
	main.camera=Vector2(128,64);main._clamp_camera();var old_camera=main.camera.x
	root.content_scale_size=Vector2i(1760,986);await frames(4)
	check(main.camera.x<old_camera,"viewport expansion reclamps camera at the map edge")
	check(main.world_to_screen(Vector2(128,64)).x>=main._world_render_rect().end.x-.01,"terrain reaches the entire expanded right edge")
	await redraw();await shot("expanded-window-right-edge")
	# Three races, one stable foundation per building, four incomplete stages
	# and the original finished painting only in the final capture.
	c.units.clear();c.buildings.clear();c.effects.clear();main.selected=[];main.camera=Vector2(64,64);main.zoom=1.75
	var examples=[c.add_building(2,3,Vector2(57,62)),c.add_building(0,0,Vector2(63,62)),c.add_building(1,3,Vector2(69,62))]
	for stage in range(5):
		for b in examples:b.progress=float(stage)/4;b.hp=ACData.building(int(b.race),int(b.kind)).hp
		await redraw();await shot("construction-three-races-stage%d"%stage)
	var result={"checks":checks,"failures":failures,"passed":failures.is_empty(),"display":DisplayServer.get_name()}
	FileAccess.open(OUT+"final-screen.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FINAL_FEEDBACK_SCREEN checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
