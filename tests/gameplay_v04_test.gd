extends SceneTree

var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool, text: String) -> void:
	checks+=1
	if not value:failures.append(text);printerr("FAIL: "+text)

func tick(c: ACCore, count: int=1) -> void:
	for _i in range(count):c.step(.05);c.resolve_spells()

func arena(race: int=0) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":401,"spawn_slots":[0,2],"players":[{"race":race},{"race":(race+1)%3}]})
	c.units.clear();c.buildings.clear()
	c.map.terrain.fill(0);c.map.buildable_map.fill(1);c.map.resources.clear()
	c._sync_resource_obstacles();c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(30,30),true).id
	c.players[1].home=c.add_building(1,0,Vector2(95,95),true).id
	c.players[0].as=50000;c.players[0].tera=50000
	c.map.reset_solids(c.buildings);c._recalculate_supply()
	return c

func ore(c: ACCore,pos: Vector2) -> Dictionary:
	var r={"id":100000+c.map.resources.size(),"pos":ACData.packed(pos),"type":"as","amount":1500,"initial_amount":1500,"busy":0.0}
	c.map.resources.append(r);c._sync_resource_obstacles()
	return r

func starts() -> void:
	check(ACCore.start_slots(2,55,[3,1])==[3,1],"authoritative owner-to-start assignments are never reshuffled")
	check(ACCore.start_slots(2,55,[3.0,1.0])==[3,1],"JSON integer-valued numbers preserve authoritative start slots")
	check(ACCore.start_slots(4,55)==ACCore.start_slots(4,55),"missing assignments shuffle reproducibly from the seed")
	var layouts: Dictionary={}
	for seed in range(48):
		var slots=ACCore.start_slots(4,seed)
		check(slots.size()==4 and slots.duplicate().all(func(slot):return slot in [0,1,2,3]) and slots.count(0)==1 and slots.count(1)==1 and slots.count(2)==1 and slots.count(3)==1,"seeded start layout uses every slot once")
		layouts[str(slots)]=true
	check(layouts.size()>8,"different seeds produce varied starting arrangements")
	check(ACCore.start_slots(2,55,[0,0])==ACCore.start_slots(2,55),"duplicate requested slots fall back to safe seeded layout")
	check(ACCore.start_slots(2,55,[-1,9])==ACCore.start_slots(2,55),"out-of-range slots cannot place players off map")
	var c=ACCore.new()
	c.setup({"map":0,"seed":55,"spawn_slots":[3,1],"players":[{"race":0},{"race":2}]})
	for owner in range(2):
		var slot=[3,1][owner]
		var headquarters=c.entity(c.players[owner].home)
		var dimensions=ACData.building(int(headquarters.race),0)
		check(c.players[owner].spawn_slot==slot and ACData.point(headquarters.pos)==c.map.start_building_anchor(slot,Vector2(dimensions.w,dimensions.h)),"actual headquarters honors owner slot and current physical dimensions %d"%owner)
	check(c.snapshot(0).players[0].spawn_slot==3 and not c.snapshot(0).players[1].has("spawn_slot"),"snapshot preserves own starting slot without exposing enemy assignment")
	var local_seeds: Dictionary={}
	var local_layouts: Dictionary={}
	for _match in range(8):
		var local=ACCore.new()
		local.setup({"map":0,"players":[{"race":0},{"race":2}]})
		local_seeds[local.match_seed]=true
		local_layouts[str(local.spawn_slots)]=true
	check(local_seeds.size()>1 and local_layouts.size()>1,"new single-player games without a supplied seed receive fresh randomized starts")
	var fixed=ACCore.new()
	fixed.setup({"map":0,"spawn_slots":[2,0],"players":[{"race":0},{"race":2}]})
	check(fixed.spawn_slots==[2,0],"authoritative slots remain fixed even when the simulation seed is omitted")

