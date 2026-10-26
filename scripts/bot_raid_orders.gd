extends RefCounted
## Expendable attack detachments retain their assignment until destroyed.
static func detach(c,owner: int,group: Array) -> Array:
	var p: Dictionary=c.players[owner];var ids=group.map(func(u):return int(u.id))
	for u in group:u._ai_expendable_owner=owner
	for key in ["_ai_wave","_ai_marching","_ai_cohort","_ai_garrison","_ai_local_defense"]:p[key]=p.get(key,[]).filter(func(id):return not int(id) in ids)
	return ids

static func members(c,owner: int,mission: Dictionary) -> Array:
	return mission.get("members",[]).map(func(id):return c.entity(int(id))).filter(func(u):return not u.is_empty() and u.hp>0 and int(u.owner)==owner and u.container<0)

static func press(c,owner: int,mission: Dictionary,visible: Array) -> Array:
	var group=members(c,owner,mission)
	if group.is_empty():return []
	var ids=group.map(func(u):return int(u.id))
	if c.time<float(mission.get("orders_at",0)):return ids
	mission.orders_at=c.time+.8
	var origin=Vector2.ZERO
	for u in group:origin+=c.center(u)
	origin/=group.size()
	var goal=ACData.point(mission.goal);var victim={};var best=INF
	# Visible workers are primary victims; a headquarters remains the durable
	# objective. Never query unseen entities using a remembered id.
	for e in visible:
		if e.hp<=0 or e.has("progress") or int(e.kind)!=0 or not c.can_see(owner,e):continue
		if c.center(e).distance_squared_to(goal)>225 and c.center(e).distance_squared_to(origin)>144:continue
		var distance=origin.distance_squared_to(c.center(e))
		if distance<best:best=distance;victim=e
	if victim.is_empty():
		var candidates=[]
		for item in c.players[owner].get("_ai_sightings",{}).values():
			if item.building and int(item.kind)==0:candidates.append(item)
		if not candidates.is_empty():
			candidates.sort_custom(func(a,b):return (0 if int(a.id)==int(mission.get("base",-1)) else 10000)+origin.distance_squared_to(ACData.point(a.pos))<(0 if int(b.id)==int(mission.get("base",-1)) else 10000)+origin.distance_squared_to(ACData.point(b.pos)))
			var item=candidates[0];goal=ACData.point(item.pos);mission.base=int(item.id);mission.goal=item.pos
			for e in visible:
				if int(e.id)==int(item.id) and c.can_see(owner,e):victim=e;break
		elif not visible.is_empty():
			var opponents=visible.filter(func(e):return e.hp>0 and group.any(func(u):return c._can_attack(c.unit_data(u),e)))
			if not opponents.is_empty():
				opponents.sort_custom(func(a,b):return origin.distance_squared_to(c.center(a))<origin.distance_squared_to(c.center(b)))
				victim=opponents[0];goal=c.center(victim);mission.goal=ACData.packed(goal)
	if not victim.is_empty():
		var ready=group.filter(func(u):return u.order!="attack" or int(u.target)!=int(victim.id)).map(func(u):return int(u.id))
		if not ready.is_empty():c.command(owner,{"type":"attack","ids":ready,"target":int(victim.id)})
	else:
		var ready=group.filter(func(u):return u.order in ["idle","hold"] or u.order!="attack" and ACData.point(u.goal).distance_squared_to(goal)>9).map(func(u):return int(u.id))
		if not ready.is_empty():c.command(owner,{"type":"attack_move","ids":ready,"pos":ACData.packed(goal),"formation":true})
	return ids

static func deployed(c,owner: int,visible: Array) -> Array:
	var p: Dictionary=c.players[owner];var kept=[];var ids=[]
	for mission in p.get("_ai_deployed_raids",[]):
		var active=press(c,owner,mission,visible)
		if not active.is_empty():kept.append(mission);ids.append_array(active)
	p._ai_deployed_raids=kept
	return ids
