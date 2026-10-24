extends "res://tests/view_input_v03_test.gd"
class Probe:
	extends "res://tests/menu_v04_harness.gd"
	func _draw_unit(e: Dictionary) -> void:
		var previous=selected.duplicate()
		selected=[int(e.id)]
		super._draw_unit(e)
		selected=previous
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/contact-20261024")
	root.size=Vector2i(1920,1200);root.content_scale_size=root.size
	main=Probe.new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":1,"seed":601,"players":[{"race":0},{"race":1},{"race":2}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.camera=Vector2(64,64);main.zoom=1.25
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear();c.map.resource_obstacles.clear()
	c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.visual_roles.clear();c.map.source_walk_masks.clear();c.map.source_water_masks.clear();c.map._visual_water_fractions.clear();c.map._build_visual_relief();c.map.reset_solids([])
	var index=0;var report=[];main.selected=[]
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			var d=ACData.unit(race,kind)
			if d.air:continue
			var pos=Vector2(48.5+(index%10)*3.4,55+(index/10)*4.2)
			var unit=c.add_unit(race,kind,pos);unit.facing=[1,1];unit.body_direction=unit.facing;unit.turret_direction=unit.facing;main.selected.append(unit.id)
			report.append({"index":index,"race":race,"kind":kind,"name":d.name});index+=1
	for heading in range(4):
		var unit=c.add_unit(0,5,Vector2(49+heading*4,68));unit.anchored=true;unit.body_direction=ACData.packed(Vector2.from_angle(PI*.25+heading*PI*.5));unit.turret_direction=unit.body_direction;unit.facing=unit.body_direction;main.selected.append(unit.id)
	main.state=c.snapshot(-1);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(6);await RenderingServer.frame_post_draw
	var name="res://build/contact-20261024/ground-contact-gallery.png"
	root.get_texture().get_image().save_png(name)
	FileAccess.open("res://build/contact-20261024/order.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for direction in range(8):
		var vector=Vector2.from_angle(direction*TAU/8)
		var previous=Vector2.ZERO
		for progress in [0.01,.25,.5,.75,1.0]:
			var pose=main.assets.vehicle(0,5,vector,vector,progress,"idle",0)
			check(pose.chassis.anchor.is_equal_approx(Vector2(128,224)-pose.chassis.contact_offset),"stable hull registration %d %s"%[direction,progress])
			check(pose.chassis.contact_offset.y>=previous.y,"contact offset unfolds monotonically")
			previous=pose.chassis.contact_offset
		check(previous==Vector2(0,32),"all deployed headings share one fixed contact correction")
	main.camera=Vector2(55,68);main.zoom=2.5;main._sync_world_canvas();main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/contact-20261024/deployed-contact-close.png")
	FileAccess.open("res://build/contact-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"ground_types":index,"headings":8,"scope":"31 ground types representative contact gallery, tank contact registration eight headings/five deploy phases; all frames not a full art audit"},"\t"))
	print("GROUND_CONTACT_GALLERY ",index," ground types + eight deployed tank headings; ",checks," checks; failures=",failures.size());quit(0 if failures.is_empty() else 1)
