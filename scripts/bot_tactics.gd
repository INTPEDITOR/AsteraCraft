extends RefCounted
## Approved army plans. Only visible sightings enter short-lived enemy memory.
static var content: Dictionary={}
static var by_id: Dictionary={}
const LEARNING=preload("res://scripts/bot_tactic_learning.gd")
const ARA=preload("res://scripts/bot_ara_policy.gd")

static func catalog() -> Array:
	if content.is_empty():
		content=JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_tactics.json"))
		for plan in content.plans:
			for key in ["primary","support","payload"]:plan[key]=plan[key].map(func(value):return int(value))
			by_id[str(plan.id)]=plan
	return content.plans

static func plan_for(p: Dictionary) -> Dictionary:
	catalog();return by_id.get(str(p.get("_ai_tactic","")),{})

static func repertoire(race: int,level: int) -> Array:
	return catalog().filter(func(t):return int(t.race)==race and int(t.min_level)<=level)

static func observe(c,owner: int,visible: Array) -> void:
	var p: Dictionary=c.players[owner];var memory: Dictionary=p.get("_ai_sightings",{})
	for e in visible:
		if e.hp<=0 or c.allied(owner,int(e.owner)) or not c.can_see(owner,e):continue
		if not p.has("_ai_confirmed_races"):p._ai_confirmed_races={}
		p._ai_confirmed_races[int(e.owner)]=int(e.race)
		if not p.has("_ai_first_race_seen"):p._ai_first_race_seen=c.time
		var d=c.unit_data(e);var building=e.has("progress")
		memory[int(e.id)]={"id":int(e.id),"owner":int(e.owner),"race":int(e.race),"kind":int(e.kind),"pos":ACData.packed(c.center(e)),"seen":c.time,"building":building,"air":false if building else bool(d.air),"role":"building" if building else str(d.role),"armor_class":str(d.get("armor_class","light")),"value":float(d.get("as",0))+float(d.get("tera",0))*1.5,"pop":0 if building else float(d.pop),"cloak":not building and c.is_cloaked(e)}
		if building:memory[int(e.id)].vision_pos=ACData.packed(c.footprint(e).get_center())
		elif ACData.can_deploy(d):memory[int(e.id)].anchored=bool(e.anchored)
		if building and int(e.kind)==0 and not p.has("_ai_first_enemy_seen"):p._ai_first_enemy_seen=c.time
	var ttl=[25,40,60,90,120,150][clampi(int(p.difficulty),0,5)]
	for id in memory.keys():
		var item: Dictionary=memory[id]
		# A stationary structure remains known until sight disproves it. Unit
		# sightings still expire; memory must never expose unseen new entities.
		if c.time-float(item.seen)>ttl and (not item.building or int(p.difficulty)<2):memory.erase(id);continue
		# A building can be disproved only when its remembered location is visible.
		var cell=ACMap.ground_cell(ACData.point(item.get("vision_pos",item.pos)))
		if item.building and c.visibility[owner][cell.y*ACMap.SIZE+cell.x]>0 and not visible.any(func(e):return int(e.id)==int(id)):memory.erase(id)
	p._ai_sightings=memory
	var intel={"air":0.0,"ground":0.0,"heavy":0.0,"light":0.0,"melee":0.0,"workers":0,"cloak":false}
	for item in memory.values():
		if item.building:continue
		var weight=maxf(.5,float(item.pop))
		intel["air" if item.air else "ground"]+=weight
		intel["heavy" if item.armor_class=="heavy" else "light"]+=weight
		if item.role in ["assault","shield","swarm","tank","guardian","stealth"]:intel.melee+=weight
		if item.role=="worker":intel.workers+=1
		if item.cloak:intel.cloak=true
	p._ai_intel=intel
	observe_hidden_fire(c,owner,visible)

