extends SceneTree
const BOT=preload("res://scripts/bot_ai.gd")
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func prepared(race: int,map_id: int=0,slot: int=0) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":map_id,"seed":1047,"spawn_slots":[slot,(slot+2)%4],"players":[{"race":race},{"race":(race+1)%3}]})
	c.players[0].as=10000;c.players[0].tera=10000
	return c
func run() -> void:
	for race in range(3):
		var c=prepared(race)
		var hq=c.entity(int(c.players[0].home))
		var worker=c.units.filter(func(u):return u.owner==0 and u.kind==0)[0]
		var site=(c.center(hq)+Vector2(6,0)).floor()
		check(c.command(0,{"type":"build","kind":2,"pos":ACData.packed(site),"ids":[worker.id]})=="","construction accepted race %d"%race)
		var building=c.entity(int(worker.target))
		if building.is_empty():continue
		c._tick_building(building,.1)
		check(worker.hp>0 and building.progress==0,"worker survives before reaching site %d"%race)
		worker.pos=ACData.packed(c.building_approach(building,c.center(worker)))
		c._tick_building(building,.1)
		check(building.progress>0,"construction initiates on arrival %d"%race)
		check((worker.hp<=0)==(race==1),"only citrus builder consumed %d"%race)
		if race==1:
			check(worker.dead_processed and building.worker==-1,"consumption produces no corpse")
			c.step(.05)
			check(c.entity(int(worker.id)).is_empty(),"consumed worker absent from selectable entities")
			c._tick_building(building,100)
			check(building.progress==1,"citrus construction continues after consumption")
	for m in range(3):
		for slot in range(4):
			for race in range(3):
				var c=prepared(race,m,slot)
				var hq=c.entity(int(c.players[0].home))
				var workers=c.units.filter(func(u):return u.owner==0 and u.kind==0)
				var site=BOT.expansion_site(c,0,workers,hq)
				check(not site.is_empty(),"reachable expansion m%d s%d r%d"%[m,slot,race])
				if not site.is_empty():
					var d=ACData.building(race,0)
					var center=ACData.point(site.pos)+Vector2(d.w,d.h)*.5
					check(center.distance_to(ACData.point(site.base.pos))<=2,"HQ centered at authored resource base")
					check(int(site.base.slot)==slot,"first expansion stays near own starting quarter")
					check(BOT.expand(c,0,workers,hq),"expansion command succeeds")
					check(not BOT.expand(c,0,workers,hq),"one incomplete expansion at a time")
				if race==1:
					for pod in ACCitrusBrood.idle_pods(c,hq):
						check(c.center(pod).y>c.center(hq).y+1.5 and absf(c.center(pod).x-c.center(hq).x)<=2.2,"brood front-only spawn")
	var c=prepared(1)
	var hq=c.entity(int(c.players[0].home))
	c.add_building(0,2,c.center(hq)+Vector2(6,0),true);c.add_building(0,4,c.center(hq)+Vector2(6,5),true);c._recalculate_supply()
	var pods=ACCitrusBrood.idle_pods(c,hq)
	var ids: Array=[]
	for pod in pods:ids.append(pod.id)
	for i in range(3):
		check(c.command(0,{"type":"morph","id":ids[0],"ids":ids,"kind":1})=="","repeated morph command starts idle body %d"%i)
	check(hq.queue.size()==3,"three independent morphs queued")
	var before=c.players[0].as
	check(c.command(0,{"type":"morph","id":ids[0],"ids":ids,"kind":2})!="" and c.players[0].as==before,"no idle body does not change active morph or spend")
	for pod in pods:check(pod.morph_kind==1,"existing morph target preserved")
	var nursery=c.add_building(0,3,Vector2(60,60),true)
	ACCitrusBrood.producer(c,nursery)
	for pod in ACCitrusBrood.idle_pods(c,nursery):
		check(int(pod.brood_mother)==int(hq.id) and c.center(pod).distance_to(c.center(hq))<7,"nursery brood also appears at mother colony")
	# Block the entire front strip. Regeneration must wait rather than jump behind.
	for pod in c.units:
		if ACCitrusBrood.is_pod(pod):pod.hp=0
	c.collision_index_valid=false
	for y in range(floori(c.center(hq).y+1),ceili(c.center(hq).y+7)):
		for x in range(floori(c.center(hq).x-4),ceili(c.center(hq).x+5)):c.map.terrain[y*128+x]=1
	c.map.reset_solids(c.buildings)
	check(ACCitrusBrood._spawn(c,hq,0).is_empty(),"blocked front never creates rear brood")
	check(BOT.PROFILES[0].interval>BOT.PROFILES[1].interval and BOT.PROFILES[1].interval>BOT.PROFILES[2].interval,"difficulty reaction ordering")
	c=prepared(0)
	var worker=c.units.filter(func(u):return u.owner==0 and u.kind==0)[0]
	var ore: Dictionary=c.map.resources.filter(func(r):return r.type=="as")[0]
	worker.pos=ACData.packed(c._resource_approach(ore,ACData.point(worker.pos),c.collision_size(0,0)))
	worker.order="gather";worker.target=ore.id;worker.gather_clock=0
	var remaining=int(ore.amount)
	c._gather(worker,2.1)
	check(worker.carried==0,"As batch waits for the slower 2.2 second interval")
	c._gather(worker,.11)
	check(worker.carried==5 and ore.amount==remaining-5,"As takes exactly five per trip")
	var vent: Dictionary=c.map.resources.filter(func(r):return r.type=="tera")[0]
	var refinery=c.add_building(0,1,c.refinery_anchor(vent),true)
	var tera_before=float(c.players[0].tera)
	c._tick_tera(refinery,3.4)
	check(c.players[0].tera==tera_before,"Tera waits 3.5 seconds")
	c._tick_tera(refinery,.11)
	check(c.players[0].tera==tera_before+8,"Tera delivers eight per interval")
	print("FEEDBACK_V051 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
