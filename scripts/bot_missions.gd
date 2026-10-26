extends RefCounted
const T=preload("res://scripts/bot_tactics.gd")
const RAIDS=preload("res://scripts/bot_raid_orders.gd")

static func move(c,owner: int,u: Dictionary,point: Vector2,attack: bool=false) -> void:
	if u.hp<=0 or u.container>=0 or not u.get("channel",{}).is_empty() or float(u.get("self_repair_until",0))>c.time:return
	var order="attack_move" if attack else "move"
	if u.order!=order or ACData.point(u.goal).distance_squared_to(point)>1:c.command(owner,{"type":order,"ids":[u.id],"pos":ACData.packed(point)})

static func remembered_goal(c,owner: int,plan: Dictionary,fallback: Vector2,excluded: Array=[]) -> Vector2:
	var p: Dictionary=c.players[owner];var best=fallback;var score=-INF
	var home=c.entity(int(p.home));var origin=c.center(home) if not home.is_empty() else Vector2(64,64)
	for item in p.get("_ai_sightings",{}).values():
		if not item.building or int(item.id) in excluded:continue
		var point=ACData.point(item.pos);var value=float(item.value)-origin.distance_to(point)
		if int(item.kind)==0:value+=500
		if value>score:score=value;best=point
	if str(plan.style) in ["raid","air_raid","split_raid","drop","expand_raid"] and score>-INF:
		var closest=INF
		for item in p.get("_ai_sightings",{}).values():
			if item.building or str(item.role)!="worker" or c.time-float(item.seen)>25:continue
			var point=ACData.point(item.pos);var distance=point.distance_to(best)
			if distance<12 and distance<closest:closest=distance;fallback=point
		if closest<INF:return fallback
	return best

static func air_risk(c,owner: int,point: Vector2) -> float:
	var risk=0.0
	for item in c.players[owner].get("_ai_sightings",{}).values():
		var d=ACData.building(int(item.race),int(item.kind)) if item.building else ACData.unit(int(item.race),int(item.kind))
		var aa=(int(item.kind)==(11 if int(item.race)==1 else 12)) if item.building else "a" in str(d.targets) and float(d.damage)>0
		if aa and ACData.point(item.pos).distance_to(point)<maxf(9,float(d.get("range",7))+2):risk+=maxf(1,float(item.get("pop",1)))
	return risk

static func landing(c,carrier: Dictionary,payload: Array,goal: Vector2,home: Vector2) -> Vector2:
	var owner=int(carrier.owner);var candidates=[]
	var back=(home-goal).normalized()
	var ground=payload.filter(func(u):return not c.unit_data(u).air)
	ground.sort_custom(func(a,b):return c._body_size(a).x*c._body_size(a).y>c._body_size(b).x*c._body_size(b).y)
	var approach=goal
	if not ground.is_empty():
		var lead=ground[0]
		approach=c.unit_free_position(int(lead.race),int(lead.kind),goal,-1,4)
		if approach.distance_to(goal)>4.5 or not c._ground_fits_size(c._body_size(lead),approach):return Vector2.INF
	for radius in [7,10,13]:
		for angle in [0,.7,-.7,1.4,-1.4,2.1,-2.1,PI]:
			var point=(goal+back.rotated(angle)*radius).clamp(Vector2(2,2),Vector2(125,125))
			if payload.any(func(u):return not c._ground_fits_size(c._body_size(u),point)):continue
			var value=air_risk(c,owner,point)*30+preload("res://scripts/bot_ara_policy.gd").landing_risk(c,owner,point)*18+point.distance_to(c.center(carrier))*.1+radius
			candidates.append({"point":point,"value":value})
	# Rank cheap observed-risk checks before spending the shared path budget.
	# The old angular order exhausted it on exposed frontal landings first.
	candidates.sort_custom(func(a,b):return float(a.value)<float(b.value))
	for candidate in candidates:
		if float(candidate.value)>=100:break
		var point: Vector2=candidate.point
		if not ground.is_empty():
			var route=c._clearance_path(ground[0],point,approach)
			if route.is_empty() or ACData.point(route.back()).distance_to(approach)>.75:continue
			if not c._ground_sweep(c._body_size(ground[0]),ACData.point(route.back()),approach):continue
		return point
	return Vector2.INF