static func observe_hidden_fire(c,owner: int,visible: Array) -> void:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<2 or c.time<float(p.get("_ai_hidden_check_at",0)):return
	p._ai_hidden_check_at=c.time+1
	# Only our own received hits and already visible attackers are inspected.
	# An unexplained hit is a suspicion, never an invisible enemy coordinate.
	for u in c.units+c.buildings:
		if int(u.owner)!=owner or u.hp<=0 or c.time-float(u.damaged)>2 or float(u.damaged)<=float(u.get("_ai_last_investigated_hit",-100)):continue
		u._ai_last_investigated_hit=float(u.damaged)
		if visible.any(func(e):
			var d=c.unit_data(e)
			var dangerous=int(e.kind) in ([10,11] if int(e.race)==1 else [11,12]) if e.has("progress") else float(d.get("damage",0))>0 or str(d.get("role",""))=="carrier"
			return dangerous and c.center(e).distance_to(c.center(u))<=float(d.get("range",9))+3):continue
		var nearby=c.center(u).distance_to(ACData.point(p.get("_ai_hidden_fire_pos",u.pos)))<12 and c.time-float(p.get("_ai_hidden_fire_at",-100))<8
		p._ai_hidden_fire_hits=int(p.get("_ai_hidden_fire_hits",0))+1 if nearby else 1
		p._ai_hidden_fire_pos=ACData.packed(c.center(u));p._ai_hidden_fire_at=c.time
		if int(p._ai_hidden_fire_hits)>=2:p._ai_detection_until=c.time+45

static func detection_needed(c,owner: int) -> bool:
	var p: Dictionary=c.players[owner]
	return int(p.difficulty)>=2 and (bool(p.get("_ai_intel",{}).get("cloak",false)) or c.time<float(p.get("_ai_detection_until",0)))

static func activate(c,owner: int,id: String) -> Dictionary:
	catalog();var p: Dictionary=c.players[owner];var plan: Dictionary=by_id.get(id,{})
	if plan.is_empty() or int(plan.race)!=int(p.race) or int(plan.min_level)>int(p.difficulty):return {}
	p._ai_tactic=id;p._ai_plan_started=c.time;p._ai_plan_next=c.time+(75 if int(p.difficulty)==5 else 120)
	p._ai_plan_started_kills=int(p.get("kills",0))
	p.erase("_ai_plan_ready_at")
	p._ai_tech_reserve=[0,0]
	var history: Array=p.get("_ai_tactic_history",[])
	history.append({"id":id,"time":c.time});if history.size()>32:history.pop_front()
	p._ai_tactic_history=history
	return plan

