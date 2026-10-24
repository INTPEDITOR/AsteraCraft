extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/move-attack-followup-20261025/visual/"
var records=[]
func capture(label: String,c) -> void:
	main.state=c.snapshot(0);main._accept_visual_snapshot(main.state.units,c.time,true)
	main.battle_hud.update_hud(true)
	for node in main._entity_canvases.values():node.next_pose=0
	main._sync_world_canvas();main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
	records.append({"file":label+".png","detail":main.battle_hud.detail_label.text})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4);main.set_process(false)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(3)
	main._start_local({"map":1,"seed":251026,"players":[{"race":0},{"race":1}]})
	main.set_process(false);main.settings.edge_scroll=false;main.spectator=false
	var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
	var origin=Vector2.INF
	for y in range(24,100,3):
		for x in range(24,100,3):
			if c._ground_sweep(Vector2(1.6,1.6),Vector2(x,y),Vector2(x+14,y)):origin=Vector2(x,y);break
		if origin!=Vector2.INF:break
	check(origin!=Vector2.INF,"real map has a clear firing lane")
	var tank=c.add_unit(0,5,origin);var victim=c.add_unit(1,3,origin+Vector2(11.5,0))
	var spotter=c.add_unit(0,8,origin+Vector2(6,2))
	victim.hp=1000;victim.order="hold";c._update_vision()
	check(c.can_see(0,victim),"actual allied air spotter supplies sight at expanded range")
	main.selected=[tank.id];main.camera=origin+Vector2(5.75,0);main.zoom=1.55
	main.camera.y-=(main._view_rect().get_center().y+24*main.zoom-main._ground_point(main.camera).y)/(32*main.zoom)
	await capture("tank-mobile-range7",c)
	check("사거리 7 ·" in main.battle_hud.detail_label.text,"mobile range seven is rendered in the actual HUD")
	var help=""
	for spec in main.battle_hud.action_specs:
		if not spec.is_empty() and bool(spec.get("deploy_action",false)):help=spec.tip
	check("고정 사거리 12 (+5)" in help and "최소 사거리 2.5" in help,"actual command tooltip shows deployed twelve and minimum 2.5")
	var before=victim.hp
	main._send_command({"type":"ability","ids":[tank.id]})
	check(float(tank.deploy_until)>c.time and not tank.anchored,"normal player command starts deployment")
	c.time=float(tank.deploy_until)+.01;c._tick_unit(tank,.05)
	check(tank.anchored,"tank finishes its real deploy transition")
	check(victim.hp<before,"deployed tank actually fires at 11.5 with allied sight")
	await capture("tank-deployed-range12",c)
	check("사거리 12 ·" in main.battle_hud.detail_label.text,"deployed range twelve replaces seven in the actual HUD")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"distance":11.5,"damage":before-victim.hp,"spotter":spotter.id,"tooltip":help,"screens":records,"runtime":"actual Windows Godot renderer; normal deployment command; real allied spotter vision"}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SIEGE_VISUAL ",JSON.stringify(result));main._release_pointer();quit(0 if failures.is_empty() else 1)
