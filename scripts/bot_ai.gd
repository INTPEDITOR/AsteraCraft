extends RefCounted
## Deterministic, resource-paying bot. Terrain is public; enemy decisions use
## current sight only. Difficulty changes planning and reaction, not income.
const NAMES=["매우 쉬움","쉬움","보통","어려움","매우어려움","헬"]
const TACTICS=preload("res://scripts/bot_tactics.gd")
const ECONOMY=preload("res://scripts/bot_economy.gd")
const MISSIONS=preload("res://scripts/bot_missions.gd")
const SKILLS=preload("res://scripts/bot_skills.gd")
const COMBAT_POLICY=preload("res://scripts/bot_combat_policy.gd")
const DIFFICULTY=preload("res://scripts/bot_difficulty.gd")
const PROFILES=[
	{"interval":.2,"workers":8,"attack":14,"assembly":1.0,"expand":480.0,"expand_workers":8,"bases":2,"retreat":.0,"tech":3,"miners":1,"production":1,"focus":false},
	{"interval":.2,"workers":12,"attack":12,"assembly":.9,"expand":360.0,"expand_workers":10,"bases":2,"retreat":.0,"tech":5,"miners":2,"production":1,"focus":false},
	{"interval":.2,"workers":16,"attack":10,"assembly":.85,"expand":210.0,"expand_workers":14,"bases":3,"retreat":.22,"tech":9,"miners":2,"production":1,"focus":false},
	{"interval":.2,"workers":18,"attack":8,"assembly":.8,"expand":160.0,"expand_workers":14,"bases":4,"retreat":.32,"tech":12,"miners":2.25,"production":1,"focus":false},
	{"interval":.2,"workers":22,"attack":6,"assembly":.75,"expand":120.0,"expand_workers":12,"bases":5,"retreat":.35,"tech":12,"miners":3,"production":2,"focus":true},
	{"interval":.2,"workers":24,"attack":4,"assembly":.7,"expand":90.0,"expand_workers":10,"bases":6,"retreat":.38,"tech":12,"miners":3,"production":3,"focus":true}]

static func tick(c, owner: int) -> void:
	var p: Dictionary=c.players[owner]
	var level=clampi(int(p.difficulty),0,PROFILES.size()-1)
	var profile: Dictionary=PROFILES[level].duplicate()
	if c.bot_planning_owner==owner and not c.bot_action_budget.available(owner):return
	if c.time<float(p.get("_ai_next",0)):return
	p._ai_next=c.time+float(profile.interval)
	var race=int(p.race)
	p._ai_unit_reserve={}
	var workers: Array=[];var army: Array=[];var bases: Array=[]
	for u in c.units:
		if int(u.owner)!=owner or u.hp<=0 or u.get("technical",false):continue
		if int(u.kind)==0:workers.append(u)
		elif c.unit_data(u).role!="carrier_drone":army.append(u)
	for b in c.buildings:
		if int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1:bases.append(b)
	if bases.is_empty():return
	var hq: Dictionary=c.entity(int(p.home))
	if hq.is_empty() or hq.hp<=0:hq=bases[0];p.home=hq.id
	var mining=ECONOMY.plan(c,owner,workers,bases)
	p._ai_miner_target=int(mining.target);p._ai_miner_count=mining.assigned.values().reduce(func(sum,value):return sum+int(value),0)
	save_worker(c,owner,workers,mining)
	ECONOMY.balance(c,owner,workers,bases,mining)
	var visible: Array=[]
	for enemy in c.units+c.buildings:
		if enemy.hp>0 and not c.allied(owner,int(enemy.owner)) and c.can_see(owner,enemy):visible.append(enemy)
	TACTICS.observe(c,owner,visible)
	var plan=TACTICS.choose(c,owner,army)
	plan=TACTICS.developed_plan(c,owner,plan,army)
	ensure_supply(c,owner,level)
	fund_combat(c,owner,plan,army,TACTICS.queued_counts(c,owner))
	if not plan.is_empty():
		if str(plan.economy)=="expand":profile.expand=minf(float(profile.expand),100);profile.expand_workers=8
	# A newly built carrier cannot fight until it buys its real interceptors.
	# Arm a small initial flight before spending every action on movement.
	for carrier in army:
		if c.unit_data(carrier).role!="carrier" or carrier.get("drones",[]).size()+carrier.get("drone_queue",[]).size()>=4:continue
		var arm_budget=available_resources(c,owner)
		if arm_budget.x>=25 and arm_budget.y>=10 and c.command(owner,{"type":"produce_drone","id":carrier.id})=="":TACTICS.log_action(p,"carrier:arm");break
	# Formation/escort updates must not consume every token while an idle
	# factory and an affordable bank wait behind them. Periodically issue one
	# real macro action first; it spends the same APM budget, not an extra one.
	if c.time>=float(p.get("_ai_production_service_at",0)) and float(p.as)>=float(p.get("_ai_unit_reserve",{}).get("as",75)):
		p._ai_production_service_at=c.time+[8,6,4,3,2,1.5][level]
		var serviced=false
		var upkeep_counts=TACTICS.queued_counts(c,owner)
		for factory in production_factories(c,owner):
			if production_room(c,factory)<=0 or race!=1 and not factory.queue.is_empty():continue
			if queue_unit(c,owner,factory,plan,army,upkeep_counts,0,level):serviced=true;break
		if not serviced:ensure_supply(c,owner,level)
	if plan.get("_ai_ara_recovery",false) and c.time>=float(p.get("_ai_ara_capacity_at",0)):
		p._ai_ara_capacity_at=c.time+6
		invest_production(c,owner,profile,plan,bases.size())
	combat(c,owner,army,bases,visible,profile)
	var emergency=str(p.get("_ai_attack_phase",""))=="defend" and army.filter(func(u):return float(c.unit_data(u).damage)>0).size()<10
	if emergency:p._ai_worker_savings=0.0
	ensure_detection(c,owner,army)
	protect_detectors(c,owner,army,bases,visible)
	if not plan.is_empty() and not emergency:TACTICS.prepare(c,owner,plan,army)
	elif emergency:p._ai_tech_reserve=[0,0]
	save_expansion(c,owner,workers,army,bases,profile,emergency)
	var opening_attack_done=bool(p.get("_ai_has_attacked",false))
	if not plan.is_empty() and str(plan.economy)=="expand" and army.size()>=4 and c.time>=90:opening_attack_done=true
	if level==5 and c.time>=120:opening_attack_done=true
	# Preserve the budget and assignment while a worker travels to a new site.
	# A pending order is not yet a building and must not be issued every tick.
	# Travelling builders must not suspend combat and economic decisions.
	# Mining assignments were balanced before combat, using two real slots per
	# patch. Do not overwrite builders, scouts or surplus workers with a second
	# independent nearest-node command here.
	# Repair interrupted sites before paying for more foundations.
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0 or b.progress>=1 or (race!=0 and b.get("initiated",false)):continue
		var w: Dictionary=c.entity(int(b.worker))
		if not w.is_empty() and w.hp>0 and w.order=="construct" and int(w.target)==int(b.id):continue
		var replacement=builder(c,workers,c.center(b))
		if not replacement.is_empty():
			c.command(owner,{"type":"context","ids":[replacement.id],"target":b.id})
	# Supply may still be sufficient after a local tower is destroyed. Restore
	# the actual factory's coverage before spending its replacement budget.
	if race==2:
		for b in c.buildings:
			if int(b.owner)==owner and b.hp>0 and not c.building_powered(b):
				power_site(c,owner,workers,ACData.point(b.pos),int(b.kind))
	var queued_workers=ECONOMY.worker_queue(c,owner)
	var target_workers=DIFFICULTY.workers(level,int(mining.target),bases.size())
	if emergency:target_workers=mini(target_workers,workers.size())
	var worker_bases=bases.duplicate()
	worker_bases.sort_custom(func(a,b):return int(mining.by_base[int(a.id)].target)-int(mining.by_base[int(a.id)].assigned)>int(mining.by_base[int(b.id)].target)-int(mining.by_base[int(b.id)].assigned))
	for b in worker_bases:
		if workers.size()+queued_workers>=target_workers:break
		if float(p.used)+float(p.reserved)+1>DIFFICULTY.supply_target(level):break
		if int(mining.by_base[int(b.id)].assigned)>=int(mining.by_base[int(b.id)].target):continue
		if production_room(c,b)<=0:continue
		# Real source bases have longer, asymmetric mining routes. Reserve the
		# opening combat budget before repeatedly filling the worker queue.
		var early_reserve=0.0
		if workers.size()+queued_workers>=8 and army.size()<6:
			var basic=4 if race==1 else 3
			var paid=c.buildings.any(func(factory):return int(factory.owner)==owner and factory.hp>0 and int(factory.kind)==basic) or workers.any(func(w):return w.order=="build_move" and int(w.build_plan.kind)==basic)
			early_reserve=float(ACData.unit(race,1).as if paid else ACData.building(race,basic).as)
		# Preserve the shared brood pool for combat once an opening economy exists.
		if race==1 and workers.size()>=8 and army.size()<workers.size()/2 and int(b.larva)<2 and float(p.get("_ai_worker_savings",0))<float(ACData.unit(race,0).as):continue
		var worker_data=ACData.unit(race,0)
		var earmarked=race==1 and float(p.get("_ai_worker_savings",0))>=float(worker_data.as)
		var worker_budget=available_resources(c,owner,true,not earmarked,false)
		if worker_budget.x<float(worker_data.as)+early_reserve or worker_budget.y<float(worker_data.tera):continue
		if c.command(owner,{"type":"train","id":b.id,"kind":0})=="":queued_workers+=1;p._ai_worker_savings=0.0
	ensure_supply(c,owner,level)
	if not plan.is_empty() and c.time>=90 and army.size()>=6 and (level==5 or str(plan.economy)=="expand"):
		MISSIONS.fortify(c,owner,workers,bases,available_resources(c,owner)-ACData.point(p.get("_ai_tech_reserve",[0,0])))
	# Buy an expansion from an affordable surplus behind a real fighting line.
	# Do not suspend all production while waiting for its full price.
	var pending_base=c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1)
	var expansion_cost=float(ACData.building(race,0).get("as",400))
	if not emergency and opening_attack_done and not pending_base and expansion_ready(c,p,army,workers,mining,plan) and c.time>=float(profile.expand) and workers.size()>=(8 if level>=4 else int(profile.expand_workers)) and bases.size()<int(profile.bases) and (available_resources(c,owner,false).x>=expansion_cost+150 or float(p.get("_ai_expand_savings",0))>=expansion_cost):
		expand(c,owner,workers,hq)
	var opening=TACTICS.build_order(race,plan) if not plan.is_empty() else ([2,3,1,7,4,6,9,5,8,10] if race==0 else ([2,4,1,3,5,6,8,7,9] if race==1 else [2,3,1,4,6,7,5,8,10,9]))
	# An expensive tech chain must not postpone the first fighting force.
	var tech_limit=mini(int(profile.tech),(4 if race==1 else 3) if not opening_attack_done or army.size()<6 else 5 if army.size()<12 else int(profile.tech))
	if plan.get("_ai_ara_recovery",false):tech_limit=mini(tech_limit,3)
	for kind in opening.slice(0,tech_limit):
		if emergency and int(kind) not in ([2,3,1] if race!=1 else [2,4,5,1,3]):continue
		if c.has_building(owner,kind):continue
		if c.prerequisites(owner,ACData.building(race,kind).requires):build(c,owner,kind)
		break
	if c.time>=60 and not emergency and race!=1:invest_production(c,owner,profile,plan,bases.size())
	var enemy_air=0
	for e in visible:
		if not e.has("progress") and c.unit_data(e).air:enemy_air+=1
	var counts=TACTICS.queued_counts(c,owner)
	for b in production_factories(c,owner):
		if int(b.owner)!=owner or b.progress<1 or b.hp<=0:continue
		if not c.building_powered(b):continue
		for slot in range(production_room(c,b)):
			if not queue_unit(c,owner,b,plan,army,counts,enemy_air,level):break
	if not emergency and bases.size()>1 and float(p.tera)<300:ensure_refineries(c,owner,bases)
	if c.time>=60 and not emergency and race==1:invest_production(c,owner,profile,plan,bases.size())
	if race==1:citrus_surplus_expansion(c,owner,workers,hq,profile,emergency)
	research_infrastructure(c,owner,plan,army,emergency)
	research_upgrades(c,owner,plan,army,emergency)
	# Skills need their real research facilities even when those are not unit prerequisites.
	if not emergency and not plan.is_empty() and not plan.get("_ai_ara_recovery",false) and level>=1 and army.size()>=6 and ACData.point(p.get("_ai_tech_reserve",[0,0])).length_squared()<.01:
		for skill in ACData.get_data().abilities:
			if int(skill.race)!=race or not str(skill.id) in plan.skills or skill.get("base",false):continue
			if not c.has_building(owner,int(skill.building)):
				var chain=[];TACTICS.building_chain(race,int(skill.building),chain)
				for kind in chain:
					if not c.has_building(owner,int(kind)) and c.prerequisites(owner,ACData.building(race,int(kind)).requires):build(c,owner,int(kind));break
				break
		for b in c.buildings:
			if int(b.owner)!=owner or b.hp<=0 or b.progress<1:continue
			if b.research=="":
				for key in plan.skills:
					var definition=ACResearch.definition(race,int(b.kind),str(key));var budget=available_resources(c,owner)
					var usable=ACData.get_data().abilities.any(func(skill):return int(skill.race)==race and str(skill.id)==str(key) and army.any(func(u):return int(u.kind) in skill.kinds))
					if usable and not definition.is_empty() and float(definition.as)<=budget.x and float(definition.tera)<=budget.y and ACResearch.level(p,str(key))==0:
						if c.command(owner,{"type":"research","id":b.id,"stat":str(key)})=="":break
			if str(plan.style)=="nuclear" and int(b.kind)==8 and int(p.get("nukes",0))<1 and available_resources(c,owner).x>=300 and available_resources(c,owner).y>=200:c.command(owner,{"type":"produce_nuke","id":b.id})
	for u in army:
		if c.unit_data(u).role=="carrier" and u.get("drones",[]).size()+u.get("drone_queue",[]).size()<8 and available_resources(c,owner).x>=25 and available_resources(c,owner).y>=10:c.command(owner,{"type":"produce_drone","id":u.id})
	var headquarters_cost=float(ACData.building(race,0).get("as",400))
	if not emergency and opening_attack_done and expansion_ready(c,p,army,workers,mining,plan) and c.time>=float(profile.expand) and workers.size()>=(8 if level>=4 else int(profile.expand_workers)) and bases.size()<int(profile.bases) and (available_resources(c,owner,false).x>=headquarters_cost+150 or float(p.get("_ai_expand_savings",0))>=headquarters_cost):
		expand(c,owner,workers,hq)
	# The single mining service above already handled new expansions and
	# exhausted patches without issuing a second order to the same worker.

