extends "res://tests/view_input_v03_test.gd"
## Targeted checks for the user's screenshots; no full match or full art approval.
class FeedbackProbe:
	extends "res://tests/menu_v04_harness.gd"
	var corpses_on_floor=0
	var corpses_on_overlay=0
	var phases_seen={}
	var deploy_stages={}
	var projected_shadows=0
	var drawing_unit=-1
	var body_actions={}
	func _cast_shadow(texture: Texture2D,anchor: Vector2,foot: Vector2,factor: float,flip: bool=false,altitude: float=0.0,opacity: float=1.0,rotation: float=0.0) -> void:
		projected_shadows+=1
		super._cast_shadow(texture,anchor,foot,factor,flip,altitude,opacity,rotation)
	func _draw_unit(e: Dictionary) -> void:
		drawing_unit=int(e.id);super._draw_unit(e);drawing_unit=-1
	func _draw_death_body(fx: Dictionary) -> void:
		if world_canvas==_root_canvas:corpses_on_floor+=1
		if world_canvas==_world_effect_canvas:corpses_on_overlay+=1
		super._draw_death_body(fx)
	func _draw_unit_frame(frame: Dictionary,point: Vector2,extent: float,color: Color=Color.WHITE) -> Rect2:
		if frame.get("action","")=="walk":phases_seen[int(frame.frame)]=true
		if frame.get("action","")=="deploy":deploy_stages[int(frame.frame)]=true
		if drawing_unit>=0:body_actions[drawing_unit]=str(frame.get("action",""))
		return super._draw_unit_frame(frame,point,extent,color)

const OUT="res://build/visual_feedback_20261024/"

func refresh() -> void:
	main.state=main.core.snapshot(-1)
	for node in main._entity_canvases.values():node.next_pose=0
	main._sync_world_canvas();main.queue_redraw();await frames(3)

