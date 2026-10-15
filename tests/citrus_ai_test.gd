extends SceneTree

var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:failures.append(message);printerr("FAIL: "+message)

func fixture(worker_count: int, larvae: int=1, extra_brood: bool=false) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":202610150,"players":[{"race":1},{"race":0}]})
	c.units.clear()
	c.buildings.clear()
	c.map.terrain.fill(0)
	c.map.buildable_map.fill(1)
	c.map.resources.clear()
	c._sync_resource_obstacles()
	c.map.reset_solids([])
	var hq=c.add_building(0,0,Vector2(30,30),true)
	hq.larva=larvae
	c.players[0].home=hq.id
	c.players[1].home=c.add_building(1,0,Vector2(95,95),true).id
	c.add_building(0,2,Vector2(35,35),true)
	c.add_building(0,2,Vector2(38,35),true)
	c.add_building(0,4,Vector2(29,37),true)
	if extra_brood:
		var brood=c.add_building(0,3,Vector2(35,38),true)
		brood.larva=2
	c.map.reset_solids(c.buildings)
	for i in range(worker_count):c.add_unit(0,0,Vector2(40+i,42))
	c.players[0].as=1000
	c.players[0].tera=500
	c._recalculate_supply()
	ACCore.CITRUS_BROOD.producer(c,hq)
	var pods=ACCore.CITRUS_BROOD.idle_pods(c,hq)
	for index in range(larvae,pods.size()):c.units.erase(pods[index])
	hq.larva=larvae
	c.collision_index_valid=false
	return c

func plan(c: ACCore) -> void:
	# Several planning turns tolerate the AI's existing randomized unit choice;
	# resources and larvae are not regenerated or supplemented between turns.
	for _i in range(12):c._ai(0)

func run() -> void:
	var c=fixture(8)
	var hq=c.entity(c.players[0].home)
	plan(c)
	check(hq.queue.any(func(item):return int(item.kind)>0),"eight-worker citrus bot reserves its last larva for an unlocked army unit")
	check(not hq.queue.any(func(item):return int(item.kind)==0),"worker growth cannot consume the last larva before opening defenses")
	check(hq.larva==0 and c.players[0].reserved>0,"army production consumes a real shared larva and population reservation")
	for _i in range(600):c.step(.05)
	check(c.units.any(func(unit):return unit.owner==0 and unit.kind>0),"reserved citrus army production completes into a real unit")

	c=fixture(7)
	hq=c.entity(c.players[0].home)
	plan(c)
	check(hq.queue.size()==1 and hq.queue[0].kind==0,"citrus bot first restores a small viable workforce")

	c=fixture(8,2)
	hq=c.entity(c.players[0].home)
	plan(c)
	check(hq.queue.any(func(item):return item.kind==0) and hq.queue.any(func(item):return item.kind>0),"two available larvae allow both economy and military growth")

	c=fixture(8)
	hq=c.entity(c.players[0].home)
	for i in range(4):c.add_unit(0,1,Vector2(55+i,50))
	c._recalculate_supply()
	plan(c)
	check(hq.queue.size()==1 and hq.queue[0].kind==0,"existing opening defenses allow continued worker growth with one larva")

	c=fixture(8,0,true)
	plan(c)
	var brood=c.buildings.filter(func(building):return building.owner==0 and building.kind==3)[0]
	check(brood.queue.any(func(item):return item.kind>0),"additional brood branch produces army even with an empty headquarters")
	check(ACData.unit(1,int(brood.queue[0].kind)).producer==0,"shared brood production intentionally honors the citrus producer override")
	print("CITRUS_AI_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