static func ensure_detection(c,owner: int,army: Array) -> void:
	if not TACTICS.detection_needed(c,owner):return
	var p: Dictionary=c.players[owner];var race=int(p.race)
	var kind=[8,9,6][race];var d=ACData.unit(race,kind)
	var detectors=army.filter(func(u):return c.unit_data(u).role in ["detector","healer_detector"] and u.hp>0 and u.container<0)
	if detectors.is_empty():
		var chain=[];TACTICS.building_chain(race,1,chain)
		if race!=1:TACTICS.building_chain(race,int(d.producer),chain)
		for required in d.requires:TACTICS.building_chain(race,int(required),chain)
		for required in chain:
			if c.has_building(owner,int(required)):continue
			if c.prerequisites(owner,ACData.building(race,int(required)).requires):build(c,owner,int(required))
			return
	if c.time>=float(p.get("_ai_detection_until",0)):return
	var base: Dictionary=c.entity(int(p.home))
	if base.is_empty():return
	var home=c.center(base);var point=ACData.point(p.get("_ai_hidden_fire_pos",ACData.packed(home)))
	point=point.move_toward(home,2.5)
	for detector in detectors:
		if c.center(detector).distance_squared_to(point)<=16:continue
		if detector.order=="move" and ACData.point(detector.goal).distance_squared_to(point)<=1:continue
		if c.command(owner,{"type":"move","ids":[detector.id],"pos":ACData.packed(point)})=="":TACTICS.log_action(p,"detection:investigate");break

static func protect_detectors(c,owner: int,army: Array,bases: Array,visible: Array) -> void:
	var p: Dictionary=c.players[owner]
	if c.time<float(p.get("_ai_detector_guard_at",0)) or bases.is_empty():return
	p._ai_detector_guard_at=c.time+1.2
	var front=army.filter(func(u):return u.hp>0 and float(c.unit_data(u).damage)>0 and not u.get("_ai_scouting",false) and int(u.get("_ai_expendable_owner",-1))!=owner and not int(u.id) in p.get("_ai_claw_pending",[]))
	for u in army:
		var d=c.unit_data(u)
		if u.hp<=0 or u.container>=0 or not d.role in ["detector","healer_detector"]:continue
		var base=bases[0]
		for b in bases:
			if c.center(b).distance_squared_to(c.center(u))<c.center(base).distance_squared_to(c.center(u)):base=b
		var home=c.center(base);var point=home+Vector2(0,5)
		var danger=visible.any(func(e):
			if e.hp<=0 or not c.can_see(owner,e):return false
			var hostile=c.unit_data(e)
			var attacks=int(e.kind)==((11 if d.air else 10) if int(e.race)==1 else (12 if d.air else 11)) if e.has("progress") else float(hostile.get("damage",0))>0 and ("a" if d.air else "g") in str(hostile.targets)
			return attacks and c.center(e).distance_squared_to(c.center(u))<pow(float(hostile.get("range",9))+3,2))
		if danger or float(u.hp)<float(d.hp)*.6 and c.time-float(u.damaged)<6:
			point=c.center(u).move_toward(point,8)
		elif c.time<float(p.get("_ai_detection_until",0)):
			point=ACData.point(p.get("_ai_hidden_fire_pos",ACData.packed(home))).move_toward(home,3)
		elif not front.is_empty():
			var wave=front.filter(func(a):return int(a.id) in p.get("_ai_wave",[]))
			var group=wave if not wave.is_empty() else front
			var leader=group[0]
			for a in group:
				if c.center(a).distance_squared_to(c.center(u))<c.center(leader).distance_squared_to(c.center(u)):leader=a
			point=c.center(leader).move_toward(home,3.5)
		if not d.air:point=c.unit_free_position(int(u.race),int(u.kind),point,int(u.id))
		if c.center(u).distance_squared_to(point)>6.25 and (u.order!="move" or ACData.point(u.goal).distance_squared_to(point)>2.25):
			if c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(point)})=="":TACTICS.log_action(p,"detection:protect")

static func queue_unit(c,owner: int,b: Dictionary,plan: Dictionary,army: Array,counts: Dictionary,enemy_air: int,level: int) -> bool:
	var p: Dictionary=c.players[owner];var race=int(p.race)
	if production_room(c,b)<=0:return false
	if race==1 and float(p.get("_ai_worker_savings",0))>=float(ACData.unit(race,0).as) and c.CITRUS_BROOD.idle_pods(c,b).size()<=1:return false
	if race==1 and int(b.kind) not in [0,3]:return false
	var choices=[];var budget=available_resources(c,owner,true,false)
	var saved: Dictionary=p.get("_ai_unit_reserve",{})
	if not plan.is_empty() and saved.is_empty():budget=(budget-ACData.point(p.get("_ai_tech_reserve",[0,0]))).max(Vector2.ZERO)
	var free_population=minf(DIFFICULTY.supply_target(level),float(p.cap))-float(p.used)-float(p.reserved)
	if race==1 and float(p.get("_ai_worker_savings",0))>=float(ACData.unit(race,0).as):free_population-=float(ACData.unit(race,0).pop)
	for kind in range(1,ACData.unit_count(race)):
		var d=ACData.unit(race,kind)
		if d.get("spawn_only",false) or (race!=1 and int(d.producer)!=int(b.kind)):continue
		if not c.prerequisites(owner,d.requires):continue
		# Rank the needed composition before checking its price. Filtering out
		# a 150-mineral archer first made every 125-mineral guardian purchase
		# prevent the bank from ever reaching the archer's price.
		if d.tera>budget.y and not c.has_building(owner,1):continue
		if float(d.pop)*maxi(1,int(d.get("production_count",1)))>free_population:continue
		if plan.is_empty() and d.role in ["transport","detector"] and army.size()<12:continue
		var utility=4.0 if float(d.damage)>0 else .65
		if not plan.is_empty():
			utility=TACTICS.production_score(c,owner,plan,kind,counts,army.size())
			if utility<0:continue
			choices.append({"kind":kind,"score":utility+c.rng.randf()*.02});continue
		if level>=2 and enemy_air>0 and "a" in str(d.targets):utility*=2.2
		choices.append({"kind":kind,"score":utility/(int(counts.get(kind,0))+1)+c.rng.randf()*.2})
	choices.sort_custom(func(a,b):return a.score>b.score)
	if choices.is_empty():return false
	var kind=int(choices[0].kind)
	var chosen=ACData.unit(race,kind)
	if float(chosen.tera)>budget.y and budget.x>=350:
		var mineral_options=choices.filter(func(item):return float(ACData.unit(race,int(item.kind)).tera)==0 and float(ACData.unit(race,int(item.kind)).damage)>0 and float(ACData.unit(race,int(item.kind)).as)<=budget.x)
		if not mineral_options.is_empty():kind=int(mineral_options[0].kind);chosen=ACData.unit(race,kind)
	if not saved.is_empty() and int(saved.kind)!=kind:budget=(budget-Vector2(saved.as,saved.tera)).max(Vector2.ZERO)
	if float(chosen.as)>budget.x or float(chosen.tera)>budget.y:return false
	var previous_broods=b.queue.map(func(q):return int(q.get("brood",-1))) if c.trace_bot_tactics and race==1 else []
	if c.command(owner,{"type":"train","id":b.id,"kind":kind})!="":return false
	if chosen.role in ["detector","healer_detector"]:p._ai_detector_purchase_next=c.time+75
	if race==0 and kind==12:p._ai_fortress_next=c.time+180
	if not saved.is_empty() and int(saved.kind)==kind:p._ai_unit_reserve={}
	counts[kind]=int(counts.get(kind,0))+maxi(1,int(ACData.unit(race,kind).get("production_count",1)))
	if c.trace_bot_tactics and not b.queue.is_empty():
		if race!=1:b.queue.back()._ai_plan=str(p.get("_ai_tactic",""))
		if race==1:
			# Queue mirrors are rebuilt in pod-id order, not purchase order.
			# Tag the newly paid body even when an older high-id job sorts last.
			for entry in b.queue:
				if int(entry.get("brood",-1)) in previous_broods:continue
				entry._ai_plan=str(p.get("_ai_tactic",""))
				var pod=c.entity(int(entry.get("brood",-1)))
				if not pod.is_empty():pod._ai_train_plan=str(p.get("_ai_tactic",""))
	TACTICS.log_action(p,"train:"+str(kind));return true

