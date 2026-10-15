extends SceneTree
var main
var checks=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func frames(n: int=4) -> void:
	for i in range(n):await process_frame
func capture(file: String) -> void:
	main.queue_redraw();main.world_canvas.queue_redraw()
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)
func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	main.settings.edge_scroll=false;main.set_process(false)
	for theme in range(3):
		main._start_local({"map":theme,"spawn_slots":[0,1],"players":[{"race":1},{"race":0}]})
		main.paused=true;main.set_process(false);main.spectator=true;main.camera=Vector2(64,64);main.zoom=.11
		main.state=main.core.snapshot(-1);main._accept_visual_snapshot(main.state.units,0,true);main._update_hud();main._sync_world_canvas()
		await capture("original-map-overview-%d.png"%theme)
	main._start_local({"map":0,"spawn_slots":[1,0],"players":[{"race":1},{"race":0}]})
	main.paused=true;main.set_process(false);main.zoom=2
	var worker=main.core.units.filter(func(u):return u.owner==0 and u.kind==0)[0]
	main.selected=[worker.id];main.build_panel=true;main._update_hud();await frames()
	var hud=main.battle_hud
	var before=hud.shell_draw_rect()
	var button=hud.action_buttons[2]
	check(button.disabled,"unaffordable building disabled")
	var rect=button.get_global_rect();var event=InputEventMouseMotion.new();event.position=button.get_global_transform_with_canvas()*(button.size*.5);event.global_position=event.position
	root.push_input(event,true);hud.update_hud()
	print("HOVER_DIAGNOSTIC ",rect," event=",event.position," visible=",hud.is_visible_in_tree()," button_visible=",button.is_visible_in_tree()," hovered=",hud._hover_help)
	check(not hud._hover_help.is_empty(),"disabled building receives real hover")
	check(hud.detail_label.text.contains("아스") and hud.detail_label.text.contains("테라") and hud.detail_label.text.contains("건설") and hud.detail_label.text.contains("선행 건물"),"building cost time prerequisites visible")
	check(hud.shell_draw_rect()==before,"hover preserves HUD proportions")
	await capture("building-menu-hover.png")
	hud._hover_help={};main.build_panel=false
	var b=main.core.add_building(0,2,Vector2(14,14),true)
	main.state=main.core.snapshot(-1);main.selected=[b.id];main.camera=main.core.center(b);main._update_hud();main._sync_world_canvas()
	var texture=main.assets.building(1,2)
	check(float(texture.get_height())/texture.get_width()>.8,"storage sac fills footprint with substantial silhouette")
	await capture("nutrient-storage-v053.png")
	var caster=main.core.add_unit(0,8,Vector2(26,20));var victim=main.core.add_unit(1,6,Vector2(29,20))
	main.core._update_vision();main.state=main.core.snapshot(0);main.selected=[caster.id];main.camera=Vector2(27,20)
	main._accept_visual_snapshot(main.state.units,0,true);main._update_hud();main._sync_world_canvas()
	await capture("mind-control-before.png")
	var key=InputEventKey.new();key.keycode=KEY_Q;key.pressed=true
	check(main.battle_hud.handle_hotkey(key) and main.pointer_order=="ability","Q enters targeted control")
	main._confirm_pointer_target(main.core.center(victim),main._ground_point(main.core.center(victim)))
	check(victim.owner==0 and caster.energy==0,"target click sends valid control command")
	main.state=main.core.snapshot(0);main.selected=[victim.id];main._update_hud()
	await capture("mind-control-after.png")
	print("ORIGINAL_VISUAL "+JSON.stringify({"checks":checks,"failures":failures}))
	main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