static func choose(c,owner: int,army: Array) -> Dictionary:
	var p: Dictionary=c.players[owner];var current=plan_for(p)
	var intel: Dictionary=p.get("_ai_intel",{})
	var own_aa=army.filter(func(u):return u.hp>0 and (float(c.unit_data(u).damage)>0 and "a" in str(c.unit_data(u).targets) or c.unit_data(u).role=="carrier" and not u.get("drones",[]).is_empty())).reduce(func(sum,u):return sum+float(c.unit_data(u).pop),0.0)
	var urgent=int(p.difficulty)==5 and not current.is_empty() and c.time-float(p.get("_ai_plan_started",0))>=25 and float(intel.get("air",0))>=4 and float(intel.get("air",0))>float(own_aa)*1.6
	var matchup_shift=not current.is_empty() and c.time<480 and LEARNING.basic_transition(c,owner,army) and not LEARNING.preferred(int(p.race),LEARNING.observed_race(c,owner),str(current.id)) and c.time-float(p.get("_ai_plan_started",0))>=75
	if not current.is_empty() and not ARA.response(c,owner).is_empty() and not ARA.counter_plan(current,ARA.response(c,owner)) and c.time-float(p.get("_ai_plan_started",0))>=45:matchup_shift=true
	if not current.is_empty():
		if not p.get("_ai_missions",[]).is_empty() or not urgent and not matchup_shift and c.time<float(p.get("_ai_plan_next",0)):return current
		# Finish a viable opening force before a random advanced plan consumes
		# its tech budget. Observed urgent counters still override the opening.
		if not urgent and not matchup_shift and int(p.difficulty)==5 and not p.get("_ai_has_attacked",false) and c.time<420:return current
		var ready=current.primary.all(func(kind):return army.filter(func(u):return int(u.kind)==int(kind) and u.hp>0).size()>=(1 if ACData.unit(int(p.race),int(kind)).pop>=3 or ACData.unit(int(p.race),int(kind)).role=="transport" else 3))
		if ready and not p.has("_ai_plan_ready_at"):p._ai_plan_ready_at=c.time
		if not urgent and not matchup_shift and c.time-float(p._ai_plan_started)<240 and (not ready or c.time-float(p.get("_ai_plan_ready_at",c.time))<90):return current
		if not urgent and not matchup_shift and not p.get("_ai_has_attacked",false) and c.time-float(p._ai_plan_started)<240:return current
		if not urgent and not matchup_shift and not p.get("_ai_wave",[]).is_empty() and c.time-float(p._ai_plan_started)<210:return current
	var choices=repertoire(int(p.race),int(p.difficulty)).filter(func(t):return float(t.min_time)<=c.time)
	if LEARNING.observed_race(c,owner)<0:
		var scouting_openings=choices.filter(func(t):return int(t.min_level)==0 and not t.transition)
		if not scouting_openings.is_empty():choices=scouting_openings
	if c.time<100:
		var openings=choices.filter(func(t):return int(t.min_level)==0 and not t.transition)
		if not openings.is_empty():choices=openings
	if int(p.difficulty)==5 and c.time<100:choices=choices.filter(func(t):return str(t.id) in ["N1","N2","E1","E3","A1","A2"])
	choices=transition_choices(c,owner,choices,army)
	if urgent:
		var anti_air=choices.filter(func(t):return t.primary.any(func(k):return "a" in str(ACData.unit(int(p.race),int(k)).targets)))
		if not anti_air.is_empty():choices=anti_air
	if choices.is_empty():return current
	var total=0.0;var ranked=[]
	for candidate in choices:
		var weight=selection_weight(c,owner,candidate,army)
		if str(candidate.id)==str(current.get("id","")):weight*=1.3 if int(p.get("kills",0))-int(p.get("_ai_plan_started_kills",0))>=4 and army.size()>=12 else .6
		ranked.append({"plan":candidate,"weight":weight});total+=weight
	var alternatives=ranked.duplicate()
	if int(p.difficulty)==5 and not p.get("_ai_sightings",{}).is_empty():
		var best=ranked.map(func(item):return float(item.weight)).max()
		ranked=ranked.filter(func(item):return float(item.weight)>=float(best)*.4)
		total=ranked.reduce(func(sum,item):return sum+float(item.weight),0.0)
	if int(p.difficulty)>=3 and not urgent and c.rng.randf()<.15:
		var best=alternatives.map(func(item):return float(item.weight)).max()
		ranked=alternatives.filter(func(item):return float(item.weight)>=float(best)*.15)
		total=ranked.reduce(func(sum,item):return sum+float(item.weight),0.0)
	var roll=c.rng.randf()*total
	for item in ranked:
		roll-=float(item.weight)
		if roll<=0:
			if str(item.plan.id)==str(current.get("id","")):p._ai_plan_next=c.time+75;return current
			return activate(c,owner,str(item.plan.id))
	return activate(c,owner,str(ranked[-1].plan.id))

static func transition_choices(c,owner: int,choices: Array,army: Array) -> Array:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<3:return choices
	var bases=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1).size()
	var workers=c.units.filter(func(u):return int(u.owner)==owner and u.hp>0 and int(u.kind)==0).size()
	var strength=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 or c.unit_data(u).role=="carrier" and not u.get("drones",[]).is_empty() else 0),0.0)
	if bases>=2 and workers>=16 and strength>=12:return choices
	if int(p.race)==2 and strength>=12 and not ARA.response(c,owner).is_empty():
		var counters=choices.filter(func(plan):return plan.primary.all(func(kind):return not ACData.unit(2,int(kind)).role in ["capital","carrier"]))
		if not counters.is_empty():return counters
	var reliable=choices.filter(func(plan):
		if str(plan.id) in ["N1","N2","E1","E3","A1","A2"]:return true
		if LEARNING.preferred(int(p.race),LEARNING.observed_race(c,owner),str(plan.id)) and LEARNING.basic_transition(c,owner,army):return true
		return plan.primary.all(func(kind):
			var d=ACData.unit(int(p.race),int(kind))
			return float(d.as)+float(d.tera)*1.5<450 and c.prerequisites(owner,d.requires) and (int(p.race)==1 or c.has_building(owner,int(d.producer)))))
	return reliable if not reliable.is_empty() else choices

