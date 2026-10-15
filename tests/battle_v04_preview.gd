extends "res://tests/view_input_v03_test.gd"

func capture(path: String) -> void:
	main._sync_world_canvas();main.queue_redraw()
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate();root.add_child(main)
	await frames(3)
	for race in range(3):
		main._start_local({"map":race,"seed":223,"players":[{"race":race},{"race":(race+1)%3,"bot":true,"difficulty":1}]})
		main.settings.edge_scroll=false;main.paused=true
		await frames(3)
		await capture("res://build/final-v04-start-race%d.png"%race)
		var c=main.core
		var home=c.center(c.buildings[0])
		main.camera=home+Vector2(1.5,2);main._clamp_camera()
		main.spectator=true
		var units: Array=[]
		for kind in range(13):
			var point=home+Vector2(-5+(kind%7)*2.2,3+floori(kind/7.0)*2.2)
			var unit=c.add_unit(0,kind,point)
			unit.facing=[0,1];unit.body_direction=[0,1];unit.turret_direction=[1,0]
			units.append(unit)
		if race==0:
			units[4].energy=84;units[4].healing=true;units[4].heal_started=c.time-.25
			units[1].hp*=.6
			c.effects.append({"type":"heal","race":0,"kind":4,"unit":units[4].id,"target":units[1].id,"projectile":"heal_medical","from":units[4].pos,"to":units[1].pos,"started":-.2,"until":.45})
		elif race==1:
			for unit in c.units:
				if int(unit.kind)==13 and int(unit.owner)==0:
					unit.brood_state="morph";unit.morph_kind=1;unit.morph_left=.25;unit.morph_total=1
					break
		main.state=c.snapshot();main.selected=[units[4].id];main._update_hud()
		await create_timer(.15).timeout
		await capture("res://build/final-v04-roster-race%d.png"%race)
		check(main.assets.vehicle_frames.size()==3,"independent chassis/turret sources loaded")
		check(main.assets.heal_frames.size()==4,"four newly authored directional heal poses loaded")
		check(main.construction_visual.available(race,7),"unique generated construction cache ready for race %d"%race)
		if race==0:
			var vent: Dictionary={}
			var distance=INF
			for resource in main.state.resources:
				if resource.type=="tera" and ACData.point(resource.pos).distance_to(home)<distance:
					vent=resource;distance=ACData.point(resource.pos).distance_to(home)
			var refinery=c.add_building(0,1,ACData.point(vent.pos)-Vector2(1.5,.5),true)
			main.camera=ACData.point(vent.pos)+Vector2(-2,1);main._clamp_camera()
			main.state=c.snapshot();main.selected=[refinery.id];main._update_hud()
			await capture("res://build/final-v04-refinery-race0.png")
	print("BATTLE_V04_PREVIEW checks=",checks," failures=",failures.size())
	main._release_pointer();quit(0 if failures.is_empty() else 1)