static func fighting_population(c,army: Array) -> float:
	return army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 or c.unit_data(u).role=="carrier" else 0),0.0)

static func research_infrastructure(c,owner: int,plan: Dictionary,army: Array,emergency: bool=false) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<2 or emergency or c.time<180 or fighting_population(c,army)<12 or TACTICS.ARA.recovery(c,owner,army) or c.time<float(p.get("_ai_research_build_at",0)):return false
	p._ai_research_build_at=c.time+10
	var counts={}
	for u in army:
		if u.hp>0:counts[int(u.kind)]=int(counts.get(int(u.kind),0))+1
	var candidates=[]
	for item in ACData.get_data().research:
		if int(item.race)!=int(p.race) or not item.has("unit_kind") or int(counts.get(int(item.unit_kind),0))<3 or ACResearch.level(p,str(item.id))>0:continue
		candidates.append({"definition":item,"priority":int(counts[int(item.unit_kind)])+(30 if str(item.id)=="golem_range" else 0)})
	candidates.sort_custom(func(a,b):return int(a.priority)>int(b.priority))
	for candidate in candidates:
		var item: Dictionary=candidate.definition;var chain=[]
		TACTICS.building_chain(int(p.race),int(item.building),chain)
		for requirement in item.get("requires",[]):TACTICS.building_chain(int(p.race),int(requirement),chain)
		for kind in chain:
			if c.has_building(owner,int(kind)):continue
			if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==int(kind)):return false
			if c.prerequisites(owner,ACData.building(int(p.race),int(kind)).requires):return build(c,owner,int(kind))
	return false

static func research_upgrades(c,owner: int,plan: Dictionary,army: Array,emergency: bool=false) -> bool:
	var p: Dictionary=c.players[owner]
	if TACTICS.ARA.recovery(c,owner,army):return false
	if int(p.difficulty)<2 or emergency or c.time<120 or c.time<float(p.get("_ai_research_next",0)):return false
	var budget=(available_resources(c,owner)-ACData.point(p.get("_ai_tech_reserve",[0,0]))).max(Vector2.ZERO)
	var counts={}
	for u in army:
		if u.hp>0:counts[int(u.kind)]=int(counts.get(int(u.kind),0))+1
	var jobs=[]
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0 or b.progress<1 or b.research!="":continue
		for item in ACResearch.catalog(int(p.race),int(b.kind)):
			var key=str(item.id);var level=ACResearch.level(p,key)
			if level>=int(item.get("max_level",1)):continue
			var priority=0.0
			if item.has("unit_kind"):
				var kind=int(item.unit_kind);var d=ACData.unit(int(p.race),kind);var count=int(counts.get(kind,0))
				if count<(1 if d.role=="transport" else 3 if float(d.pop)>=2 else 6):continue
				priority=count*(3.0 if kind in plan.get("primary",[]) else 1.0)+20+(40 if key=="golem_range" else 0)
			elif key in ["attack","armor","shield"]:
				if fighting_population(c,army)<8:continue
				priority=8.0-level*2+(2 if key=="attack" else 0)
			elif key=="stim" and int(p.difficulty)>=3 and int(counts.get(1,0))+int(counts.get(2,0))>=8:
				priority=25
			elif key in plan.get("skills",[]) and ACData.get_data().abilities.any(func(skill):return str(skill.id)==key and int(skill.race)==int(p.race) and army.any(func(u):return int(u.kind) in skill.kinds)):
				priority=12
			else:continue
			var price=Vector2(item.as,item.tera)+Vector2.ONE*float(item.get("step",0))*level
			if price.x>budget.x or price.y>budget.y:continue
			jobs.append({"building":b.id,"key":key,"priority":priority})
	jobs.sort_custom(func(a,b):return float(a.priority)>float(b.priority))
	for job in jobs:
		if c.command(owner,{"type":"research","id":job.building,"stat":job.key})=="":p._ai_research_next=c.time+6;TACTICS.log_action(p,"research:priority");return true
	return false

static func production_bottleneck(c,owner: int,plan: Dictionary) -> String:
	var p: Dictionary=c.players[owner];var free=minf(200,float(p.cap))-float(p.used)-float(p.reserved)
	if float(p.used)+float(p.reserved)>=199:return "population_limit"
	if free<3 and float(p.cap)<200:return "supply"
	var budget=available_resources(c,owner,true,false);var cheapest=Vector2(INF,INF);var producers=[]
	for kind in plan.get("primary",[]):
		var d=ACData.unit(int(p.race),int(kind))
		if not c.prerequisites(owner,d.requires):continue
		cheapest=cheapest.min(Vector2(d.as,d.tera));producers.append(int(d.producer))
	if not cheapest.is_finite():return "technology"
	if budget.x<cheapest.x:return "as"
	if budget.y<cheapest.y:return "tera"
	var factories=production_factories(c,owner).filter(func(b):return int(p.race)==1 and int(b.kind) in [0,3] or int(b.kind) in producers)
	if factories.is_empty() or not factories.any(func(b):return production_room(c,b)>0):return "capacity"
	return "balanced"

static func expansion_ready(c,p: Dictionary,army: Array,workers: Array,mining: Dictionary,plan: Dictionary) -> bool:
	if int(p.difficulty)<4:return true
	var minimum=clampi(ceili(float(mining.target)*.45),8,12)
	# Casualties must not continually reset expansion savings and demand a
	# larger surviving army than the economy can ever replenish on one base.
	return workers.size()>=minimum and (fighting_population(c,army)>=3 or c.time>=180 or float(p.get("_ai_expand_savings",0))>0)

static func citrus_surplus_expansion(c,owner: int,workers: Array,hq: Dictionary,profile: Dictionary,emergency: bool) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.race)!=1 or int(p.difficulty)<2:return false
	var pending=c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1) or workers.any(func(w):return w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==0)
	var cost=float(ACData.building(1,0).as)
	# Run after paid reinforcement and gradual nursery investment. These are
	# genuine spare resources, excluding army/worker/expansion/travel earmarks.
	# Citrus can turn persistent excess into more resource bases and brood
	# production even beyond the other races' ordinary expansion count cap.
	if emergency or str(p.get("_ai_attack_phase",""))=="defend" or pending or workers.size()<8 or c.time<maxf(120,float(profile.expand)) or available_resources(c,owner).x<cost*2:
		p.erase("_ai_citrus_surplus_since");return false
	if not p.has("_ai_citrus_surplus_since"):p._ai_citrus_surplus_since=c.time
	if c.time-float(p._ai_citrus_surplus_since)<20 or c.time<float(p.get("_ai_citrus_expansion_next",0)) or c.time<float(p.get("_ai_citrus_site_retry",0)):return false
	# Reuse real path, resource, occupancy and visible-enemy site checks. An
	# unavailable location cannot trigger expensive full searches every tick.
	p._ai_citrus_site_retry=c.time+8
	if not expand(c,owner,workers,hq):return false
	p._ai_citrus_expansion_next=c.time+120
	p._ai_citrus_surplus_expansions=int(p.get("_ai_citrus_surplus_expansions",0))+1
	p.erase("_ai_citrus_surplus_since");return true

static func production_factories(c,owner: int) -> Array:
	var factories=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and b.progress>=1 and c.building_powered(b))
	var saved: Dictionary=c.players[owner].get("_ai_unit_reserve",{})
	if not saved.is_empty():factories.sort_custom(func(a,b):return int(a.id)==int(saved.producer) and int(b.id)!=int(saved.producer))
	return factories

static func production_room(c,factory: Dictionary) -> int:
	if factory.hp<=0 or factory.progress<1 or not c.building_powered(factory):return 0
	if int(factory.race)==1:
		if int(factory.kind) not in [0,3]:return 0
		# Each real pod has at most one active job. The mirrored pool is a
		# collection of simultaneous jobs, not a long sequential queue.
		return mini(2,c.CITRUS_BROOD.idle_pods(c,factory).size())
	return maxi(0,2-factory.queue.size())

static func fund_combat(c,owner: int,plan: Dictionary,army: Array,counts: Dictionary) -> void:
	var p: Dictionary=c.players[owner];var race=int(p.race);var best={};var score=-INF
	var free=minf(DIFFICULTY.supply_target(int(p.difficulty)),float(p.cap))-float(p.used)-float(p.reserved)
	for factory in production_factories(c,owner):
		if production_room(c,factory)<=0 or race!=1 and not factory.queue.is_empty():continue
		for kind in range(1,ACData.unit_count(race)):
			var d=ACData.unit(race,kind)
			if d.get("spawn_only",false) or race!=1 and int(d.producer)!=int(factory.kind) or not c.prerequisites(owner,d.requires):continue
			if float(d.pop)*maxi(1,int(d.get("production_count",1)))>free:continue
			if float(d.tera)>float(p.tera) and not c.has_building(owner,1):continue
			var value=TACTICS.production_score(c,owner,plan,kind,counts,army.size()) if not plan.is_empty() else (4.0 if float(d.damage)>0 else 0.0)/(int(counts.get(kind,0))+1)
			if value<=0 or value<=score:continue
			score=value;best={"kind":kind,"producer":int(factory.id),"as":float(d.as),"tera":float(d.tera)}
	p._ai_unit_reserve=best

static func ensure_supply(c,owner: int,level: int) -> void:
	var p: Dictionary=c.players[owner]
	if float(p.cap)>=DIFFICULTY.supply_target(level):return
	var future=float(p.cap);var producers=0
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0:continue
		if b.progress<1:
			if int(b.kind)==2 or float(ACData.building(int(b.race),int(b.kind)).time)*(1-float(b.progress))<=20:future+=float(ACData.building(int(b.race),int(b.kind)).supply)
		elif int(b.kind) in ([0,3] if int(p.race)==1 else [0,3,4,5]):producers+=1
	for w in c.units:
		if int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==2:future+=float(ACData.building(int(w.race),2).supply)
	if future>=DIFFICULTY.supply_target(level):return
	var headroom=clampf(producers*[1,1,1.5,2.5,3,4][level],8 if level>=4 else 5,32)
	if future-float(p.used)-float(p.reserved)<headroom:build(c,owner,2,2 if level>=4 else 1)