static func selection_weight(c,owner: int,plan: Dictionary,army: Array) -> float:
	var p: Dictionary=c.players[owner];var intel: Dictionary=p.get("_ai_intel",{})
	var weight=1.0;var air_power=0.0;var ground_power=0.0;var heavy_bonus=0.0;var light_bonus=0.0
	for kind in plan.primary:
		var d=ACData.unit(int(p.race),int(kind));var damage=float(d.damage)
		if d.role=="carrier":damage=25
		if "a" in str(d.targets) or d.role=="carrier":air_power+=damage
		if "g" in str(d.targets) or d.role=="carrier":ground_power+=damage
		heavy_bonus+=float(d.get("bonus_heavy",0));light_bonus+=float(d.get("bonus_light",0))
	if int(p.difficulty)>=2:
		var air=float(intel.get("air",0));var ground=float(intel.get("ground",0))
		if air>ground and air>2:weight*=4.0 if air_power>0 else .2
		if ground>air and ground>2:weight*=1.8 if ground_power>0 else .3
		if float(intel.get("melee",0))>5 and str(plan.style) in ["siege","caster","suicide"]:weight*=2.0
		if float(intel.get("heavy",0))>float(intel.get("light",0))+2:weight*=1.0+minf(2,heavy_bonus*.15)
		if float(intel.get("light",0))>float(intel.get("heavy",0))+2:weight*=1.0+minf(2,light_bonus*.2)
		if int(intel.get("workers",0))>=4 and str(plan.style) in ["raid","air_raid","drop","split_raid"]:weight*=1.6
		if bool(intel.get("cloak",false)) and plan.support.any(func(k):return ACData.unit(int(p.race),int(k)).role in ["detector","healer_detector"]):weight*=1.8
	var existing=0
	for u in army:
		if int(u.kind) in plan.primary:existing+=1
	weight*=1.0+minf(2.0,existing*.12)
	var capital=plan.primary.any(func(k):
		var unit=ACData.unit(int(p.race),int(k))
		return float(unit.as)+float(unit.tera)*1.5>=450)
	if capital:
		var bases=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1).size()
		var line=army.filter(func(u):return u.hp>0 and (float(c.unit_data(u).damage)>3 or c.unit_data(u).role=="carrier" and not u.get("drones",[]).is_empty())).size()
		if bases<2 or line<12:weight*=.15
	if int(p.race)==0 and 12 in plan.primary+plan.support:weight*=.2 if preload("res://scripts/bot_fortress_policy.gd").favorable(c,owner,army.size()) else .05
	return maxf(.01,weight*LEARNING.weight(c,owner,plan)*ARA.choice_weight(c,owner,plan))

static func building_chain(race: int,kind: int,result: Array,visiting: Array=[]) -> void:
	if kind==0 or kind in result or kind in visiting:return
	visiting.append(kind)
	for required in ACData.building(race,kind).requires:building_chain(race,int(required),result,visiting.duplicate())
	result.append(kind)

static func build_order(race: int,plan: Dictionary) -> Array:
	var result=[];building_chain(race,2,result)
	var kinds: Array=plan.get("primary",[]).duplicate();kinds.append_array(plan.get("support",[]))
	# Secure the actual fighting line before expensive support-caster tech.
	# E15/E16 otherwise completed the parasite branch and bought several
	# fragile casters while their heavy infantry/air cover was still locked.
	var support_roles=["parasite","medic","priest","healer_detector","detector","transport"]
	kinds=kinds.filter(func(k):return not ACData.unit(race,int(k)).role in support_roles)+kinds.filter(func(k):return ACData.unit(race,int(k)).role in support_roles)
	# Keep an affordable opening army while working toward a capital/air plan.
	building_chain(race,4 if race==1 else 3,result)
	if kinds.any(func(k):return float(ACData.unit(race,int(k)).tera)>0):building_chain(race,1,result)
	if race==0 and plan.get("_ai_bio",false):building_chain(race,7,result)
	for kind in kinds:
		var d=ACData.unit(race,int(kind))
		if race!=1:building_chain(race,int(d.producer),result)
		for required in d.requires:building_chain(race,int(required),result)
	return result

