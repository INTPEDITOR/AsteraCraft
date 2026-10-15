extends SceneTree

var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)

func arena(race: int) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":57,"spawn_slots":[0,2],"players":[{"race":race},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear()
	c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c._sync_resource_obstacles();c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(30,30),true).id
	c.players[1].home=c.add_building(1,0,Vector2(100,100),true).id
	c.players[0].as=5000;c.players[0].tera=5000
	c.map.reset_solids(c.buildings);c._recalculate_supply()
	return c

func tick(c: ACCore,count: int=1) -> void:
	for _i in range(count):c.step(.05)

func issue(c: ACCore, worker: Dictionary, site: Vector2, queued: bool=true, ids: Array=[]) -> String:
	return c.command(0,{"type":"build","kind":2,"pos":ACData.packed(site),"ids":[worker.id] if ids.is_empty() else ids,"queued":queued})

func sequencing(race: int) -> void:
	var c=arena(race)
	var worker=c.add_unit(0,0,Vector2(40,36))
	var spare=c.add_unit(0,0,Vector2(46,32))
	var initial=c.players[0].as
	check(issue(c,worker,Vector2(40,30),true,[worker.id,spare.id])=="","first Shift site is accepted, race %d"%race)
	var first=c.entity(worker.target)
	check(first.worker==worker.id and spare.order=="idle","first selected worker owns the plan despite a closer spare, race %d"%race)
	check(issue(c,worker,Vector2(43,34),true,[worker.id,spare.id])=="" and worker.build_queue.size()==1,"busy selected worker receives its own second site, race %d"%race)
	check(c.buildings.size()==3 and c.players[0].as==initial-ACData.building(race,2).as,"waiting plan neither creates a scaffold nor charges early, race %d"%race)
	check(issue(c,worker,Vector2(43,34))!="" and worker.build_queue.size()==1,"duplicate waiting footprints are rejected without replacing the queue, race %d"%race)
	var snapshot=c.snapshot(0)
	var copy=snapshot.units.filter(func(u):return u.id==worker.id)[0]
	copy.build_queue[0].pos[0]=99
	check(worker.build_queue[0].pos[0]==43,"snapshot build plans do not alias the simulation queue, race %d"%race)
	var second: Dictionary={}
	var premature=false
	var other_builder=false
	for _step in range(2400):
		tick(c)
		if spare.order=="construct":other_builder=true
		if c.buildings.size()>3:
			second=c.buildings.filter(func(b):return b.id!=first.id and b.owner==0 and b.kind==2)[0]
			if race==0 and first.progress<1:premature=true
			if race!=0 and not first.get("initiated",false):premature=true
			if second.progress>=1:break
	check(not second.is_empty() and second.worker==worker.id and not other_builder,"same worker reaches and constructs both sites without summoning another, race %d"%race)
	check(not premature and first.progress>=1 and not second.is_empty() and second.progress>=1,"plans begin in the faction's proper completion/initiation order, race %d"%race)
	check(worker.hp>0 and worker.build_queue.is_empty(),"builder survives sequential construction and drains its queue, race %d"%race)
	check(c.players[0].as==initial-2*ACData.building(race,2).as,"each actual building charges its cost exactly once, race %d"%race)
	if race!=0:check(first.initiated and first.worker==worker.id,"seed planting/warp initiation retains the original worker identity, race %d"%race)

