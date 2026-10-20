extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena():
	var c=ACCore.new();c.setup({"map":0,"seed":611,"players":[{"race":0},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c._sync_resource_obstacles();c.map.reset_solids([]);c.collision_index_valid=false
	c.players[0].as=10000;c.players[0].tera=10000
	return c
func _initialize():call_deferred("run")
func run():
	var c=arena();var w=c.add_unit(0,0,Vector2(25,30))
	check(c.command(0,{"type":"build","kind":2,"ids":[w.id],"pos":[35,30]})=="","distant plan accepted")
	check(c.buildings.is_empty() and w.order=="build_move","distant command creates no remote foundation")
	for i in range(200):
		c.time+=.05;c.paths_this_tick=0;c._tick_unit(w,.05)
		if w.order=="construct":break
	check(c.buildings.size()==1 and c.construction_reach(w,c.buildings[0]),"worker arrives within 0.18 tiles before creating foundation")
	if not c.buildings.is_empty():
		var b=c.buildings[0];var moving=0;var working=0;var passed=false;var continuous=true
		for i in range(250):
			c.time+=.05;c.paths_this_tick=0;c._tick_unit(w,.05)
			var before=float(b.progress);c._tick_building(b,.05)
			if w.moving:moving+=1;continuous=continuous and b.progress>before
			if w.action_intent=="construct":working+=1
			if c.collision_rect(w).intersects(c.footprint(b)):passed=true
			c._separate_units(.05)
		check(moving>20 and working>20 and passed,"builder alternates working and traversing its own scaffold")
		check(continuous,"construction advances during every traversal tick")
		b.progress=.9999;c._tick_building(b,.05)
		check(b.progress>=1 and w.order=="idle" and c._unit_fits(w,ACData.point(w.pos)),"finished builder exits to free ground")
	# A manual order from inside the scaffold releases the collision exception.
	c=arena();w=c.add_unit(0,0,Vector2(34,30));c.command(0,{"type":"build","kind":2,"ids":[w.id],"pos":[35,30]})
	for i in range(150):
		c.time+=.05;c.paths_this_tick=0;c._tick_unit(w,.05)
		if not c.buildings.is_empty():c._tick_building(c.buildings[0],.05)
		if w.has("_construction_site") and c.collision_rect(w).intersects(c.footprint(c.buildings[0])):break
	if not c.buildings.is_empty():
		var b=c.buildings[0];var progress=float(b.progress)
		c.command(0,{"type":"stop","ids":[w.id]});c._tick_unit(w,.05);c._tick_building(b,.05)
		check(not w.has("_construction_site") and c._unit_fits(w,ACData.point(w.pos)) and is_equal_approx(progress,float(b.progress)),"stop exits scaffold and pauses construction")
	# Damage is integrated with dt, including armor, upgrades and light bonus.
	for dt in [.025,.05,.1]:
		c=arena();var u=c.add_unit(0,13,Vector2(40,40));var target=c.add_unit(1,1,Vector2(42,40));target.hp=1000;target.order="hold"
		c.players[0].attack=2;c.players[1].armor=3;c._rebuild_collision_index()
		var before=float(target.hp)
		for i in range(roundi(2.0/dt)):c.time+=dt;c._tick_flame(u,target,dt)
		var expected=(9.0+4.0+9.0-float(target._definition.armor)-3.0)/.65*2.0
		check(absf(before-target.hp-expected)<.002,"continuous flame DPS independent of tick duration %s"%dt)
		check(c.effects.size()<=18,"flame presentation does not emit per-simulation-tick sound/projectiles")
	# Concave obstacle requires moving temporarily away from the final goal.
	for kind in [0,5,6,12,13]:
		c=arena()
		for y in range(35,47):c.map.terrain[y*128+45]=1
		for x in range(35,46):c.map.terrain[35*128+x]=1;c.map.terrain[46*128+x]=1
		c.map.reset_solids([])
		var u=c.add_unit(0,kind,Vector2(41,40));var goal=Vector2(50,40);u.order="move";u.goal=ACData.packed(goal)
		var valid=true
		for i in range(1200):
			c.time+=.05;c.paths_this_tick=0;c.collision_index_valid=false;c._tick_unit(u,.05)
			valid=valid and c._ground_fits_size(c._body_size(u),ACData.point(u.pos))
			if ACData.point(u.pos).distance_to(goal)<.6:break
		check(valid and ACData.point(u.pos).distance_to(goal)<.6,"unit escapes concave terrain via routed corners %d"%kind)
	var director=load("res://scripts/voice_director.gd").new()
	director.add_ping(Vector2(40,40),0)
	for i in range(1,80):director.add_ping(Vector2(42,41),i*.1)
	check(director.pings.size()==1 and director.pings[0].time==0,"same battle cannot continuously refresh minimap warning")
	director.add_ping(Vector2(90,90),2);check(director.pings.size()==2,"separate battle warns independently")
	director.add_ping(Vector2(40,40),8.01);check(director.pings.size()==3,"same battle warns again after eight seconds")
	director.free()
	var report={"checks":checks,"failures":failures};FileAccess.open("res://build/qa-v061-core.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOTFIX_CORE_V061 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
