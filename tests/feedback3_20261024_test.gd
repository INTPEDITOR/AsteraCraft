extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/feedback3-20261024/"
class Probe:
	extends "res://tests/menu_v04_harness.gd"
	var links=[]
	func _draw_link(from: Vector2,to: Vector2,width: float,tint: Color,strength: float=1.0) -> void:
		links.append({"from":from,"to":to,"width":width})
		super._draw_link(from,to,width,tint,strength)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func redraw() -> void:
	main.state=main.core.snapshot(-1);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(4)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size=Vector2i(1600,900);root.size=root.content_scale_size
	main=Probe.new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"players":[{"race":0,"color_id":0},{"race":0,"color_id":1},{"race":1,"color_id":6},{"race":2,"color_id":3}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.settings.edge_scroll=false
	main.local_slot=1;main._focus_home(true);await redraw();await shot("northwest-resources")
	var resources=[]
	for resource in main.state.resources:
		var p=ACData.point(resource.pos)
		if p.distance_to(Vector2(9,7.5))>12:continue
		var rect=main._resource_screen_rect(resource)
		resources.append({"id":resource.id,"pos":resource.pos,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"retained":main._entity_canvases.has(int(resource.id))})
	print("RESOURCE_PROBE ",JSON.stringify({"camera":main.camera,"size":main.size,"clip":main.world_clip.get_rect(),"resources":resources}))
	main.camera.x=11.071428;await redraw();await shot("northwest-resources-offset-clip")
	for entry in resources:
		var node=main._entity_canvases[int(entry.id)]
		check(node.bounds.has_area(),"explicit resource sprite bounds at clipped map edge %d"%int(entry.id))
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();main.selected=[];main.local_slot=0;main.camera=Vector2(64,64);main.zoom=1.75
	for race in range(3):
		var owner=[0,2,3][race]
		var unit=c.add_unit(owner,[1,2,2][race],Vector2(60+race*4,62));c._death_visual(unit)
		var hq=c.add_building(owner,0,Vector2(58+race*5,66),true);hq.rally=[60+race*4,64];main.selected.append(hq.id)
	await redraw();await shot("death-and-rally-player-colors")
	for key in main._player_overlay_canvases:
		var node=main._player_overlay_canvases[key]
		check(node.material!=null,"chosen palette on "+key)
		if key.begins_with("death:"):check(node.z_index==1,"ground death remains below standing units")
	main.build_kind=0;main.pointer_position=main._ground_point(Vector2(64,60));await redraw();await shot("blue-construction-ghost")
	check(main._player_overlay_canvases.has("ghost"),"actual construction ghost uses its own player palette")
	main.build_kind=-1;c.effects.clear();c.units.clear();c.buildings.clear();main.selected=[]
	for zoom in [1.0,1.75,2.5]:
		main.zoom=zoom
		for corner in [Vector2.ZERO,Vector2(128,0),Vector2(128,128),Vector2(0,128)]:
			main.camera=corner;main._clamp_camera()
			var origin=main.world_to_screen(Vector2.ZERO);var end=main.world_to_screen(Vector2(128,128))
			check(origin.x<=.01 and origin.y<=.01 and end.x>=main.size.x-.01 and end.y>=main.size.y+main._camera_southern_rise*zoom-.01,"full viewport is covered at %s zoom %.2f"%[corner,zoom])
	main.zoom=1.75;main.camera=Vector2(14,0);main._clamp_camera();await redraw();await shot("top-edge-no-black-strip")
	main.camera=Vector2(64,64)
	for index in range(4):
		var unit=c.add_unit(0,5,Vector2(59+index*3,64));unit.anchored=true;unit.body_direction=ACData.packed(Vector2.from_angle(PI*.25+index*PI*.5));unit.turret_direction=unit.body_direction;unit.facing=unit.body_direction;main.selected.append(unit.id)
		var vehicle=main.assets.vehicle(0,5,ACData.point(unit.body_direction),ACData.point(unit.turret_direction),1)
		check(vehicle.chassis.get("complete_deployment",false),"whole deployment body replaces cut support fragments")
	await redraw();await shot("siege-four-directions")
	c.units.clear();c.buildings.clear();c.effects.clear();main.selected=[];c.time=30
	var victim=c.add_building(2,0,Vector2(62,62),true)
	var shooters=[]
	for index in range(6):
		var point=Vector2(64,64)+Vector2.from_angle(index*TAU/6)*6
		var unit=c.add_unit(0,9,point);shooters.append(unit);unit.fired=c.time;unit.facing=ACData.packed((Vector2(64,64)-point).normalized());unit.turret_direction=unit.facing;unit.body_direction=unit.facing
		c._effect("shot",unit,c.center(victim),.8,{"target":victim.id,"projectile":"laser","damage":18})
		unit.pos=ACData.packed(point+Vector2(2,1))
	c.time+=.16;main.visual_motion.clear();main.visual_current.clear();main.links.clear();await redraw();await shot("laser-current-muzzles-soft-contacts")
	check(main.links.size()>=shooters.size(),"actual laser effects use soft connected light")
	for unit in shooters:
		var tip=main._weapon_tip(unit,ACData.point(unit.pos),c.center(victim))
		check(main.links.any(func(link):return Vector2(link.from).distance_to(tip)<.1),"beam follows the moved source muzzle %d"%int(unit.id))
		var contact=main._link_target_point(victim,tip)
		check(main._building_screen_rect(victim).has_point(contact),"beam contact remains on the target surface")
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"resources":resources},"\t"))
	print("FEEDBACK3 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