static func developed_plan(c,owner: int,source: Dictionary,army: Array) -> Dictionary:
	if source.is_empty():return source
	source=LEARNING.composition(c,owner,source)
	source=ARA.compose(c,owner,source,army)
	if source.get("_ai_ara_recovery",false):return source
	var p: Dictionary=c.players[owner];var level=clampi(int(p.difficulty),0,5)
	if level<2 or c.time<[0,0,210,150,105,75][level]:return source
	# A melee opening is an opening, not permission to keep an unsupported
	# shield/guardian/swarm army for the rest of the match. Retain its role,
	# then unlock a real firing line and later siege through normal buildings.
	var race=int(p.race)
	if source.get("_ai_mech",false) or source.has("_ai_opening_matchup"):return source
	if race==1 and level>=3 and c.time>=120:
		source=source.duplicate(true)
		if not 10 in source.primary and not 10 in source.support:source.support.push_front(10)
		source.weights["10"]=maxf(5,float(source.weights.get("10",0)))
		if not 2 in source.primary and not 2 in source.support:source.support.append(2)
		source.weights["2"]=maxf(6,float(source.weights.get("2",0)))
	var ground_line=source.primary.any(func(kind):return not ACData.unit(race,int(kind)).air and float(ACData.unit(race,int(kind)).damage)>0 and "g" in str(ACData.unit(race,int(kind)).targets))
	if not ground_line or source.drop or not str(source.style) in ["line","rush","siege"]:return source
	var plan=source.duplicate(true);var ranged=1 if race==0 else 2
	var melee=plan.primary.any(func(kind):return float(ACData.unit(race,int(kind)).range)<2)
	if melee:
		if not ranged in plan.primary and not ranged in plan.support:plan.support.append(ranged)
		plan.weights[str(ranged)]=maxf(6,float(plan.weights.get(str(ranged),0)))
		for kind in plan.primary:
			if float(ACData.unit(race,int(kind)).range)<2:plan.weights[str(kind)]=minf(4,float(plan.weights.get(str(kind),4)))
	if level>=3 and int(source.stage)<=1 and c.time>=[0,0,600,420,300,240][level]:
		var siege=[5,6,8][race]
		if not siege in plan.primary and not siege in plan.support:plan.support.append(siege)
		plan.weights[str(siege)]=maxf(3,float(plan.weights.get(str(siege),0)))
	return plan

static func prepare(c,owner: int,plan: Dictionary,army: Array) -> void:
	var p: Dictionary=c.players[owner];p._ai_tech_reserve=[0,0]
	if not c.units.any(func(u):return int(u.owner)==owner and int(u.kind)==0 and u.hp>0 and u.container<0 and not u.get("_ai_scouting",false) and not u.order in ["construct","build_move"]):return
	var combatants=army.filter(func(u):return float(c.unit_data(u).damage)>0).size()
	var population=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 else 0),0.0)
	var opening=build_order(int(p.race),plan).slice(0,3)
	for kind in build_order(int(p.race),plan):
		if c.has_building(owner,int(kind)):continue
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==int(kind)):return
		if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==int(kind)):return
		var d=ACData.building(int(p.race),int(kind))
		var basic_mech=int(p.race)==0 and int(kind) in [4,6,9,7] and LEARNING.basic_transition(c,owner,army) or int(p.race)==1 and int(kind) in [5,6,7] and c.time>=150 and combatants>=6
		if int(p.difficulty)>=4 and population<12 and not int(kind) in opening and not basic_mech:return
		if not c.prerequisites(owner,d.requires):return
		if combatants<3 and int(kind) not in [1,2,3,4]:return
		c._ai_build(owner,int(kind))
		var fighting_population=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 else 0),0.0)
		if combatants>=6 and float(fighting_population)>=6 and not c.units.any(func(w):return int(w.owner)==owner and w.order=="build_move" and int(w.build_plan.kind)==int(kind)):
			p._ai_tech_reserve=[float(d.as),float(d.tera)]
		return