static func production_target(level: int,base_count: int,budget: Vector2) -> int:
	# Spend a surplus on throughput rather than indefinitely keeping a fixed
	# three factories. Higher levels react sooner and support larger economies.
	var floor_count=[1,1,1,1,2,2][level]
	var threshold=[1000000,1000000,900,700,500,350][level]
	var extra=clampi(floori((budget.x-threshold)/500.0)+1,0,[0,0,1,2,3,4][level])
	return mini([1,1,3,6,10,14][level],floor_count+maxi(0,base_count-1)*[0,0,0,1,1,2][level]+extra)

static func invest_production(c,owner: int,profile: Dictionary,plan: Dictionary,base_count: int) -> void:
	var p: Dictionary=c.players[owner];var level=clampi(int(p.difficulty),0,5)
	if level<2 or c.time<float(p.get("_ai_production_next",0)):return
	p._ai_production_next=c.time+[0,0,12,6,3,2][level]
	p._ai_production_bottleneck=production_bottleneck(c,owner,plan)
	if str(p._ai_production_bottleneck)=="population_limit":return
	if str(p._ai_production_bottleneck)=="supply":ensure_supply(c,owner,level);return
	if str(p._ai_production_bottleneck)=="tera":
		ensure_refineries(c,owner,c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1))
		return
	if int(p.race)==1:
		if available_resources(c,owner).x>=float(ACData.building(1,3).as):ensure_citrus_nurseries(c,owner)
		return
	var budget=available_resources(c,owner)-ACData.point(p.get("_ai_tech_reserve",[0,0]))
	if budget.x<[0,0,400,325,200,150][level]:return
	var race=int(p.race);var weights={};var all_counts=TACTICS.queued_counts(c,owner)
	var primary_factories=plan.get("primary",[]).map(func(kind):return int(ACData.unit(race,int(kind)).producer))
	for kind in range(1,ACData.unit_count(race)):
		var d=ACData.unit(race,kind)
		if d.get("spawn_only",false) or not c.prerequisites(owner,d.requires):continue
		var weight=float(plan.get("weights",{}).get(str(kind),0)) if not plan.is_empty() else (1.0 if float(d.damage)>0 else 0.0)
		if not plan.is_empty():weight*=2.5 if kind in plan.primary else .65
		if d.role in ["detector","healer_detector","transport"]:
			var cap=2 if d.role in ["detector","healer_detector"] else 3
			if int(all_counts.get(kind,0))>=cap:continue
		if (budget.x>=800 or budget.x>=400 and budget.y<75) and float(d.tera)==0 and float(d.damage)>0 and "g" in str(d.targets):weight=maxf(weight,6)
		if weight<=0:continue
		var producer=3 if race==1 else int(d.producer)
		weights[producer]=float(weights.get(producer,0))+weight
	var total=0;var options=[]
	for kind in weights:
		var facilities=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==int(kind) and b.hp>0)
		var travelling=c.units.filter(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==int(kind)).size()
		var count=facilities.size()+travelling;total+=count
		var active=facilities.filter(func(b):return b.progress>=1 and c.building_powered(b))
		# Empty facilities should be used before buying duplicates. Never let
		# army casualties disable production replacement while cash is available.
		var busy=active.filter(func(b):return not b.queue.is_empty()).size()
		if not active.is_empty() and busy*2<active.size():continue
		if c.prerequisites(owner,ACData.building(race,int(kind)).requires):options.append({"kind":int(kind),"score":float(weights[kind])/float(count+1)})
	var basic_count=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==3).size()+c.units.filter(func(w):return int(w.owner)==owner and w.order=="build_move" and int(w.build_plan.kind)==3).size()
	var mech=race==0 and 4 in primary_factories
	var basic_shortfall=level>=4 and basic_count<(clampi(ceili(float(p.get("_ai_miner_count",0))/8.0),1,6) if 3 in primary_factories else 1)
	var mech_count=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==4).size()+c.units.filter(func(w):return int(w.owner)==owner and w.order=="build_move" and int(w.build_plan.kind)==4).size()
	var mech_shortfall=mech and mech_count<clampi(ceili(float(p.get("_ai_miner_count",0))/10.0),2,8)
	if mech_shortfall:
		for option in options:
			if int(option.kind)==4:option.score+=100
	if basic_shortfall:
		for option in options:
			if int(option.kind)==3:option.score+=100
	if total>=production_target(level,base_count,budget) and not basic_shortfall and not mech_shortfall:
		# Idle gas factories are not usable mineral-only throughput. Add a
		# small number of the affordable producer instead of buying more of
		# the same gas-locked factories or leaving the bank untouched.
		if budget.x<600 or budget.y>=75:return
		var basic=3
		var count=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==basic).size()+c.units.filter(func(w):return int(w.owner)==owner and w.order=="build_move" and int(w.build_plan.kind)==basic).size()
		if count>=mini(4,ceili(budget.x/600.0)):return
		options=options.filter(func(item):return int(item.kind)==basic)
	options.sort_custom(func(a,b):return a.score>b.score)
	for option in options:
		if build(c,owner,int(option.kind),2 if level>=4 and budget.x>=800 else 1):TACTICS.log_action(p,"capacity:"+str(option.kind));return

static func save_expansion(c,owner: int,workers: Array,army: Array,bases: Array,profile: Dictionary,emergency: bool) -> void:
	var p: Dictionary=c.players[owner];var level=int(p.difficulty);var earned=float(p.get("_as_collected",0))
	var income=maxf(0,earned-float(p.get("_ai_expand_income",earned)));p._ai_expand_income=earned
	var pending=c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1) or workers.any(func(w):return w.order=="build_move" and int(w.build_plan.kind)==0)
	var mining=ECONOMY.plan(c,owner,workers,bases)
	if level<2 or pending or bases.size()>=int(profile.bases):
		p._ai_expand_savings=0.0
		if pending:p._ai_tech_reserve=[0,0]
		return
	if emergency:
		p._ai_expand_savings=minf(float(p.get("_ai_expand_savings",0)),maxf(0,float(p.as)*.5));return
	if not expansion_ready(c,p,army,workers,mining,TACTICS.plan_for(p)) or c.time<float(profile.expand):return
	# Earmark part of new real mineral deposits, keeping the remainder for
	# reinforcement. This is neither extra income nor a complete army pause.
	# A unit reservation cannot erode money already earmarked for a base.
	# Otherwise each new infantry purchase repeatedly reset the saving to zero.
	p._ai_expand_savings=minf(maxf(0,available_resources(c,owner,false,false).x),minf(float(ACData.building(int(p.race),0).as),float(p.get("_ai_expand_savings",0))+income*[0,0,.25,.25,.25,.25][level]))
	if float(p._ai_expand_savings)>0:p._ai_tech_reserve=[0,0]

static func save_worker(c,owner: int,workers: Array,mining: Dictionary) -> void:
	var p: Dictionary=c.players[owner];var earned=float(p.get("_as_collected",0))
	var income=maxf(0,earned-float(p.get("_ai_worker_income",earned)));p._ai_worker_income=earned
	if int(p.race)!=1 or workers.size()+ECONOMY.worker_queue(c,owner)>=int(mining.target) or str(p.get("_ai_attack_phase",""))=="defend":p._ai_worker_savings=0.0;return
	# Construction consumes citrus workers. Protect a small replacement share
	# and one real pod, rather than letting army morphs erase the economy.
	var room=available_resources(c,owner,true,false,false)
	p._ai_worker_savings=minf(room.x,minf(float(ACData.unit(1,0).as),float(p.get("_ai_worker_savings",0))+income*.2))

static func available_resources(c,owner: int,reserve_expansion: bool=true,reserve_unit: bool=true,reserve_worker: bool=true) -> Vector2:
	var budget=Vector2(c.players[owner].as,c.players[owner].tera)
	if reserve_expansion:budget.x-=float(c.players[owner].get("_ai_expand_savings",0))
	var saved: Dictionary=c.players[owner].get("_ai_unit_reserve",{})
	if reserve_unit and not saved.is_empty():budget-=Vector2(saved.as,saved.tera)
	if reserve_worker:budget.x-=float(c.players[owner].get("_ai_worker_savings",0))
	# The game charges a foundation on arrival, so travelling plans need a
	# planning reservation. Never modify the player's real resource balance.
	for worker in c.units:
		if int(worker.owner)!=owner or worker.hp<=0 or worker.order!="build_move":continue
		var plan: Dictionary=worker.get("build_plan",{})
		if plan.is_empty():continue
		var definition=ACData.building(int(worker.race),int(plan.kind))
		budget-=Vector2(definition.as,definition.tera)
	# Saving future Tera must not forbid an As-only purchase costing zero Tera.
	return budget.max(Vector2.ZERO)

static func builder(c,workers: Array,goal: Vector2) -> Dictionary:
	var best: Dictionary={};var distance=INF
	for u in workers:
		if u.hp<=0 or u.container>=0 or u.get("_ai_scouting",false) or u.order in ["construct","build_move"] or not u.build_queue.is_empty():continue
		var d: float=c.center(u).distance_squared_to(goal)
		if d<distance:distance=d;best=u
	return best

static func blocks_lane(c,owner: int,pos: Vector2,definition: Dictionary) -> bool:
	var rect=Rect2(pos-Vector2(.5,.5),Vector2(definition.w,definition.h)).grow(.6)
	for hq in c.buildings:
		if int(hq.owner)!=owner or int(hq.kind)!=0 or hq.hp<=0:continue
		var home: Vector2=c.center(hq)
		if int(hq.race)==1 and rect.intersects(Rect2(home+Vector2(-3,1.8),Vector2(6,4.6))):return true
		for node in c.map.resources:
			var resource=ACData.point(node.pos)
			if node.type!="as" or node.amount<=0 or resource.distance_to(home)>13:continue
			for step in range(1,11):
				if rect.has_point(home.lerp(resource,float(step)/10.0)):return true
	return false

static func nursery_counts(c,owner: int,bases: Array) -> Dictionary:
	var result={}
	for base in bases:result[int(base.id)]=0
	var plans=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==3 and b.hp>0).map(func(b):return c.center(b))
	plans.append_array(c.units.filter(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==3).map(func(w):return ACData.point(w.build_plan.pos)+Vector2(1.5,1)))
	for point in plans:
		var nearest=-1;var distance=144.0001
		for base in bases:
			var value=c.center(base).distance_squared_to(point)
			if value<distance:distance=value;nearest=int(base.id)
		if nearest>=0:result[nearest]+=1
	return result

static func ensure_citrus_nurseries(c,owner: int) -> void:
	var p: Dictionary=c.players[owner]
	if c.time<float(p.get("_ai_nursery_next",0)):return
	if c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==3 and b.hp>0 and b.progress<1) or c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==3):return
	var bases=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress>=1)
	var counts=nursery_counts(c,owner,bases)
	for base in bases:
		if int(counts[int(base.id)])<2:
			if build(c,owner,3,1,int(base.id)):p._ai_nursery_next=c.time+45
			return

