extends SceneTree
func _initialize():
	var checks=0;var failures=[]
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":2}]});var sizes={}
		for race in range(3):
			for kind in range(ACData.unit_count(race)):
				if ACData.unit(race,kind).air:continue
				var key=Vector2i((ACCore.collision_size(race,kind)*16).ceil())
				if sizes.has(key):continue
				sizes[key]=true;c.paths_this_tick=0
				var probe={"id":-10,"race":race,"kind":kind,"_body_size":Vector2(key)/16.0,"blocked_clock":0,"order":"idle","hp":1,"container":-1}
				c._clearance_path(probe,Vector2(20,20),Vector2(21,20))
				var nav: AStarGrid2D=c.clearance_paths[key];var mismatch=false
				for y in range(512):
					for x in range(512):
						checks+=1
						if nav.is_point_solid(Vector2i(x,y))==c.map.source_ground_fits(Vector2(key)/16.0,Vector2(x,y)*.25):mismatch=true
				if mismatch:failures.append("terrain and dynamic occupancy mismatch %d %s"%[theme,key])
		print("CLEARANCE_MAP ",theme," sizes=",sizes.size())
	print("CLEARANCE_TEMPLATES_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