static func scout(c,owner: int,army: Array,home: Vector2,defend: bool) -> Array:
	return preload("res://scripts/bot_recon.gd").scout(c,owner,army,home,defend)

static func before_combat(c,owner: int,army: Array,plan: Dictionary,home: Vector2,goal: Vector2,visible: Array,defend: bool) -> Array:
	var p: Dictionary=c.players[owner];var reserved=scout(c,owner,army,home,defend)
	reserved.append_array(RAIDS.deployed(c,owner,visible))
	reserved.append_array(p.get("_ai_local_defense",[]))
	for u in army:
		if c.unit_data(u).role in ["detector","healer_detector"]:reserved.append(int(u.id));continue
		if not u.get("channel",{}).is_empty() or (not defend and float(u.get("self_repair_until",0))>c.time):reserved.append(int(u.id))
	if plan.drop:reserved.append_array(drops(c,owner,army,plan,home,goal,defend))
	if str(plan.style)=="nuclear":reserved.append_array(nuclear(c,owner,army,home,goal,visible,defend))
	reserved.append_array(preload("res://scripts/bot_harassment.gd").tick(c,owner,army,home,visible,defend,reserved))
	reserved.append_array(preload("res://scripts/bot_citrus_air_raids.gd").tick(c,owner,army,home,visible,defend,reserved))
	if int(p.difficulty)==5 and not defend and army.size()>=12 and c.time>=float(p.get("_ai_decisive_until",0)):
		var guards: Array=p.get("_ai_garrison",[]).filter(func(id):return army.any(func(u):return int(u.id)==int(id) and u.hp>0) and not int(id) in reserved)
		for u in army:
			if guards.size()>=2:break
			if int(u.id) in guards or int(u.id) in reserved or int(u.id) in p.get("_ai_wave",[]) or int(u.id) in p.get("_ai_marching",[]):continue
			if c.unit_data(u).role in ["rifle","assault","shield","swarm","spitter","guardian","archer","anti_air"]:guards.append(int(u.id))
		p._ai_garrison=guards
		for id in guards:
			var u=c.entity(int(id));var point=c.unit_free_position(int(u.race),int(u.kind),home+Vector2(0,5),int(u.id))
			if c.center(u).distance_to(point)>2:move(c,owner,u,point)
			elif u.order!="hold":c.command(owner,{"type":"hold","ids":[u.id]})
			reserved.append(int(id))
	return reserved

static func fortify(c,owner: int,workers: Array,bases: Array,available: Vector2) -> void:
	var p: Dictionary=c.players[owner]
	if c.time<float(p.get("_ai_fortify_next",0)):return
	p._ai_fortify_next=c.time+10
	var kind=10 if int(p.race)==1 else 11
	var d=ACData.building(int(p.race),kind)
	if available.x<float(d.as)+75 or available.y<float(d.tera) or not c.prerequisites(owner,d.requires):return
	if workers.any(func(w):return w.order=="build_move" and int(w.build_plan.kind)==kind):return
	for base in bases:
		var home=c.center(base)
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==kind and c.center(b).distance_to(home)<13):continue
		var ore=c.map.resources.filter(func(r):return r.type=="as" and ACData.point(r.pos).distance_to(home)<13)
		var axis=(Vector2(64,64)-home).normalized()
		if not ore.is_empty():axis=(ACData.point(ore[0].pos)-home).normalized()
		var center=home+axis*5
		for radius in [0,2,4,6]:
			for angle in range(8):
				var point=(center+Vector2.from_angle(angle*TAU/8)*radius).floor()
				if c.placement(owner,kind,point)!="":continue
				var builders=workers.filter(func(w):return not w.get("_ai_scouting",false) and not w.order in ["construct","build_move"] and w.build_queue.is_empty())
				if builders.is_empty():return
				builders.sort_custom(func(a,b):return c.center(a).distance_squared_to(point)<c.center(b).distance_squared_to(point))
				if c.command(owner,{"type":"build","ids":[builders[0].id],"kind":kind,"pos":ACData.packed(point)})=="":T.log_action(p,"home:defense_build")
				return