static func ensure_refineries(c,owner: int,bases: Array) -> void:
	var p: Dictionary=c.players[owner]
	if available_resources(c,owner).x<200:return
	for base in bases:
		var home=c.center(base)
		if c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==1 and b.hp>0 and c.center(b).distance_squared_to(home)<225):continue
		if c.map.resources.any(func(node):return node.type=="tera" and c.footprint_distance(base,ACData.point(node.pos))<13):
			build(c,owner,1,1,int(base.id));return

static func build(c,owner: int,kind: int,max_pending: int=1,base_id: int=-1) -> bool:
	if int(c.players[owner].race)==1 and kind in [4,5,6,7,8,9]:
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==kind) or c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==kind):return false
	if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==kind):return false
	var race=int(c.players[owner].race);var d=ACData.building(race,kind)
	var budget=available_resources(c,owner)
	if budget.x<d.as or budget.y<d.tera:return false
	if c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==kind and b.hp>0 and b.progress<1).size()>=max_pending:return false
	var bases=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress>=1)
	if base_id>=0:bases=bases.filter(func(b):return int(b.id)==base_id)
	var nursery=c.players[owner].race==1 and kind==3
	var nursery_totals=nursery_counts(c,owner,c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress>=1)) if nursery else {}
	var workers=c.units.filter(func(u):return int(u.owner)==owner and int(u.kind)==0 and u.hp>0)
	for hq in bases:
		if nursery and int(nursery_totals.get(int(hq.id),0))>=2:continue
		var home: Vector2=c.center(hq)
		if kind==1:
			for node in c.map.resources:
				if node.type!="tera" or ACData.point(node.pos).distance_to(home)>14:continue
				var anchor: Vector2=c.refinery_anchor(node)
				var placement_error: String=c.placement(owner,kind,anchor)
				if placement_error.contains("규율탑"):return power_site(c,owner,workers,anchor,kind)
				if placement_error!="":continue
				var worker=builder(c,workers,anchor)
				if not worker.is_empty():return c.command(owner,{"type":"build","kind":kind,"pos":ACData.packed(anchor),"ids":[worker.id]})==""
			continue
		for attempt in range(80):
			var pos=(home+Vector2(c.rng.randi_range(-10,9),c.rng.randi_range(-8,9))).floor()
			if nursery and (pos+Vector2(d.w,d.h)*.5).distance_squared_to(home)>144:continue
			if pos.distance_to(home)<4 or blocks_lane(c,owner,pos,d) or c.placement(owner,kind,pos)!="":continue
			var footprint=Rect2(pos-Vector2.ONE*.5,Vector2(d.w,d.h))
			var reserved=workers.any(func(w):
				if w.order!="build_move" or w.build_plan.is_empty():return false
				var planned=ACData.building(race,int(w.build_plan.kind))
				return footprint.intersects(Rect2(ACData.point(w.build_plan.pos)-Vector2.ONE*.5,Vector2(planned.w,planned.h))))
			if reserved:continue
			var worker=builder(c,workers,pos)
			if not worker.is_empty():return c.command(owner,{"type":"build","kind":kind,"pos":ACData.packed(pos),"ids":[worker.id]})==""
	return false

static func power_site(c,owner: int,workers: Array,anchor: Vector2,kind: int) -> bool:
	for b in c.buildings:
		if int(b.owner)==owner and int(b.kind)==2 and b.hp>0 and b.progress<1 and power_covers(anchor,kind,ACData.point(b.pos)):return false
	for w in workers:
		if w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==2 and power_covers(anchor,kind,ACData.point(w.build_plan.pos)):return false
	if available_resources(c,owner).x<float(ACData.building(2,2).as):return false
	for ring in range(3,8):
		for offset in [Vector2(ring,0),Vector2(-ring,0),Vector2(0,ring),Vector2(0,-ring),Vector2(ring,ring),Vector2(-ring,-ring)]:
			var pos=(anchor+offset).floor()
			if c.placement(owner,2,pos)!="" or blocks_lane(c,owner,pos,ACData.building(2,2)):continue
			if not power_covers(anchor,kind,pos):continue
			var worker=builder(c,workers,pos)
			if not worker.is_empty():return c.command(owner,{"type":"build","kind":2,"pos":ACData.packed(pos),"ids":[worker.id]})==""
	return false

static func power_covers(anchor: Vector2,kind: int,tower_pos: Vector2) -> bool:
	var d=ACData.building(2,kind)
	var tower=ACData.building(2,2)
	var middle=tower_pos+Vector2(tower.w,tower.h)*.5
	for corner in [anchor,anchor+Vector2(d.w-1,0),anchor+Vector2(0,d.h-1),anchor+Vector2(d.w-1,d.h-1)]:
		if middle.distance_squared_to(corner)>144.0:return false
	return true

static func expansion_site(c,owner: int,workers: Array,hq: Dictionary) -> Dictionary:
	var d=ACData.building(int(c.players[owner].race),0)
	var best: Dictionary={};var score=INF
	for base in c.map.bases:
		if str(base.get("access","ground"))!="ground":continue
		var site=ACData.point(base.pos);var occupied=false;var minerals=0
		for node in c.map.resources:
			if node.id in base.resources and node.type=="as":minerals+=int(node.amount)
		if minerals<500:continue
		for b in c.buildings:
			if b.hp<=0:continue
			if int(b.owner)==owner and int(b.race)==2 and int(b.kind)==2:continue
			if (int(b.owner)==owner or c.can_see(owner,b)) and c.center(b).distance_to(site)<(10 if c.allied(owner,int(b.owner)) else 22):occupied=true;break
		if occupied:continue
		for enemy in c.units:
			if enemy.hp>0 and not c.allied(owner,int(enemy.owner)) and c.can_see(owner,enemy) and c.center(enemy).distance_to(site)<16:occupied=true;break
		if occupied:continue
		var worker=builder(c,workers,site)
		if worker.is_empty():continue
		var approach: Vector2=c.map.nearest_free(site+Vector2(0,3))
		if approach.distance_to(site)>6:continue
		# Expand outward from a completed base, never from a wandering worker.
		# Reject remote sites and long detours even when they are technically reachable.
		var value=INF
		for own_base in c.buildings:
			if int(own_base.owner)!=owner or int(own_base.kind)!=0 or own_base.hp<=0 or own_base.progress<1:continue
			var direct: float=site.distance_to(c.center(own_base))
			if direct>48:continue
			var origin: Vector2=c.map.nearest_free(c.center(own_base)+Vector2(0,4))
			var path: Array=c.map.navigator.get_id_path(Vector2i(origin.round()),Vector2i(approach.round()))
			if path.is_empty() or path.size()>80 or path.size()>direct*2.5+12:continue
			value=minf(value,float(path.size())+direct*.3)
		if value>=score:continue
		var anchors=[]
		for y in range(-9,10):
			for x in range(-9,10):anchors.append((site-Vector2(d.w,d.h)*.5+Vector2(x,y)).floor())
		anchors.sort_custom(func(a,b):return a.distance_squared_to(site)<b.distance_squared_to(site))
		var balanced=c.map.headquarters_sites.get(c.map.bases.find(base),[])
		if not balanced.is_empty():anchors.push_front(ACData.point(balanced))
		for anchor in anchors:
			var error: String=c.placement(owner,0,anchor)
			if error=="" or (int(c.players[owner].race)==2 and error.contains("규율탑")):
				best={"pos":ACData.packed(anchor),"worker":worker.id,"base":base};score=value;break
	return best

static func expand(c,owner: int,workers: Array,hq: Dictionary) -> bool:
	if c.time<float(c.players[owner].get("_ai_expansion_search_next",0)):return false
	if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==0):return false
	for b in c.buildings:
		if int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1:return false
	var definition=ACData.building(int(c.players[owner].race),0)
	# The completed expansion earmark owns this money. Do not demand an
	# additional unit price before allowing the saved headquarters purchase.
	var budget=available_resources(c,owner,false,false)
	if budget.x<float(definition.as) or budget.y<float(definition.tera):return false
	var choice=expansion_site(c,owner,workers,hq)
	if choice.is_empty():c.players[owner]._ai_expansion_search_next=c.time+8;return false
	if int(c.players[owner].race)==2 and c.placement(owner,0,ACData.point(choice.pos)).contains("규율탑"):
		return power_site(c,owner,workers,ACData.point(choice.pos),0)
	var accepted=c.command(owner,{"type":"build","kind":0,"pos":choice.pos,"ids":[choice.worker]})==""
	if accepted:c.players[owner]._ai_expand_savings=0.0;c.players[owner]._ai_expansion_search_next=c.time+20
	return accepted

static func redistribute(c,owner: int,workers: Array,bases: Array) -> void:
	if bases.size()<2:return
	var best=-1;var lowest=INF;var counts: Array=[]
	for i in range(bases.size()):
		var count=0
		for w in workers:
			var node: Dictionary=c.resource(int(w.target))
			if w.order=="gather" and not node.is_empty() and ACData.point(node.pos).distance_to(c.center(bases[i]))<13:count+=1
		counts.append(count)
		var id: int=c.nearest_resource(c.center(bases[i]),"as",owner)
		var node: Dictionary=c.resource(id)
		if not node.is_empty() and ACData.point(node.pos).distance_to(c.center(bases[i]))<13 and count<lowest:lowest=count;best=i
	if best<0:return
	for w in workers:
		if w.order!="gather" or int(w.carried)>0:continue
		var node: Dictionary=c.resource(int(w.target))
		if node.is_empty():continue
		for i in range(bases.size()):
			if i==best or counts[i]<=lowest+3 or ACData.point(node.pos).distance_to(c.center(bases[i]))>=13:continue
			var target=c.nearest_resource(c.center(bases[best]),"as",owner)
			if c.command(owner,{"type":"gather","ids":[w.id],"target":target})!="":return
			w.auto_mine_hq=int(bases[best].id)
			w.erase("mining_anchor");w.erase("mining_base")
			return

static func staging_safe(c,point: Vector2,visible: Array,guard_strength: float=0) -> bool:
	var hostile_strength=0.0
	for enemy in visible:
		var d=ACData.building(int(enemy.race),int(enemy.kind)) if enemy.has("progress") else c.unit_data(enemy)
		var distance=c.footprint_distance(enemy,point) if enemy.has("progress") else c.center(enemy).distance_to(point)
		if distance>=maxf(8,float(d.get("range",0))+4):continue
		if enemy.has("progress"):
			# Keep assembly outside an actual enemy base or defensive position.
			return false
		if float(d.damage)<=0 and d.role!="carrier":continue
		hostile_strength+=maxf(1,float(d.pop))
	# A lone scout cannot repeatedly drag an assembled force to a new site.
	return hostile_strength==0 or hostile_strength<guard_strength*.4

static func assembly_ground(c,dimensions: Vector2,point: Vector2,back: Vector2) -> bool:
	if dimensions==Vector2.ZERO:return true
	var spacing=maxf(1.65,maxf(dimensions.x,dimensions.y)+.25);var side=back.orthogonal()
	for row in range(2):
		for column in range(-1,2):
			var slot=point+back*row*spacing+side*column*spacing
			if not c._ground_fits_size(dimensions,slot) or not c._ground_sweep(dimensions,point,slot):return false
	return true

