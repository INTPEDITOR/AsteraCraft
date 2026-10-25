extends SceneTree
var checks=0
var failures=[]
var records=[]
var output="res://build/cliff-fix-20261025/"
var detail={}
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output+=args[0]+"/"
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)
func raw_level(c,p: Vector2) -> int:
	var sub=Vector2i(((p+Vector2.ONE*.5)*4).floor())
	var tile=(sub.y/4)*128+sub.x/4;var bit=(sub.y%4)*4+sub.x%4
	return (int(detail.maps[c.map.theme].height_bits[tile])>>(bit*2))&3
func enemy_point(c,p: Vector2,level: int) -> Vector2:
	for radius in range(1,8):
		for y in range(maxi(1,int(p.y)-radius),mini(127,int(p.y)+radius+1)):
			for x in range(maxi(1,int(p.x)-radius),mini(127,int(p.x)+radius+1)):
				var q=Vector2(x,y)
				if q.distance_to(p)>8 or not c._ground_fits_size(c.collision_size(1,0),q) or not c._ground_fits_size(c.collision_size(0,0),q):continue
				if raw_level(c,q)<=level:continue
				if int(c.map.height_map[y*128+x])<=level:continue
				return q
	return Vector2.INF
func run() -> void:
	detail=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_terrain_detail.json"))
	var probes=JSON.parse_string(FileAccess.get_file_as_string("res://build/cliff-fix-20261025/height-probe-before.json"))
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":1}]})
		c.units.clear();c.buildings.clear();c.map.resource_obstacles.clear();c.map.reset_solids([]);c.collision_index_valid=false
		var tested_push=false
		for sample in probes[theme].examples:
			var p=ACData.point(sample.pos);var q=ACData.point(sample.high_target) if sample.has("high_target") else enemy_point(c,p,int(sample.actual))
			check(q.is_finite(),"higher ground target exists map=%d source=%s"%[theme,p])
			if not q.is_finite():continue
			c.units.clear();c.collision_index_valid=false;c.vision_signatures.clear()
			var unit=c.add_unit(0,0,p);var enemy=c.add_unit(1,0,q)
			var level=int(c.map.call("ground_level",p)) if c.map.has_method("ground_level") else int(c.map.height_map[int(p.y)*128+int(p.x)])
			check(level==int(sample.actual),"ground eye height matches exact foot map=%d source=%s"%[theme,p])
			c._update_vision()
			check(not c.can_see(0,enemy),"cliff foot does not grant high-ground sight map=%d source=%s"%[theme,p])
			var hidden=not c.can_see(0,enemy)
			var drone=c.add_unit(0,8,p);c._update_vision()
			check(c.can_see(0,enemy),"air spotter still reveals high ground map=%d source=%s"%[theme,p])
			drone.hp=0
			if not tested_push and not c._ground_sweep(c.collision_size(0,0),p,q):
				var old=unit.pos.duplicate();var moved=c._displace_unit(unit,q-p)
				check(not moved and unit.pos==old,"collision correction cannot jump across cliff map=%d"%theme)
				c._set_unit_position(unit,p)
				var rock=Vector2.INF
				for index in range(1,40):
					var candidate=p.lerp(q,float(index)/40)
					if not c._ground_fits_size(c.collision_size(0,0),candidate):rock=candidate;break
				check(rock.is_finite(),"solid cliff face exists map=%d"%theme)
				if rock.is_finite():
					c.command(0,{"type":"context","ids":[unit.id],"target":-1,"pos":ACData.packed(rock)})
					for tick in range(80):
						var previous=ACData.point(unit.pos);c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0
						c._tick_unit(unit,.05)
						check(c._ground_fits_size(c.collision_size(0,0),ACData.point(unit.pos)) and c._ground_sweep(c.collision_size(0,0),previous,ACData.point(unit.pos)),"command toward cliff stays on passable ground map=%d tick=%d"%[theme,tick])
				tested_push=true
			records.append({"map":theme,"low":ACData.packed(p),"high_target":ACData.packed(q),"eye_height":level,"actual_height":sample.actual,"high_ground_hidden":hidden})
		check(tested_push,"cliff displacement and blocked move exercised map=%d"%theme)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CLIFF_GUARD ",JSON.stringify({"passed":result.passed,"checks":checks,"cases":records.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