static func queued_counts(c,owner: int) -> Dictionary:
	var counts={};var seen_broods={}
	for u in c.units:
		if int(u.owner)==owner and u.hp>0 and not u.get("technical",false):counts[int(u.kind)]=int(counts.get(int(u.kind),0))+1
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0:continue
		for q in b.queue:
			# Linked citrus buildings mirror the same physical morph job. Count
			# that body once, rather than once per nursery showing its queue.
			if q.has("brood"):
				if seen_broods.has(int(q.brood)):continue
				seen_broods[int(q.brood)]=true
			counts[int(q.kind)]=int(counts.get(int(q.kind),0))+maxi(1,int(ACData.unit(int(b.race),int(q.kind)).get("production_count",1)))
	return counts

static func production_score(c,owner: int,plan: Dictionary,kind: int,counts: Dictionary,army_size: int) -> float:
	var p: Dictionary=c.players[owner];var d=ACData.unit(int(p.race),kind)
	var count=int(counts.get(kind,0));var weight=float(plan.weights.get(str(kind),0))
	if kind==0 or d.get("spawn_only",false):return -1
	if int(p.race)==2 and kind==5:
		var front=0
		for own_kind in counts:
			if int(own_kind) in [1,2,7,8,10]:front+=int(counts[own_kind])
		if count>=clampi(ceili(front/10.0),2,6):return -1
	if d.role in ["detector","healer_detector"]:
		var bases=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1).size()
		var cap=3 if bases>=4 and army_size>=48 else 2
		if count>=cap or c.time<float(p.get("_ai_detector_purchase_next",0)) and not (count==0 and detection_needed(c,owner)):return -1
	if int(p.race)==0 and kind==3 and count>=clampi(ceili(army_size/10.0),2,5):return -1
	if int(p.race)==0 and plan.get("_ai_mech",false) and kind in [1,2]:
		var hardware=float(counts.get(5,0))*3+float(counts.get(6,0))*2+float(counts.get(13,0))*2
		var rifle_limit=clampi(ceili(hardware*.2),4,12) if c.has_building(owner,4) else 8
		if float(p.tera)<50 and float(p.as)>=800:rifle_limit=maxi(12,rifle_limit)
		if count>=(rifle_limit if kind==1 else 2):return -1
	if int(p.race)==1 and kind==1 and int(p.difficulty)>=3 and c.time>=90:
		# One ready raid and one replacement detachment, not a front-line flood.
		if count>=24:return -1
		weight=3.0 if count<12 else .8
	if int(p.race)==1 and kind==10 and int(p.difficulty)>=3 and c.time>=150:
		if count>=8:return -1
		weight=maxf(weight,6 if count<4 else 2.5)
	if int(p.race)==1 and kind==4:
		var fighters=0
		for own_kind in counts:
			var own=ACData.unit(1,int(own_kind))
			if int(own_kind)>0 and own.role!="suicide" and float(own.damage)>0 and "g" in str(own.targets):fighters+=int(counts[own_kind])
		if fighters<6 or count>=clampi(ceili(fighters/8.0),1,4):return -1
		weight=minf(2.5,weight)
	if int(p.race)==0 and kind==2 and count>=4:return -1
	if int(p.race)==0 and kind==12:
		if count>=1 or not preload("res://scripts/bot_fortress_policy.gd").favorable(c,owner,army_size):return -1
		weight=minf(weight,.15)
	# A gas-heavy plan must not leave thousands of real As idle. These
	# reinforcements spend no Tera and do not consume the gas being saved.
	if int(p.difficulty)>=2 and (float(p.as)>=800 or float(p.as)>=400 and float(p.tera)<75) and float(d.tera)==0 and float(d.damage)>0 and "g" in str(d.targets):weight=maxf(weight,5)
	var known_base=p.get("_ai_sightings",{}).values().any(func(item):return item.building and int(item.kind)==0)
	var known_air=float(p.get("_ai_intel",{}).get("air",0))
	if int(p.difficulty)>=2 and d.air and "a" in str(d.targets) and not "g" in str(d.targets):
		# Air superiority does not destroy a headquarters. Retain a real
		# escort proportional to observed aircraft, then fund ground damage.
		var escort=maxi(2 if int(p.difficulty)>=4 else 1,ceili(known_air/maxf(1,float(d.pop))))
		if count>=escort:return -1
	if int(p.difficulty)>=2 and float(d.damage)>0 and "g" in str(d.targets):
		var ground=0
		for own_kind in counts:
			if int(own_kind)==0:continue
			var own=ACData.unit(int(p.race),int(own_kind))
			if float(own.damage)>0 and "g" in str(own.targets):ground+=int(counts[own_kind])
		var primary_ground=plan.get("primary",[]).any(func(k):return float(ACData.unit(int(p.race),int(k)).damage)>0 and "g" in str(ACData.unit(int(p.race),int(k)).targets) or ACData.unit(int(p.race),int(k)).role=="carrier")
		if (not primary_ground or known_base and army_size>=6 and ground<maxi(6,ceili(army_size*.5))) and kind==(1 if int(p.race)==0 else 2):weight=maxf(weight,6)
	if weight<=0:
		if detection_needed(c,owner) and d.role in ["detector","healer_detector"]:weight=4
		elif int(p.difficulty)>=3 and kind in [1,2] and (army_size<12 or not plan.primary.any(func(primary):return c.prerequisites(owner,ACData.unit(int(p.race),int(primary)).requires))):weight=3 if kind==(1 if int(p.race)==0 else 2) else 1.5
		elif army_size<6 and kind in [1,2]:weight=.15
		elif float(p.get("_ai_intel",{}).get("air",0))>2 and "a" in str(d.targets):weight=.7
		else:return -1
	if d.role=="transport":
		if not plan.drop or count>=maxi(1,mini(3,army_size/8)) or army_size<3:return -1
	elif d.role=="parasite":
		var escorts=0
		for own_kind in counts:
			var own=ACData.unit(int(p.race),int(own_kind))
			if int(own_kind)>0 and float(own.damage)>3 and not own.role in ["carrier_drone","brood"]:escorts+=int(counts[own_kind])
		if count>=maxi(1,mini(3,ceili(escorts/6.0))):return -1
	elif d.role in ["detector","healer_detector","medic","priest"]:
		var limit=maxi(1,ceili(army_size/(5.0 if d.role in ["medic","priest"] else 10.0)))
		if d.role=="medic":
			var biological=0
			for own_kind in counts:
				if int(own_kind)>0 and int(own_kind)!=kind and str(ACData.unit(int(p.race),int(own_kind)).get("material",""))=="biological":biological+=int(counts[own_kind])
			limit=clampi(ceili(biological/6.0),1,10)
		if d.role in ["detector","healer_detector"] and detection_needed(c,owner):limit=maxi(2,limit);weight=maxf(4,weight)
		if army_size<3 and not (d.role in ["detector","healer_detector"] and detection_needed(c,owner)) or count>=limit:return -1
	if int(p.race)==0 and kind==7 and str(plan.style)=="nuclear" and count>=2:return -1
	return weight/float(count+1)