static func home_assembly(c,p: Dictionary,army: Array,near: Vector2,home: Vector2) -> Vector2:
	var dimensions=Vector2.ZERO
	for u in army:
		if not c.unit_data(u).air:dimensions=dimensions.max(c._body_size(u))
	var cache: Dictionary=p.get("_ai_home_assembly",{})
	if int(cache.get("revision",-1))==c.map.revision and ACData.point(cache.get("dimensions",[0,0]))==dimensions and ACData.point(cache.get("home",[0,0]))==home:return ACData.point(cache.point)
	var recruits=army.filter(func(u):return not c.unit_data(u).air and c.center(u).distance_squared_to(home)<=576 and not int(u.id) in p.get("_ai_wave",[]) and not int(u.id) in p.get("_ai_marching",[]) and c._ground_fits_size(dimensions,c.center(u)))
	var anchor=near
	if not recruits.is_empty():
		var middle=Vector2.ZERO
		for u in recruits:middle+=c.center(u)
		middle/=recruits.size()
		recruits.sort_custom(func(a,b):return c.center(a).distance_squared_to(middle)<c.center(b).distance_squared_to(middle));anchor=c.center(recruits[0])
	var back=(home-near).normalized();var chosen=near;var found=false
	for search_origin in [near,anchor]:
		for ring in range(7):
			for turn in range(12 if ring>0 else 1):
				var point=(search_origin+Vector2.from_angle(turn*TAU/12)*ring*1.5).round().clamp(Vector2(2,2),Vector2(125,125))
				if not assembly_ground(c,dimensions,point,back):continue
				if not recruits.is_empty():
					if not c._ground_sweep(dimensions,anchor,point):continue
				elif c.map.path(near,point).is_empty():continue
				chosen=point;found=true;break
			if found:break
		if found:break
	# Cache exact body dimensions; position rounding would turn e.g. 1.0625
	# into 1.063 and miss this cache on every planning turn.
	p._ai_home_assembly={"revision":c.map.revision,"dimensions":[dimensions.x,dimensions.y],"home":ACData.packed(home),"point":ACData.packed(chosen)}
	return chosen

static func assembly_ready(c,u: Dictionary,point: Vector2) -> bool:
	var distance=c.center(u).distance_squared_to(point)
	if distance<=3.0625:return true
	# A formed cohort already fighting at forward assembly has arrived.
	# Requiring every shooter to stand on its exact idle slot repeatedly
	# cancelled commitment as the frontline stepped out to engage.
	if distance<=49 and int(u.id) in c.players[int(u.owner)].get("_ai_marching",[]) and (c.time-float(u.fired)<2 or c.time-float(u.damaged)<2):
		var target=c.entity(int(u.target)) if u.order=="attack" else c.entity(int(u.get("_auto_target",-1)))
		if not target.is_empty() and target.hp>0 and not c.allied(int(u.owner),int(target.owner)) and c.can_see(int(u.owner),target) and c._can_attack(c.unit_data(u),target):return true
	# The movement resolver may finish beside an occupied formation slot.
	# Accept that compact physical arrival, not a distant or unrelated idle.
	return distance<=6.25 and u.order in ["idle","hold"] and ACData.point(u.goal).distance_squared_to(point)<.25

static func staging_connected(c,owner: int,dimensions: Vector2,origin: Vector2,point: Vector2) -> bool:
	if dimensions==Vector2.ZERO:return true
	var p: Dictionary=c.players[owner]
	if not p.has("_ai_stage_reach"):p._ai_stage_reach={}
	var cache: Dictionary=p._ai_stage_reach
	var key=str(point)+":"+str(dimensions)
	var saved: Dictionary=cache.get(key,{})
	# A checked body sweep joins the new origin to the cached origin in the
	# same unchanged world. Reuse connectivity, never a route or blocked edge.
	if int(saved.get("revision",-1))==c.map.revision and c._ground_sweep(dimensions,ACData.point(saved.origin),origin):
		saved.origin=ACData.packed(origin);return bool(saved.connected)
	var connected=not c.map.path(origin,point).is_empty()
	if cache.size()>64:cache.clear()
	cache[key]={"revision":c.map.revision,"origin":ACData.packed(origin),"connected":connected}
	return connected

static func forward_staging(c,army: Array,home: Vector2,goal: Vector2,visible: Array,previous: Vector2) -> Vector2:
	var dimensions=Vector2.ZERO
	var strength=0.0
	var ground=[]
	for u in army:
		if not c.unit_data(u).air:dimensions=dimensions.max(c._body_size(u));ground.append(u)
		if float(c.unit_data(u).damage)>0:strength+=maxf(1,float(c.unit_data(u).pop))
	var origin=home
	if not ground.is_empty():
		var middle=Vector2.ZERO
		for u in ground:middle+=c.center(u)
		middle/=ground.size();ground.sort_custom(func(a,b):return c.center(a).distance_squared_to(middle)<c.center(b).distance_squared_to(middle));origin=c.center(ground[0])
	var owner=int(army[0].owner) if not army.is_empty() else 0
	if previous.is_finite() and assembly_ground(c,dimensions,previous,(home-previous).normalized()) and staging_safe(c,previous,visible,strength) and staging_connected(c,owner,dimensions,origin,previous):return previous
	var back=(home-goal).normalized()
	for distance in [16,20,24,28]:
		for angle in [0,.3,-.3,.6,-.6]:
			var point=(goal+back.rotated(angle)*distance).round().clamp(Vector2.ONE,Vector2(126,126))
			if not staging_safe(c,point,visible):continue
			if dimensions!=Vector2.ZERO:
				if not assembly_ground(c,dimensions,point,(home-point).normalized()) or not staging_connected(c,owner,dimensions,origin,point):continue
			return point
	return home

static func staging_slot(c,p: Dictionary,u: Dictionary,stage: Vector2,home: Vector2) -> Vector2:
	if not p.has("_ai_stage_slots"):p._ai_stage_slots={}
	var slots: Dictionary=p._ai_stage_slots;var id=int(u.id)
	if not slots.has(id):
		slots[id]={"index":0,"origin":[-999,-999],"pos":ACData.packed(stage)}
	var item: Dictionary=slots[id]
	var band=COMBAT_POLICY.band(c.unit_data(u))
	if ACData.point(item.origin).distance_squared_to(stage)>=.01 or int(item.get("band",-1))!=band:
		var index=0
		while slots.values().any(func(s):return ACData.point(s.origin).distance_squared_to(stage)<.01 and int(s.get("band",-1))==band and int(s.index)==index):index+=1
		item.index=index;item.band=band
	var spacing=float(p.get("_ai_stage_spacing",1.65))
	if ACData.point(item.origin).distance_squared_to(stage)<.01 and is_equal_approx(float(item.get("spacing",0)),spacing):return ACData.point(item.pos)
	var back=(home-stage).normalized();var side=back.orthogonal();var index=int(item.index)
	var desired=(stage+side*float(index%7-3)*spacing+back*(float(index/7)*spacing+float(band)*3)).clamp(Vector2.ONE,Vector2(126,126))
	var chosen=desired
	if not c.unit_data(u).air and (not c._ground_fits_size(c._body_size(u),desired) or not c._ground_sweep(c._body_size(u),stage,desired)):
		var found=false
		for ring in range(1,7):
			for turn in range(12):
				var candidate=desired+Vector2.from_angle(float(turn)*TAU/12)*float(ring)*.5
				if c._ground_fits_size(c._body_size(u),candidate) and c._ground_sweep(c._body_size(u),stage,candidate):chosen=candidate;found=true;break
			if found:break
		if not found:chosen=stage
	item.origin=ACData.packed(stage);item.pos=ACData.packed(chosen);item.spacing=spacing;return chosen

static func combat_power(c,e: Dictionary) -> float:
	var d=c.unit_data(e)
	var damage=float(d.get("damage",24 if e.has("progress") else 0))
	if str(d.get("role",""))=="carrier":damage=25
	return sqrt(maxf(0,float(e.hp)+float(e.get("shield",0)))*maxf(0,damage)/maxf(.2,float(d.get("period",1))))*(1.2 if e.has("progress") else 1.0)

static func ranged_kite(c,owner: int,army: Array,visible: Array,wave: Array,defend: bool) -> void:
	if int(c.players[owner].difficulty)!=5 or army.is_empty():return
	if c.bot_planning_owner==owner and not c.bot_action_budget.available(owner):return
	var p: Dictionary=c.players[owner];var cursor=int(p.get("_ai_kite_cursor",0))%army.size()
	for offset in range(army.size()):
		var index=(cursor+offset)%army.size();var u: Dictionary=army[index];var d=c.unit_data(u)
		if not defend and not int(u.id) in wave:continue
		if d.air or float(d.range)<3 or u.anchored or u.container>=0 or not u.get("channel",{}).is_empty() or int(u.get("burst_left",0))>0:continue
		if float(u.cooldown)<=.28 or c.time-float(u.fired)<.16 or c.time<float(u.get("_ai_kite_next",0)) or float(u.get("rooted_until",0))>c.time:continue
		if float(u.hp)<float(d.hp)*.38 and c.time-float(u.damaged)<5:continue
		var closest: Dictionary={};var distance=minf(3.4,float(d.range)*.75)
		for enemy in visible:
			if enemy.has("progress") or enemy.hp<=0 or not c._can_attack(c.unit_data(enemy),u):continue
			var ed=c.unit_data(enemy)
			if float(ed.damage)<=0 or float(ed.range)>1.5:continue
			var gap=c.center(u).distance_to(c.center(enemy))
			if gap<distance:distance=gap;closest=enemy
		if closest.is_empty():continue
		var away=(c.center(u)-c.center(closest)).normalized()
		if away.length_squared()<.01:continue
		for angle in [0,.55,-.55]:
			var destination=c.center(u)+away.rotated(angle)*1.4
			if not c._ground_sweep(c._body_size(u),c.center(u),destination) or not c._unit_fits(u,destination,false):continue
			if c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(destination)})=="":
				u._ai_kite_until=c.time+.28;u._ai_kite_next=c.time+.65;p._ai_kite_cursor=(index+1)%army.size();TACTICS.log_action(p,"micro:kite")
			return

static func assault_group(c,fighters: Array,minimum: int,radius: float,minimum_population: float=0) -> Array:
	if fighters.size()<minimum:return []
	var points=fighters.map(func(u):return c.center(u));var best=[];var best_population=-1.0
	var stride=maxi(1,floori(fighters.size()/16.0))
	for index in range(0,fighters.size(),stride):
		var group=[]
		for other in range(fighters.size()):
			if points[index].distance_squared_to(points[other])<=radius*radius:group.append(fighters[other])
		var population=group.reduce(func(sum,u):return sum+float(c.unit_data(u).pop),0.0)
		if group.size()>=minimum and population>=minimum_population and (population>best_population or is_equal_approx(population,best_population) and group.size()>best.size()):best=group;best_population=population
	return best if best.size()>=minimum else []

