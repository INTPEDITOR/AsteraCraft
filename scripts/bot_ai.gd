extends RefCounted
## Deterministic, resource-paying bot. Terrain is public; enemy decisions use
## current sight only. Difficulty changes planning and reaction, not income.
const NAMES=["매우 쉬움","쉬움","보통","어려움","매우어려움","헬"]
const PROFILES=[
	{"interval":6.0,"workers":8,"attack":14,"assembly":1.0,"expand":480.0,"expand_workers":8,"bases":2,"retreat":.0,"tech":3,"miners":1,"production":1,"focus":false},
	{"interval":4.5,"workers":12,"attack":12,"assembly":.9,"expand":360.0,"expand_workers":10,"bases":2,"retreat":.0,"tech":5,"miners":2,"production":1,"focus":false},
	{"interval":2.5,"workers":16,"attack":10,"assembly":.85,"expand":210.0,"expand_workers":14,"bases":3,"retreat":.22,"tech":9,"miners":2,"production":1,"focus":false},
	{"interval":1.0,"workers":18,"attack":8,"assembly":.8,"expand":160.0,"expand_workers":14,"bases":4,"retreat":.32,"tech":12,"miners":2.25,"production":1,"focus":false},
	{"interval":.65,"workers":22,"attack":6,"assembly":.75,"expand":120.0,"expand_workers":12,"bases":5,"retreat":.35,"tech":12,"miners":3,"production":2,"focus":true},
	{"interval":.35,"workers":24,"attack":4,"assembly":.7,"expand":90.0,"expand_workers":10,"bases":6,"retreat":.38,"tech":12,"miners":3,"production":3,"focus":true}]