static func research_keys(c,owner: int,plan: Dictionary,building: Dictionary,army: Array) -> Array:
	var result=[];var race=int(c.players[owner].race)
	for item in ACResearch.catalog(race,int(building.kind)):
		if item.has("unit_kind") and army.any(func(u):return int(u.kind)==int(item.unit_kind)):result.append(str(item.id))
	for key in plan.skills:
		var d=ACResearch.definition(race,int(building.kind),str(key))
		if not d.is_empty() and not str(key) in result:result.append(str(key))
	if race==2 and 5 in plan.primary and not ACResearch.definition(race,int(building.kind),"judgment_mastery").is_empty():result.append("judgment_mastery")
	result.append_array(["attack","armor","shield"])
	return result

static func log_action(p: Dictionary,key: String,plan_override: String="") -> void:
	if not p.has("_ai_tactic_actions"):p._ai_tactic_actions={}
	p._ai_tactic_actions[key]=int(p._ai_tactic_actions.get(key,0))+1
	if p.get("_ai_trace",false):
		var plan=plan_override if not plan_override.is_empty() else str(p.get("_ai_tactic",""));var history: Dictionary=p.get("_ai_plan_actions",{})
		if not history.has(plan):history[plan]={}
		history[plan][key]=int(history[plan].get(key,0))+1;p._ai_plan_actions=history
