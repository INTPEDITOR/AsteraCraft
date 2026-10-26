class_name ACBurstWeapon
extends RefCounted

static func cancel(u: Dictionary) -> void:
	if not u.has("burst_left"):return
	u.burst_left=0;u.burst_target=-1

static func shoot(c,u: Dictionary,target: Dictionary) -> void:
	var d: Dictionary=u._definition
	var count=maxi(1,int(d.get("burst_count",1)))
	var split=bool(d.get("burst_split_total",false))
	var base=float(d.damage)/count if split else float(d.damage)
	u.facing=ACData.packed((c.center(target)-c.center(u)).normalized())
	u.turret_direction=u.facing.duplicate();u._aiming=true
	c._damage(u,target,base+float(c.players[u.owner].attack)*2.0/count,true,"attack",1.0/count,1.0/count if split else 1.0)
	c._attack_splash(u,target,base,1.0/count,1.0/count if split else 1.0,1.0/count)
	u.burst_shot=int(u.get("burst_shot",0))+1
	u.fired=c.time
	c._set_action(u,"attack",true)

static func start(c,u: Dictionary,target: Dictionary) -> void:
	u.burst_owner=int(u.owner);u.burst_target=int(target.id)
	u.burst_shot=0
	u.burst_left=maxi(0,int(u._definition.get("burst_count",1))-1)
	u.burst_at=c.time+float(u._definition.get("burst_interval",.12))
	shoot(c,u,target)

static func tick(c,u: Dictionary) -> bool:
	if int(u.get("burst_left",0))<=0:return false
	var target: Dictionary=c.entity(int(u.burst_target))
	if u.owner!=u.burst_owner or u.order not in ["attack","attack_move","idle","hold"] or target.is_empty() or target.hp<=0 or not c.attack_target_allowed(u,target) or not c.can_see(int(u.owner),target) or not c._can_attack(u._definition,target):
		cancel(u);return false
	if u.order=="attack" and int(u.target)!=int(target.id):cancel(u);return false
	var reach=float(u._definition.range)+.25
	if u.anchored and ACData.can_deploy(u._definition) and u._definition.role in ["siege","fortress"]:reach+=3
	if target.has("progress"):
		var building=ACData.building(int(target.race),int(target.kind));reach+=minf(building.w,building.h)*.45
	if c.center(u).distance_to(c.center(target))>reach:cancel(u);return false
	u._aiming=true;u.facing=ACData.packed((c.center(target)-c.center(u)).normalized());u.turret_direction=u.facing.duplicate()
	while int(u.burst_left)>0 and c.time+.00001>=float(u.burst_at):
		shoot(c,u,target);u.burst_left-=1;u.burst_at+=float(u._definition.get("burst_interval",.12))
		if target.hp<=0:cancel(u);break
	return true
