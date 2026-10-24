extends SceneTree
var checks=0
var failures=[]
var records=[]
var output="res://build/move-attack-followup-20261025/"
var baseline=false
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output+=args[0]+"/"
	baseline="--baseline" in args
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func open_line(c,probe) -> Array:
	for y in range(24,100,3):
		for x in range(24,100,3):
			var from=Vector2(x,y);var to=from+Vector2(16,0)
			if c._ground_sweep(c._body_size(probe),from,to) and c._ground_sweep(Vector2(2,2),from+Vector2(4,0),from+Vector2(12,0)):return [from,to]
	return []
func clear(c) -> void:
	c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
	c.paths_this_tick=0;c.path_time_this_tick=0;c.crowd_arrival_cache.clear();c.path_cache.clear()
func run() -> void:
	var c=load("res://build/move-attack-followup-20261025/baseline_core.gd").new() if baseline else ACCore.new()
	c.setup({"map":1,"seed":251026,"players":[{"race":0},{"race":1},{"race":2}]})
	clear(c)
	var tank=c.add_unit(0,5,Vector2(67,52));var line=open_line(c,tank)
	check(line.size()==2,"real source map has a clear test field")
	var origin: Vector2=line[0];var goal: Vector2=line[1]
	c._set_unit_position(tank,origin)
	var enemy=c.add_unit(1,1,origin+Vector2(0,8))
	var friend=c.add_unit(0,5,origin.lerp(goal,.5))
	tank._auto_target=enemy.id;tank._scan_at=c.time+10
	tank._surround_target=enemy.id;tank._surround_offset=[-1,0];tank._surround_until=c.time+10;tank._surround_retry=c.time+10
	c.command(0,{"type":"context","ids":[tank.id],"target":-1,"pos":ACData.packed(goal)})
	check(int(tank.get("_auto_target",-1))<0,"right-click movement releases previous automatic combat target")
	check(float(tank.get("_surround_until",0))<=c.time,"manual movement releases stale surround reservation")
	tank.blocked_clock=1.0
	var route=c._clearance_path(tank,origin,goal);var clear_route=not route.is_empty();var previous=origin
	for raw in route:
		var point=ACData.point(raw);var count=maxi(1,ceili(previous.distance_to(point)/.05))
		for index in range(count+1):
			if not c._unit_fits(tank,previous.lerp(point,float(index)/count)):clear_route=false;break
		previous=point
	check(clear_route,"a retreating former combatant can route around parked allies")
	records.append({"case":"manual_retreat","stale_target":tank.get("_auto_target",-1),"detour_clear":clear_route})
	clear(c)
	var attacker=c.add_unit(2,1,origin)
	var target=c.add_unit(0,0,origin+Vector2(12,0))
	c.add_building(0,2,origin+Vector2(5,-1),true);c.map.reset_solids(c.buildings);c.collision_index_valid=false
	attacker.order="attack";attacker.target=target.id;c.visibility[2].fill(1)
	c.time=10;c.paths_this_tick=1;c.path_time_this_tick=5000
	var first=c._melee_approach(attacker,target)
	check(first.distance_to(ACData.point(attacker.pos))<.1,"busy approach waits without crossing the wall")
	check(float(attacker.get("_surround_retry",0))<=c.time+.051,"deferred search is not cached as an unreachable target")
	c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0
	var retry=c._melee_approach(attacker,target)
	check(retry.distance_to(ACData.point(attacker.pos))>1,"melee retries the reachable approach on the next free tick")
	records.append({"case":"deferred_melee_approach","first":ACData.packed(first),"retry":ACData.packed(retry),"retry_until":attacker.get("_surround_retry",0)})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("MOVE_ATTACK_FOLLOWUP ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