func interruptions(race: int) -> void:
	var c=arena(race)
	var worker=c.add_unit(0,0,Vector2(40,36))
	var spare=c.add_unit(0,0,Vector2(44,36))
	issue(c,worker,Vector2(40,30));issue(c,worker,Vector2(43,34))
	var first=c.entity(worker.target)
	var paid=c.players[0].as
	c.command(0,{"type":"cancel","id":first.id})
	var refunded=c.players[0].as
	c.command(0,{"type":"cancel","id":first.id})
	check(c.players[0].as==refunded and refunded==paid+ACData.building(race,2).as*.75,"cancelled active scaffold refunds once, race %d"%race)
	tick(c,2)
	check(worker.order=="construct" and c.entity(worker.target).pos==[43.0,34.0] and spare.order=="idle","active-building cancellation advances the same worker's next site, race %d"%race)
	issue(c,worker,Vector2(38,39))
	check(worker.build_queue.size()==1,"another pending site exists before explicit stop, race %d"%race)
	c.command(0,{"type":"stop","ids":[worker.id]})
	var count=c.buildings.size()
	tick(c,30)
	check(worker.build_queue.is_empty() and worker.order=="idle" and c.buildings.size()==count,"stop clears pending construction without replacing the selected builder, race %d"%race)
	c=arena(race);worker=c.add_unit(0,0,Vector2(40,36));spare=c.add_unit(0,0,Vector2(44,36))
	issue(c,worker,Vector2(40,30));issue(c,worker,Vector2(43,34))
	paid=c.players[0].as;worker.hp=0
	check(issue(c,worker,Vector2(38,39),true,[worker.id,spare.id])!="" and spare.order=="idle","a dead first selected builder cannot redirect Shift to the second selected worker, race %d"%race)
	check(c.command(0,{"type":"build","kind":2,"pos":[38,39],"ids":[],"queued":true})!="" and spare.order=="idle","lost Shift selection cannot recruit an unrelated idle worker, race %d"%race)
	tick(c,40)
	check(c.buildings.size()==3 and c.players[0].as==paid and spare.order=="idle","dead builder's uncharged plans never recruit another worker, race %d"%race)
	c=arena(race);worker=c.add_unit(0,0,Vector2(40,36))
	issue(c,worker,Vector2(40,30));issue(c,worker,Vector2(43,34));issue(c,worker,Vector2(38,39))
	c.map.terrain[34*ACMap.SIZE+43]=1;c.map.reset_solids(c.buildings)
	first=c.entity(worker.target)
	first.progress=1;worker.order="idle"
	tick(c)
	check(worker.order=="construct" and c.entity(worker.target).pos==[38.0,39.0] and worker.build_queue.is_empty(),"invalid queued site is skipped and the same worker proceeds to the next valid site, race %d"%race)
	check(c.events.any(func(event):return str(event.get("text","")).contains("연속 건설 건너뜀")),"skipped site reports its reason once, race %d"%race)
	c=arena(race);worker=c.add_unit(0,0,Vector2(40,36))
	issue(c,worker,Vector2(40,30));issue(c,worker,Vector2(43,34))
	c.players[0].as=0;first=c.entity(worker.target);first.progress=1;worker.order="idle"
	tick(c,10)
	check(worker.order=="idle" and worker.build_queue.is_empty() and c.players[0].as==0 and c.buildings.size()==3,"unaffordable waiting plan is skipped once without negative resources or replacement workers, race %d"%race)
	c=arena(race);worker=c.add_unit(0,0,Vector2(40,36))
	issue(c,worker,Vector2(40,30));issue(c,worker,Vector2(43,34))
	var enemy_snapshot=c.snapshot(1)
	c.visibility[1].fill(1);enemy_snapshot=c.snapshot(1)
	var visible_worker=enemy_snapshot.units.filter(func(u):return u.id==worker.id)[0]
	check(visible_worker.build_queue.is_empty(),"visible enemy worker does not disclose future hidden building sites, race %d"%race)

func research_roles() -> void:
	for race in range(3):
		var c=arena(race)
		var lab=5 if race==1 else 6
		for kind in range(13):
			var building=c.add_building(0,kind,Vector2(70+kind%4*5,65+int(kind/4)*5),true)
			var wallet=c.players[0].as
			var result=c.command(0,{"type":"research","id":building.id,"stat":"attack"})
			check((result=="")== (kind==lab),"only the designated research building accepts research, race %d kind %d"%[race,kind])
			if kind!=lab:check(c.players[0].as==wallet and building.research=="","nonresearch buildings neither spend nor start upgrades, race %d kind %d"%[race,kind])
		check(ACData.research_stats(race,lab)==(["attack","armor","shield"] if race==2 else ["attack","armor"]),"research API exposes faction-specific upgrade buttons, race %d"%race)

func run() -> void:
	for race in range(3):sequencing(race);interruptions(race)
	research_roles()
	print("CONSTRUCTION_QUEUE_V04_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
