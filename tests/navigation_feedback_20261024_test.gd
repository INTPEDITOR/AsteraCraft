extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var journeys=[]
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":2}]})
		c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		for kind in [0,1]:
			for pair in [[0,1],[1,2],[2,3],[3,0]]:
				c.units.clear();c.collision_index_valid=false;c.paths_this_tick=0
				var u=c.add_unit(0,kind,ACData.point(c.map.starts[pair[0]]));var start=ACData.point(u.pos)
				var goal=c.unit_free_position(0,kind,ACData.point(c.map.starts[pair[1]]))
				var route=c._clearance_path(u,start,goal)
				var label="map%d kind%d %s"%[theme,kind,pair]
				check(not route.is_empty() and ACData.point(route.back()).distance_to(goal)<.4,"complete connected route "+label)
				var previous=start;var swept=true;var length=0.0
				for raw in route:
					var p=ACData.point(raw);swept=swept and c._ground_sweep(c._body_size(u),previous,p);length+=previous.distance_to(p);previous=p
				check(swept,"entire shortened route fits the body "+label)
				u.goal=ACData.packed(goal);u.order="move";u.path=[]
				var arrived=false;var walked=0.0
				for tick in range(4000):
					c.time+=.05;c.paths_this_tick=0;u.moving=false
					var before=ACData.point(u.pos);arrived=c._move(u,goal,.05,.25);walked+=before.distance_to(ACData.point(u.pos))
					if arrived:break
				check(arrived and ACData.point(u.pos).distance_to(goal)<.4,"actual map crossing "+label)
				check(walked<=length*1.12+1.5,"movement follows shortened route "+label)
				journeys.append({"map":theme,"kind":kind,"slots":pair,"route":length,"walked":walked,"arrived":arrived})
		print("NAVIGATION_MAP_FINISHED ",theme)
	var output={"checks":checks,"failures":failures,"journeys":journeys}
	FileAccess.open("res://build/player_colors_20261024/navigation.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("NAVIGATION_FEEDBACK ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
