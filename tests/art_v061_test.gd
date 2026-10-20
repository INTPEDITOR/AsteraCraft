extends "res://tests/view_input_v03_test.gd"
func run():
	root.size=Vector2i(1600,1000)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":611,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false)
	var art=main.assets
	var side=art.vehicle(0,5,Vector2.RIGHT,Vector2.RIGHT)
	check(side.chassis.sprite_bounds.size.x*54/float(side.chassis.scale_hint)>=48,"tank chassis width is based on tracks, not the long cannon or deployed legs")
	check(is_equal_approx(54*float(side.turret_scale)/float(side.turret.scale_hint),54.0/224),"enlarging chassis preserves cannon size and muzzle scale")
	for heading in range(8):
		var direction=Vector2.UP.rotated(heading*TAU/8)
		for stage in range(7):
			var vehicle=art.vehicle(0,5,direction,direction,stage/6.0)
			check(vehicle.deployment_stage==stage,"correct deployment sprite stage")
			check(vehicle.muzzle.dot(direction)>0,"cannon muzzle faces actual attack direction")
			for part in [vehicle.chassis,vehicle.turret]:
				var used=part.texture.get_image().get_used_rect()
				check(used.position.x>1 and used.position.y>1 and used.end.x<255 and used.end.y<255,"complete separated layer stays within padded cell")
		var fixed=art.vehicle(0,5,direction,Vector2.LEFT,1)
		var turned=art.vehicle(0,5,direction,Vector2.RIGHT,1)
		check(fixed.chassis.texture==turned.chassis.texture and fixed.chassis.flip==turned.chassis.flip and fixed.turret.flip!=turned.turret.flip,"stationary chassis does not rotate with aiming turret")
	for frame in art.v060_effects.weapon_flame:
		check(frame.get_width()>frame.get_height()*4,"continuous flame is a narrow complete stream")
		var image=frame.get_image()
		check(image.get_pixel(0,0).a<.01 and image.get_pixel(image.get_width()-1,0).a<.01,"flame corners are transparent")
	var c=main.core;c.units.clear();c.buildings.clear();c.map.resources.clear();c.collision_index_valid=false
	var p=Vector2(64,64)
	for heading in range(8):
		var dir=Vector2.UP.rotated(heading*TAU/8);var position=p+Vector2((heading%4-1.5)*4,(heading/4-0.5)*5)
		var u=c.add_unit(0,13,position);u.pos=ACData.packed(position);u.facing=ACData.packed(dir);u.body_direction=u.facing.duplicate()
		var target=c.add_unit(1,1,position+dir*3);target.pos=ACData.packed(position+dir*3);target.hp=10000
		c._damage(u,target,.01,true);u.action="attack"
	main.spectator=true;main.camera=p;main.zoom=1.2;main.state=c.snapshot(-1);main._accept_visual_snapshot(main.state.units,c.time,true);main._sync_world_canvas();main._update_hud();await frames(12)
	root.get_texture().get_image().save_png("res://build/qa-v061-flame-directions.png")
	c.units.clear();c.effects.clear();c.collision_index_valid=false
	for stage in range(3):
		for heading in range(5):
			var dir=Vector2.UP.rotated(heading*TAU/8);var position=p+Vector2((heading-2)*4,(stage-1)*4)
			var u=c.add_unit(0,5,position);u.pos=ACData.packed(position);u.facing=ACData.packed(dir);u.body_direction=u.facing.duplicate();u.turret_direction=u.facing.duplicate()
			if stage==1:u.deploy_started=-1.25;u.deploy_until=1.25;u.deploy_to=true
			elif stage==2:u.anchored=true
	main.state=c.snapshot(-1);main._accept_visual_snapshot(main.state.units,c.time,true);main._sync_world_canvas();await frames(12)
	root.get_texture().get_image().save_png("res://build/qa-v061-tank-transform.png")
	check(main.ui.z_index>main._world_effect_canvas.z_index and main.ui.z_index>3200,"HUD remains above units and effects")
	FileAccess.open("res://build/qa-v061-art.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ART_V061 ",JSON.stringify({"checks":checks,"failures":failures}));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