func queues(race: int) -> void:
	var c=arena(race)
	var hq=c.entity(c.players[0].home)
	# Isolate the five-entry command boundary with sufficient larvae in this
	# fixture; generation timing remains covered by economy/AI regressions.
	if race==1:
		ACCore.CITRUS_BROOD.producer(c,hq)
		while ACCore.CITRUS_BROOD.idle_pods(c,hq).size()<5:
			var pod=c.add_unit(0,13,Vector2(31+c.units.size(),36))
			pod.brood_parent=hq.id
	else:hq.larva=5
	for _i in range(5):check(c.command(0,{"type":"train","id":hq.id,"kind":0})=="","queue accepts one of five total entries, race %d"%race)
	check(hq.queue.size()==5,"current production plus waiting entries total five, race %d"%race)
	var wallet=c.players[0].as
	var reserved=c.players[0].reserved
	check(c.command(0,{"type":"train","id":hq.id,"kind":0})!="" and hq.queue.size()==5 and c.players[0].as==wallet and c.players[0].reserved==reserved,"sixth entry is rejected without spending or reserving, race %d"%race)
	c.step(1.0)
	var current_left=hq.queue[0].left
	check(c.command(0,{"type":"cancel","id":hq.id,"queue_index":2})=="" and hq.queue.size()==4 and hq.queue[0].left==current_left,"indexed waiting cancellation preserves current progress, race %d"%race)
	check(c.players[0].as==wallet+ACData.unit(race,0).as and c.players[0].reserved==reserved-1,"indexed cancellation refunds resources and population, race %d"%race)
	check(c.command(0,{"type":"cancel","id":hq.id,"queue_index":20})!="" and hq.queue.size()==4,"invalid cancellation index changes no queue, race %d"%race)
	c.command(0,{"type":"cancel","id":hq.id,"queue_index":0})
	check(hq.queue[0].left==(current_left if race==1 else hq.queue[0].total),"cancellation preserves independent citrus morph progress or promotes an unstarted queue entry, race %d"%race)
	c.command(0,{"type":"cancel","id":hq.id})
	check(hq.queue.size()==2,"legacy cancellation still removes the last entry, race %d"%race)
	check(c.command(0,{"type":"rally","id":hq.id,"pos":[48.25,49.75]})=="" and hq.rally==[48.25,49.75],"single-building rally accepts the exact clicked ground point, race %d"%race)
	check(c.command(0,{"type":"rally","ids":[hq.id],"pos":[-1,49]})!="" and hq.rally==[48.25,49.75],"invalid rally does not replace the current point, race %d"%race)
	var mover=c.add_unit(0,1,Vector2(45,45))
	check(c.command(0,{"type":"attack_move","ids":[mover.id],"pos":[53,45]})=="","attack-ground coordinates accept a normal move command, race %d"%race)
	tick(c,30)
	check(ACData.point(mover.pos).x>45.5,"attack-ground order actually moves toward the clicked point, race %d"%race)

func contact(race: int) -> void:
	var c=arena(race)
	var worker=c.add_unit(0,0,Vector2(42.5,31))
	var building=c.add_building(0,2,Vector2(40,30),false)
	building.worker=worker.id;worker.order="construct";worker.target=building.id
	c.map.reset_solids(c.buildings)
	var progress=building.progress
	c._tick_building(building,.2)
	check(building.progress==progress and worker.hp>0,"old distant construction range cannot initiate or consume worker, race %d"%race)
	var approach=c.building_approach(building,ACData.point(worker.pos),worker)
	var probe=worker.duplicate();probe.pos=ACData.packed(approach)
	check(absf(c.body_footprint_gap(probe,building)-.15)<.002 and not ACCore.collision_rect(probe).intersects(c.footprint(building)),"construction approach targets a .15-tile body gap outside the footprint, race %d"%race)
	worker.pos=ACData.packed(approach);c.collision_index_valid=false
	c._tick_building(building,.2)
	check(building.progress>progress,"construction starts after body reaches the near footprint edge, race %d"%race)
	if race==0:
		worker.pos=[44,31];progress=building.progress;c._tick_building(building,.2)
		check(building.progress==progress,"human construction pauses when its builder leaves close range")
	elif race==1:check(worker.hp>0 and building.initiated and worker.order=="idle","citrus worker plants a seedling at close range and survives")
	else:check(building.initiated and worker.order=="idle","owl construction releases its worker after close initiation")
	c=arena(race)
	worker=c.add_unit(0,0,Vector2(35.5,31));worker.order="gather";worker.carried=8
	var hq=c.entity(c.players[0].home)
	var wallet=c.players[0].as
	c._gather(worker,.05)
	check(c.players[0].as==wallet and worker.carried==8,"As cannot unload at the old distant center threshold, race %d"%race)
	var delivered=false
	for _i in range(120):
		tick(c)
		if c.players[0].as>wallet:
			delivered=true
			check(c.body_footprint_gap(worker,hq)<=ACCore.AS_UNLOAD_REACH+.001 and not ACCore.collision_rect(worker).intersects(c.footprint(hq)),"As unload occurs only at actual close body contact, race %d"%race)
			break
	check(delivered and c.players[0].as==wallet+8,"worker completes a short near-edge delivery, race %d"%race)

