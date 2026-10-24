extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/nuclear_20261024/"
func redraw() -> void:
	main.state=main.core.snapshot(-1);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(4)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":601,"players":[{"race":0,"color_id":0},{"race":1,"color_id":6}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.camera=Vector2(64,59);main.zoom=1.75
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.time=2
	c._effect("skill",{"id":-1,"owner":0,"race":0,"pos":[64,64]},Vector2(64,64),16,{"skill":"nuclear","radius":5})
	var id=int(c.effects.back().id);var info=main.assets.sprites.effect_info("nuclear")
	check("nuclear_stable_20261024" in str(info.file),"new registered cloud is used by actual game")
	check(info.count==24 and info.frame_offsets.size()==24,"24 authored frames have individual registration offsets")
	var origin=Vector2.INF;var scale_value=Vector2.INF
	for age in [.25,.8,1.5,3.0,5.0,8.0,12.0,15.0]:
		c.time=2+age;await redraw()
		var node=main.nuclear_clouds[id]
		if not origin.is_finite():origin=node.position;scale_value=node.scale
		check(node.position.is_equal_approx(origin),"cloud ground origin never shifts at %.2f"%age)
		check(node.scale.is_equal_approx(scale_value),"cloud render scale never pulses at %.2f"%age)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"cloud-%04d.png"%roundi(age*100))
	if "--animation" in OS.get_cmdline_user_args():
		for frame in range(160):
			c.time=2+frame/10.0;await redraw();await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"anim-%03d.png"%frame)
	c.effects.clear();c.time=19
	var minis=[]
	for race in range(3):
		c.players[0].race=race;await redraw();await frames(2)
		var hud=main.battle_hud;var hole=hud._minimap_frame_rect();var rect=hud.minimap_rect()
		check(hole.grow(-3).encloses(rect),"map and markers have safe internal padding race%d"%race)
		check(is_equal_approx(rect.size.x,rect.size.y),"map preserves aspect ratio race%d"%race)
		check(rect==main._mini_rect(),"input and display use the same reduced bounds race%d"%race)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(hole.grow(16))).save_png(OUT+"minimap-r%d.png"%race)
		minis.append({"race":race,"hole":str(hole),"map":str(rect)})
	var result={"checks":checks,"failures":failures,"frames":24,"fixed_origin":str(origin),"fixed_scale":str(scale_value),"minimaps":minis}
	FileAccess.open(OUT+"visual-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("NUCLEAR_MINIMAP ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
