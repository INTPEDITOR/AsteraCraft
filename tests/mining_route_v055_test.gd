extends SceneTree
var checks=0
var failures: Array=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	for theme in range(3):
		for race in range(3):
			var c=ACCore.new();c.setup({"map":theme,"spawn_slots":[0,1,2,3],"players":[{"race":race},{"race":race},{"race":race},{"race":race}]})
			for u in c.units:
				if u.kind==0:u.order="gather";u.target=c.nearest_resource(ACData.point(u.pos),"as",int(u.owner))
			for tick in range(1200):c.step(.05)
			for owner in range(4):check(c.players[owner].gathered>=80,"all original starts mine %d/%d/%d (%s)"%[theme,race,owner,c.players[owner].gathered])
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":0},{"race":1}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.resources=[{"id":100000,"pos":[50.5,50],"type":"as","amount":1500,"initial_amount":1500,"busy":0}];c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	var miner=c.add_unit(0,0,Vector2(40,50));miner.order="gather";miner.target=100000
	var friendly=c.add_unit(0,1,Vector2(45,50));var enemy=c.add_unit(1,1,Vector2(46,50));var idle=c.add_unit(0,0,Vector2(44,50))
	check(c._unit_fits(miner,ACData.point(friendly.pos)) and c._unit_fits(miner,ACData.point(enemy.pos)) and c._unit_fits(miner,ACData.point(idle.pos)),"mining ignores friendly enemy and idle worker bodies")
	var original=miner.pos.duplicate();miner.pos=friendly.pos.duplicate();check(not c._resolve_unit_pair(miner,friendly,false,.05),"separation respects mining pass through");miner.pos=original;c.collision_index_valid=false
	check(not c._unit_fits(miner,Vector2(50.5,50)),"mineral remains solid")
	miner.carried=5;check(c.mining_worker(miner) and c._unit_fits(miner,ACData.point(enemy.pos)),"return cargo ignores units")
	miner.carried=0;miner.order="move";check(not c._unit_fits(miner,ACData.point(friendly.pos)),"non-mining restores normal collision")
	miner.order="gather";miner.target=100000
	var goal=c._resource_approach(c.map.resources[0],ACData.point(miner.pos),c._body_size(miner))
	check(goal.x<49.5 and absf(goal.y-50)<.01,"nearest reachable mineral face")
	var distance=0.0
	for tick in range(200):
		var old=ACData.point(miner.pos);c.time+=.05;c.paths_this_tick=0;c._tick_unit(miner,.05);distance+=old.distance_to(ACData.point(miner.pos))
		if miner.carried>0:break
	check(miner.carried>0 and distance<10,"direct mining path through blocking units without detour")
	c.add_building(0,0,Vector2(35,45),true);c.map.reset_solids(c.buildings)
	check(not c._unit_fits(miner,Vector2(36,46)),"buildings remain solid")
	print("MINING_ROUTE "+JSON.stringify({"checks":checks,"failures":failures,"direct_distance":distance}));quit(0 if failures.is_empty() else 1)
