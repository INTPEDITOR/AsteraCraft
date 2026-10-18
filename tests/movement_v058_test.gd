extends SceneTree
var failures=[]
var checks=0
func check(value,label):
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func arena(race):
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":race},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.resources.clear();c.map.buildable_map.fill(1);c._sync_resource_obstacles();c.map.reset_solids([]);c.collision_index_valid=false
	return c
func _initialize():call_deferred("run")
func run():
	for race in range(3):
		for kind in range(13):
			if ACData.unit(race,kind).air:continue
			var c=arena(race)
			# Two-cell aperture offset from start/goal: forces a route around a wall.
			for x in range(45,49):
				for y in range(128):
					if y not in [50,51]:c.map.terrain[y*128+x]=2
			c.map.reset_solids([])
			var u=c.add_unit(0,kind,Vector2(38,43));u.order="move";u.goal=[55,43]
			var route=c._clearance_path(u,ACData.point(u.pos),Vector2(55,43))
			check(not route.is_empty(),"two-cell route %d/%d"%[race,kind])
			var valid=true
			for point in route:
				if not c._ground_fits_size(c._body_size(u),ACData.point(point)):valid=false
			check(valid,"route body clearance %d/%d"%[race,kind])
			for tick in range(1800):
				c.time+=.05;c.paths_this_tick=0;c.collision_index_valid=false;c._tick_unit(u,.05)
				if ACData.point(u.pos).distance_to(Vector2(55,43))<1:break
			check(ACData.point(u.pos).distance_to(Vector2(55,43))<1,"traverse aperture %d/%d at %s"%[race,kind,u.pos])
	var c=arena(2);c.add_building(0,0,Vector2(20,20),true);c.map.reset_solids(c.buildings)
	check(not c.in_owl_power(0,Vector2(25,24)),"HQ does not grant owl construction power")
	var tower=c.add_building(0,2,Vector2(30,30),true);c.map.reset_solids(c.buildings)
	check(c.placement(0,3,Vector2(34,32),false)=="","owl construction near complete tower")
	check(c.placement(0,3,Vector2(43,32),false)!="","whole footprint requires tower")
	tower.progress=.5;check(not c.in_owl_power(0,Vector2(34,32)),"unfinished tower gives no power")
	tower.progress=1;tower.hp=0;check(not c.in_owl_power(0,Vector2(34,32)),"destroyed tower gives no power")
	c=arena(0);var a=c.add_unit(0,0,Vector2(40,40));var b=c.add_unit(0,12,Vector2(43,40))
	a.order="build_move";check(c._workers_can_overlap(a,b),"builder ignores unit collision")
	a.order="construct";check(c._workers_can_overlap(a,b),"constructing worker ignores unit collision")
	a.order="move";check(not c._workers_can_overlap(a,b),"ordinary worker retains collision")
	check(is_equal_approx(ACCore.TERA_INTERVAL,3.0),"Tera 3 second interval")
	print("MOVEMENT_V058 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