static func combat_cohort_size(c,owner: int,army: Array,profile: Dictionary,wave: Array) -> int:
	if int(c.players[owner].difficulty)!=5:return int(profile.attack)
	var fighters=army.filter(func(u):return u.hp>0 and (float(c.unit_data(u).damage)>0 or c.unit_data(u).role=="carrier"))
	if fighters.is_empty():return 6
	var average=fighting_population(c,fighters)/fighters.size()
	var standing=fighting_population(c,fighters.filter(func(u):return int(u.id) in wave))
	return clampi(ceili((6.0 if standing>=16 else 10.0)/maxf(.5,average)),4,12)

static func decisive_assault(c,owner: int,army: Array,goal: Vector2,wave: Array,defend: bool) -> Dictionary:
	var p: Dictionary=c.players[owner];var level=clampi(int(p.difficulty),0,5)
	var active=c.time<float(p.get("_ai_decisive_until",0))
	if level<3 or defend or not str(p.get("_ai_goal_reason","")) in ["visible_enemy","remembered_enemy"]:return {"active":false,"wave":wave}
	if c.time<float(p.get("_ai_decisive_check_at",0)):return {"active":active,"wave":wave}
	var fighters=army.filter(func(u):
		var d=c.unit_data(u)
		return u.hp>0 and u.container<0 and not int(u.id) in wave and u.get("channel",{}).is_empty() and float(u.get("self_repair_until",0))<=c.time and (float(d.damage)>0 and "g" in str(d.targets) or d.role=="carrier" and not u.get("drones",[]).is_empty()))
	if not active:
		p._ai_decisive_check_at=c.time+10
		var proactive=[0,0,0,720,600,480][level]
		if level>=4 and float(p.used)+float(p.reserved)>=160:proactive=minf(proactive,300)
		var stalemate=c.time>=proactive-120 and c.time-float(p.get("_ai_last_commit",p.get("_ai_first_enemy_seen",c.time)))>=90
		if c.time<float(p.get("_ai_decisive_next",0)) or c.time<proactive and not stalemate:return {"active":false,"wave":wave}
	# Count real fighting supply: a few heavy units can constitute a main
	# force, while a handful of cheap half-supply units cannot replace one.
	var group=assault_group(c,fighters,3,14 if active else 18,4 if active else 12)
	if group.is_empty():return {"active":active,"wave":wave}
	var center=Vector2.ZERO
	for u in group:center+=c.center(u)
	center/=group.size()
	var companions=army.filter(func(u):return u.hp>0 and not int(u.id) in wave and not u in group and u.get("channel",{}).is_empty() and c.unit_data(u).role in ["medic","priest","healer_detector","detector"] and c.center(u).distance_squared_to(center)<=324)
	var ids=(group+companions).map(func(u):return int(u.id))
	if c.command(owner,{"type":"attack_move","ids":ids,"pos":ACData.packed(goal),"formation":true})!="":
		p._ai_decisive_check_at=c.time+.5;return {"active":active,"wave":wave}
	var combined=wave.duplicate()
	for id in ids:
		if not id in combined:combined.append(id)
	if not active:p._ai_decisive_until=c.time+150;p._ai_decisive_next=c.time+180
	p._ai_decisive_check_at=c.time+6;p._ai_last_commit=c.time;p._ai_has_attacked=true;p._ai_wave_goal=ACData.packed(goal);p._ai_wave_size=combined.size()
	TACTICS.log_action(p,"attack:decisive_reinforce" if active else "attack:decisive")
	return {"active":true,"wave":combined}