static func drops(c,owner: int,army: Array,plan: Dictionary,home: Vector2,goal: Vector2,defend: bool) -> Array:
	var p: Dictionary=c.players[owner];var missions: Array=p.get("_ai_missions",[]);var reserved=[]
	var carriers=army.filter(func(u):return int(u.kind)==int(plan.transport) and u.hp>0 and u.container<0)
	if not defend and str(p.get("_ai_attack_phase",""))!="decisive" and not p.get("_ai_sightings",{}).is_empty() and c.time>=float(p.get("_ai_drop_next",0)):
		for carrier in carriers:
			if missions.size()>=2 or missions.any(func(m):return int(m.carrier)==int(carrier.id)):continue
			var taken=[]
			for m in missions:taken.append_array(m.members)
			var busy: Array=p.get("_ai_wave",[])+p.get("_ai_marching",[])+p.get("_ai_garrison",[])+p.get("_ai_local_defense",[])
			var riders=army.filter(func(u):return u.hp>0 and u.container<0 and int(u.kind) in plan.payload and not int(u.id) in taken and not int(u.id) in busy and not u.get("_ai_scouting",false) and c.time-float(u.damaged)>3)
			riders.sort_custom(func(a,b):return c.center(a).distance_squared_to(c.center(carrier))<c.center(b).distance_squared_to(c.center(carrier)))
			var members=[];var population=0.0
			for u in riders:
				var pop=float(c.unit_data(u).pop)
				if population+pop>8:continue
				members.append(int(u.id));population+=pop
				if population>=7:break
			if members.is_empty():continue
			var payload=members.map(func(id):return c.entity(int(id)))
			var land=landing(c,carrier,payload,goal,home)
			if not land.is_finite():continue
			missions.append({"carrier":int(carrier.id),"members":members,"phase":"load","started":c.time,"phase_at":c.time,"goal":ACData.packed(goal),"landing":ACData.packed(land),"home":ACData.packed(home)})
			p._ai_drop_next=c.time+35;T.log_action(p,"drop:prepare")
	var kept=[]
	for m in missions:
		var carrier=c.entity(int(m.carrier))
		if carrier.is_empty() or carrier.hp<=0 or int(carrier.owner)!=owner:continue
		var riders=m.members.map(func(id):return c.entity(int(id))).filter(func(u):return not u.is_empty() and u.hp>0 and int(u.owner)==owner)
		if defend:m.phase="return"
		if c.time-float(m.started)>150:m.phase="return"
		if carrier.hp<float(c.unit_data(carrier).hp)*.4:m.phase="return"
		reserved.append(int(carrier.id))
		for u in riders:reserved.append(int(u.id))
		var point=ACData.point(m.landing)
		match str(m.phase):
			"load":
				if carrier.order!="hold":c.command(owner,{"type":"hold","ids":[carrier.id]})
				for u in riders:
					if u.container<0:board(c,owner,u,carrier)
				if not carrier.cargo.is_empty() and (riders.all(func(u):return int(u.container)==int(carrier.id)) or c.time-float(m.phase_at)>30):
					m.phase="travel";m.phase_at=c.time;T.log_action(p,"drop:launch")
				elif c.time-float(m.phase_at)>45:m.phase="return"
			"travel":
				if air_risk(c,owner,point)>4:m.phase="return"
				else:
					var waypoint=point
					var middle=c.center(carrier).lerp(point,.5)
					if air_risk(c,owner,middle)>3:
						waypoint=(middle+(point-c.center(carrier)).normalized().orthogonal()*14).clamp(Vector2(2,2),Vector2(125,125))
					move(c,owner,carrier,waypoint)
					if c.center(carrier).distance_to(point)<1.2:m.phase="unload";m.phase_at=c.time
			"unload":
				if riders.any(func(u):return not c._ground_fits_size(c._body_size(u),c.center(carrier))):m.phase="return"
				else:
					if carrier.order!="hold":c.command(owner,{"type":"hold","ids":[carrier.id]})
					for id in carrier.cargo.duplicate():c.command(owner,{"type":"unload_one","id":carrier.id,"passenger":id})
					if carrier.cargo.is_empty():
						var ids=RAIDS.detach(c,owner,riders)
						if not p.has("_ai_deployed_raids"):p._ai_deployed_raids=[]
						p._ai_deployed_raids.append({"members":ids,"goal":m.goal,"started":c.time})
						m.members=[];m.phase="return";m.phase_at=c.time;p._ai_has_attacked=true;T.log_action(p,"drop:unload")
			"fight":
				for u in riders:
					var d=c.unit_data(u)
					if int(u.race)==0 and d.role=="siege" and c.center(u).distance_to(ACData.point(m.goal))<ACData.attack_range(d,true) and not u.anchored and float(u.get("deploy_until",0))<=c.time:
						c.command(owner,{"type":"ability","ids":[u.id]})
					elif not u.anchored:move(c,owner,u,ACData.point(m.goal),true)
				if c.time-float(m.phase_at)>18 or riders.size()<maxi(1,ceili(m.members.size()*.5)):m.phase="extract";m.phase_at=c.time;T.log_action(p,"drop:extract")
			"extract":
				if carrier.order!="hold":c.command(owner,{"type":"hold","ids":[carrier.id]})
				for u in riders:
					if u.container<0:board(c,owner,u,carrier)
				if riders.all(func(u):return u.container>=0) or c.time-float(m.phase_at)>16:m.phase="return"
			"return":
				var back=home+Vector2(0,5)
				move(c,owner,carrier,back)
				if defend:
					for u in riders:
						if u.container<0:reserved.erase(int(u.id))
				if c.center(carrier).distance_to(back)<2:
					for id in carrier.cargo.duplicate():c.command(owner,{"type":"unload_one","id":carrier.id,"passenger":id})
					if carrier.cargo.is_empty():T.log_action(p,"drop:return");continue
		kept.append(m)
	p._ai_missions=kept
	return reserved

