extends RefCounted
## Approved army plans. Only visible sightings enter short-lived enemy memory.
static var content: Dictionary={}
static var by_id: Dictionary={}

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
		var d=c.unit_data(e);var building=e.has("progress")
		memory[int(e.id)]={"id":int(e.id),"owner":int(e.owner),"race":int(e.race),"kind":int(e.kind),"pos":ACData.packed(c.center(e)),"seen":c.time,"building":building,"air":false if building else bool(d.air),"role":"building" if building else str(d.role),"armor_class":str(d.get("armor_class","light")),"value":float(d.get("as",0))+float(d.get("tera",0))*1.5,"pop":0 if building else float(d.pop),"cloak":not building and c.is_cloaked(e)}
		if building and int(e.kind)==0 and not p.has("_ai_first_enemy_seen"):p._ai_first_enemy_seen=c.time
	var ttl=[25,40,60,90,120,150][clampi(int(p.difficulty),0,5)]
	for id in memory.keys():
		var item: Dictionary=memory[id]
		if c.time-float(item.seen)>ttl:memory.erase(id);continue
		# A building can be disproved only when its remembered location is visible.
		var cell=ACMap.ground_cell(ACData.point(item.pos))
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

static func activate(c,owner: int,id: String) -> Dictionary:
	catalog();var p: Dictionary=c.players[owner];var plan: Dictionary=by_id.get(id,{})
	if plan.is_empty() or int(plan.race)!=int(p.race) or int(plan.min_level)>int(p.difficulty):return {}
	p._ai_tactic=id;p._ai_plan_started=c.time;p._ai_plan_next=c.time+(75 if int(p.difficulty)==5 else 120)
	p.erase("_ai_plan_ready_at")
	p._ai_tech_reserve=[0,0]
	var history: Array=p.get("_ai_tactic_history",[])
	history.append({"id":id,"time":c.time});if history.size()>32:history.pop_front()
	p._ai_tactic_history=history
	return plan

static func choose(c,owner: int,army: Array) -> Dictionary:
	var p: Dictionary=c.players[owner];var current=plan_for(p)
	var intel: Dictionary=p.get("_ai_intel",{})
	var own_aa=army.filter(func(u):return u.hp>0 and float(c.unit_data(u).damage)>0 and "a" in str(c.unit_data(u).targets)).reduce(func(sum,u):return sum+float(c.unit_data(u).pop),0.0)
	var urgent=int(p.difficulty)==5 and not current.is_empty() and c.time-float(p.get("_ai_plan_started",0))>=25 and float(intel.get("air",0))>=4 and float(intel.get("air",0))>float(own_aa)*1.6
	if not current.is_empty():
		if not p.get("_ai_missions",[]).is_empty() or not urgent and c.time<float(p.get("_ai_plan_next",0)):return current
		# Finish a viable opening force before a random advanced plan consumes
		# its tech budget. Observed urgent counters still override the opening.
		if not urgent and int(p.difficulty)==5 and not p.get("_ai_has_attacked",false) and c.time<420:return current
		var ready=current.primary.all(func(kind):return army.filter(func(u):return int(u.kind)==int(kind) and u.hp>0).size()>=(1 if ACData.unit(int(p.race),int(kind)).pop>=3 or ACData.unit(int(p.race),int(kind)).role=="transport" else 3))
		if ready and not p.has("_ai_plan_ready_at"):p._ai_plan_ready_at=c.time
		if not urgent and c.time-float(p._ai_plan_started)<240 and (not ready or c.time-float(p.get("_ai_plan_ready_at",c.time))<90):return current
		if not urgent and not p.get("_ai_has_attacked",false) and c.time-float(p._ai_plan_started)<240:return current
		if not urgent and not p.get("_ai_wave",[]).is_empty() and c.time-float(p._ai_plan_started)<210:return current
	var choices=repertoire(int(p.race),int(p.difficulty)).filter(func(t):return float(t.min_time)<=c.time)
	if int(p.difficulty)==5 and c.time<100:choices=choices.filter(func(t):return str(t.id) in ["N1","N2","E1","E3","A1","A2"])
	if urgent:
		var anti_air=choices.filter(func(t):return t.primary.any(func(k):return "a" in str(ACData.unit(int(p.race),int(k)).targets)))
		if not anti_air.is_empty():choices=anti_air
	if choices.is_empty():return current
	var total=0.0;var ranked=[]
	for candidate in choices:
		var weight=selection_weight(c,owner,candidate,army)
		if str(candidate.id)==str(current.get("id","")):weight*=.25
		ranked.append({"plan":candidate,"weight":weight});total+=weight
	if int(p.difficulty)==5 and not p.get("_ai_sightings",{}).is_empty():
		var best=ranked.map(func(item):return float(item.weight)).max()
		ranked=ranked.filter(func(item):return float(item.weight)>=float(best)*.4)
		total=ranked.reduce(func(sum,item):return sum+float(item.weight),0.0)
	var roll=c.rng.randf()*total
	for item in ranked:
		roll-=float(item.weight)
		if roll<=0:return activate(c,owner,str(item.plan.id))
	return activate(c,owner,str(ranked[-1].plan.id))

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
	return maxf(.01,weight)