static func tick(c, owner: int) -> void:
	var p: Dictionary=c.players[owner]
	var level=clampi(int(p.difficulty),0,PROFILES.size()-1)
	var profile: Dictionary=PROFILES[level]
	if c.time<float(p.get("_ai_next",0)):return
	p._ai_next=c.time+float(profile.interval)
	var race=int(p.race)
	var workers: Array=[];var army: Array=[];var bases: Array=[]
	for u in c.units:
		if int(u.owner)!=owner or u.hp<=0 or u.get("technical",false):continue
		if int(u.kind)==0:workers.append(u)
		else:army.append(u)
	for b in c.buildings:
		if int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1:bases.append(b)
	if bases.is_empty():return
	var hq: Dictionary=c.entity(int(p.home))
	if hq.is_empty() or hq.hp<=0:hq=bases[0];p.home=hq.id
	var opening_attack_done=bool(p.get("_ai_has_attacked",false))
	# Preserve the budget and assignment while a worker travels to a new site.
	# A pending order is not yet a building and must not be issued every tick.
	# Travelling builders must not suspend combat and economic decisions.
	for u in workers:
		if u.order=="idle":
			u.order="gather";u.target=c.nearest_resource(c.center(u),"as",owner)
	# Repair interrupted sites before paying for more foundations.
	for b in c.buildings:
		if int(b.owner)!=owner or b.hp<=0 or b.progress>=1 or (race!=0 and b.get("initiated",false)):continue
		var w: Dictionary=c.entity(int(b.worker))
		if not w.is_empty() and w.hp>0 and w.order=="construct" and int(w.target)==int(b.id):continue
		var replacement=builder(c,workers,c.center(b))
		if not replacement.is_empty():
			c._release_mining_claim(replacement)
			b.worker=replacement.id;replacement.order="construct";replacement.target=b.id;replacement.path=[];replacement.approach_target=-1
	# Supply may still be sufficient after a local tower is destroyed. Restore
	# the actual factory's coverage before spending its replacement budget.
	if race==2:
		for b in c.buildings:
			if int(b.owner)==owner and b.hp>0 and not c.building_powered(b):
				power_site(c,owner,workers,ACData.point(b.pos),int(b.kind))
	var queued_workers=0
	for b in bases:
		for q in b.queue:
			if int(q.kind)==0:queued_workers+=1
	var target_workers=0
	for b in bases:
		var patches=0
		for r in c.map.resources:
			if r.type=="as" and r.amount>0 and ACData.point(r.pos).distance_to(c.center(b))<13:patches+=1
		target_workers+=mini(int(profile.workers),ceili(patches*float(profile.miners)))
	# Share a modest opening economy, then scale it after the first wave.
	# Otherwise fast planners buy workers at the expense of their first army.
	if not opening_attack_done:target_workers=mini(target_workers,8)
	for b in bases:
		if workers.size()+queued_workers>=target_workers:break
		if b.queue.size()>=2:continue
		# Real source bases have longer, asymmetric mining routes. Reserve the
		# opening combat budget before repeatedly filling the worker queue.
		if race!=1 and workers.size()+queued_workers>=8 and army.size()<2:continue
		# Preserve the shared brood pool for combat once an opening economy exists.
		if race==1 and workers.size()>=8 and army.size()<workers.size()/2 and int(b.larva)<2:continue
		var worker_data=ACData.unit(race,0)
		var worker_budget=available_resources(c,owner)
		if worker_budget.x<float(worker_data.as) or worker_budget.y<float(worker_data.tera):continue
		if c.command(owner,{"type":"train","id":b.id,"kind":0})=="":queued_workers+=1
	if p.cap-p.used-p.reserved<5 and p.cap<200:build(c,owner,2)
	# Save for an expansion instead of spending the last minerals on another
	# production batch every planning turn. Active foundations already reserve it.
	var pending_base=c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1)
	if opening_attack_done and not pending_base and army.size()>=4 and c.time>=float(profile.expand) and workers.size()>=int(profile.expand_workers) and bases.size()<int(profile.bases):
		var option=expansion_site(c,owner,workers,hq)
		if not option.is_empty():
			var cost=float(ACData.building(race,0).get("as",400))
			if available_resources(c,owner).x>=cost+50:expand(c,owner,workers,hq)
			else:
				var threats: Array=[]
				for e in c.units+c.buildings:
					if e.hp>0 and not c.allied(owner,int(e.owner)) and c.can_see(owner,e):threats.append(e)
				combat(c,owner,army,bases,threats,profile)
				return
	var opening=[2,3,1,7,4,6,9,5,8,10] if race==0 else ([2,4,1,3,5,6,8,7,9] if race==1 else [2,3,1,4,6,7,5,8,10,9])
	# An expensive tech chain must not postpone the first fighting force.
	var tech_limit=mini(int(profile.tech),3 if not opening_attack_done or army.size()<6 else 5 if army.size()<12 else int(profile.tech))
	for kind in opening.slice(0,tech_limit):
		if c.has_building(owner,kind):continue
		if c.prerequisites(owner,ACData.building(race,kind).requires):build(c,owner,kind)
		break
	if opening_attack_done and int(profile.production)>1 and army.size()>=6 and c.time>=60:
		var producers=[3] if race==1 else []
		if race!=1:
			for kind in range(1,ACData.unit_count(race)):
				var producer=int(ACData.unit(race,kind).producer)
				if producer>1 and not producer in producers:producers.append(producer)
		for kind in producers:
			var count=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==kind and b.hp>0).size()
			if count>0 and count<int(profile.production) and c.prerequisites(owner,ACData.building(race,kind).requires):
				build(c,owner,kind);break
	var visible: Array=[]
	for enemy in c.units+c.buildings:
		if enemy.hp>0 and not c.allied(owner,int(enemy.owner)) and c.can_see(owner,enemy):visible.append(enemy)
	var enemy_air=0
	for e in visible:
		if not e.has("progress") and c.unit_data(e).air:enemy_air+=1
	for b in c.buildings:
		if int(b.owner)!=owner or b.progress<1 or b.hp<=0 or b.queue.size()>=2:continue
		if not c.building_powered(b):continue
		var choices: Array=[]
		var budget=available_resources(c,owner)
		var free_population=minf(200,float(p.cap))-float(p.used)-float(p.reserved)
		for kind in range(1,ACData.unit_count(race)):
			var d=ACData.unit(race,kind)
			if d.get("spawn_only",false):continue
			if (race!=1 and int(d.producer)!=int(b.kind)) or (race==1 and int(b.kind) not in [0,3]):continue
			if not c.prerequisites(owner,d.requires) or d.as>budget.x or d.tera>budget.y:continue
			if float(d.pop)*maxi(1,int(d.get("production_count",1)))>free_population:continue
			if d.role in ["transport","detector"] and army.size()<12:continue
			var count=0
			for u in army:
				if int(u.kind)==kind:count+=1
			var utility=4.0 if float(d.damage)>0 else .65
			if level>=2 and enemy_air>0 and "a" in str(d.targets):utility*=2.2
			choices.append({"kind":kind,"score":utility/(count+1)+c.rng.randf()*.2})
		choices.sort_custom(func(a,b):return a.score>b.score)
		if not choices.is_empty():c.command(owner,{"type":"train","id":b.id,"kind":choices[0].kind})
	# Upgrades compete for real resources and run in designated buildings only.
	if opening_attack_done and level>=2 and army.size()>=8 and available_resources(c,owner)==Vector2(p.as,p.tera):
		for b in c.buildings:
			if int(b.owner)!=owner or b.progress<1 or b.research!="":continue
			var choices=[]
			for item in ACResearch.catalog(int(b.race),int(b.kind)):
				if not item.has("unit_kind") or ACResearch.level(p,str(item.id))>0:continue
				var count=0
				for unit in c.units:
					if int(unit.owner)==owner and int(unit.race)==int(item.race) and int(unit.kind)==int(item.unit_kind) and unit.hp>0:count+=1
				if count>=(1 if ACData.unit(int(item.race),int(item.unit_kind)).role=="transport" else 3):choices.append(str(item.id))
			choices.append_array(["attack","armor","shield"])
			for stat in choices:
				if c.command(owner,{"type":"research","id":b.id,"stat":stat})=="":break
	var headquarters_cost=float(ACData.building(race,0).get("as",400))
	if opening_attack_done and c.time>=float(profile.expand) and workers.size()>=int(profile.expand_workers) and bases.size()<int(profile.bases) and available_resources(c,owner).x>=headquarters_cost+100:
		expand(c,owner,workers,hq)
	redistribute(c,owner,workers,bases)
	combat(c,owner,army,bases,visible,profile)

