extends RefCounted
const T=preload("res://scripts/bot_tactics.gd")
const R=preload("res://scripts/bot_raid_orders.gd")

static func risk(c,owner: int,point: Vector2) -> float:
	var total=0.0
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if ACData.point(item.pos).distance_squared_to(point)>100:continue
		if not item.building and c.time-float(item.seen)>35:continue
		var d=ACData.building(int(item.race),int(item.kind)) if item.building else ACData.unit(int(item.race),int(item.kind))
		if item.building:
			if int(item.kind) in ([10,11] if int(item.race)==1 else [11,12]):total+=6
		elif float(d.damage)>0 and "g" in str(d.targets) and d.role!="worker":total+=maxf(1,float(d.pop))
	return total

static func target(c,owner: int,home: Vector2,group: Array) -> Vector2:
	var best=Vector2.INF;var score=-INF
	for item in c.players[owner].get("_ai_sightings",{}).values():
		var worker=not item.building and str(item.role)=="worker" and c.time-float(item.seen)<=25
		if not worker and not (item.building and int(item.kind)==0):continue
		var point=ACData.point(item.pos)
		if point.distance_squared_to(home)<324 or risk(c,owner,point)>group.size()*.6:continue
		if c.map.bases.any(func(base):return str(base.get("access","ground"))!="ground" and ACData.point(base.pos).distance_squared_to(point)<36):continue
		var value=(80 if worker else 20)-c.center(group[0]).distance_to(point)*.2
		if value>score:score=value;best=point
	return best

static func tick(c,owner: int,army: Array,home: Vector2,visible: Array,defend: bool,excluded: Array) -> Array:
	var p: Dictionary=c.players[owner]
	if int(p.race)==1:return citrus_tick(c,owner,army,home,visible,defend,excluded)
	if not int(p.race) in [0,2]:return []
	var mission: Dictionary=p.get("_ai_assault_raid",{})
	if mission.is_empty():
		if defend or army.size()<6 or c.time<float(p.get("_ai_assault_next",0)):return []
		p._ai_assault_next=c.time+5
		var kinds=[2,3] if int(p.race)==0 else [10]
		var candidates=army.filter(func(u):return int(u.kind) in kinds and u.hp>=float(c.unit_data(u).hp)*.75 and u.container<0 and not int(u.id) in excluded and not u.get("_ai_scouting",false) and c.time-float(u.damaged)>4 and c.time-float(u.fired)>2)
		candidates.sort_custom(func(a,b):return int(a.kind)==2 and int(b.kind)!=2)
		var group=candidates.slice(0,4)
		if group.size()<2:return []
		var goal=target(c,owner,home,group)
		if not goal.is_finite():return []
		var route=c._clearance_path(group[0],c.center(group[0]),goal)
		if route.is_empty() or ACData.point(route.back()).distance_to(goal)>3:return []
		var ids=R.detach(c,owner,group)
		mission={"members":ids,"goal":ACData.packed(goal),"started":c.time,"returning":false};p._ai_assault_raid=mission;T.log_action(p,"assault_raid:launch")
	var ids=R.press(c,owner,mission,visible)
	if ids.is_empty():p.erase("_ai_assault_raid");p._ai_assault_next=c.time+30
	return ids

static func citrus_target(c,owner: int,home: Vector2,group: Array) -> Dictionary:
	var p: Dictionary=c.players[owner];var chosen={};var best=-INF
	for item in p.get("_ai_sightings",{}).values():
		if not item.building or int(item.kind)!=0:continue
		var point=ACData.point(item.pos)
		if point.distance_squared_to(home)<324 or c.map.starts.any(func(s):return ACData.point(s).distance_squared_to(point)<100):continue
		if c.map.bases.any(func(base):return str(base.get("access","ground"))!="ground" and ACData.point(base.pos).distance_squared_to(point)<64):continue
		var danger=risk(c,owner,point)
		if danger>10:continue
		var workers=p._ai_sightings.values().filter(func(w):return not w.building and str(w.role)=="worker" and c.time-float(w.seen)<30 and ACData.point(w.pos).distance_squared_to(point)<144).size()
		var value=100+workers*15-danger*8-c.center(group[0]).distance_to(point)*.3
		if value>best:best=value;chosen={"point":ACData.packed(point),"base":int(item.id)}
	return chosen

static func citrus_tick(c,owner: int,army: Array,home: Vector2,visible: Array,defend: bool,excluded: Array) -> Array:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<3:return []
	var mission: Dictionary=p.get("_ai_claw_raid",{})
	if not mission.is_empty():
		var ids=R.press(c,owner,mission,visible)
		if ids.is_empty():p.erase("_ai_claw_raid");p._ai_claw_next=c.time+20;T.log_action(p,"claw_raid:destroyed")
		return ids
	if defend:
		p.erase("_ai_claw_pending");return []
	if c.time<float(p.get("_ai_claw_next",0)):return p.get("_ai_claw_pending",[])
	p._ai_claw_next=c.time+2
	var candidates=army.filter(func(u):return int(u.kind)==1 and u.hp>=float(c.unit_data(u).hp)*.7 and u.container<0 and not int(u.id) in excluded and not u.get("_ai_scouting",false) and c.time-float(u.damaged)>4 and c.time-float(u.fired)>2)
	if candidates.is_empty():p.erase("_ai_claw_pending");return []
	candidates.sort_custom(func(a,b):return c.center(a).distance_squared_to(home)<c.center(b).distance_squared_to(home))
	var choice=citrus_target(c,owner,home,candidates)
	var group=candidates.slice(0,12);var ids=group.map(func(u):return int(u.id))
	p._ai_claw_pending=ids
	for key in ["_ai_wave","_ai_marching","_ai_cohort"]:p[key]=p.get(key,[]).filter(func(id):return not int(id) in ids)
	var anchor=c.center(group[0])
	if choice.is_empty() or group.size()<12 or group.any(func(u):return c.center(u).distance_squared_to(anchor)>324):
		var assemble=c.unit_free_position(1,1,home+Vector2(0,6),-1)
		for u in group:
			if c.center(u).distance_squared_to(assemble)>9 and (u.order!="move" or ACData.point(u.goal).distance_squared_to(assemble)>1):c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(assemble)})
		return ids
	var goal=ACData.point(choice.point);var route=c._clearance_path(group[0],c.center(group[0]),goal)
	if route.is_empty() or ACData.point(route.back()).distance_to(goal)>3:p.erase("_ai_claw_pending");return []
	ids=R.detach(c,owner,group)
	mission={"members":ids,"goal":choice.point,"base":choice.base,"started":c.time,"returning":false};p._ai_claw_raid=mission;p.erase("_ai_claw_pending")
	T.log_action(p,"claw_raid:launch")
	R.press(c,owner,mission,visible)
	return ids
