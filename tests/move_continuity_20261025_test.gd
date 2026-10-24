extends SceneTree

var checks=0
var failures=[]
var observations=[]
var output="res://build/move-continuity-20261025/"

func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output+=args[0]+"/"
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)

func clear_units(c) -> void:
	c.units.clear();c.collision_index_valid=false;c.paths_this_tick=0;c.path_time_this_tick=0
	c.crowd_arrival_cache.clear()

func open_line(c,unit,length: float=16) -> Array:
	for y in range(24,105,3):
		for x in range(24,100,3):
			var from=Vector2(x,y);var to=from+Vector2(length,0)
			if c._ground_sweep(c._body_size(unit),from,to):return [from,to]
	return []

func run() -> void:
	var c=ACCore.new();c.setup({"map":1,"seed":20261025,"players":[{"race":0},{"race":1},{"race":2}]})
	c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			if ACData.unit(race,kind).air:continue
			clear_units(c)
			var unit=c.add_unit(race,kind,Vector2(67,52))
			var line=open_line(c,unit)
			check(line.size()==2,"open test route exists %d:%d"%[race,kind])
			if line.is_empty():continue
			c._set_unit_position(unit,line[0]);unit.order="move";unit.goal=ACData.packed(line[1])
			unit.path=[ACData.packed(line[1])];unit._path_goal=unit.goal.duplicate();unit.path_rev=c.map.revision;unit.repath=0
			# A real busy tick may exhaust its path budget before this unit's turn.
			c.paths_this_tick=1;c.path_time_this_tick=5000;c.time=10.0
			unit._shortcut_at=99.0;unit._shortcut_goal=unit.goal.duplicate()
			var previous=ACData.point(unit.pos)
			c._move(unit,line[1],.05)
			var travelled=previous.distance_to(ACData.point(unit.pos))
			check(travelled>=float(ACData.unit(race,kind).speed)*.05*.99,"busy path tick keeps existing movement %d:%d"%[race,kind])
			check(not unit.path.is_empty(),"busy path tick retains safe route %d:%d"%[race,kind])
			observations.append({"case":"refresh_budget","race":race,"kind":kind,"distance":travelled,"expected_distance":float(ACData.unit(race,kind).speed)*.05,"path_retained":not unit.path.is_empty()})
	# A new order has no reusable path; it must wait rather than move blindly.
	clear_units(c)
	var tank=c.add_unit(0,5,Vector2(67,52));var line=open_line(c,tank)
	c._set_unit_position(tank,line[0]);tank.order="move";tank.goal=ACData.packed(line[1]);tank.path=[]
	c.paths_this_tick=1;c.path_time_this_tick=5000;tank._shortcut_at=99.0;tank._shortcut_goal=tank.goal.duplicate()
	var previous=ACData.point(tank.pos);c._move(tank,line[1],.05)
	check(previous==ACData.point(tank.pos),"new route still waits safely when budget is exhausted")
	# A changed terrain revision cannot use the old route as if it were current.
	tank.path=[ACData.packed(line[1])];tank._path_goal=tank.goal.duplicate();tank.path_rev=c.map.revision-1
	c._move(tank,line[1],.05)
	check(previous==ACData.point(tank.pos),"stale terrain route waits for a new search")
	clear_units(c)
	tank=c.add_unit(0,5,line[0]);var blocker=c.add_unit(0,5,line[0].lerp(line[1],.5))
	tank.order="move";tank.goal=ACData.packed(line[1]);tank.blocked_clock=1.0
	var route=c._clearance_path(tank,line[0],line[1]);var clear=true;previous=line[0]
	for raw in route:
		var point=ACData.point(raw);var samples=maxi(1,ceili(previous.distance_to(point)/.05))
		for index in range(samples+1):
			if not c._unit_fits(tank,previous.lerp(point,float(index)/samples)):clear=false;break
		previous=point
	check(not route.is_empty() and clear,"shortened crowd route preserves the parked vehicle detour")
	observations.append({"case":"parked_vehicle_detour","route":route,"avoids_blocker":clear})
	c.command(0,{"type":"context","ids":[tank.id],"target":-1,"pos":ACData.packed(line[0])})
	check(not tank.get("_path_avoids_units",false) and not tank.has("_formation_anchor"),"new single order clears previous detour and formation")
	var goal=line[0]+Vector2(4,0)
	c._set_unit_position(tank,goal-Vector2(2.2,0));c._set_unit_position(blocker,goal+Vector2(.9,0))
	tank.order="move";tank.goal=ACData.packed(goal);tank._formation_anchor=[90.0,90.0]
	blocker.order="idle";blocker.goal=blocker.pos.duplicate();blocker._formation_anchor=[91.0,91.0]
	c.crowd_arrival_cache.clear()
	check(not c._crowd_arrived(tank,goal,.5),"unrelated parked troops do not cause formation arrival")
	blocker._formation_anchor=tank._formation_anchor.duplicate();c.crowd_arrival_cache.clear()
	check(c._crowd_arrived(tank,goal,.5),"same formation can settle beside its occupied slot")
	c._set_unit_position(blocker,goal+Vector2(2,0));c.crowd_arrival_cache.clear()
	check(not c._crowd_arrived(tank,goal,.5),"unoccupied formation goal still requires approaching the destination")
	c.add_building(0,2,goal-Vector2(1,0),true);c.map.reset_solids(c.buildings);c.collision_index_valid=false;c.crowd_arrival_cache.clear()
	check(not c._crowd_arrived(tank,goal,.5),"a terrain or building obstacle is not mistaken for an arrived formation")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MOVE_CONTINUITY ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures.size(),"ground_units":observations.filter(func(item):return item.case=="refresh_budget").size()}))
	quit(0 if failures.is_empty() else 1)