static func board(c,owner: int,u: Dictionary,carrier: Dictionary) -> void:
	if float(u.get("deploy_until",0))>c.time:return
	if u.anchored:
		c.command(owner,{"type":"ability","ids":[u.id]});return
	if u.order!="load" or int(u.target)!=int(carrier.id):c.command(owner,{"type":"context","ids":[u.id],"target":carrier.id})

static func nuclear_value(c,point: Vector2,visible: Array) -> float:
	return visible.filter(func(e):return c.center(e).distance_to(point)<7).reduce(func(sum,e):return sum+float(c.unit_data(e).get("as",0))+float(c.unit_data(e).get("tera",0))*1.5+(300 if e.has("progress") and int(e.kind)==0 else 0),0.0)

static func nuclear(c,owner: int,army: Array,home: Vector2,goal: Vector2,visible: Array,defend: bool) -> Array:
	var p: Dictionary=c.players[owner];var reserved=[]
	var point=ACData.point(p.get("_ai_nuclear_point",[-999,-999]))
	if c.time<float(p.get("_ai_nuclear_until",0)):
		var guide=c.entity(int(p.get("_ai_nuclear_caster",-1)))
		if not guide.is_empty() and guide.hp>0 and int(guide.owner)==owner:
			reserved.append(int(guide.id))
			if guide.get("channel",{}).is_empty() and guide.order!="hold":c.command(owner,{"type":"hold","ids":[guide.id]})
		for u in c.units:
			if u.hp<=0 or int(u.owner)!=owner or u.container>=0:continue
			if not u.get("channel",{}).is_empty():reserved.append(int(u.id));continue
			if c.center(u).distance_to(point)<10:
				var axis=(c.center(u)-point).normalized()
				if axis.length_squared()<.1:axis=(home-point).normalized()
				move(c,int(u.owner),u,(point+axis*12).clamp(Vector2.ONE,Vector2(126,126)));reserved.append(int(u.id))
		return reserved
	if defend or int(p.get("nukes",0))<=0 or ACResearch.level(p,"nuclear")<=0:return reserved
	var scouts=army.filter(func(u):return int(u.kind)==7 and u.hp>0 and u.container<0)
	for scout in scouts:
		var candidates=visible.filter(func(e):return c.center(e).distance_to(c.center(scout))<=12 and c.center(e).distance_to(home)>22)
		candidates.sort_custom(func(a,b):return nuclear_value(c,c.center(a),visible)>nuclear_value(c,c.center(b),visible) or is_equal_approx(nuclear_value(c,c.center(a),visible),nuclear_value(c,c.center(b),visible)) and a.has("progress") and not b.has("progress"))
		for target in candidates:
			point=c.center(target)
			var value=nuclear_value(c,point,visible)
			if value<450:continue
			if c.buildings.any(func(b):return b.hp>0 and c.allied(owner,int(b.owner)) and c.center(b).distance_to(point)<11):continue
			if c.units.any(func(u):return u.hp>0 and c.allied(owner,int(u.owner)) and u.container<0 and c.center(u).distance_to(point)<10):
				p._ai_nuclear_point=ACData.packed(point);p._ai_nuclear_until=c.time+3;p._ai_nuclear_caster=int(scout.id)
				return nuclear(c,owner,army,home,goal,[],false)
			if c.command(owner,{"type":"skill","skill":"nuclear","ids":[scout.id],"pos":ACData.packed(point)})=="":
				p._ai_nuclear_point=ACData.packed(point);p._ai_nuclear_until=c.time+18.5;p._ai_nuclear_caster=int(scout.id);reserved.append(int(scout.id));T.log_action(p,"nuclear:launch");return reserved
	return reserved

