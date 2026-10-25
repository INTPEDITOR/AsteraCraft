extends "res://tests/abilities_v060_test.gd"
var records=[]
func walk_case(race: int,axis: int,reverse: bool,offset: float,crossing: bool=false) -> void:
	var c=arena(race,race)
	c.map.source_walk_masks.clear();c.map.source_detail_active=false;c.map.height_map.fill(0)
	var d=ACData.building(race,2);var origin=Vector2(40,40)
	var a=c.add_building(0,2,origin,true)
	var b=c.add_building(0,2,origin+Vector2(float(d.w),0) if axis==0 else origin+Vector2(0,float(d.h)),true)
	if crossing:
		c.add_building(0,2,origin+Vector2(0,float(d.h)),true);c.add_building(0,2,origin+Vector2(float(d.w),float(d.h)),true)
	c.map.reset_solids(c.buildings);c.collision_index_valid=false
	var edge=40+float(d.w if axis==0 else d.h)-.5
	var start=Vector2(edge+offset,37) if axis==0 else Vector2(37,edge+offset)
	var goal=Vector2(edge-offset,44) if axis==0 else Vector2(44,edge-offset)
	if crossing:
		# Start in the upper seam so the shortest route must turn through the
		# four-way junction, rather than taking the unobstructed outside edge.
		start=Vector2(edge,40.25);goal=Vector2(40+float(d.w)*2+2,40+float(d.h)-.5)
	if reverse:var swap=start;start=goal;goal=swap
	var u=c.add_unit(0,0,start);var before=u.pos
	# Spawning uses the ordinary free-position resolver. This fixture models
	# a worker that has already walked into the legal upper passage.
	if crossing:c._set_unit_position(u,start)
	c.command(0,{"type":"move","ids":[u.id],"pos":ACData.packed(goal)})
	var samples=0;var maximum=0.0;var illegal=false;var arrived=false
	for tick in range(600):
		c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index();c._tick_unit(u,.05);c._separate_units(.05)
		var point=c.center(u)
		if not c._ground_fits_size(c._body_size(u),point):
			samples+=1
			var error=absf(point[axis]-edge)
			if crossing:error=minf(absf(point.x-(40+float(d.w)-.5)),absf(point.y-(40+float(d.h)-.5)))
			maximum=maxf(maximum,error)
			if error>.002:illegal=true
		if point.distance_to(goal)<.55:arrived=true;break
	var label="%d axis%d reverse%s offset%s cross%s"%[race,axis,reverse,offset,crossing]
	check(arrived and samples>0,"worker crosses the actual shared boundary "+label)
	check(not illegal and maximum<=.002,"contact center remains on exact edge "+label)
	var off=Vector2(edge+.12,40.5) if axis==0 else Vector2(40.5,edge+.12)
	check(not c._ground_fits_size(c._body_size(u),off,0),"interior parallel lane rejected "+label)
	records.append({"case":label,"arrived":arrived,"samples":samples,"max_error_tiles":maximum,"pos":u.pos,"path":u.path,"goal":u.goal,"order":u.order})
func run():
	for race in range(3):
		for axis in [0,1]:
			for reverse in [false,true]:
				for offset in [0.0,.35,-.35]:walk_case(race,axis,reverse,offset)
		walk_case(race,0,false,0,true)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records}
	DirAccess.make_dir_recursive_absolute("res://build/worker-centerline-20261026")
	FileAccess.open("res://build/worker-centerline-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WORKER_CENTERLINE ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures,"cases":records.size()}));quit(0 if failures.is_empty() else 1)
