extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/air-hover-20261024/"
class Probe:
	extends "res://tests/menu_v04_harness.gd"
	var bodies={}
	var shadows={}
	var rings={}
	var exhausts=0
	func _draw_unit_frame(frame: Dictionary,point: Vector2,extent: float,color: Color=Color.WHITE) -> Rect2:
		if frame.get("bomber_exhaust",false):exhausts+=1
		if not _palette_entity.is_empty() and not _palette_entity.has("progress"):
			var id=int(_palette_entity.id)
			if not bodies.has(id):bodies[id]={"point":point,"extent":extent,"texture":frame.texture.get_instance_id()}
		return super._draw_unit_frame(frame,point,extent,color)
	func _world_shadow(point: Vector2,dimensions: Vector2,opacity: float=.3) -> void:
		if not _palette_entity.is_empty():shadows[int(_palette_entity.id)]=point
		super._world_shadow(point,dimensions,opacity)
	func _world_transform(origin: Vector2=Vector2.ZERO,rotation: float=0.0,scale_value: Vector2=Vector2.ONE) -> void:
		if not _palette_entity.is_empty() and scale_value==Vector2(1,.46):rings[int(_palette_entity.id)]=origin
		super._world_transform(origin,rotation,scale_value)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect()
	main=Probe.new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect();await frames(3)
	main._start_local({"map":1,"players":[{"race":0},{"race":1},{"race":2}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.settings.edge_scroll=false
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear()
	main.camera=Vector2(64,64);main.zoom=1.75
	var units=[]
	for race in range(3):
		for kind in range(ACData.get_data().units[race].size()):
			if not ACData.unit(race,kind).air:continue
			var index=units.size();var unit=c.add_unit(race,kind,Vector2(54+(index%6)*4,61+(index/6)*6))
			unit.action="idle";unit.moving=false;unit.facing=[1.0,0.0];unit.body_direction=unit.facing.duplicate();units.append(unit)
	main.selected=units.map(func(unit):return unit.id);main.state=c.snapshot();main._update_hud()
	var samples={};var report=[]
	for unit in units:samples[int(unit.id)]=[]
	for index in range(16):
		main.state.time=10.0+index*.25;main.visual_clock=0
		main.bodies.clear();main.shadows.clear();main.rings.clear();main.exhausts=0
		for node in main._entity_canvases.values():node.next_pose=0
		main._sync_world_canvas();await frames(4);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"idle-%02d.png"%index)
		for unit in units:
			var id=int(unit.id);check(main.bodies.has(id),"aircraft drawn %d:%d"%[unit.race,unit.kind])
			if not main.bodies.has(id):continue
			var foot=main._ground_point(main._visual_position(unit));var pose=main.bodies[id]
			check(main.shadows.get(id,Vector2.INF).is_equal_approx(foot),"shadow stays on ground %d"%id)
			check(main.rings.get(id,Vector2.INF).is_equal_approx(foot),"selection ring stays on ground %d"%id)
			var offset=main._air_hover_offset(unit)
			check(main._air_hover_offset(unit,99)==offset,"hover phase does not reset with action clock")
			if not (unit.race==0 and unit.kind==8):check(pose.point.is_equal_approx(foot-Vector2(0,22*main.zoom)+offset),"drawn body follows hover %d"%id)
			samples[id].append({"y":pose.point.y,"extent":pose.extent,"texture":pose.texture,"offset":offset.y})
		check(main.exhausts==0,"idle bombers emit no exhaust")
	for unit in units:
		var values: Array=samples[int(unit.id)];var lowest=INF;var highest=-INF
		for value in values:
			lowest=minf(lowest,float(value.y));highest=maxf(highest,float(value.y))
			check(is_equal_approx(float(value.extent),float(values[0].extent)),"hover never resizes artwork")
		check(highest-lowest>3,"visible idle hover %d:%d"%[unit.race,unit.kind])
		main.paused=true;var frozen=main._air_hover_offset(unit);main.visual_clock+=.01
		check(main._air_hover_offset(unit)==frozen,"pause freezes flight motion")
		main.paused=false;main.visual_clock=0;var a=main._air_hover_offset(unit);main.visual_clock=.01;var b=main._air_hover_offset(unit)
		check(a.distance_to(b)<.15,"flight motion advances smoothly between snapshots")
		main.paused=true
		report.append({"race":unit.race,"kind":unit.kind,"name":ACData.unit(unit.race,unit.kind).name,"body_y_span":highest-lowest})
	var ground=c.add_unit(0,1,Vector2(64,64));check(main._air_hover_offset(ground)==Vector2.ZERO,"ground units never hover")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"aircraft":report,"frames":16}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("AIR_HOVER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
