extends RefCounted
## Public map locations are search candidates; occupancy is learned from sight.
static func sites(c,owner: int,home: Vector2) -> Array:
	var result=[]
	for entry in c.map.starts+c.map.bases.map(func(b):return b.pos):
		var point=ACData.point(entry)
		if point.distance_squared_to(home)<400:continue
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and c.center(b).distance_squared_to(point)<100):continue
		if not result.any(func(old):return old.distance_squared_to(point)<25):result.append(point)
	return result

static func seen(c,owner: int,point: Vector2) -> bool:
	var cell=ACMap.ground_cell(point)
	return c.visibility[owner][cell.y*ACMap.SIZE+cell.x]>0

static func army_goal(c,owner: int,army: Array,home: Vector2,visible: Array) -> Vector2:
	var p: Dictionary=c.players[owner];var empty: Dictionary=p.get("_ai_attack_empty_sites",{})
	var options=sites(c,owner,home)
	# Ground armies must not waste a wave on public island locations. Those
	# remain valid reconnaissance targets for an actual aircraft/transport.
	if army.any(func(u):return not c.unit_data(u).air):
		options=options.filter(func(point):return not c.map.bases.any(func(b):return str(b.get("access","ground"))!="ground" and ACData.point(b.pos).distance_squared_to(point)<25))
	for point in options:
		if seen(c,owner,point) and not visible.any(func(e):return c.center(e).distance_squared_to(point)<144):empty[str(point)]=c.time
	p._ai_attack_empty_sites=empty
	var remaining=options.filter(func(point):return not empty.has(str(point)))
	var current=ACData.point(p.get("_ai_attack_search_goal",[-999,-999]))
	if not remaining.is_empty():
		p._ai_goal_reason="search_unseen"
		if current in remaining:return current
		# Keep the nearest remaining public start before sweeping expansions.
		var starts=remaining.filter(func(point):return c.map.starts.any(func(s):return ACData.point(s).distance_squared_to(point)<25))
		if not starts.is_empty():remaining=starts
	else:
		remaining=options.filter(func(point):return c.time-float(empty.get(str(point),c.time))>=90)
		p._ai_goal_reason="patrol" if not remaining.is_empty() else "regroup_after_search"
		if remaining.is_empty():return home
	var origin=home
	if not army.is_empty():
		origin=Vector2.ZERO
		for u in army:origin+=c.center(u)
		origin/=army.size()
	remaining.sort_custom(func(a,b):return origin.distance_squared_to(a)<origin.distance_squared_to(b))
	p._ai_attack_search_goal=ACData.packed(remaining[0])
	return remaining[0]

static func finish(c,owner: int,u: Dictionary,home: Vector2) -> void:
	var p: Dictionary=c.players[owner]
	if not u.is_empty() and int(u.owner)==owner:
		u._ai_scouting=false
		if u.hp>0 and u.container<0:
			if int(u.kind)==0:
				u._ai_scout_return=true
				var ore=c.nearest_resource(home,"as",owner)
				if ore>=0 and c.command(owner,{"type":"gather","ids":[u.id],"target":ore})=="":u.erase("_ai_scout_return")
				else:c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(home)})
			else:c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(home)})
	p._ai_scout=-1;p._ai_scout_next=c.time+[180,150,120,90,75,60][clampi(int(p.difficulty),0,5)]
	p.erase("_ai_scout_goal")