func busy_resources() -> void:
	var c=arena()
	var busy=ore(c,Vector2(44.5,40))
	var near_free=ore(c,Vector2(48.5,40))
	ore(c,Vector2(52.5,40))
	var holder=c.add_unit(0,0,Vector2(43,40));holder.order="gather";holder.target=busy.id
	var seeker=c.add_unit(0,0,Vector2(43,41));seeker.order="gather";seeker.target=busy.id
	c._claim_miner(holder,busy)
	c._gather(seeker,.05)
	check(seeker.target==near_free.id and seeker.mining_state=="travel","busy As immediately redirects to the nearest actually free alternative")
	var before=ACData.point(seeker.pos)
	tick(c,140)
	check(ACData.point(seeker.pos).distance_to(before)>1 and near_free.amount<1500,"redirected worker walks to and harvests the alternative node")
	check(int(c.mining_claims.get(busy.id,-1)) in [-1,holder.id],"retargeting does not steal a live miner's claim")

func healing() -> void:
	for race in range(3):
		for kind in range(13):
			check(ACData.unit_max_energy(race,kind)==(200.0 if [race,kind] in [[0,4],[2,4],[2,5]] else 0.0),"energy capacity exists only for units with energy abilities")
	var c=arena()
	var medic=c.add_unit(0,4,Vector2(42,40))
	var ally=c.add_unit(0,1,Vector2(44,40));ally.hp-=30
	var before=ally.hp
	tick(c)
	check(medic.healing and medic.action=="heal" and medic.heal_target==ally.id and ally.hp>before,"medical healing has an explicit state, target and animation")
	check(medic.max_energy==200 and medic.energy<100,"medical healing consumes displayed energy")
	var pulses=c.effects.filter(func(effect):return effect.type=="heal" and effect.get("heal_kind","")=="medic")
	check(pulses.size()==1 and pulses[0].target==ally.id and pulses[0].projectile=="heal_medical","medical beam/sound event is distinct from gunfire")
	check(medic.fired<0 and not c.effects.any(func(effect):return effect.type=="shot" and effect.unit==medic.id),"healing never fires a weapon cue")
	tick(c,40)
	check(c.effects.filter(func(effect):return effect.type=="heal" and effect.unit==medic.id).size()<=1,"healing pulses are bounded rather than emitted every simulation tick")
	medic.energy=.01;ally.hp-=10;c._support(medic,ACData.unit(0,4),1.0)
	check(medic.energy>=0 and medic.energy<=medic.max_energy,"partial healing cannot overdraw energy")
	var normal=c.add_unit(0,1,Vector2(50,50));tick(c)
	check(normal.max_energy==0 and normal.energy==0,"ordinary units explicitly have no energy capacity or hidden mana")
	var snap=c.snapshot().units.filter(func(unit):return unit.id==medic.id)[0]
	check(snap.has("max_energy") and snap.has("healing") and snap.has("heal_target") and snap.has("heal_pulse"),"snapshots preserve healing and energy display schema")

func flee() -> void:
	var c=arena()
	var attacker=c.add_unit(1,1,Vector2(40,40));attacker.order="hold";attacker.cooldown=1000
	var passive=c.add_unit(0,4,Vector2(43,40))
	var origin=ACData.point(passive.pos)
	c._damage(attacker,passive,1,false)
	var goal=ACData.point(passive.goal)
	check(passive.fleeing and passive.order=="move" and goal.x>origin.x and absf(origin.distance_to(goal)-4)<.01,"unarmed damaged unit flees four tiles away from its attacker")
	for _i in range(8):c._damage(attacker,passive,1,false)
	check(ACData.point(passive.goal)==goal,"repeated hits do not extend or reissue an active flight goal")
	tick(c,25)
	check(ACData.point(passive.pos).x>origin.x and ACData.point(passive.pos).distance_to(origin)<=4.1,"ground flight follows ordinary collision-safe movement")
	c.command(0,{"type":"move","ids":[passive.id],"pos":[43,44]})
	c._damage(attacker,passive,1,false)
	check(not passive.fleeing and passive.goal==[43,44],"a fresh player order immediately overrides automatic flight")
	tick(c,180)
	check(not passive.fleeing and passive.order=="idle","flight and manual movement terminate without endless autonomous retreat")
	var worker=c.add_unit(0,0,Vector2(45,45));c._damage(attacker,worker,1,false)
	check(not worker.fleeing,"armed workers are excluded from passive-unit flight")
	var air=c.add_unit(0,8,Vector2(1,20));attacker.pos=[5,20];c.collision_index_valid=false
	c._damage(attacker,air,1,false)
	check(ACData.point(air.goal).is_finite() and ACData.point(air.goal).x>=1 and ACData.point(air.goal).y>=1,"air flight remains finite and inside map bounds")
	var same=c.add_unit(0,4,Vector2(60,60));attacker.pos=same.pos.duplicate();c.collision_index_valid=false
	c._damage(attacker,same,1,false)
	check(ACData.point(same.goal).is_finite() and same.fleeing,"coincident source and victim use a stable nonzero escape direction")
	c=arena();c.map.terrain.fill(1);c.map.terrain[60*ACMap.SIZE+60]=0;c.map.reset_solids(c.buildings)
	passive=c.add_unit(0,4,Vector2(60,60))
	var source={"owner":1,"race":0,"pos":[62,60]}
	c._damage(source,passive,1,false)
	check(not passive.fleeing and ACData.point(passive.pos)==Vector2(60,60),"completely blocked flight stays put without invalid paths or teleportation")

