extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var reports=[]
	for theme in range(3):
		for race in range(3):
			var c=ACCore.new();c.setup({"map":theme,"spawn_slots":[0,1,2,3],"players":[{"race":race},{"race":race},{"race":race},{"race":race}]})
			for owner in range(4):
				var hq=c.entity(c.players[owner].home);var d=ACData.building(race,0)
				check(d.w==4 and d.h==3,"all races use the same headquarters footprint")
				var rect=Rect2(ACData.point(hq.pos)-Vector2.ONE*.5,Vector2(d.w,d.h));var gap=INF
				for node in c.map.resources:
					if node.type!="as" or node.amount<=0:continue
					check(not rect.intersects(c.resource_rect(node).grow(ACMap.HQ_MINERAL_GAP)),"starting headquarters respects mineral clearance")
					if node.slot==owner:gap=minf(gap,ACMap.footprint_gap(rect,c.resource_rect(node)))
				check(gap>=ACMap.HQ_MINERAL_GAP and gap<ACMap.HQ_MINERAL_GAP+1,"starting headquarters hugs nearest legal mineral perimeter")
				var workers=[]
				for unit in c.units:
					if unit.owner==owner and unit.kind==0:workers.append(unit)
				check(workers.size()==4,"four starting workers")
				for unit in workers:
					check(is_equal_approx(unit.pos[1],workers[0].pos[1]) and unit.pos[1]>rect.end.y,"starting workers in one row below headquarters")
					check(c._unit_fits(unit,ACData.point(unit.pos),false),"starting worker ground/resource clearance")
				reports.append({"map":theme,"race":race,"slot":owner,"anchor":hq.pos,"gap":gap})
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":0},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c.map.resources=[{"id":100000,"type":"as","pos":[40.5,40],"collision_size":[2,1],"amount":1000,"initial_amount":1000,"busy":0,"slot":0}]
	c.add_building(0,0,Vector2(20,20),true);c.map.reset_solids(c.buildings);c._sync_resource_obstacles()
	check(c.placement(0,0,Vector2(43,40),false).contains("2칸"),"new headquarters rejected at one-tile gap")
	check(c.placement(0,0,Vector2(44,40),false)=="","new headquarters allowed at exactly two tiles")
	check(c.placement(0,2,Vector2(42,40),false)=="","ordinary building may touch mineral boundary")
	check(c.placement(0,2,Vector2(41,40),false)!="","ordinary building may not overlap mineral")
	c.map.resources[0].amount=0;c._sync_resource_obstacles()
	check(c.placement(0,0,Vector2(44,40),false)=="","depleted minerals do not retain headquarters exclusion")
	var output={"checks":checks,"failures":failures,"starts":reports}
	FileAccess.open("res://build/source-terrain/headquarters.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("HEADQUARTERS_SPACING checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
