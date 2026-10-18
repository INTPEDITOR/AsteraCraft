extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var timings=[]
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":2}]})
		var unit=c.units[0];var start=ACData.point(unit.pos)
		c.paths_this_tick=0;c._clearance_path(unit,start,start+Vector2(5,5))
		var key=Vector2i((c._body_size(unit)*16).ceil())
		var original=c.clearance_paths[key]
		var building=c.add_building(0,2,Vector2(55,55),true)
		for remove in [false,true]:
			if remove:building.hp=0
			c.map.reset_solids(c.buildings);c.paths_this_tick=0
			var began=Time.get_ticks_usec()
			c._clearance_path(unit,start,start+Vector2(5,5))
			var incremental=Time.get_ticks_usec()-began
			check(c.clearance_paths[key]==original,"map %d retains grid after change"%theme)
			var nav: AStarGrid2D=c.clearance_paths[key]
			var mismatch=0
			for y in range(512):
				for x in range(512):
					if nav.is_point_solid(Vector2i(x,y))==c.map.source_ground_fits(Vector2(key)/16.0,Vector2(x,y)*.25):mismatch+=1
			check(mismatch==0,"map %d exact full-grid collision after remove=%s"%[theme,remove])
			c.clearance_paths.clear();c.path_cache.clear();c.paths_this_tick=0
			began=Time.get_ticks_usec();c._clearance_path(unit,start,start+Vector2(5,5))
			timings.append({"map":theme,"removed":remove,"incremental_ms":incremental/1000.0,"rebuild_ms":(Time.get_ticks_usec()-began)/1000.0})
			original=c.clearance_paths[key]
		var rng=RandomNumberGenerator.new();rng.seed=5510
		for i in range(1000):
			var a=Vector2(rng.randf_range(1,127),rng.randf_range(1,127));var b=a+Vector2(rng.randf_range(-10,10),rng.randf_range(-10,10))
			var dimensions=c._body_size(unit);var expected=true
			var samples=maxi(1,ceili(a.distance_to(b)/.2))
			for sample in range(samples+1):
				if not c._ground_fits_size(dimensions,a.lerp(b,float(sample)/samples)):expected=false;break
			check(c._ground_sweep(dimensions,a,b)==expected,"sweep equivalence %d/%d"%[theme,i])
	print("NAVIGATION_CACHE_V0510 ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}));quit(0 if failures.is_empty() else 1)
