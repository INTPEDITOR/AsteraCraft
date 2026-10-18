extends RefCounted
## Deterministic, resource-paying bot. Terrain is public; enemy decisions use
## current sight only. Difficulty changes planning and reaction, not income.
const PROFILES=[
	{"interval":4.5,"workers":12,"attack":16,"expand":360.0,"bases":2,"retreat":.0,"tech":5},
	{"interval":2.5,"workers":16,"attack":12,"expand":210.0,"bases":3,"retreat":.22,"tech":9},
	{"interval":1.0,"workers":18,"attack":9,"expand":160.0,"bases":4,"retreat":.32,"tech":12}]

static func tick(c, owner: int) -> void:
	var p: Dictionary=c.players[owner]
	var level=clampi(int(p.difficulty),0,2)
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
	# Preserve the budget and assignment while a worker travels to a new site.
	# A pending order is not yet a building and must not be issued every tick.
	if workers.any(func(w):return w.order=="build_move"):return
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
	var queued_workers=0
	for b in bases:
		for q in b.queue:
			if int(q.kind)==0:queued_workers+=1
	var target_workers=0
	for b in bases:
		var patches=0
		for r in c.map.resources:
			if r.type=="as" and r.amount>0 and ACData.point(r.pos).distance_to(c.center(b))<13:patches+=1
		target_workers+=mini(int(profile.workers),patches*2)
	for b in bases:
		if workers.size()+queued_workers>=target_workers:break
		if b.queue.size()>=2:continue
		# Real source bases have longer, asymmetric mining routes. Reserve the
		# opening combat budget before repeatedly filling the worker queue.
		if race!=1 and workers.size()+queued_workers>=8 and army.size()<2:continue
		# Preserve the shared brood pool for combat once an opening economy exists.
		if race==1 and workers.size()>=8 and army.size()<workers.size()/2 and int(b.larva)<2:continue
		if c.command(owner,{"type":"train","id":b.id,"kind":0})=="":queued_workers+=1
	if p.cap-p.used-p.reserved<5 and p.cap<200:build(c,owner,2)
	# Save for an expansion instead of spending the last minerals on another
	# production batch every planning turn. Active foundations already reserve it.
	var pending_base=c.buildings.any(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1)
	if not pending_base and army.size()>=4 and c.time>=float(profile.expand) and workers.size()>=int(profile.workers)-2 and bases.size()<int(profile.bases):
		var option=expansion_site(c,owner,workers,hq)
		if not option.is_empty():
			var cost=float(ACData.building(race,0).get("as",400))
			if p.as>=cost+50:expand(c,owner,workers,hq)
			else:
				var threats: Array=[]
				for e in c.units+c.buildings:
					if e.hp>0 and not c.allied(owner,int(e.owner)) and c.can_see(owner,e):threats.append(e)
				combat(c,owner,army,bases,threats,profile)
				return
	var opening=[2,3,1,7,4,6,9,5,8,10] if race==0 else ([2,4,1,3,5,6,8,7,9] if race==1 else [2,3,1,4,6,7,5,8,10,9])
	for kind in opening.slice(0,int(profile.tech)):
		if c.has_building(owner,kind):continue
		if c.prerequisites(owner,ACData.building(race,kind).requires):build(c,owner,kind)
		break
	var visible: Array=[]
	for enemy in c.units+c.buildings:
		if enemy.hp>0 and not c.allied(owner,int(enemy.owner)) and c.can_see(owner,enemy):visible.append(enemy)
	var enemy_air=0
	for e in visible:
		if not e.has("progress") and ACData.unit(int(e.race),int(e.kind)).air:enemy_air+=1
	for b in c.buildings:
		if int(b.owner)!=owner or b.progress<1 or b.hp<=0 or b.queue.size()>=2:continue
		var choices: Array=[]
		for kind in range(1,13):
			var d=ACData.unit(race,kind)
			if (race!=1 and int(d.producer)!=int(b.kind)) or (race==1 and int(b.kind) not in [0,3]):continue
			if not c.prerequisites(owner,d.requires) or d.as>p.as or d.tera>p.tera:continue
			if d.role in ["transport","detector"] and army.size()<12:continue
			var count=0
			for u in army:
				if int(u.kind)==kind:count+=1
			var utility=4.0 if float(d.damage)>0 else .65
			if level>0 and enemy_air>0 and "a" in str(d.targets):utility*=2.2
			choices.append({"kind":kind,"score":utility/(count+1)+c.rng.randf()*.2})
		choices.sort_custom(func(a,b):return a.score>b.score)
		if not choices.is_empty():c.command(owner,{"type":"train","id":b.id,"kind":choices[0].kind})
	# Upgrades compete for real resources and run in designated buildings only.
	if level>0 and army.size()>=8:
		for b in c.buildings:
			if int(b.owner)!=owner or b.progress<1 or b.research!="":continue
			for stat in ["attack","armor","shield"]:
				if c.command(owner,{"type":"research","id":b.id,"stat":stat})=="":break
	var headquarters_cost=float(ACData.building(race,0).get("as",400))
	if c.time>=float(profile.expand) and workers.size()>=int(profile.workers)-2 and bases.size()<int(profile.bases) and p.as>=headquarters_cost+100:
		expand(c,owner,workers,hq)
	redistribute(c,owner,workers,bases)
	combat(c,owner,army,bases,visible,profile)

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
	if c.players[owner].as<d.as or c.players[owner].tera<d.tera:return false
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
	if c.buildings.any(func(b):return b.owner==owner and b.kind==2 and b.hp>0 and b.progress<1 and c.center(b).distance_to(anchor)<10):return false
	var d=ACData.building(2,kind)
	for ring in range(3,8):
		for offset in [Vector2(ring,0),Vector2(-ring,0),Vector2(0,ring),Vector2(0,-ring),Vector2(ring,ring),Vector2(-ring,-ring)]:
			var pos=(anchor+offset).floor()
			if c.placement(owner,2,pos)!="" or blocks_lane(c,owner,pos,ACData.building(2,2)):continue
			var middle=pos+Vector2(1,1)
			var covered=true
			for corner in [anchor,anchor+Vector2(d.w-1,0),anchor+Vector2(0,d.h-1),anchor+Vector2(d.w-1,d.h-1)]:
				if middle.distance_to(corner)>11.5:covered=false
			if not covered:continue
			var worker=builder(c,workers,pos)
			if not worker.is_empty():return c.command(owner,{"type":"build","kind":2,"pos":ACData.packed(pos),"ids":[worker.id]})==""
	return false

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
		var origin: Vector2=c.map.nearest_free(c.center(worker))
		var approach: Vector2=c.map.nearest_free(site+Vector2(0,3))
		if approach.distance_to(site)>6:continue
		var path: Array=c.map.navigator.get_id_path(Vector2i(origin.round()),Vector2i(approach.round()))
		if path.is_empty():continue
		var value=float(path.size())+site.distance_to(c.center(hq))*.3
		if value>=score:continue
		for offset in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var anchor=(site-Vector2(d.w,d.h)*.5+offset).floor()
			var error: String=c.placement(owner,0,anchor)
			if error=="" or (int(c.players[owner].race)==2 and error.contains("규율탑")):
				best={"pos":ACData.packed(anchor),"worker":worker.id,"base":base};score=value;break
	return best

