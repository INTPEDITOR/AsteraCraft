extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():
	var c=ACCore.new();c.setup({"map":0,"spawn_slots":[0,2],"players":[{"race":1},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c.collision_index_valid=false
	var hq=c.add_building(0,0,Vector2(30,30),true);c.map.reset_solids(c.buildings)
	var spawn=c.center(hq)+Vector2(0,ACData.building(1,0).h*.5+.85)
	var worker=c.add_unit(0,0,spawn);worker.order="idle"
	var soldier=c.add_unit(1,1,spawn+Vector2(2,0))
	ACCitrusBrood.producer(c,hq)
	var pods=ACCitrusBrood.idle_pods(c,hq)
	check(pods.size()==3,"three brood bodies spawn despite ordinary units at the outlet")
	check(ACData.point(pods[0].pos).distance_to(spawn)<.001,"a worker does not force brood away from the preferred spawn")
	for pod in pods:check(c._unit_fits(pod,spawn,true)==(pod.id==pods[0].id),"brood spacing considers other brood only")
	c._set_unit_position(worker,Vector2(50,50));c._set_unit_position(soldier,Vector2(53,50))
	for pod in pods:
		check(c._unit_fits(worker,ACData.point(pod.pos)) and c._unit_fits(soldier,ACData.point(pod.pos)),"workers and combat units can pass through brood")
		for other in pods:
			if other.id!=pod.id:check(not c.collision_rect(pod).intersects(c.collision_rect(other)) and not c._unit_fits(pod,ACData.point(other.pos)),"brood bodies remain separated from each other")
	var pod=pods[0];var old=pod.pos.duplicate();worker.pos=pod.pos.duplicate()
	check(not c._resolve_unit_pair(worker,pod,false,.05) and pod.pos==old,"ordinary units never push a brood body")
	c._set_unit_position(worker,Vector2(50,50));c.collision_index_valid=false
	pod.brood_state="morph"
	check(c._unit_fits(soldier,ACData.point(pod.pos)),"morphing brood keeps the same pass-through policy")
	var unit=c.transform_brood(pod,1)
	check(unit.collision_layer==c.COLLISION_GROUND and not c._unit_fits(soldier,ACData.point(unit.pos)),"completed combat unit restores normal collision")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://build/source-terrain/brood-collision.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BROOD_COLLISION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