func pixel_rect(area: Rect2) -> Rect2i:
	var scale_value=Vector2(root.get_texture().get_image().get_size())/main.size
	return Rect2i(area.position*scale_value,area.size*scale_value)

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size=Vector2i(1600,1000);root.size=Vector2i(1600,1000)
	main=FeedbackProbe.new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":413,"players":[{"race":0},{"race":1},{"race":2}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.settings.edge_scroll=false
	check(main.assets.sprites.portraits.is_empty(),"cancelled portrait replacement catalog is not loaded")
	var u=main.core.add_unit(0,2,Vector2(64,64));main.state=main.core.snapshot(0);main.selected=[u.id];main.battle_hud.update_hud(true);main.battle_hud._process(0)
	check(main.battle_hud._portrait_canvas.texture==main.battle_hud._portrait,"HUD displays the preserved original portrait")
	for race in range(3):
		for kind in range(16 if race==0 else 14):
			var portrait: AtlasTexture=main.battle_hud.portraits.get("%d:%d"%[race,kind])
			check(portrait!=null and "faces_v0" in portrait.atlas.resource_path,"original portrait %d:%d"%[race,kind])
	var old_icon: AtlasTexture=main.battle_hud._unit_texture(0,2)
	check(old_icon.atlas.resource_path=="res://assets/icons_units_0_v060.png","clipped replacement icons use the original complete atlas again")
	var drone=main.battle_hud._unit_texture(0,8)
	var drone_image=drone.get_image();drone_image.save_png(OUT+"drone-current-icon.png")
	check(drone_image.get_used_rect().has_area() and Rect2i(Vector2i.ONE*2,drone_image.get_size()-Vector2i.ONE*4).encloses(drone_image.get_used_rect()),"current two-rotor drone icon fits with transparent padding")
	for race in range(3):
		for kind in range(13):
			var base=main.assets.sprites.building(race,kind,1,false,Vector2.DOWN,0)
			var fixed=true
			for active in [false,true]:
				for clock in [0.0,.3,.8,2.0]:
					var pose=main.assets.sprites.building(race,kind,1,active,Vector2.DOWN,clock,.2)
					if not base.is_empty():fixed=fixed and pose.texture==base.texture and pose.anchor==base.anchor and pose.scale_hint==base.scale_hint
					else:fixed=fixed and main.assets.building_idle(race,kind,clock)==main.assets.building(race,kind)
			check(fixed,"building %d:%d keeps one fixed body during idle, production and firing"%[race,kind])
			var texture: Texture2D=base.texture if not base.is_empty() else main.assets.building(race,kind)
			var image=texture.get_image();image.save_png(OUT+"building-%d-%02d.png"%[race,kind])
			var light=main.building_status_lights.part(texture,race)
			light.texture.get_image().save_png(OUT+"lights-%d-%02d.png"%[race,kind])
			check(int(light.pixels)<=maxi(1,int(light.opaque*.018)),"building %d:%d light part is bounded to existing emissive pixels"%[race,kind])
			var construction: Dictionary=main.assets.sprites.buildings.get("%d:%d"%[race,kind],{}).get("actions",{}).get("construction",{})
			check(int(construction.get("rows",0))==5,"construction keeps five stages %d:%d"%[race,kind])
	var flower=[]
	for heading in [0,14,15]:
		var f=main.assets.unit(1,7,Vector2.UP.rotated(TAU*heading/16),"idle",0)
		flower.append(f.sprite_bounds.size.y/float(f.scale_hint))
	check(float(flower.max())/float(flower.min())<1.12,"flower NNW oversized body now matches neighboring headings")
	main.camera=Vector2(64,64);main.zoom=1.75;main._zoom_target=main.zoom;main._zoom_animating=false
	var anchor=Vector2(940,340);var terrain_point=main.screen_to_world(anchor)
	main._zoom_anchor=anchor;main._zoom_target=2.2;main._zoom_animating=true
	main._update_zoom(1.0/60)
	check(main.zoom>1.75 and main.zoom<1.95,"zoom approaches its target without a one-frame jump")
	var pinned=true
	for i in range(50):
		main._update_zoom(1.0/60)
		pinned=pinned and main.screen_to_world(anchor).distance_to(terrain_point)<.025
	check(pinned and absf(main.zoom-2.2)<.001,"zoom settles smoothly while terrain stays under the pointer")
	main.zoom=2.4;main._zoom_animating=false
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles()
	main.camera=Vector2(64,64);main.selected=[];main.visual_motion.clear()
	u=c.add_unit(0,2,Vector2(64,64));u.pos=[64.0,64.0];u.moving=true;u.action="walk";u.facing=ACData.packed(Vector2.UP.rotated(TAU*2/16));u.body_direction=u.facing.duplicate();u.fired=-99
	var ne_clip=main.assets.sprites.units["0:2"].actions.walk
	check(str(ne_clip.frames[2].file).contains("NE_run_fix"),"assault NE walk uses the corrected seven authored poses")
	for phase in range(7):
		c.time=10+phase/9.0;main.visual_motion[int(u.id)]={"walking":true,"phase":phase+.05,"pos":ACData.point(u.pos)}
		await refresh();await shot("assault-ne-run-%d"%phase)
	check(main.phases_seen.size()==7,"actual assault world renderer displays all seven NE run poses")
	var worker=c.add_unit(2,0,Vector2(60,64));worker.facing=[-1,0];worker.body_direction=[-1,0];worker.moving=true;worker.action="walk";worker.fired=-99
	var worker_clip=main.assets.sprites.units["2:0"].actions.walk
	var worker_files=true
	for phase in range(7):
		worker_files=worker_files and str(worker_clip.frames[phase*16+12].file).contains("W_walk_fix")
		c.time=12+phase/9.0;main.visual_motion[int(worker.id)]={"walking":true,"phase":phase+.05,"pos":ACData.point(worker.pos)}
		await refresh()
		if phase==3:await shot("owl-worker-west-walk")
	check(worker_files,"all seven WEST worker walk frames use the newly authored left-facing poses")
	var original_u=u
	var tank=c.add_unit(0,5,Vector2(68,64));tank.facing=[1,0];tank.body_direction=[1,0];tank.turret_direction=[1,0]
	var vehicle=main.assets.vehicle(0,5,Vector2.RIGHT,Vector2.RIGHT,0,"idle",0)
	check(main.assets.siege_supports(Vector2.RIGHT,0,vehicle.chassis).is_empty(),"mobile siege tank has no extended stabilizers")
	c.time=20;main.state=c.snapshot(-1);c._ability(tank,ACData.point(tank.pos))
	check(tank.has("deploy_until") and float(tank.deploy_until)==22.5,"siege activation keeps the existing real deployment duration")
	for step in range(1,7):
		c.time=20+step/6.0*2.5;await refresh()
		if step in [1,3,6]:await shot("siege-deploy-%d"%step)
	check(main.deploy_stages.size()==6,"actual siege rendering restores all six unfolding support stages")
	for race in range(3):
		for kind in range(16 if race==0 else 14):
			var d=ACData.unit(race,kind)
			if not bool(d.air) or str(d.material)!="mechanical" or (race==0 and kind==8):continue
			check(main._uses_fixed_hull({"race":race,"kind":kind}),"mechanical aircraft uses fixed direction hull %d:%d"%[race,kind])
			var air=c.add_unit(race,kind,Vector2(64,67));air.facing=[1,0];air.body_direction=[1,0];air.moving=true;air.action="walk";air.fired=c.time
			await refresh()
			check(main.body_actions.get(int(air.id),"")=="idle","actual moving/firing aircraft renders its fixed idle hull %d:%d"%[race,kind])
			c.units.erase(air)
	check(main.projected_shadows==0,"units no longer draw projected silhouette shadows")
	u=original_u
	c.time=11.0
	c._death_visual(u,-1);u.pos=[64.1,64.1];u.moving=false;u.action="idle";c.time+=1.0
	main.visual_motion.clear();main.corpses_on_floor=0;main.corpses_on_overlay=0
	await refresh();await shot("corpse-under-unit")
	check(main.corpses_on_floor>0 and main.corpses_on_overlay==0,"ground corpse is rendered below standing entities, never in the top overlay")
	main.selected=[u.id];main.battle_hud.update_hud(true);await frames(3);await shot("hud-restored")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var logical_region=main.battle_hud._minimap_frame_rect().grow(3)
		var region=pixel_rect(logical_region)
		var before=root.get_texture().get_image().get_region(region).get_data()
		var flash=Control.new();flash.z_index=3290;flash.draw.connect(func():flash.draw_rect(logical_region,Color.MAGENTA));main.add_child(flash);flash.queue_redraw();await frames(3)
		await RenderingServer.frame_post_draw
		check(before==root.get_texture().get_image().get_region(region).get_data(),"minimap and frame edges fully mask a bright world flash behind them")
		flash.queue_free()
	# Compare the exact existing building portrait cited in the user's screenshot.
	var portrait: AtlasTexture=main.battle_hud.building_portraits[2]
	check(portrait.atlas.resource_path=="res://assets/building_portraits_v4.png","the cited natural owl building portrait keeps its exact original source")
	check(portrait.region.size.is_equal_approx(portrait.atlas.get_size()*Vector2(.84/3.0,.52)),"the original owl building portrait crop and aspect are preserved")
	c.units.clear();c.effects.clear();c.buildings.clear();main.selected=[];main.camera=Vector2(64,64);main.zoom=1.75
	var tree=c.add_building(1,0,Vector2(62,62),true);tree.hp=ACData.building(1,0).hp*.35;c.time=22
	await refresh();await shot("citrus-juice-damage")
	check(main.building_damage_visual._juice_frames.size()==8,"citrus building damage uses the transparent eight-frame liquid asset")
	check(main.projected_shadows==0,"buildings also keep only the faint round contact shadow")
	main.selected=[tree.id];main.battle_hud.update_hud(true);main.battle_hud._process(0);await frames(3)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(pixel_rect(main.battle_hud._portrait_rect())).save_png(OUT+"original-citrus-building-portrait-in-hud.png")
	var council=c.add_building(2,0,Vector2(68,62),true);await refresh();main.selected=[council.id];main.battle_hud.update_hud(true);main.battle_hud._process(0);await frames(3)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(pixel_rect(main.battle_hud._portrait_rect())).save_png(OUT+"original-owl-building-portrait-in-hud.png")
	var result={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Screenshot-driven rendering fixes; full art review remains incomplete","display":DisplayServer.get_name()}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("VISUAL_FEEDBACK checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
