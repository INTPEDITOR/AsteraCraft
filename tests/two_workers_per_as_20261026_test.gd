extends "res://tests/abilities_v060_test.gd"
const E=preload("res://scripts/bot_economy.gd")
const CORE=preload("res://scripts/core.gd")
func fixture(race):
	var c=CORE.new();c.setup({"map":0,"players":[{"race":race},{"race":race}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.source_detail_active=false;c.map.source_height_active=false;c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.buildable_map.fill(1);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false;c.ai_clock=100000
	c.players[0].bot=true;c.players[0].difficulty=5;c.players[0].cap=200
	var hq=c.add_building(0,0,Vector2(42,43),true);c.players[0].home=hq.id;c.add_building(1,0,Vector2(115,115),true)
	add_line(c,Vector2(35,35),0);c.map.reset_solids(c.buildings)
	for i in range(16):c.add_unit(0,0,Vector2(41+i%4,49+i/4))
	c._rebuild_collision_index();c._update_vision()
	return c
func add_line(c,start: Vector2,base: int):
	for i in range(8):c.map.resources.append({"id":1000+base*8+i,"type":"as","pos":ACData.packed(start+Vector2(i*1.5,0)),"amount":100000,"initial_amount":100000,"busy":0.0,"base":base})
	c.collision_index_valid=false;c._sync_resource_obstacles()
func workers(c):return c.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==0 and u.hp>0)
func bases(c):return c.buildings.filter(func(b):return int(b.owner)==0 and int(b.kind)==0 and b.hp>0 and b.progress>=1)
func service(c):
	c.bot_action_budget.begin(c,0);c.bot_planning_owner=0
	E.balance(c,0,workers(c),bases(c),E.plan(c,0,workers(c),bases(c)));c.bot_planning_owner=-1
func advance(c,ticks: int):
	for tick in range(ticks):
		if tick%4==0:service(c)
		c.step(.05);c.resolve_spells()
func run():
	var records=[]
	for race in range(3):
		var c=fixture(race)
		for turn in range(40):c.time+=.25;service(c)
		var mining=E.plan(c,0,workers(c),bases(c))
		check(mining.target==16 and mining.assigned.values().all(func(n):return int(n)==2),"one eight-patch base has exactly two assigned miners per patch race "+str(race))
		var before=workers(c).map(func(u):return u.target)
		advance(c,400);mining=E.plan(c,0,workers(c),bases(c))
		check(mining.assigned.values().all(func(n):return int(n)==2) and workers(c).map(func(u):return u.target)==before,"real harvesting keeps assignments instead of oscillating to busy neighbors race "+str(race))
		check(float(c.players[0].gathered)>0,"assigned workers really mine and return resources race "+str(race))
		var second=c.add_building(0,0,Vector2(84,86),true);add_line(c,Vector2(78,78),1);c.map.reset_solids(c.buildings)
		advance(c,160);mining=E.plan(c,0,workers(c),bases(c))
		check(mining.target==32 and int(mining.by_base[int(second.id)].assigned)>0,"new expansion receives real worker transfers and a 32-worker total target race "+str(race))
		for i in range(16):c.add_unit(0,0,Vector2(84+i%4,92+i/4))
		advance(c,640);mining=E.plan(c,0,workers(c),bases(c))
		check(mining.assigned.values().all(func(n):return int(n)==2),"two completed bases each saturate their eight patches without three on any patch race "+str(race))
		c.map.resources[0].amount=0;c._sync_resource_obstacles();advance(c,400)
		mining=E.plan(c,0,workers(c),bases(c))
		check(mining.target==30 and mining.assigned.values().all(func(n):return int(n)<=2),"depleted patch reduces target and never overloads remaining patches race "+str(race))
		var actions=int(c.players[0].get("_ai_actions_total",0))
		for turn in range(10):c.time+=.25;service(c)
		check(int(c.players[0].get("_ai_actions_total",0))==actions,"surplus workers wait without repeated movement commands race "+str(race))
		var w=workers(c);w[0].order="construct";w[1]._ai_scouting=true;w[1].order="move";w[1].goal=[65,65]
		service(c)
		check(w[0].order=="construct" and w[1].order=="move" and w[1].goal==[65,65],"builders and active scouts retain their own orders race "+str(race))
		var q={"kind":0,"brood":999999};bases(c)[0].queue=[q];bases(c)[1].queue=[q]
		check(E.worker_queue(c,0)==1,"shared brood mirrors reserve only one real worker job race "+str(race))
		records.append({"race":race,"worker_target":mining.target,"workers":w.size(),"gathered":c.players[0].gathered})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/two-workers-per-as-20261026")
	FileAccess.open("res://build/two-workers-per-as-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("TWO_WORKERS_PER_AS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