static func scout(c,owner: int,army: Array,home: Vector2,defend: bool) -> Array:
	var p: Dictionary=c.players[owner];var level=int(p.difficulty);var reserved=[]
	var known=preload("res://scripts/bot_tactic_learning.gd").observed_race(c,owner)>=0
	if level<2 and known:
		var finished=c.entity(int(p.get("_ai_scout",-1)))
		if not finished.is_empty():finish(c,owner,finished,home)
		return reserved
	var u=c.entity(int(p.get("_ai_scout",-1)))
	if u.is_empty() and int(p.get("_ai_scout",-1))>=0:
		finish(c,owner,{},home);return reserved
	if not u.is_empty():
		if known and not p.get("_ai_scout_known_at_launch",false):finish(c,owner,u,home);return reserved
		var expired=c.time-float(p.get("_ai_scout_started",0))>=float(p.get("_ai_scout_budget",90))
		if defend or u.hp<=float(c.unit_data(u).hp)*.55 or int(u.owner)!=owner or u.container>=0 or c.time-float(u.damaged)<5 or expired:
			finish(c,owner,u,home);return reserved
	elif defend:return reserved
	if u.is_empty():
		if c.time<maxf(float([90,70,50,35,25,18][clampi(level,0,5)]),float(p.get("_ai_scout_next",0))):return reserved
		var busy: Array=p.get("_ai_wave",[])+p.get("_ai_marching",[])+p.get("_ai_cohort",[])+p.get("_ai_garrison",[])+p.get("_ai_local_defense",[])
		busy.append_array(p.get("_ai_claw_raid",{}).get("members",[]));busy.append_array(p.get("_ai_assault_raid",{}).get("members",[]));busy.append_array(p.get("_ai_bat_raid",{}).get("members",[]));busy.append_array(p.get("_ai_mobile_raid",{}).get("members",[]))
		for mission in p.get("_ai_missions",[]):busy.append(int(mission.carrier));busy.append_array(mission.members)
		var candidates=army.filter(func(a):return a.hp>float(c.unit_data(a).hp)*.8 and a.container<0 and not int(a.id) in busy and c.time-float(a.damaged)>8 and (int(p.race)==1 and int(a.kind)==1 or c.unit_data(a).role in ["assault","fighter"] and army.size()>=12))
		var workers=c.units.filter(func(w):return int(w.owner)==owner and int(w.kind)==0 and w.hp>0 and w.container<0)
		if candidates.is_empty() and workers.size()>=(6 if not known else 8):
			candidates=workers.filter(func(w):return w.order in ["gather","idle"] and float(w.get("carried",0))<=0 and w.build_queue.is_empty() and w.hp>float(c.unit_data(w).hp)*.8 and c.time-float(w.damaged)>8)
		if candidates.is_empty():return reserved
		candidates.sort_custom(func(a,b):return float(c.unit_data(a).as)+float(c.unit_data(a).tera)*1.5<float(c.unit_data(b).as)+float(c.unit_data(b).tera)*1.5)
		u=candidates[0];u._ai_scouting=true;p._ai_scout=u.id;p._ai_scout_last=u.id;p._ai_scout_started=c.time;p._ai_scout_checks=0
		p._ai_scout_known_at_launch=known
		p._ai_scout_budget=(45 if int(u.kind)==0 else 60) if known else 150
		p._ai_scout_sorties=int(p.get("_ai_scout_sorties",0))+1
		if int(u.kind)==0:p._ai_worker_scouts=int(p.get("_ai_worker_scouts",0))+1
	reserved.append(int(u.id))
	var visited: Dictionary=p.get("_ai_scout_visited",{})
	var goal=ACData.point(p.get("_ai_scout_goal",[-999,-999]))
	if goal.x>=0 and seen(c,owner,goal):
		visited[str(goal)]=c.time;p._ai_scout_checks=int(p.get("_ai_scout_checks",0))+1;p.erase("_ai_scout_goal");goal=Vector2(-999,-999)
		p._ai_scout_visited=visited
		if int(p._ai_scout_checks)>=(2 if known else 3):finish(c,owner,u,home);return reserved
	if goal.x<0:
		var options=sites(c,owner,home).filter(func(point):return not seen(c,owner,point) and c.time-float(visited.get(str(point),-10000))>=90)
		if not c.unit_data(u).air:options=options.filter(func(point):return not c.map.bases.any(func(b):return str(b.get("access","ground"))!="ground" and ACData.point(b.pos).distance_squared_to(point)<25))
		if options.is_empty():finish(c,owner,u,home);return reserved
		# First search starts; subsequent sorties check public expansion sites too.
		if not p.has("_ai_first_enemy_seen"):
			var starts=options.filter(func(point):return c.map.starts.any(func(s):return ACData.point(s).distance_squared_to(point)<25))
			if not starts.is_empty():options=starts
		var hostile_bases=p.get("_ai_sightings",{}).values().filter(func(item):return item.building and int(item.kind)==0)
		if known and not hostile_bases.is_empty():
			var expansions=options.filter(func(point):return not hostile_bases.any(func(b):return point.distance_squared_to(ACData.point(b.pos))<100))
			if not expansions.is_empty():options=expansions
		options.sort_custom(func(a,b):
			var aa=c.center(u).distance_squared_to(a);var bb=c.center(u).distance_squared_to(b)
			if known and not hostile_bases.is_empty():
				aa=hostile_bases.map(func(item):return a.distance_squared_to(ACData.point(item.pos))).min()+aa*.2
				bb=hostile_bases.map(func(item):return b.distance_squared_to(ACData.point(item.pos))).min()+bb*.2
			return aa<bb)
		goal=options[0];p._ai_scout_goal=ACData.packed(goal)
	if u.order!="move" or ACData.point(u.goal).distance_squared_to(goal)>1:c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(goal)})
	return reserved
