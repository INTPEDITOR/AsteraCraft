extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/feedback4-20261024/"
class Probe:
	extends "res://tests/menu_v04_harness.gd"
	var footprints=[]
	var exhaust_calls=0
	func _draw_footprint(pos: Vector2,dimensions: Vector2,color: Color,fill: bool=false) -> void:
		footprints.append({"pos":pos,"size":dimensions});super._draw_footprint(pos,dimensions,color,fill)
	func _draw_unit_frame(frame: Dictionary,point: Vector2,extent: float,color: Color=Color.WHITE) -> Rect2:
		if frame.get("bomber_exhaust",false):exhaust_calls+=1
		return super._draw_unit_frame(frame,point,extent,color)
func redraw() -> void:
	main.state=main.core.snapshot(0);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(4)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=Probe.new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	var service=main._game_updater();service.install_enabled=true;service.checked=true
	var hub=main.ui.get_node("MainHub");hub._build_update_panel();hub._layout()
	var plates=[]
	for race in range(3):
		hub.choose_background(race);service.state="current";service.message="최신 버전입니다.";service.changed.emit();await frames(3)
		check(hub.update_panel.size.x<=202 and hub.update_panel.size.y<=54,"small update control race "+str(race))
		check(Rect2(Vector2.ZERO,hub.size).encloses(hub.update_panel.get_rect()),"compact update button remains inside viewport")
		plates.append(hub.update_button.get_theme_stylebox("normal").texture.resource_path)
		await shot("menu-update-r%d"%race)
	check(plates.size()==3 and plates[0]!=plates[1] and plates[1]!=plates[2],"three distinct faction button plates")
	main._start_local({"map":1,"players":[{"race":0},{"race":0}]});main.paused=true;main.set_process(false);main.spectator=true
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear();c.map.source_walk_masks.clear();c.map.height_map.fill(0);c.map.reset_solids([])
	c.visibility[0].fill(1);c.explored[0].fill(1);main.camera=Vector2(48,46);main.zoom=1.5
	var shield=c.add_unit(0,3,Vector2(45,44));main.selected=[shield.id];await redraw()
	check(main.battle_hud.action_specs.all(func(spec):return spec.is_empty() or not "방패 전개" in str(spec)),"shield deployment absent from real command card")
	for race in range(3):
		c.players[0].race=race;var definition=ACData.building(race,1);var position=Vector2(44,44)
		main.state=c.snapshot(0);main.local_slot=0;main._palette_entity={};main.footprints.clear()
		# The ghost is drawn through an actual overlay canvas, below.
		main.build_kind=1;main.selected=[];main.pointer_position=main.world_to_screen(position+Vector2(float(definition.w)-1,float(definition.h)-1)*.5)
		await redraw();await shot("tera-placement-r%d"%race)
		check(main.footprints.any(func(entry):return Vector2(entry.pos).is_equal_approx(position-Vector2(.5,.5))),"refinery preview uses the same corrected footprint origin as completed selection, race "+str(race))
	main.build_kind=-1;c.players[0].race=0;c.units.clear();c.effects.clear();main.camera=Vector2(48,46);main.zoom=1.5
	var bombers=[]
	for heading in range(16):
		var u=c.add_unit(0,10,Vector2(40+heading%4*5,40+heading/4*4));u.facing=ACData.packed(Vector2.UP.rotated(float(heading)*TAU/16));u.body_direction=u.facing.duplicate();u.action="idle";u.moving=false;bombers.append(u)
	main.selected=[bombers[0].id];await redraw();main.exhaust_calls=0;await frames(3)
	check(main.exhaust_calls==0,"stationary bomber draws no exhaust layer")
	await shot("bomber-idle-sixteen-directions")
	var ground=main._ground_point(main._visual_position(bombers[0]));var before=main._air_hover_offset(bombers[0],0);main.state.time+=1
	var after=main._air_hover_offset(bombers[0],0)
	check(before.distance_to(after)>1 and ground==main._ground_point(main._visual_position(bombers[0])),"idle bomber hovers while ground marker stays fixed")
	for u in bombers:u.moving=true;u.action="walk"
	main.exhaust_calls=0;await redraw()
	check(main.exhaust_calls>0,"moving bombers draw separated exhaust layer")
	await shot("bomber-moving-sixteen-directions")
	var effects=0
	for key in ["bullet","shell","missile","acid","seed","thorn","plasma","bolt","claw","slash","bash","spark","vine","explosion"]:
		for phase in range(8):
			var image=main.assets.skill_texture("weapon_"+key,(phase+.1)/8).get_image();var box=image.get_used_rect()
			check(image.get_size()==Vector2i(192,192) and box.position.x>=8 and box.position.y>=8 and box.end.x<=184 and box.end.y<=184,"standalone padded impact frame "+key+":"+str(phase));effects+=1
	main.core.effects.clear();c.units.clear();main.camera=Vector2(46,43);main.zoom=2.5
	var bomber=c.add_unit(0,10,Vector2(44,42));var victim=c.add_building(1,0,Vector2(46,42),true);bomber.facing=[1,0];bomber.body_direction=[1,0];bomber.moving=false
	c.effects=[{"id":9999,"type":"shot","owner":0,"race":0,"kind":10,"unit":bomber.id,"from":bomber.pos,"to":ACData.packed(c.center(victim)),"started":c.time-.91,"until":c.time+.09,"damage":100,"projectile":"bomb","target":victim.id}]
	await redraw();await shot("bomber-impact-complete")
	c.units.clear();c.buildings.clear();c.effects.clear();c.players[0].race=2;main.camera=Vector2(46,44);main.zoom=2
	var archers=[]
	for index in range(8):
		var u=c.add_unit(0,2,Vector2(44+index%4*2.6,42+index/4*3));u.order="move";u.goal=ACData.packed(ACData.point(u.pos)+Vector2(-5,5));c.paths_this_tick=0;c._move(u,ACData.point(u.goal),.1,.25);archers.append(u)
		check(u.moving and ACData.point(u.facing).x<0 and ACData.point(u.facing).y>0,"archer actually moves southwest")
	main.selected=[archers[0].id];await redraw();await shot("owl-archers-walking-southwest")
	for phase in range(7):
		check(main.assets.unit(2,2,Vector2(-1,1),"walk",(phase+.1)/9).get("flip",false),"southwest walking pose reflects the existing southeast art "+str(phase))
	for race in range(3):
		main.battle_hud.race=race
		for scale in [1.0,1.75,2.5]:
			main.zoom=scale;main.camera=Vector2(64,128);main._clamp_camera()
			check(main._ground_point(Vector2(64,127.5)).y<main._camera_view_bottom(),"last map row is visible above faction HUD at zoom "+str(scale))
			var mini=main._mini_rect();check(absf(main._minimap_camera_rect(mini).end.y-(mini.end.y-1))<.1,"minimap camera outline reaches map bottom at southern limit")
	main.battle_hud.race=2;main.zoom=1.75;main.camera=Vector2(64,128);main._clamp_camera()
	c.units.clear();var edge=c.add_unit(0,2,Vector2(64,127));main.selected=[edge.id];await redraw();await shot("southern-map-edge-above-hud")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"impact_frames_checked":effects,"faction_update_plates":plates}
	FileAccess.open(OUT+"screen-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FEEDBACK4_SCREEN ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
