extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":2},{"race":0}]})
		c.units.clear();c.buildings.clear();c.collision_index_valid=false;c.map.reset_solids([])
		for vent in c.map.resources:
			if vent.type!="tera":continue
			c.buildings.clear();c.collision_index_valid=false;c.map.reset_solids([])
			var base=c.map.bases[int(vent.base)]
			var hq=c.add_building(0,0,(ACData.point(base.pos)-Vector2(2,1.5)).floor(),true)
			c.map.reset_solids(c.buildings)
			var anchor=c.refinery_anchor(vent)
			check(c.placement(0,1,anchor,false)=="","map %d vent %d builds without tower"%[theme,vent.id])
			hq.hp=0
			check(c.placement(0,1,anchor,false).contains("본진"),"destroyed HQ prevents Tera")
			hq.hp=100;hq.progress=.5
			check(c.placement(0,1,anchor,false).contains("본진"),"unfinished HQ prevents Tera")
			hq.progress=1;hq.pos=[110,110]
			if c.center(hq).distance_to(ACData.point(vent.pos))>ACCore.TERA_HQ_RADIUS:
				check(c.placement(0,1,anchor,false).contains("본진"),"distant HQ prevents Tera")
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":2},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.resources.clear();c.map.buildable_map.fill(1);c._sync_resource_obstacles();c.map.reset_solids([]);c.collision_index_valid=false
	check(c.placement(0,0,Vector2(30,30),false)=="","HQ without tower")
	check(c.placement(0,2,Vector2(30,30),false)=="","tower without tower")
	c.add_building(0,0,Vector2(20,20),true)
	check(c.placement(0,3,Vector2(34,32),false)!="","other buildings still require tower")
	c.add_building(0,2,Vector2(30,30),true);c.map.reset_solids(c.buildings)
	check(c.placement(0,3,Vector2(34,32),false)=="","other buildings inside tower range")
	check(c.placement(0,3,Vector2(60,60),false).contains("규율탑"),"other buildings outside tower range rejected")
	print("OWL_PLACEMENT_V0510 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