static func building_chain(race: int,kind: int,result: Array,visiting: Array=[]) -> void:
	if kind==0 or kind in result or kind in visiting:return
	visiting.append(kind)
	for required in ACData.building(race,kind).requires:building_chain(race,int(required),result,visiting.duplicate())
	result.append(kind)

static func build_order(race: int,plan: Dictionary) -> Array:
	var result=[];building_chain(race,2,result)
	var kinds: Array=plan.get("primary",[]).duplicate();kinds.append_array(plan.get("support",[]))
	if kinds.any(func(k):return float(ACData.unit(race,int(k)).tera)>0):building_chain(race,1,result)
	# Keep an affordable opening army while working toward a capital/air plan.
	building_chain(race,4 if race==1 else 3,result)
	for kind in kinds:
		var d=ACData.unit(race,int(kind))
		if race!=1:building_chain(race,int(d.producer),result)
		for required in d.requires:building_chain(race,int(required),result)
	return result

static func prepare(c,owner: int,plan: Dictionary,army: Array) -> void:
	var p: Dictionary=c.players[owner];p._ai_tech_reserve=[0,0]
	if not c.units.any(func(u):return int(u.owner)==owner and int(u.kind)==0 and u.hp>0 and u.container<0 and not u.get("_ai_scouting",false) and not u.order in ["construct","build_move"]):return
	var combatants=army.filter(func(u):return float(c.unit_data(u).damage)>0).size()
	for kind in build_order(int(p.race),plan):
		if c.has_building(owner,int(kind)):continue
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==int(kind)):return
		if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==int(kind)):return
		var d=ACData.building(int(p.race),int(kind))
		if not c.prerequisites(owner,d.requires):return
		if combatants<3 and int(kind) not in [1,2,3,4]:return
		c._ai_build(owner,int(kind))
		var fighting_population=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 else 0),0.0)
		if combatants>=6 and float(fighting_population)>=6 and not c.units.any(func(w):return int(w.owner)==owner and w.order=="build_move" and int(w.build_plan.kind)==int(kind)):
			p._ai_tech_reserve=[float(d.as),float(d.tera)]
		return

static func queued_counts(c,owner: int) -> Dictionary:
	var counts={}
	for u in c.units:
		if int(u.owner)==owner and u.hp>0 and not u.get("technical",false):counts[int(u.kind)]=int(counts.get(int(u.kind),0))+1
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0:continue
		for q in b.queue:counts[int(q.kind)]=int(counts.get(int(q.kind),0))+maxi(1,int(ACData.unit(int(b.race),int(q.kind)).get("production_count",1)))
	return counts

static func production_score(c,owner: int,plan: Dictionary,kind: int,counts: Dictionary,army_size: int) -> float:
	var p: Dictionary=c.players[owner];var d=ACData.unit(int(p.race),kind)
	var count=int(counts.get(kind,0));var weight=float(plan.weights.get(str(kind),0))
	if kind==0 or d.get("spawn_only",false):return -1
	if weight<=0:
		if bool(p.get("_ai_intel",{}).get("cloak",false)) and d.role in ["detector","healer_detector"]:weight=1
		elif army_size<6 and kind in [1,2]:weight=.15
		elif float(p.get("_ai_intel",{}).get("air",0))>2 and "a" in str(d.targets):weight=.7
		else:return -1
	if d.role=="transport":
		if not plan.drop or count>=maxi(1,mini(3,army_size/8)) or army_size<3:return -1
	elif d.role in ["detector","healer_detector","medic","priest"]:
		if army_size<3 or count>=maxi(1,ceili(army_size/(5.0 if d.role in ["medic","priest"] else 10.0))):return -1
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

static func log_action(p: Dictionary,key: String) -> void:
	if not p.has("_ai_tactic_actions"):p._ai_tactic_actions={}
	p._ai_tactic_actions[key]=int(p._ai_tactic_actions.get(key,0))+1
