extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var report=[]
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":1}]})
		c.units.clear();c.buildings.clear();c.map.resource_obstacles.clear();c.map.reset_solids([])
		check(c.map.source_detail_active,"8px source geometry active %d"%theme)
		check(c.map.visual_ramps.size()==[12,6,4][theme],"all source ramp regions %d"%theme)
		var opened=0
		for y in range(512):
			for x in range(512):
				var tile=(y/4)*128+x/4;var bit=(y%4)*4+x%4
				var expected=(c.map.source_walk_masks[tile]&(1<<bit))!=0
				var p=Vector2(x,y)*.25-Vector2.ONE*.375
				check(c.map.source_ground_fits(Vector2.ONE*.1,p)==expected,"source mask exact %d"%theme)
				if c.map.visual_role(tile)==3 and c.map.is_water(tile):check(not expected,"converted water has no walkable minitiles")
				if expected and c.map.terrain[tile]!=0:opened+=1
		var traversed=0
		for ramp in c.map.visual_ramps:
			for kind in [0,12]:
				c.units.clear();c.collision_index_valid=false;c.paths_this_tick=0
				var center: Vector2=ramp.center-Vector2.ONE*.5
				var axis: Vector2=ramp.direction
				var a=center-axis*(ramp.length*.5+1.5)
				var b=center+axis*(ramp.length*.5+1.5)
				var unit=c.add_unit(0,kind,a)
				# Actual body clearance picks the closest usable landing.
				var route=c._clearance_path(unit,a,b)
				var label="map %d ramp %s kind %d"%[theme,ramp.center,kind]
				check(not route.is_empty(),"route "+label)
				if route.is_empty():continue
				# Shortened movement paths omit the starting point. Read the same
				# snapped entrance from the clearance grid instead of mistaking
				# the first (often final) waypoint for the ramp's entry landing.
				var dimensions=c._body_size(unit)
				var nav: AStarGrid2D=c.clearance_paths[Vector2i((dimensions*16).ceil())]
				var start=Vector2(c._clearance_free(nav,a,dimensions,true))*nav.cell_size
				var goal=ACData.point(route[-1])
				check(start.distance_to(a)<3 and goal.distance_to(b)<3,"landings stay near source ramp "+label)
				check((start-center).dot(axis)<0 and (goal-center).dot(axis)>0,"route crosses ramp "+label)
				var previous=start
				for raw in route:
					var p=ACData.point(raw)
					check(c._ground_sweep(c._body_size(unit),previous,p),"swept route clearance "+label)
					previous=p
				unit.pos=ACData.packed(start);unit.goal=ACData.packed(goal);unit.order="move";unit.path=[]
				for tick in range(1200):
					c.time+=.05;c.paths_this_tick=0;c.collision_index_valid=false;c._tick_unit(unit,.05)
					if ACData.point(unit.pos).distance_to(goal)<.6:break
				check(ACData.point(unit.pos).distance_to(goal)<.6,"actual traversal "+label)
				traversed+=1
		# Resource/building occupancy must still override otherwise open fine cells.
		var p=c.map.nearest_free(Vector2(64,64))
		c.map.set_resource_obstacles([Rect2(p-Vector2.ONE,Vector2.ONE*2)])
		check(not c.map.source_ground_fits(Vector2.ONE*.2,p),"dynamic resource blocks fine terrain")
		c.map.set_resource_obstacles([])
		report.append({"theme":theme,"ramps":c.map.visual_ramps.size(),"traversals":traversed,"recovered_walk_minitiles":opened})
	var output={"checks":checks,"failures":failures,"maps":report}
	DirAccess.make_dir_recursive_absolute("res://build/source-terrain")
	FileAccess.open("res://build/source-terrain/navigation.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("SOURCE_TERRAIN ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
