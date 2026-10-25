extends SceneTree
const AI=preload("res://scripts/bot_ai.gd")
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func arena(race,level):
	var c=ACCore.new()
	c.setup({"map":0,"seed":621,"spawn_slots":[0,2],"players":[{"race":race,"difficulty":level,"bot":true},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear()
	c.map.source_detail_active=false;c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.buildable_map.fill(1)
	c.map.reset_solids([]);c.collision_index_valid=false
	var hq=c.add_building(0,0,Vector2(30,30),true);c.players[0].home=hq.id
	c.add_building(1,0,Vector2(95,95),true)
	c.add_building(0,2,Vector2(35,30),true)
	c.add_building(0,4 if race==1 else 3,Vector2(30,36),true)
	for i in range(8):c.add_unit(0,0,Vector2(40+i,42))
	c.players[0].as=1000;c.players[0].tera=1000;c.players[0].cap=200
	c.roots.update(c)
	c.time=20;c.roots.update(c)
	return c
func _initialize():call_deferred("run")
func run():
	for race in range(3):
		for level in range(6):
			var label="%d:%d"%[race,level]
			var c=arena(race,level)
			check(AI.build(c,0,2),"legal supply construction "+label)
			var builders=c.units.filter(func(u):return u.owner==0 and u.order=="build_move")
			if builders.is_empty():continue
			var w=builders[0]
			var cost=float(ACData.building(race,2).as)
			c.players[0].as=cost;c.players[0].tera=0
			AI.tick(c,0)
			check(c.players[0].as==cost and AI.available_resources(c,0).x==0,"travelling foundation budget survives production "+label)
			w.pos=ACData.packed(c.building_approach(w.build_plan,c.center(w),w))
			check(c._arrive_construction(w)=="","reserved foundation can be paid on arrival "+label)
			var site=c.entity(w.target);c._tick_building(site,1000)
			check(site.progress>=1,"race construction finishes "+label)
			c.players[0].as=1000;c.players[0].tera=1000;c.players[0]._ai_next=0
			AI.tick(c,0)
			check(c.buildings.any(func(b):return b.owner==0 and b.queue.any(func(q):return int(q.kind)>0)),"unlocked combat production "+label)
			var hq=c.entity(c.players[0].home)
			var rally=c.map.nearest_free(c.center(hq)+(Vector2(63.5,63.5)-c.center(hq)).normalized()*7)
			var army=[]
			# Hell now commits a larger main force instead of a four-body feed.
			var committed_count=6 if level==5 else int(AI.PROFILES[level].attack)
			for i in range(committed_count+(1 if level>=2 else 0)):army.append(c.add_unit(0,1,rally))
			AI.combat(c,0,army,[hq],[],AI.PROFILES[level])
			check(c.players[0]._ai_wave.is_empty() and army.all(func(u):return u.order in ["move","hold"]),"army assembles before travelling as a cohort "+label)
			for leg in range(3):
				for u in army:
					var slot=c.players[0].get("_ai_stage_slots",{}).get(int(u.id),{})
					if not slot.is_empty():u.pos=slot.pos.duplicate()
				AI.combat(c,0,army,[hq],[],AI.PROFILES[level])
			var scout=int(c.players[0].get("_ai_scout",-1))
			var fighters=army.filter(func(u):return int(u.id)!=scout)
			check(c.players[0]._ai_wave.size()==fighters.size() and fighters.size()>=committed_count and fighters.all(func(u):return u.order=="attack_move"),"assembled main wave attacks while its scout remains independent "+label)
	for level in range(6):
		var c=arena(2,level)
		var factory=c.buildings.filter(func(b):return b.owner==0 and b.kind==3)[0]
		for b in c.buildings:
			if b.owner==0 and b.kind==2:b.hp=0
		c.add_building(0,2,Vector2(90,50),true)
		c.players[0].as=100;c.players[0].tera=0
		AI.tick(c,0)
		var plans=c.units.filter(func(u):return u.owner==0 and u.order=="build_move" and u.build_plan.kind==2)
		check(plans.size()==1 and AI.power_covers(ACData.point(factory.pos),3,ACData.point(plans[0].build_plan.pos)),"lost local power restored despite spare supply %d"%level)
		c.players[0]._ai_next=0;AI.tick(c,0)
		check(c.units.filter(func(u):return u.owner==0 and u.order=="build_move" and u.build_plan.kind==2).size()==1,"power reservation prevents duplicate plans %d"%level)
	# A one-population rifle is available even when a higher-scoring shield
	# soldier cannot fit; failed expensive choices must not stall the queue.
	var c=arena(0,1)
	c.add_building(0,6,Vector2(45,30),true)
	for i in range(5):c.add_unit(0,1,Vector2(50+i,50))
	c.players[0].used=199;c.players[0].reserved=0;c.players[0].cap=200
	AI.tick(c,0)
	var queued=[]
	for b in c.buildings:
		if b.owner==0:queued.append_array(b.queue)
	check(queued.any(func(q):return ACData.unit(0,int(q.kind)).pop<=1),"remaining population selects a unit that fits")
	check(c.players[0].used+c.players[0].reserved<=200,"production respects hard population cap")
	print("BOT_AI_V062 ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
