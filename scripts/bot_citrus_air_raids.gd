extends RefCounted
const T=preload("res://scripts/bot_tactics.gd")
static func move(c,owner: int,u: Dictionary,point: Vector2,attack: bool=false) -> void:
	var order="attack_move" if attack else "move"
	if u.order!=order or ACData.point(u.goal).distance_squared_to(point)>1:c.command(owner,{"type":order,"ids":[u.id],"pos":ACData.packed(point)})

static func air_risk(c,owner: int,point: Vector2,air: bool=true) -> float:
	var result=0.0
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if ACData.point(item.pos).distance_squared_to(point)>144:continue
		var d=ACData.building(int(item.race),int(item.kind)) if item.building else ACData.unit(int(item.race),int(item.kind))
		var anti_air=int(item.kind)==((11 if air else 10) if int(item.race)==1 else (12 if air else 11)) if item.building else str(d.role)!="worker" and ("a" if air else "g") in str(d.targets) and float(d.damage)>0
		if anti_air:result+=maxf(1,float(item.get("pop",1)))
	return result

static func target(c,owner: int,group: Array,home: Vector2) -> Vector2:
	var best=Vector2.INF;var value=-INF
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if not item.building or int(item.kind)!=0:continue
		var point=ACData.point(item.pos);var danger=air_risk(c,owner,point,bool(c.unit_data(group[0]).air))
		if point.distance_squared_to(home)<324 or danger>maxf(3,group.size()*.75):continue
		var workers=c.players[owner]._ai_sightings.values().filter(func(w):return not w.building and str(w.role)=="worker" and c.time-float(w.seen)<30 and ACData.point(w.pos).distance_squared_to(point)<144).size()
		var score=workers*15-danger*20+100-group.reduce(func(sum,u):return sum+c.center(u).distance_to(point),0.0)/group.size()
		if score>value:value=score;best=point
	return best

static func tick(c,owner: int,army: Array,home: Vector2,visible: Array,defend: bool,excluded: Array) -> Array:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<3:return []
	var race=int(p.race);var mission_key="_ai_bat_raid" if race==1 else "_ai_mobile_raid"
	var next_key="_ai_bat_next" if race==1 else "_ai_mobile_next";var event="bat_raid:" if race==1 else "mobile_raid:"
	var mission: Dictionary=p.get(mission_key,{})
	if mission.is_empty():
		if defend or c.time<float(p.get(next_key,0)):return []
		p[next_key]=c.time+5
		var kinds=[13,6] if race==0 else [10] if race==1 else [13]
		var group=army.filter(func(u):return int(u.kind) in kinds and int(u.get("_ai_expendable_owner",-1))!=owner and u.hp>=float(c.unit_data(u).hp)*.75 and u.container<0 and not int(u.id) in excluded and not u.get("_ai_scouting",false)).slice(0,6 if race==1 else 4)
		if group.size()<(4 if race==1 else 2) or army.size()<8:return []
		var point=target(c,owner,group,home)
		if not point.is_finite():return []
		if not c.unit_data(group[0]).air:
			var route=c._clearance_path(group[0],c.center(group[0]),point)
			if route.is_empty() or ACData.point(route.back()).distance_to(point)>3:return []
		var ids=group.map(func(u):return int(u.id))
		for key in ["_ai_wave","_ai_marching","_ai_cohort"]:p[key]=p.get(key,[]).filter(func(id):return not int(id) in ids)
		mission={"members":ids,"goal":ACData.packed(point),"phase":"approach","started":c.time,"phase_at":c.time,"orders_at":0};p[mission_key]=mission;T.log_action(p,event+"launch")
	var group=mission.members.map(func(id):return c.entity(int(id))).filter(func(u):return not u.is_empty() and u.hp>0 and int(u.owner)==owner and u.container<0)
	if group.is_empty():p.erase(mission_key);p[next_key]=c.time+45;return []
	var point=ACData.point(mission.goal);var phase=str(mission.phase)
	var danger=air_risk(c,owner,point,bool(c.unit_data(group[0]).air))
	if phase!="return" and (defend or group.size()<2 or group.any(func(u):return u.hp<float(c.unit_data(u).hp)*.5) or danger>maxf(4,group.size()) or c.time-float(mission.started)>100):mission.phase="return";phase="return";T.log_action(p,event+"disengage")
	if c.time<float(mission.orders_at):return group.map(func(u):return int(u.id))
	mission.orders_at=c.time+.8
	if phase=="return":
		if group.all(func(u):return c.center(u).distance_squared_to(home)<100):p.erase(mission_key);p[next_key]=c.time+30;T.log_action(p,event+"return");return []
		for u in group:move(c,owner,u,home+Vector2(0,4))
	elif phase=="approach":
		# Approach from the side rather than crossing the known anti-air centre.
		var side=(point-home).normalized().orthogonal()*9
		var flank=(point+(home-point).normalized()*8+side).clamp(Vector2(2,2),Vector2(125,125))
		for u in group:move(c,owner,u,flank)
		if group.any(func(u):return c.center(u).distance_squared_to(flank)<25):mission.phase="strike";mission.phase_at=c.time
	elif phase=="strike":
		var victims=visible.filter(func(e):return e.hp>0 and not e.has("progress") and int(e.kind)==0 and c.center(e).distance_squared_to(point)<196)
		for u in group:
			if not victims.is_empty():
				victims.sort_custom(func(a,b):return c.center(u).distance_squared_to(c.center(a))<c.center(u).distance_squared_to(c.center(b)))
				if u.order!="attack" or int(u.target)!=int(victims[0].id):c.command(owner,{"type":"attack","ids":[u.id],"target":victims[0].id})
			else:move(c,owner,u,point,true)
		if c.time-float(mission.phase_at)>6 and group.any(func(u):return c.time-float(u.fired)<2) or c.time-float(mission.phase_at)>12:mission.phase="peel";mission.phase_at=c.time;T.log_action(p,event+"peel")
	elif phase=="peel":
		var back=point+(home-point).normalized()*13
		for u in group:move(c,owner,u,back)
		if c.time-float(mission.phase_at)>5:mission.phase="approach";mission.phase_at=c.time
	return group.map(func(u):return int(u.id))