static func combat(c,owner: int,army: Array,bases: Array,visible: Array,profile: Dictionary) -> void:
	var p: Dictionary=c.players[owner];var home: Vector2=c.center(bases[0])
	var plan=TACTICS.plan_for(p)
	army=army.filter(func(u):return int(u.get("container",-1))<0 and not (c.unit_data(u).role=="transport" and not c.unit_data(u).air))
	var target: Dictionary={};var defend=false;var distance=INF;var home_threats=[];var local_defenders=[]
	for enemy in visible:
		if not plan.is_empty():
			var ed=c.unit_data(enemy)
			var dangerous=(int(enemy.kind) in ([10,11] if int(enemy.race)==1 else [11,12])) if enemy.has("progress") else float(ed.damage)>0 or ed.role=="carrier"
			if not dangerous or not enemy.has("progress") and ed.role=="worker" and not c._team_threat(enemy,owner):continue
			if not enemy.has("progress") and ed.role!="carrier" and not "g" in str(ed.targets):continue
		for hq in bases:
			var d: float=c.center(enemy).distance_to(c.center(hq))
			if d<18:
				if not enemy in home_threats:home_threats.append(enemy)
				if d<distance:distance=d;target=enemy;defend=true
	if defend and not plan.is_empty() and int(p.difficulty)>=3 and army.size()>=6:
		var danger=home_threats.reduce(func(sum,e):return sum+combat_power(c,e),0.0)
		var available=army.filter(func(u):return int(u.get("_ai_expendable_owner",-1))!=owner and float(c.unit_data(u).damage)>0 and not c.unit_data(u).role in ["transport","carrier_drone"] and u.get("channel",{}).is_empty() and float(u.get("self_repair_until",0))<=c.time and home_threats.any(func(e):return c._can_attack(c.unit_data(u),e)))
		var strength=available.reduce(func(sum,u):return sum+combat_power(c,u),0.0)
		if strength>=danger*1.4:
			var defense_point=c.center(target);var old_guard: Array=p.get("_ai_local_defense",[])
			available.sort_custom(func(a,b):return c.center(a).distance_to(defense_point)/maxf(.8,float(c.unit_data(a).speed))+(5 if int(a.id) in p.get("_ai_wave",[]) else 0)<c.center(b).distance_to(defense_point)/maxf(.8,float(c.unit_data(b).speed))+(5 if int(b.id) in p.get("_ai_wave",[]) else 0))
			var group=[];var assigned=0.0
			for u in available:
				if group.size()>=maxi(3,ceili(army.size()*.45)) or assigned>=danger*1.35 and group.size()>=2:break
				group.append(int(u.id));assigned+=combat_power(c,u)
			if assigned>=danger*1.35:
				var orders=group.filter(func(id):
					var u=c.entity(int(id))
					return not int(id) in old_guard or u.order in ["idle","hold"] or u.order=="move" or u.order=="attack_move" and ACData.point(u.goal).distance_squared_to(defense_point)>9)
				if orders.is_empty() or c.command(owner,{"type":"attack_move","ids":orders,"pos":ACData.packed(defense_point),"formation":true})=="":
					local_defenders=group;defend=false;target={};distance=INF
					if not orders.is_empty():TACTICS.log_action(p,"defend:detachment")
	if defend and not plan.is_empty() and army.size()>=8 and home_threats.size()==1:
		var ed=c.unit_data(target)
		var severe=target.has("progress") or ed.role in ["siege","fortress","tree","capital","carrier","mage","parasite","stealth"]
		if not severe:
			var defenders=army.filter(func(u):return int(u.get("_ai_expendable_owner",-1))!=owner and c._can_attack(c.unit_data(u),target) and float(c.unit_data(u).damage)>0)
			defenders.sort_custom(func(a,b):return c.center(a).distance_squared_to(c.center(target))<c.center(b).distance_squared_to(c.center(target)))
			local_defenders=defenders.slice(0,3).map(func(u):return int(u.id))
			for id in local_defenders:
				var unit=c.entity(int(id))
				if unit.order!="attack" or int(unit.target)!=int(target.id):c.command(owner,{"type":"attack","ids":[id],"target":target.id});TACTICS.log_action(p,"defend:local")
			defend=false;target={};distance=INF
	p._ai_local_defense=local_defenders
	if not defend:
		for enemy in visible:
			if not local_defenders.is_empty() and enemy in home_threats:continue
			var score=c.center(enemy).distance_to(home)-(80 if enemy.has("progress") and int(enemy.kind)==0 else 0)
			if enemy.has("progress") and score<distance:distance=score;target=enemy
	var goal: Vector2
	var guarded=home_threats.map(func(e):return int(e.id)) if not local_defenders.is_empty() else []
	var remembered=p.get("_ai_sightings",{}).values().any(func(item):return item.building and not int(item.id) in guarded)
	if not target.is_empty():goal=c.center(target);p._ai_goal_reason="visible_enemy"
	elif remembered and not plan.is_empty():goal=MISSIONS.remembered_goal(c,owner,plan,home,guarded);p._ai_goal_reason="remembered_enemy"
	else:goal=preload("res://scripts/bot_recon.gd").army_goal(c,owner,army,home,visible)
	var search_rest=not defend and str(p.get("_ai_goal_reason",""))=="regroup_after_search"
	var rally: Vector2=c.map.nearest_free(home+(Vector2(63.5,63.5)-home).normalized()*7)
	if not plan.is_empty():rally=home_assembly(c,p,army,rally,home)
	var reserved=[]
	var full_army=army.duplicate()
	if not plan.is_empty():
		reserved=MISSIONS.before_combat(c,owner,army,plan,home,goal,visible,defend)
		reserved.append_array(local_defenders)
		army=army.filter(func(u):return not int(u.id) in reserved and c.unit_data(u).role!="transport" and c.unit_data(u).role!="carrier_drone")
	var wave: Array=p.get("_ai_wave",[]).filter(func(id):
		var u=c.entity(int(id))
		return not u.is_empty() and u.hp>0 and int(u.owner)==owner and int(u.container)<0 and not int(u.id) in reserved)
	var decisive=decisive_assault(c,owner,army,goal,wave,defend)
	wave=decisive.wave
	if defend or search_rest or (not decisive.active and not p.get("_ai_wave",[]).is_empty() and wave.size()<maxi(3,ceili(int(p.get("_ai_wave_size",0))*.5))):
		wave=[];p._ai_cohort=[]
	var attack=not wave.is_empty()
	var old_stage=ACData.point(p.get("_ai_stage_pos",[-999,-999]))
	if not p.has("_ai_stage_goal") or ACData.point(p._ai_stage_goal).distance_squared_to(goal)>36:old_stage=Vector2.INF
	var stage=rally if defend else forward_staging(c,army,home,goal,visible,old_stage)
	if not plan.is_empty() and stage.distance_squared_to(home)<.01:stage=rally
	# Form a complete home cohort before travelling to forward assembly.
	# New recruits wait for their own cohort, even after scouting changes the
	# target. This prevents individual units feeding along a hundred-tile route.
	var marching: Array=p.get("_ai_marching",[]).filter(func(id):return army.any(func(u):return int(u.id)==int(id) and not int(id) in wave))
	if defend or search_rest:marching=[]
	p._ai_stage_pos=ACData.packed(stage);p._ai_stage_goal=ACData.packed(goal)
	p._ai_stage_spacing=1.65
	for u in army:p._ai_stage_spacing=maxf(float(p._ai_stage_spacing),maxf(c._body_size(u).x,c._body_size(u).y)+.25)
	if p.has("_ai_stage_slots"):
		for id in p._ai_stage_slots.keys():
			if not army.any(func(u):return int(u.id)==int(id)):p._ai_stage_slots.erase(id)
	var slots={}
	for u in army:
		if int(u.id) not in wave:slots[int(u.id)]=staging_slot(c,p,u,rally if not plan.is_empty() and not int(u.id) in marching else stage,home)
	# Elapsed time is not a reason to demand a bigger recovery cohort. That
	# requirement trapped depleted armies at home after the ten-minute mark.
	var threshold=combat_cohort_size(c,owner,army,profile,wave)
	if not defend and not search_rest and not decisive.active:
		var pool=army.filter(func(u):return int(u.id) not in wave and (float(c.unit_data(u).damage)>0 or c.unit_data(u).role=="carrier" and not u.get("drones",[]).is_empty()) and not (u.hp<float(c.unit_data(u).hp)*float(profile.retreat) and c.time-float(u.damaged)<5))
		if not plan.is_empty():
			var home_ready=pool.filter(func(u):return not int(u.id) in marching and assembly_ready(c,u,slots[int(u.id)]))
			if home_ready.size()>=threshold:
				var group=army.filter(func(u):return not int(u.id) in wave and not int(u.id) in marching and assembly_ready(c,u,slots[int(u.id)]))
				for u in group:marching.append(int(u.id));slots[int(u.id)]=staging_slot(c,p,u,stage,home)
				TACTICS.log_action(p,"stage:cohort_depart")
			pool=pool.filter(func(u):return int(u.id) in marching)
			# A formed group may lose members en route. A remnant below a real
			# fighting quorum returns to regroup instead of waiting forever.
			var minimum=maxi(3,floori(threshold*float(profile.assembly)))
			if pool.size()<minimum and not marching.is_empty():
				for u in army:
					if int(u.id) in marching:slots[int(u.id)]=staging_slot(c,p,u,rally,home)
				marching=[];pool=[];p.erase("_ai_stage_wait")
		var cohort: Array=p.get("_ai_cohort",[]).filter(func(id):return pool.any(func(u):return int(u.id)==int(id)))
		if cohort.size()<threshold and pool.size()>=threshold:
			pool.sort_custom(func(a,b):return c.center(a).distance_squared_to(stage)<c.center(b).distance_squared_to(stage))
			cohort=pool.slice(0,threshold).map(func(u):return int(u.id))
		p._ai_cohort=cohort
		# Launch any full, physically assembled cohort. A blocked older member
		# must not stall a ready replacement group while it finds a new route.
		var ready_pool=pool.filter(func(u):return assembly_ready(c,u,slots[int(u.id)]))
		if ready_pool.size()>=threshold:
			cohort=ready_pool.slice(0,threshold).map(func(u):return int(u.id));p._ai_cohort=cohort
		var ready=cohort.filter(func(id):return assembly_ready(c,c.entity(int(id)),slots[int(id)]))
		var survivors_ready=false
		if not plan.is_empty():
			var minimum=maxi(3,floori(threshold*float(profile.assembly)))
			if ready_pool.size()>=minimum:
				if not p.has("_ai_stage_wait"):p._ai_stage_wait=c.time
				# Wait for slow members first. After a real wait, an intact
				# surviving quorum can act without feeding single stragglers.
				survivors_ready=c.time-float(p._ai_stage_wait)>=15
			else:p.erase("_ai_stage_wait")
		# Keep the six-unit opening cohort, but consolidate a developed Hell
		# army before its next main assault. Wait only six seconds for nearby
		# formed reinforcements; this never creates a growing time-based quota.
		var launch=(cohort.size()>=threshold and ready.size()==cohort.size()) or survivors_ready
		if int(p.difficulty)==5 and wave.is_empty() and army.size()>=18 and pool.size()>=threshold and str(p.get("_ai_goal_reason","")) in ["visible_enemy","remembered_enemy"]:
			var desired=clampi(ceili(army.size()*.4),threshold,18)
			if ready_pool.size()>=threshold:
				if not p.has("_ai_mass_wait"):p._ai_mass_wait=c.time
				launch=ready_pool.size()>=desired or c.time-float(p._ai_mass_wait)>=6
			else:launch=false;p.erase("_ai_mass_wait")
		else:p.erase("_ai_mass_wait")
		# Arrive in front of the enemy before committing. Late/slow units stay
		# with the next cohort instead of individually following a departed wave.
		if launch:
			var departing=[]
			for u in army:
				if int(u.id) not in wave and (plan.is_empty() or int(u.id) in marching) and assembly_ready(c,u,slots[int(u.id)]):departing.append(int(u.id))
			if not departing.is_empty() and c.command(owner,{"type":"attack_move","ids":departing,"pos":ACData.packed(goal),"formation":true})=="":
				wave.append_array(departing)
				p._ai_wave_size=wave.size();p._ai_has_attacked=true;attack=true;p._ai_cohort=[];p.erase("_ai_stage_wait");p.erase("_ai_mass_wait")
				p._ai_wave_goal=ACData.packed(goal);p._ai_last_commit=c.time;TACTICS.log_action(p,"attack:commit")
				for id in departing:p._ai_stage_slots.erase(int(id));marching.erase(int(id))
	if attack and ACData.point(p.get("_ai_wave_goal",ACData.packed(goal))).distance_squared_to(goal)>9:
		if c.command(owner,{"type":"attack_move","ids":wave,"pos":ACData.packed(goal),"formation":true})=="":p._ai_wave_goal=ACData.packed(goal)
	p._ai_wave=wave
	p._ai_marching=marching
	p._ai_attack_phase="defend" if defend else "regroup" if search_rest else "decisive" if decisive.active and attack else "push" if attack else "assemble"
	if TACTICS.ARA.escort(c,owner,army,visible,wave,goal,defend):TACTICS.log_action(p,"ara:escort")
	if TACTICS.ARA.flank(c,owner,army,wave,home,goal,defend):TACTICS.log_action(p,"ara:flank")
	COMBAT_POLICY.spread(c,owner,army,visible,wave,defend)
	ranged_kite(c,owner,army,visible,wave,defend)
	var focus_groups={};var focus_load={};var splash_clusters={}
	var cursor=int(p.get("_ai_micro_cursor",0))%maxi(1,army.size())
	var command_army=army.slice(cursor)+army.slice(0,cursor)
	p._ai_micro_cursor=(cursor+1)%maxi(1,army.size())
	for u in command_army:
		var d=c.unit_data(u)
		if c.time<float(u.get("_ai_kite_until",0)):continue
		if plan.is_empty() and int(p.difficulty)>=2 and d.role=="parasite" and float(u.energy)>=200 and float(u.ability_cd)<=0:
			var choice: Dictionary={};var value=-1.0
			for enemy in visible:
				if enemy.has("progress") or enemy.hp<=0 or enemy.get("technical",false) or enemy.get("container",-1)>=0 or not enemy.get("cargo",[]).is_empty() or c.allied(owner,int(enemy.owner)):continue
				if c.center(u).distance_squared_to(c.center(enemy))>36:continue
				var ed=c.unit_data(enemy);var worth=float(ed.get("as",0))+float(ed.get("tera",0))*1.5
				if worth>value:value=worth;choice=enemy
			if not choice.is_empty():c._mind_control(u,int(choice.id))
		if plan.is_empty() and int(p.difficulty)>=2 and int(u.race)==0 and int(u.kind)==7 and not u.get("cloak_active",false) and float(u.energy)>=30 and (attack or c.time-float(u.damaged)<5):c._ability(u,c.center(u))
		if not d.air and d.role=="transport":continue
		if float(u.hp)<float(d.hp)*(minf(.12,float(profile.retreat)) if decisive.active else float(profile.retreat)) and c.time-float(u.damaged)<5:
			# A recovered straggler rejoins staging instead of walking back into
			# the departed wave alone when its short damage timer expires.
			wave.erase(int(u.id))
			if u.order!="move" or ACData.point(u.goal).distance_squared_to(rally)>1:c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(rally)})
			continue
		if plan.is_empty() and int(p.difficulty)>=2 and d.role=="mage" and not target.is_empty() and c.center(u).distance_to(goal)<float(d.range)+2:c._ability(u,goal)
		if (defend or int(u.id) in wave) and bool(profile.get("focus",false)) and float(d.damage)>0:
			var focus: Dictionary={};var score=INF
			for enemy in visible:
				if not c._can_attack(d,enemy) or c.center(u).distance_to(c.center(enemy))>maxf(7,float(d.range)+2):continue
				var value=COMBAT_POLICY.target_score(c,u,enemy,visible,splash_clusters)
				if not is_finite(value):continue
				if float(focus_load.get(int(enemy.id),0))>=float(enemy.hp)+float(enemy.get("shield",0)):value+=1000
				if int(p.difficulty)==5 and not enemy.has("progress"):
					if c.unit_data(enemy).role in ["medic","priest","healer_detector","mage","siege","parasite"]:value*=.5
					if int(u.target)==int(enemy.id):value*=.8
				if value<score:score=value;focus=enemy
			if not focus.is_empty():
				var target_id=int(focus.id)
				focus_load[target_id]=float(focus_load.get(target_id,0))+maxf(1,float(d.damage))
				if u.order!="attack" or int(u.target)!=target_id:
					if not focus_groups.has(target_id):focus_groups[target_id]=[]
					focus_groups[target_id].append(int(u.id))
				continue
		if attack and int(u.id) in wave:
			if u.order in ["idle","hold"]:c.command(owner,{"type":"attack_move","ids":[u.id],"pos":ACData.packed(goal)})
			continue
		if defend:
			if u.order in ["idle","hold","move"] or ACData.point(u.goal).distance_squared_to(goal)>9:c.command(owner,{"type":"attack_move","ids":[u.id],"pos":ACData.packed(goal)})
			continue
		if not plan.is_empty() and float(d.damage)>0:
			# Travelling toward an assembly point is not permission to ignore an
			# enemy wave already shooting the cohort. Fight locally, then regroup.
			var threats=visible.filter(func(e):return not e.has("progress") and c._can_attack(d,e) and (float(c.unit_data(e).damage)>0 or c.unit_data(e).role=="carrier") and c.center(u).distance_to(c.center(e))<maxf(6,float(d.range)+1.5))
			if not threats.is_empty():
				threats.sort_custom(func(a,b):return c.center(u).distance_squared_to(c.center(a))<c.center(u).distance_squared_to(c.center(b)))
				if u.order!="attack" or int(u.target)!=int(threats[0].id):c.command(owner,{"type":"attack","ids":[u.id],"target":threats[0].id})
				continue
		var destination: Vector2=slots[int(u.id)]
		if assembly_ready(c,u,destination):
			if u.order!="hold":c.command(owner,{"type":"hold","ids":[u.id],"pos":ACData.packed(destination)})
		elif u.order!="move" or ACData.point(u.goal).distance_squared_to(destination)>.25:
			c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(destination)})
	# One physical group command is one action. Batch a common focus target
	# instead of exhausting the APM budget ordering identical attacks per unit.
	for target_id in focus_groups:c.command(owner,{"type":"attack","ids":focus_groups[target_id],"target":target_id})
	if not plan.is_empty():
		MISSIONS.after_combat(c,owner,army,plan,visible,home,goal,defend)
		var workers=c.units.filter(func(u):return int(u.owner)==owner and u.hp>0 and int(u.kind)==0)
		if not defend:MISSIONS.forward_build(c,owner,workers,plan,stage)
		SKILLS.tick(c,owner,full_army,visible,plan,attack or defend or not local_defenders.is_empty(),goal)
