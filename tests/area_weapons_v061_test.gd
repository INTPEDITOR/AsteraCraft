extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena():
	var c=ACCore.new();c.setup({"map":0,"seed":611,"players":[{"race":0},{"race":0},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c.map.reset_solids([]);c.collision_index_valid=false
	return c
func _initialize():call_deferred("run")
func run():
	var c=arena();var u=c.add_unit(0,13,Vector2(40,40))
	var target=c.add_unit(1,1,Vector2(43,40));var between=c.add_unit(1,1,Vector2(41.5,40.1))
	var edge=c.add_unit(1,1,Vector2(42.8,40.6));var outside=c.add_unit(1,1,Vector2(41,42))
	var behind=c.add_unit(1,1,Vector2(39,40));var friendly=c.add_unit(0,1,Vector2(42,40))
	var air=c.add_unit(1,9,Vector2(42,40));var boarded=c.add_unit(1,1,Vector2(42,40));boarded.container=999
	for e in c.units:e.hp=1000
	c._rebuild_collision_index();c._tick_flame(u,target,.1)
	check(target.hp<1000 and between.hp<1000 and edge.hp<1000,"flame burns primary, intervening and cone-edge enemies")
	check(is_equal_approx(target.hp,between.hp),"cone does not double-hit primary victim")
	for e in [outside,behind,friendly,air,boarded]:check(e.hp==1000,"flame excludes outside cone, behind, friendly, air and boarded %s"%e.id)
	for entry in [[0,5],[0,6],[0,10],[0,12],[1,2],[1,3],[1,6],[1,12],[2,7],[2,8],[2,12]]:
		c=arena();c.players[0].race=entry[0];u=c.add_unit(0,entry[1],Vector2(40,40))
		target=c.add_unit(1,1,Vector2(43,40));var neighbor=c.add_unit(1,1,Vector2(43.4,40))
		friendly=c.add_unit(0,0,Vector2(43.4,40));air=c.add_unit(1,9,Vector2(43.4,40))
		var far=c.add_unit(1,1,Vector2(46,40))
		target.pos=[43,40];neighbor.pos=[43.4,40];friendly.pos=[43.4,40];air.pos=[43.4,40];far.pos=[46,40]
		for e in c.units:e.hp=1000
		c._rebuild_collision_index();c._attack_splash(u,target,float(u._definition.damage))
		check(neighbor.hp<1000,"explosive weapon splashes %s"%str(entry))
		check(target.hp==1000 and friendly.hp==1000 and air.hp==1000 and far.hp==1000,"splash excludes direct victim, allies, other layer, out of range %s"%str(entry))
	# Burst cannon keeps total damage and applies area damage on all three shells.
	c=arena();u=c.add_unit(0,12,Vector2(40,40));target=c.add_unit(1,1,Vector2(43,40))
	var neighbor=c.add_unit(1,1,Vector2(43.4,40));target.pos=[43,40];neighbor.pos=[43.4,40];target.hp=1000;neighbor.hp=1000;c._rebuild_collision_index()
	for i in range(3):ACBurstWeapon.shoot(c,u,target)
	check(absf((1000-target.hp)-40)<.01,"three cannon shells retain total direct damage")
	check(absf((1000-neighbor.hp)-16)<.01,"three cannon shells apply splash once per shell")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://build/qa-v061-area-weapons.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AREA_WEAPONS_V061 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
