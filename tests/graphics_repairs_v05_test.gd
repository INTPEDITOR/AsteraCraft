extends "res://tests/view_input_v03_test.gd"

const OUT="res://build/graphics-repairs-v05/"
var captures: Array=[]

func capture(name: String) -> void:
	main._sync_world_canvas();main.queue_redraw();await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	captures.append(name)

func sync_fixture() -> void:
	main.state=main.core.snapshot()
	main.visual_motion.clear();main._accept_visual_snapshot(main.state.units,main.core.time,true)
	main._update_hud()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	main._start_local({"map":0,"seed":617,"players":[{"name":"Review","race":0},{"name":"Fixture","race":2}]})
	main.paused=true;main.spectator=true;main.set_process(false);main.zoom=1.75
	var c=main.core;c.units.clear()
	var roster: Array=[]
	for race in range(3):
		c.players[0].race=race
		var n=0
		for kind in range(13):
			if not ACData.unit(race,kind).air:continue
			var unit=c.add_unit(0,kind,Vector2(57+n*4.5,60+race*2.5))
			roster.append({"unit":unit,"start":ACData.point(unit.pos)})
			n+=1
			var key="%d:%d"%[race,kind]
			check(main.assets.repaired_air.has(key),"Replacement air art loaded: "+key)
			var image=main.assets.repaired_air[key].texture.get_image()
			check(image.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO,image.get_size()))==image.get_used_rect().grow(2),"Air silhouette has transparent gutter: "+key)
			check(image.get_pixel(0,0).a==0 and image.get_pixel(319,319).a==0,"Air background really transparent: "+key)
			for heading in range(32):
				var direction=Vector2.UP.rotated(TAU*heading/32.0)
				var frame=main.assets.unit(race,kind,direction,"walk",.2)
				check(Vector2.UP.rotated(float(frame.rotation)).dot(direction)>.9999,"Artwork nose agrees with heading: %s/%d"%[key,heading])
				check(frame.anchor==Vector2(160,160),"Air pivot cannot drift between headings")
	c.players[0].race=0;main.camera=Vector2(64,62.5)
	for heading in range(8):
		var direction=Vector2.UP.rotated(TAU*heading/8.0)
		for item in roster:
			item.unit.pos=ACData.packed(item.start)
			c.command(0,{"type":"move","ids":[item.unit.id],"pos":ACData.packed(item.start+direction*12)})
		for tick in range(8):c.step(.05)
		for item in roster:
			var delta=ACData.point(item.unit.pos)-item.start
			check(delta.length()>.1,"Aircraft actually advances in simulation")
			if delta.length()>.1:
				check(main._visual_facing(item.unit).dot(delta.normalized())>.995,"Aircraft facing follows actual displacement")
		sync_fixture();await capture("air-heading-%02d"%heading)
	# Actual firing frames and registered muzzle points, including mirrored views.
	c.units.clear();var infantry: Array=[]
	for kind in [1,2,3,7]:infantry.append(c.add_unit(0,kind,Vector2(58+infantry.size()*4,63)))
	for heading in range(8):
		var direction=Vector2.UP.rotated(heading*TAU/8)
		for unit in infantry:
			unit.facing=ACData.packed(direction);unit.body_direction=unit.facing.duplicate()
			unit.action="attack";unit.action_clock=.06
			var frame=main.assets.unit(0,int(unit.kind),direction,"attack",.06)
			check(frame.has("muzzle") and frame.muzzle.is_finite(),"Firing pose supplies its own visible muzzle")
			check(absf(frame.muzzle.x)<frame.scale_hint*1.2 and absf(frame.muzzle.y)<frame.scale_hint*1.2,"Muzzle remains inside sprite vicinity")
		sync_fixture();await capture("fire-heading-%02d"%heading)
	# Walk/therapy states all use the new outlined emblem, without old gun art.
	c.units.clear();var medic=c.add_unit(0,4,Vector2(64,63))
	for action in ["idle","walk","heal"]:
		var frame=main.assets.unit(0,4,Vector2.RIGHT,action,.1)
		check(frame.texture is AtlasTexture and frame.texture.atlas.resource_path.ends_with("medic_registered_v05.png"),"Medic state uses corrected generated sheet: "+action)
		medic.action=action;medic.action_clock=.1;medic.facing=[1,0];medic.healing=action=="heal";medic.heal_started=c.time-.1
		sync_fixture();main.selected=[medic.id];await capture("medic-"+action)
	# Independent chassis gait and turret are exercised with real draw calls.
	c.units.clear();var vehicles: Array=[]
	for kind in [5,6,12]:vehicles.append(c.add_unit(0,kind,Vector2(59+vehicles.size()*5,63)))
	for tick in range(8):
		for unit in vehicles:
			unit.action="walk";unit.moving=true;unit.action_clock=tick*.055
			unit.facing=[1,0];unit.body_direction=[1,0];unit.turret_direction=[0,-1]
		sync_fixture()
		for unit in vehicles:main.visual_motion[int(unit.id)]={"walking":true,"phase":tick*.50}
		await capture("vehicle-step-%02d"%tick)
	check(main._vehicle_gait_meshes.size()>3 and main._vehicle_gait_meshes.size()<=48,"Vehicle motion uses bounded reusable meshes")
	main._release_pointer()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"scope":"Real movement simulation plus controlled animation fixtures; overhead air rotation, medicine/firing sheets, chassis gait, alpha and muzzle registration. Not a full gameplay/balance test."}
	FileAccess.open(OUT+"audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GRAPHICS_REPAIRS_V05 checks=",checks," failures=",failures.size()," captures=",captures.size())
	quit(0 if failures.is_empty() else 1)