static func expand(c,owner: int,workers: Array,hq: Dictionary) -> bool:
	if c.units.any(func(w):return int(w.owner)==owner and w.hp>0 and w.order=="build_move" and int(w.build_plan.kind)==0):return false
	for b in c.buildings:
		if int(b.owner)==owner and int(b.kind)==0 and b.hp>0 and b.progress<1:return false
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
			return

static func combat(c,owner: int,army: Array,bases: Array,visible: Array,profile: Dictionary) -> void:
	var p: Dictionary=c.players[owner];var home: Vector2=c.center(bases[0])
	var target: Dictionary={};var defend=false;var distance=INF
	for enemy in visible:
		for hq in bases:
			var d: float=c.center(enemy).distance_to(c.center(hq))
			if d<18 and d<distance:distance=d;target=enemy;defend=true
	if not defend:
		for enemy in visible:
			if enemy.has("progress") and c.center(enemy).distance_to(home)<distance:distance=c.center(enemy).distance_to(home);target=enemy
	var fighting=0
	for u in army:
		if ACData.unit(int(u.race),int(u.kind)).damage>0:fighting+=1
	var attack=defend or fighting>=int(profile.attack)
	var slot=posmod(int(p.spawn_slot)+1+int(p.ai_goal),4)
	if slot==int(p.spawn_slot):p.ai_goal=(int(p.ai_goal)+1)%3;slot=posmod(int(p.spawn_slot)+1+int(p.ai_goal),4)
	var goal: Vector2=c.center(target) if not target.is_empty() else ACData.point(c.map.starts[slot])
	if target.is_empty():
		var tile=Vector2i(goal)
		if c.visibility[owner][tile.y*ACMap.SIZE+tile.x]>0:p.ai_goal=(int(p.ai_goal)+1)%3
	var rally: Vector2=c.map.nearest_free(home+(Vector2(63.5,63.5)-home).normalized()*7)
	for u in army:
		var d=ACData.unit(int(u.race),int(u.kind))
		if d.role=="parasite" and float(u.energy)>=100 and float(u.ability_cd)<=0:
			var choice: Dictionary={};var value=-1.0
			for enemy in visible:
				if enemy.has("progress") or enemy.hp<=0 or enemy.get("technical",false) or enemy.get("container",-1)>=0 or not enemy.get("cargo",[]).is_empty() or c.allied(owner,int(enemy.owner)):continue
				if c.center(u).distance_squared_to(c.center(enemy))>36:continue
				var ed=ACData.unit(int(enemy.race),int(enemy.kind));var worth=float(ed.get("as",0))+float(ed.get("tera",0))*1.5
				if worth>value:value=worth;choice=enemy
			if not choice.is_empty():c._mind_control(u,int(choice.id))
		if int(u.race)==0 and int(u.kind)==7 and not u.get("cloak_active",false) and float(u.energy)>=30 and (attack or c.time-float(u.damaged)<5):c._ability(u,c.center(u))
		if not d.air and d.role=="transport":continue
		if float(u.hp)<float(d.hp)*float(profile.retreat) and c.time-float(u.damaged)<5:
			if u.order!="move":u.order="move";u.goal=ACData.packed(rally);u.path=[]
			continue
		if defend or u.order in ["idle","hold"]:
			if not attack and c.center(u).distance_to(rally)<3:continue
			u.order="attack_move";u.goal=ACData.packed(goal if attack else rally);u.path=[]
		if int(p.difficulty)>0 and d.role=="mage" and not target.is_empty() and c.center(u).distance_to(goal)<float(d.range)+2:c._ability(u,goal)
