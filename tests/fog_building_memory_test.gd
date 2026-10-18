extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():
	var core=ACCore.new();core.setup({"map":0,"spawn_slots":[0,2],"players":[{"race":0},{"race":1}]})
	core.units.clear();core.buildings.clear();core.map.terrain.fill(0);core.map.height_map.fill(0);core.map.resources.clear();core.map.buildable_map.fill(1);core.map.visual_roles.fill(0);core.map._build_visual_relief();core.map.reset_solids([])
	var building=core.add_building(1,0,Vector2(60,60),true)
	var point=Vector2i(core.center(building));var index=point.y*128+point.x
	core.visibility[0].fill(0);core.explored[0].fill(1)
	check(core.snapshot(0).building_memory.is_empty(),"explored but unobserved buildings never appear")
	core.visibility[0][index]=1;var visible=core.snapshot(0)
	check(visible.buildings.size()==1 and visible.building_memory.is_empty(),"visible building is live and is recorded")
	core.visibility[0].fill(0);var fog_before=core.visibility[0].duplicate();var seen_before=core.explored[0].duplicate()
	var hidden=core.snapshot(0)
	check(hidden.buildings.is_empty() and hidden.building_memory.size()==1,"hidden building becomes a separate last-seen marker")
	var marker=hidden.building_memory[0]
	check(marker.remembered and marker.pos==building.pos and marker.progress==1,"remembered location and last observed appearance match")
	check(not marker.has("hp") and not marker.has("queue") and not marker.has("research"),"memory provides no current economy combat or production data")
	building.hp=1;building.progress=.5;building.queue=[{"kind":1,"left":5}];core.time+=10
	check(core.snapshot(0).building_memory[0]==marker,"hidden live changes cannot refresh the marker")
	building.hp=0;core.buildings.clear()
	check(core.snapshot(0).building_memory[0]==marker,"hidden destruction preserves last-seen presence")
	check(core.visibility[0]==fog_before and core.explored[0]==seen_before,"remembered buildings provide no vision or explored area")
	core.visibility[0][index]=1
	check(core.snapshot(0).building_memory.is_empty(),"revisiting the empty site clears obsolete memory")
	building=core.add_building(1,4,Vector2(60,60),false);building.progress=.2
	point=Vector2i(core.center(building));index=point.y*128+point.x;core.visibility[0][index]=1;core.snapshot(0)
	core.visibility[0].fill(0);building.progress=1
	check(core.snapshot(0).building_memory[0].progress==.2,"unfinished construction freezes at the last observed stage")
	core.visibility[0][index]=1;core.snapshot(0);core.visibility[0].fill(0)
	check(core.snapshot(0).building_memory[0].progress==1,"new scouting refreshes the recorded appearance")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://build/source-terrain/fog-building-memory.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FOG_BUILDING_MEMORY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
