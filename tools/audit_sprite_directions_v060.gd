extends "res://tests/view_input_v03_test.gd"

class SpriteGrid extends Control:
	var controller: Control
	var race=0
	func pose(frame: Dictionary,point: Vector2,extent: float) -> void:
		var factor=extent/maxf(1,float(frame.scale_hint))
		draw_set_transform(point,float(frame.get("rotation",0)),Vector2(-factor if frame.get("flip",false) else factor,factor))
		draw_texture(frame.texture,-frame.anchor)
		draw_set_transform(Vector2.ZERO)
	func _draw() -> void:
		var font=get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO,size),Color("22272a"))
		for heading in range(8):
			var dir=Vector2.UP.rotated(heading*TAU/8)
			var top=Vector2(240+heading*160,36)
			draw_line(top,top+dir*22,Color("8ce8b4"),3,true)
			draw_string(font,top+Vector2(-40,35),["N","NE","E","SE","S","SW","W","NW"][heading],HORIZONTAL_ALIGNMENT_CENTER,80,16)
		for kind in range(ACData.unit_count(race)):
			var y=88+kind*144
			var d=ACData.unit(race,kind)
			draw_string(font,Vector2(8,y+50),str(kind)+" "+str(d.name),HORIZONTAL_ALIGNMENT_LEFT,152,15)
			for heading in range(8):
				var dir=Vector2.UP.rotated(heading*TAU/8)
				var point=Vector2(240+heading*160,y+112)
				var frame=controller.assets.unit(race,kind,dir,"attack",.06)
				var vehicle=controller.assets.vehicle(race,kind,dir,dir)
				var origin=Vector2(64,64)
				var source={"race":race,"kind":kind,"facing":ACData.packed(dir),"body_direction":ACData.packed(dir),"action_clock":.06}
				var muzzle=(controller._weapon_tip(source,origin,origin+dir*10)-controller._ground_point(origin))*80.0/float(d.visual_extent)
				var body=point-Vector2(0,22*80/float(d.visual_extent) if d.air else 0)
				if vehicle.is_empty():pose(frame,body,80)
				else:
					pose(vehicle.chassis,body,80)
					pose(vehicle.turret,body+vehicle.mount*80/vehicle.chassis.scale_hint,80*vehicle.turret_scale)
				if float(d.damage)>0:
					draw_circle(point+muzzle,3,Color("ff4747"))
					draw_line(point+muzzle,point+muzzle+dir*24,Color("ff7070"),1.4,true)
				draw_circle(point,2,Color("82a6bb"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/direction-audit-v060")
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main._start_local({"map":0,"seed":617,"players":[{"race":0},{"race":1}]})
	main.paused=true;main.set_process(false);main.zoom=1
	for race in range(3):
		var viewport=SubViewport.new();viewport.size=Vector2i(1520,88+ACData.unit_count(race)*144);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var grid=SpriteGrid.new();grid.controller=main;grid.race=race;grid.size=viewport.size;viewport.add_child(grid)
		await frames(4);await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://build/direction-audit-v060/race%d.png"%race)
		viewport.queue_free();await frames(2)
	main.queue_free();await frames(2);print("SPRITE_DIRECTION_AUDIT three eight-heading firing grids exported");quit()