func ranged_spacing() -> void:
	for race in range(3):
		for kind in range(13):
			var definition=ACData.unit(race,kind)
			if definition.damage<=0 or definition.range<=1.5:continue
			var c=arena(race)
			var shooter=c.add_unit(0,kind,Vector2(55,55))
			var target_kind=1
			if "g" not in definition.targets:
				for candidate in range(13):
					var opponent=ACData.unit((race+1)%3,candidate)
					if opponent.air and opponent.role not in ["parasite","stealth"]:
						target_kind=candidate
						break
			var target=c.add_unit(1,target_kind,Vector2(55+definition.range+2,55))
			target.hp=10000;target.shield=0;target.order="hold"
			c.visibility[0].fill(1)
			shooter.order="attack";shooter.target=target.id
			var origin=ACData.point(shooter.pos)
			c._tick_unit(shooter,.05)
			check(shooter.fired<0 and target.hp==10000,"ranged unit cannot fire beyond its configured reach, race %d kind %d"%[race,kind])
			check(ACData.point(shooter.pos).distance_to(origin)>0,"ranged attacker closes the distance instead of firing from afar, race %d kind %d"%[race,kind])
			for _step in range(120):
				c.time+=.05
				c._tick_unit(shooter,.05)
				if shooter.fired>=0:break
			var distance=c.center(shooter).distance_to(c.center(target))
			check(shooter.fired>=0 and distance<=float(definition.range)+.002,"actual shot occurs within the current balance-data range, race %d kind %d"%[race,kind])
			check(distance>=float(definition.range)-float(definition.speed)*.05-.025 and not ACCore.units_overlap(shooter,target),"pursuing ranged unit stops at weapon spacing with separate collision boxes, race %d kind %d"%[race,kind])

func turret_directions() -> void:
	var c=arena(0)
	var chassis=c.add_unit(0,6,Vector2(55,55))
	c.command(0,{"type":"move","ids":[chassis.id],"pos":[59,55]})
	tick(c,10)
	check(ACData.point(chassis.body_direction).x>.95 and chassis.turret_direction==chassis.body_direction,"moving missile vehicle aims its inactive turret along its chassis travel direction")
	var enemy=c.add_unit(1,1,ACData.point(chassis.pos)+Vector2(0,4))
	enemy.order="hold";enemy.cooldown=1000
	c.visibility[0].fill(1)
	c.command(0,{"type":"attack","ids":[chassis.id],"target":enemy.id})
	tick(c)
	check(ACData.point(chassis.body_direction).x>.95 and ACData.point(chassis.turret_direction).y>.95 and chassis.fired>=0,"stationary chassis retains its travel direction while turret fires toward another bearing")
	var view=c.snapshot(0).units.filter(func(u):return u.id==chassis.id)[0]
	view.body_direction[0]=0;view.turret_direction[1]=0
	check(ACData.point(chassis.body_direction).x>.95 and ACData.point(chassis.turret_direction).y>.95,"separate turret/chassis snapshot vectors never alias simulation state")
	c.command(0,{"type":"stop","ids":[chassis.id]})
	enemy.hp=0;tick(c,2)
	check(chassis.turret_direction==chassis.body_direction,"turret returns to chassis direction when no attack target remains")

func settled_yield() -> void:
	var c=arena(0)
	var arriving=c.add_unit(0,1,Vector2(50,49.3))
	var settled=c.add_unit(0,1,Vector2(50,50))
	settled.goal=[50,47.26]
	var farthest=0.0
	for _request in range(50):
		c._request_room(arriving,Vector2(50,52),.05)
		farthest=maxf(farthest,ACData.point(settled.pos).distance_to(ACData.point(settled.goal)))
	check(farthest<=2.751,"repeated nearby arrivals cannot push a settled troop beyond its assigned formation area")
	check(not ACCore.units_overlap(arriving,settled),"bounded yielding preserves each troop's physical collision box")

func run() -> void:
	starts()
	for race in range(3):queues(race);contact(race)
	busy_resources();healing();flee();ranged_spacing();turret_directions();settled_yield()
	check(ACData.missing_building_names(0,[6,7],[6])==[ACData.building(0,7).name],"locked production names the exact missing technology building")
	print("GAMEPLAY_V04_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