static func available_resources(c,owner: int) -> Vector2:
	var budget=Vector2(c.players[owner].as,c.players[owner].tera)
	# The game charges a foundation on arrival, so travelling plans need a
	# planning reservation. Never modify the player's real resource balance.
	for worker in c.units:
		if int(worker.owner)!=owner or worker.hp<=0 or worker.order!="build_move":continue
		var plan: Dictionary=worker.get("build_plan",{})
		if plan.is_empty():continue
		var definition=ACData.building(int(worker.race),int(plan.kind))
		budget-=Vector2(definition.as,definition.tera)
	return budget

static func builder(c,workers: Array,goal: Vector2) -> Dictionary:
	var best: Dictionary={};var distance=INF
	for u in workers:
		if u.hp<=0 or u.container>=0 or u.order in ["construct","build_move"] or not u.build_queue.is_empty():continue
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

static func build(c,owner: int,kind: int) -> bool:
	if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==kind):return false
	var race=int(c.players[owner].race);var d=ACData.building(race,kind)
	var budget=available_resources(c,owner)
	if budget.x<d.as or budget.y<d.tera:return false
	for b in c.buildings:
		if int(b.owner)==owner and int(b.kind)==kind and b.hp>0 and b.progress<1:return false
	var bases=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress>=1)
	var workers=c.units.filter(func(u):return int(u.owner)==owner and int(u.kind)==0 and u.hp>0)
	for hq in bases:
		var home: Vector2=c.center(hq)
		if kind==1:
			for node in c.map.resources:
				if node.type!="tera" or node.amount<=0 or ACData.point(node.pos).distance_to(home)>14:continue
				var anchor: Vector2=c.refinery_anchor(node)
				var placement_error: String=c.placement(owner,kind,anchor)
				if placement_error.contains("규율탑"):return power_site(c,owner,workers,anchor,kind)
				if placement_error!="":continue
				var worker=builder(c,workers,anchor)
				if not worker.is_empty():return c.command(owner,{"type":"build","kind":kind,"pos":ACData.packed(anchor),"ids":[worker.id]})==""
			continue
		for attempt in range(80):
			var pos=(home+Vector2(c.rng.randi_range(-10,9),c.rng.randi_range(-8,9))).floor()
			if pos.distance_to(home)<4 or blocks_lane(c,owner,pos,d) or c.placement(owner,kind,pos)!="":continue
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
	if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==0):return false
	for b in c.buildings:
		if int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1:return false
	var definition=ACData.building(int(c.players[owner].race),0)
	var budget=available_resources(c,owner)
	if budget.x<float(definition.as) or budget.y<float(definition.tera):return false
	var choice=expansion_site(c,owner,workers,hq)
	if choice.is_empty():return false
	if int(c.players[owner].race)==2 and c.placement(owner,0,ACData.point(choice.pos)).contains("규율탑"):
		return power_site(c,owner,workers,ACData.point(choice.pos),0)
	return c.command(owner,{"type":"build","kind":0,"pos":choice.pos,"ids":[choice.worker]})==""

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
			c._release_mining_claim(w);w.target=c.nearest_resource(c.center(bases[best]),"as",owner);w.path=[];w.approach_target=-1
			w.erase("mining_anchor");w.erase("mining_base")
			return