static func forward_build(c,owner: int,workers: Array,plan: Dictionary,stage: Vector2) -> void:
	var p: Dictionary=c.players[owner]
	if not plan.forward or workers.is_empty() or c.time<float(p.get("_ai_forward_next",0)):return
	p._ai_forward_next=c.time+8
	var kinds=[12,10,11] if int(p.race)==1 else [2,11,12]
	for kind in kinds:
		if not c.prerequisites(owner,ACData.building(int(p.race),kind).requires):continue
		if c.buildings.any(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==kind and c.center(b).distance_to(stage)<13):continue
		if workers.any(func(w):return w.order=="build_move" and int(w.build_plan.kind)==kind):return
		var center=stage
		if int(p.race)==1 and kind==12:
			var sources=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and b.progress>=1 and int(b.kind) in [0,12])
			if sources.is_empty():return
			sources.sort_custom(func(a,b):return c.center(a).distance_squared_to(stage)<c.center(b).distance_squared_to(stage))
			var origin=c.center(sources[0]);center=origin+(stage-origin).normalized()*8
		for radius in [0,3,6,9]:
			for angle in range(8):
				var point=(center+Vector2.from_angle(angle*TAU/8)*radius).floor()
				if c.placement(owner,kind,point)!="":continue
				var candidates=workers.filter(func(w):return not w.get("_ai_scouting",false) and not w.order in ["construct","build_move"] and w.build_queue.is_empty())
				if candidates.is_empty():return
				candidates.sort_custom(func(a,b):return c.center(a).distance_squared_to(point)<c.center(b).distance_squared_to(point))
				if c.command(owner,{"type":"build","ids":[candidates[0].id],"kind":kind,"pos":ACData.packed(point)})=="":T.log_action(p,"forward:build")
				return

