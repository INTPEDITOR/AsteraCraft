extends RefCounted
## Observed counter plans and protection for a depleted Araowl battle line.
static func recovery(c,owner: int,army: Array) -> bool:
	if int(c.players[owner].race)!=2 or int(c.players[owner].difficulty)<2 or c.time<90:return false
	var population=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if u.hp>0 and (float(c.unit_data(u).damage)>0 or c.unit_data(u).role=="carrier") else 0),0.0)
	return population<(8 if c.time<240 else 12)

static func response(c,owner: int) -> String:
	if int(c.players[owner].race)!=2 or int(c.players[owner].difficulty)<3:return ""
	var mass=0.0;var tanks=0;var heavy_hits=0.0
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if item.building or c.time-float(item.seen)>75:continue
		if int(item.race)==1 and str(item.role) in ["spitter","siege"]:mass+=maxf(1,float(item.pop))
		if int(item.race)==0 and str(item.role) in ["siege","fortress"]:tanks+=1
		var enemy=ACData.unit(int(item.race),int(item.kind))
		if "g" in str(enemy.targets) and float(enemy.damage)>25:heavy_hits+=maxf(1,float(item.pop))
	if tanks>=2:return "siege_flank"
	if mass>=6:return "mass_splash"
	if heavy_hits>=4:return "heavy_hits"
	return ""

static func counter_plan(plan: Dictionary,kind: String) -> bool:
	var primary: Array=plan.get("primary",[])
	if kind=="mass_splash":return primary.any(func(k):return int(k) in [5,7,8])
	if kind=="siege_flank":return 7 in primary or 10 in primary or bool(plan.get("drop",false))
	if kind=="heavy_hits":return 7 in primary
	return true

static func choice_weight(c,owner: int,plan: Dictionary) -> float:
	var kind=response(c,owner)
	if kind.is_empty():return 1.0
	return 3.5 if counter_plan(plan,kind) else .7

static func compose(c,owner: int,source: Dictionary,army: Array) -> Dictionary:
	if int(c.players[owner].race)!=2:return source
	var p: Dictionary=c.players[owner];p._ai_ara_recovery=recovery(c,owner,army);p._ai_ara_response=response(c,owner)
	if p._ai_ara_recovery:
		var plan=source.duplicate(true)
		plan.primary=[1,2];plan.support=[];plan.skills=[]
		plan.weights={"1":2 if float(p.get("_ai_intel",{}).get("air",0))>=4 else 4,"2":8}
		plan._ai_ara_recovery=true
		return plan
	# Existing stealth, drop and capital armies remain real alternatives. A
	# conventional ground line adds the observed mass-army counters gradually.
	if str(p._ai_ara_response)=="mass_splash" and not source.drop and not source.primary.any(func(k):return int(k) in [9,10,12]):
		var plan=source.duplicate(true)
		for kind in [7,8]:
			if not kind in plan.primary:plan.primary.append(kind)
		if not 5 in plan.support and not 5 in plan.primary:plan.support.append(5)
		plan.weights["7"]=maxf(6,float(plan.weights.get("7",0)));plan.weights["8"]=maxf(6,float(plan.weights.get("8",0)))
		plan.weights["5"]=maxf(2,float(plan.weights.get("5",0)))
		for key in ["1","2"]:plan.weights[key]=minf(4,float(plan.weights.get(key,0)))
		for skill in ["shockwave","pierce","judgment"]:
			if not skill in plan.skills:plan.skills.append(skill)
		return plan
	if str(p._ai_ara_response) in ["siege_flank","heavy_hits"] and not 12 in source.primary:
		var plan=source.duplicate(true)
		if not 7 in plan.primary and not 7 in plan.support:plan.support.append(7)
		plan.weights["7"]=maxf(5,float(plan.weights.get("7",0)))
		if not "shockwave" in plan.skills:plan.skills.append("shockwave")
		return plan
	return source

static func escort(c,owner: int,army: Array,visible: Array,wave: Array,goal: Vector2,defend: bool) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.race)!=2 or int(p.difficulty)<3 or defend or c.time<float(p.get("_ai_ara_escort_next",0)):return false
	p._ai_ara_escort_next=c.time+.7
	var ranged=army.filter(func(u):return u.hp>0 and int(u.id) in wave and int(u.kind) in [2,3,5,7,8] and u.container<0 and int(u.get("_ai_expendable_owner",-1))!=owner)
	if ranged.is_empty():return false
	for u in army:
		if u.hp<=0 or int(u.kind)!=1 or not int(u.id) in wave or u.container>=0 or int(u.get("_ai_expendable_owner",-1))==owner or c.time<float(u.get("_ai_kite_until",0)):continue
		if visible.any(func(e):return e.hp>0 and c._can_attack(c.unit_data(u),e) and c.center(u).distance_to(c.center(e))<2.3):continue
		var nearest=ranged[0]
		for ally in ranged:
			if c.center(u).distance_squared_to(c.center(ally))<c.center(u).distance_squared_to(c.center(nearest)):nearest=ally
		var gap=c.center(u).distance_to(c.center(nearest))
		if gap<=6 or gap>20:continue
		var point=c.center(nearest)+(goal-c.center(nearest)).normalized()*3
		point=c.unit_free_position(int(u.race),int(u.kind),point,int(u.id))
		if c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(point)})=="":u._ai_kite_until=c.time+.8;return true
	return false

static func flank(c,owner: int,army: Array,wave: Array,home: Vector2,goal: Vector2,defend: bool) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.race)!=2 or defend or response(c,owner)!="siege_flank" or c.time<float(p.get("_ai_ara_flank_next",0)):return false
	p._ai_ara_flank_next=c.time+1
	var group=army.filter(func(u):return u.hp>0 and int(u.kind)==10 and int(u.id) in wave and u.container<0 and int(u.get("_ai_expendable_owner",-1))!=owner).slice(0,4)
	if group.is_empty():return false
	var side=(goal-home).normalized().orthogonal()*10
	if int(group[0].id)%2==0:side=-side
	var point=(goal+side).clamp(Vector2(2,2),Vector2(125,125));var ids=[]
	for u in group:
		if ACData.point(u.get("_ai_ara_flank_goal",[-999,-999])).distance_squared_to(goal)>36:u._ai_ara_flank_goal=ACData.packed(goal);u._ai_ara_flank_done=false
		if c.center(u).distance_to(point)<2.5:u._ai_ara_flank_done=true
		if u.get("_ai_ara_flank_done",false):continue
		ids.append(int(u.id))
	if ids.is_empty():return false
	var lead=c.entity(ids[0]);var route=c._clearance_path(lead,c.center(lead),point)
	if route.is_empty() or ACData.point(route.back()).distance_to(point)>2:return false
	if c.command(owner,{"type":"move","ids":ids,"pos":ACData.packed(point),"formation":true})!="":return false
	for id in ids:c.entity(int(id))._ai_kite_until=c.time+1.1
	return true

static func landing_risk(c,owner: int,point: Vector2) -> float:
	if int(c.players[owner].race)!=2:return 0
	var risk=0.0
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if item.building or int(item.race)!=0 or not str(item.role) in ["siege","fortress"] or c.time-float(item.seen)>75:continue
		var d=ACData.unit(0,int(item.kind));var reach=ACData.attack_range(d,bool(item.get("anchored",false)))
		if point.distance_to(ACData.point(item.pos))<=reach+2:risk+=1
	return risk