static func staging_safe(c,point: Vector2,visible: Array) -> bool:
	for enemy in visible:
		var d=ACData.building(int(enemy.race),int(enemy.kind)) if enemy.has("progress") else c.unit_data(enemy)
		var distance=c.footprint_distance(enemy,point) if enemy.has("progress") else c.center(enemy).distance_to(point)
		if distance<maxf(8,float(d.get("range",0))+4):return false
	return true

static func forward_staging(c,army: Array,home: Vector2,goal: Vector2,visible: Array,previous: Vector2) -> Vector2:
	var dimensions=Vector2.ZERO
	for u in army:
		if not c.unit_data(u).air:dimensions=dimensions.max(c._body_size(u))
	if previous.is_finite() and (dimensions==Vector2.ZERO or c._ground_fits_size(dimensions,previous)) and staging_safe(c,previous,visible):return previous
	var back=(home-goal).normalized()
	for distance in [16,20,24,28]:
		for angle in [0,.3,-.3,.6,-.6]:
			var point=(goal+back.rotated(angle)*distance).round().clamp(Vector2.ONE,Vector2(126,126))
			if not staging_safe(c,point,visible):continue
			if dimensions!=Vector2.ZERO:
				if not c._ground_fits_size(dimensions,point) or c.map.path(home,point).is_empty():continue
			return point
	return home

static func staging_slot(c,p: Dictionary,u: Dictionary,stage: Vector2,home: Vector2) -> Vector2:
	if not p.has("_ai_stage_slots"):p._ai_stage_slots={}
	var slots: Dictionary=p._ai_stage_slots;var id=int(u.id)
	if not slots.has(id):
		var index=0
		while slots.values().any(func(s):return int(s.index)==index):index+=1
		slots[id]={"index":index,"origin":[-999,-999],"pos":ACData.packed(stage)}
	var item: Dictionary=slots[id]
	if ACData.point(item.origin).distance_squared_to(stage)<.01:return ACData.point(item.pos)
	var back=(home-stage).normalized();var side=back.orthogonal();var index=int(item.index)
	var desired=(stage+side*float(index%7-3)*1.65+back*float(index/7)*1.65).clamp(Vector2.ONE,Vector2(126,126))
	var chosen=desired
	if not c.unit_data(u).air and not c._ground_fits_size(c._body_size(u),desired):
		var found=false
		for ring in range(1,7):
			for turn in range(12):
				var candidate=desired+Vector2.from_angle(float(turn)*TAU/12)*float(ring)*.5
				if c._ground_fits_size(c._body_size(u),candidate):chosen=candidate;found=true;break
			if found:break
		if not found:chosen=stage
	item.origin=ACData.packed(stage);item.pos=ACData.packed(chosen);return chosen