static func after_combat(c,owner: int,army: Array,plan: Dictionary,visible: Array,home: Vector2,goal: Vector2,defend: bool) -> void:
	var p: Dictionary=c.players[owner];var wave: Array=p.get("_ai_wave",[])
	var decisive=not defend and str(p.get("_ai_attack_phase",""))=="decisive"
	var committed=army.filter(func(u):return int(u.id) in wave and u.hp>0 and u.container<0)
	var front=committed.filter(func(u):return float(c.unit_data(u).damage)>0 and "g" in str(c.unit_data(u).targets) or c.unit_data(u).role=="carrier")
	for u in army:
		if int(u.get("_ai_expendable_owner",-1))==owner or int(u.id) in p.get("_ai_claw_pending",[]):continue
		if int(u.id) in p.get("_ai_bat_raid",{}).get("members",[]) or int(u.id) in p.get("_ai_mobile_raid",{}).get("members",[]):continue
		if int(u.id) in p.get("_ai_assault_raid",{}).get("members",[]):continue
		if int(u.id) in p.get("_ai_claw_raid",{}).get("members",[]):continue
		if u.hp<=0 or u.container>=0 or not u.get("channel",{}).is_empty() or float(u.get("self_repair_until",0))>c.time:continue
		if c.time<float(u.get("_ai_kite_until",0)):continue
		var d=c.unit_data(u)
		if d.role in ["detector","healer_detector"]:continue
		if d.role=="transport" and not int(u.id) in wave:continue
		if d.role in ["siege","fortress","tree"] and ACData.can_deploy(d) and not d.air and float(u.get("deploy_until",0))<=c.time:
			var target=visible.filter(func(e):return c._can_attack(d,e) and c.center(u).distance_to(c.center(e))<=ACData.attack_range(d,true)*.95)
			var want=(defend or int(u.id) in wave) and not target.is_empty()
			if want:u.erase("_ai_siege_empty_since")
			elif u.anchored:
				if not u.has("_ai_siege_empty_since"):u._ai_siege_empty_since=c.time
				want=c.time<float(u.get("_ai_siege_hold_until",0)) or c.time-float(u._ai_siege_empty_since)<2.5
			if want!=bool(u.anchored) and c.command(owner,{"type":"ability","ids":[u.id]})=="":
				if want:u._ai_siege_hold_until=c.time+5
		if not int(u.id) in wave or defend:continue
		if not decisive and bool(plan.split) and d.air:
			var side=(goal-home).normalized().orthogonal()*10
			var flank=(goal+side).clamp(Vector2(2,2),Vector2(125,125))
			if not u.has("_ai_flank_target") or ACData.point(u._ai_flank_target).distance_to(goal)>6:
				u._ai_flank_target=ACData.packed(goal);u._ai_flank_done=false
			if c.center(u).distance_to(flank)<3:u._ai_flank_done=true
			move(c,owner,u,goal if u.get("_ai_flank_done",false) else flank,true)
		elif not decisive and str(plan.style) in ["raid","air_raid","expand_raid","mobile","stealth"] and c.center(u).distance_to(goal)<5:
			var points=[]
			for item in p.get("_ai_sightings",{}).values():
				if item.building and int(item.kind)==0 and ACData.point(item.pos).distance_to(goal)>12:points.append(ACData.point(item.pos))
			if not points.is_empty() and c.time>=float(p.get("_ai_raid_next",0)):p._ai_raid_next=c.time+18;p._ai_raid_goal=ACData.packed(points[0])
			if p.has("_ai_raid_goal"):move(c,owner,u,ACData.point(p._ai_raid_goal),true)
		if d.role in ["medic","priest","healer_detector","detector"] and not front.is_empty():
			var leader=front[0];var point=c.center(leader)+(home-c.center(leader)).normalized()*2.5
			move(c,owner,u,point)
		if d.air and "a" in str(d.targets) and not "g" in str(d.targets):
			var enemies=visible.filter(func(e):return not e.has("progress") and c.unit_data(e).air and c.center(e).distance_to(c.center(u))<12)
			if not enemies.is_empty() and (u.order!="attack" or int(u.target)!=int(enemies[0].id)):c.command(owner,{"type":"attack","ids":[u.id],"target":enemies[0].id})
			elif enemies.is_empty() and not front.is_empty():
				var leader=front[0]
				move(c,owner,u,c.center(leader)+(home-c.center(leader)).normalized()*3)