static func combat(c,owner: int,army: Array,bases: Array,visible: Array,profile: Dictionary) -> void:
	var p: Dictionary=c.players[owner];var home: Vector2=c.center(bases[0])
	army=army.filter(func(u):return int(u.get("container",-1))<0 and not (c.unit_data(u).role=="transport" and not c.unit_data(u).air))
	var target: Dictionary={};var defend=false;var distance=INF
	for enemy in visible:
		for hq in bases:
			var d: float=c.center(enemy).distance_to(c.center(hq))
			if d<18 and d<distance:distance=d;target=enemy;defend=true
	if not defend:
		for enemy in visible:
			if enemy.has("progress") and c.center(enemy).distance_to(home)<distance:distance=c.center(enemy).distance_to(home);target=enemy
	var slot=posmod(int(p.spawn_slot)+1+int(p.ai_goal),4)
	if slot==int(p.spawn_slot):p.ai_goal=(int(p.ai_goal)+1)%3;slot=posmod(int(p.spawn_slot)+1+int(p.ai_goal),4)
	var goal: Vector2=c.center(target) if not target.is_empty() else ACData.point(c.map.starts[slot])
	if target.is_empty():
		var tile=Vector2i(goal)
		if c.visibility[owner][tile.y*ACMap.SIZE+tile.x]>0:p.ai_goal=(int(p.ai_goal)+1)%3
	var rally: Vector2=c.map.nearest_free(home+(Vector2(63.5,63.5)-home).normalized()*7)
	var wave: Array=p.get("_ai_wave",[]).filter(func(id):
		var u=c.entity(int(id))
		return not u.is_empty() and u.hp>0 and int(u.owner)==owner and int(u.container)<0)
	if defend or (not p.get("_ai_wave",[]).is_empty() and wave.size()<maxi(3,ceili(int(p.get("_ai_wave_size",0))*.5))):
		wave=[];p._ai_cohort=[]
	var attack=not wave.is_empty()
	var old_stage=ACData.point(p.get("_ai_stage_pos",[-999,-999]))
	if not p.has("_ai_stage_goal") or ACData.point(p._ai_stage_goal).distance_squared_to(goal)>36:old_stage=Vector2.INF
	var stage=rally if defend else forward_staging(c,army,home,goal,visible,old_stage)
	p._ai_stage_pos=ACData.packed(stage);p._ai_stage_goal=ACData.packed(goal)
	if p.has("_ai_stage_slots"):
		for id in p._ai_stage_slots.keys():
			if not army.any(func(u):return int(u.id)==int(id)):p._ai_stage_slots.erase(id)
	var slots={}
	for u in army:
		if int(u.id) not in wave:slots[int(u.id)]=staging_slot(c,p,u,stage,home)
	var threshold=int(profile.attack)+mini(16,floori(c.time/600)*4)
	if not defend:
		var pool=army.filter(func(u):return int(u.id) not in wave and float(c.unit_data(u).damage)>0 and not (u.hp<float(c.unit_data(u).hp)*float(profile.retreat) and c.time-float(u.damaged)<5))
		var cohort: Array=p.get("_ai_cohort",[]).filter(func(id):return pool.any(func(u):return int(u.id)==int(id)))
		if cohort.size()<threshold and pool.size()>=threshold:
			pool.sort_custom(func(a,b):return c.center(a).distance_squared_to(stage)<c.center(b).distance_squared_to(stage))
			cohort=pool.slice(0,threshold).map(func(u):return int(u.id))
		p._ai_cohort=cohort
		var ready=cohort.filter(func(id):return c.center(c.entity(int(id))).distance_squared_to(slots[int(id)])<=3.0625)
		# Arrive in front of the enemy before committing. Late/slow units stay
		# with the next cohort instead of individually following a departed wave.
		if cohort.size()>=threshold and ready.size()==cohort.size():
			var departing=[]
			for u in army:
				if int(u.id) not in wave and c.center(u).distance_squared_to(slots[int(u.id)])<=3.0625:departing.append(int(u.id))
			wave.append_array(departing)
			p._ai_wave_size=wave.size();p._ai_has_attacked=true;attack=true;p._ai_cohort=[]
			c.command(owner,{"type":"attack_move","ids":departing,"pos":ACData.packed(goal),"formation":true})
			p._ai_wave_goal=ACData.packed(goal)
			for id in departing:p._ai_stage_slots.erase(int(id))
	if attack and ACData.point(p.get("_ai_wave_goal",ACData.packed(goal))).distance_squared_to(goal)>9:
		c.command(owner,{"type":"attack_move","ids":wave,"pos":ACData.packed(goal),"formation":true});p._ai_wave_goal=ACData.packed(goal)
	p._ai_wave=wave
	p._ai_attack_phase="defend" if defend else "push" if attack else "assemble"
	for u in army:
		var d=c.unit_data(u)
		if int(p.difficulty)>=2 and d.role=="parasite" and float(u.energy)>=200 and float(u.ability_cd)<=0:
			var choice: Dictionary={};var value=-1.0
			for enemy in visible:
				if enemy.has("progress") or enemy.hp<=0 or enemy.get("technical",false) or enemy.get("container",-1)>=0 or not enemy.get("cargo",[]).is_empty() or c.allied(owner,int(enemy.owner)):continue
				if c.center(u).distance_squared_to(c.center(enemy))>36:continue
				var ed=c.unit_data(enemy);var worth=float(ed.get("as",0))+float(ed.get("tera",0))*1.5
				if worth>value:value=worth;choice=enemy
			if not choice.is_empty():c._mind_control(u,int(choice.id))
		if int(p.difficulty)>=2 and int(u.race)==0 and int(u.kind)==7 and not u.get("cloak_active",false) and float(u.energy)>=30 and (attack or c.time-float(u.damaged)<5):c._ability(u,c.center(u))
		if not d.air and d.role=="transport":continue
		if float(u.hp)<float(d.hp)*float(profile.retreat) and c.time-float(u.damaged)<5:
			# A recovered straggler rejoins staging instead of walking back into
			# the departed wave alone when its short damage timer expires.
			wave.erase(int(u.id))
			if u.order!="move" or ACData.point(u.goal).distance_squared_to(rally)>1:c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(rally)})
			continue
		if int(p.difficulty)>=2 and d.role=="mage" and not target.is_empty() and c.center(u).distance_to(goal)<float(d.range)+2:c._ability(u,goal)
		if (defend or int(u.id) in wave) and bool(profile.get("focus",false)) and float(d.damage)>0:
			var focus: Dictionary={};var score=INF
			for enemy in visible:
				if not c._can_attack(d,enemy) or c.center(u).distance_to(c.center(enemy))>maxf(7,float(d.range)+2):continue
				var value=float(enemy.hp)+float(enemy.get("shield",0))+(1000 if enemy.has("progress") else 0)
				if value<score:score=value;focus=enemy
			if not focus.is_empty():
				if u.order!="attack" or int(u.target)!=int(focus.id):c.command(owner,{"type":"attack","ids":[u.id],"target":focus.id})
				continue
		if attack and int(u.id) in wave:
			if u.order in ["idle","hold"]:c.command(owner,{"type":"attack_move","ids":[u.id],"pos":ACData.packed(goal)})
			continue
		if defend:
			if u.order in ["idle","hold","move"] or ACData.point(u.goal).distance_squared_to(goal)>9:c.command(owner,{"type":"attack_move","ids":[u.id],"pos":ACData.packed(goal)})
			continue
		var destination: Vector2=slots[int(u.id)]
		if c.center(u).distance_squared_to(destination)<=1.44:
			if u.order!="hold":c.command(owner,{"type":"hold","ids":[u.id]})
		elif u.order!="move" or ACData.point(u.goal).distance_squared_to(destination)>.25:
			c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(destination)})
