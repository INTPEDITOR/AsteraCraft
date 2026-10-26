extends RefCounted

static func band(d: Dictionary) -> int:
	if str(d.role) in ["medic","priest","healer_detector","detector"]:return 3
	if str(d.role) in ["siege","fortress","tree"] and float(d.range)>=3:return 2
	if float(d.range)<=1.5 and str(d.role)!="suicide":return 0
	return 1

static func worthwhile_bomb(c,u: Dictionary,target: Dictionary,visible: Array=[]) -> bool:
	if target.is_empty() or target.hp<=0:return false
	var d=c.unit_data(u);var radius=float(d.get("splash_radius",2.3));var victims=visible if not visible.is_empty() else c._query_entities(c.center(target),radius)
	var count=0;var health=0.0
	for e in victims:
		if e.hp<=0 or e.has("progress") or c.allied(int(u.owner),int(e.owner)) or not c.can_see(int(u.owner),e) or not c._can_attack(d,e) or c.center(e).distance_squared_to(c.center(target))>radius*radius:continue
		count+=1;health+=maxf(0,float(e.hp))+maxf(0,float(e.shield))
	if count>=2 and health>=float(d.damage)*.7:return true
	if target.has("progress"):return false
	var enemy=c.unit_data(target)
	return float(enemy.as)+float(enemy.tera)*1.5>=200 and float(target.hp)+float(target.shield)>=minf(70,float(d.damage)*.7)

static func target_score(c,u: Dictionary,target: Dictionary,visible: Array,clusters: Dictionary={}) -> float:
	var d=c.unit_data(u);var enemy=c.unit_data(target);var structure=target.has("progress")
	var damage=maxf(1,float(d.damage)+float(d.get("bonus_"+str(enemy.get("armor_class","heavy" if structure else "light")),0))-float(enemy.get("armor",0)))
	var health=maxf(1,float(target.hp)+float(target.get("shield",0)))
	var value=health/damage*maxf(.1,float(d.period))+c.center(u).distance_to(c.center(target))*.35+(80 if structure else 0)
	if float(d.range)<=1.5:value+=c.center(u).distance_to(c.center(target))*5
	if str(d.role)=="flamer" and (str(enemy.get("armor_class",""))=="light" or str(enemy.get("role",""))=="worker"):value*=.6
	if float(d.get("splash_radius",0))>0:
		var radius=float(d.splash_radius)
		var cache_key=Vector2(radius,int(target.id))
		if not clusters.has(cache_key):clusters[cache_key]=visible.filter(func(e):return e.hp>0 and not e.has("progress") and c.center(e).distance_squared_to(c.center(target))<=radius*radius).size()
		var group=int(clusters[cache_key])
		value/=1+minf(1.5,maxi(0,group-1)*.35)
	if str(d.role)=="suicide" and not worthwhile_bomb(c,u,target,visible):return INF
	return value

static func spread(c,owner: int,army: Array,visible: Array,wave: Array,defend: bool) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<3 or c.time<float(p.get("_ai_spread_next",0)):return false
	p._ai_spread_next=c.time+.8
	var threats=visible.filter(func(e):return e.hp>0 and not e.has("progress") and float(c.unit_data(e).get("splash_radius",0))>=.8)
	if threats.is_empty():return false
	for u in army:
		var d=c.unit_data(u)
		if u.hp<=0 or u.anchored or u.container>=0 or not defend and not int(u.id) in wave or c.time<float(u.get("_ai_kite_until",0)):continue
		if not threats.any(func(e):return c._can_attack(c.unit_data(e),u) and c.center(e).distance_to(c.center(u))<ACData.attack_range(c.unit_data(e),bool(e.anchored))+4):continue
		var nearby=army.filter(func(a):return a.hp>0 and int(a.id)!=int(u.id) and c.center(a).distance_squared_to(c.center(u))<3.24)
		if nearby.size()<2:continue
		var middle=Vector2.ZERO
		for a in nearby:middle+=c.center(a)
		middle/=nearby.size();var away=(c.center(u)-middle).normalized()
		if away.length_squared()<.01:away=Vector2.RIGHT.rotated(float(int(u.id)%8)*TAU/8)
		for turn in [0,.7,-.7]:
			var point=c.center(u)+away.rotated(turn)*2
			if not d.air and (not c._ground_sweep(c._body_size(u),c.center(u),point) or not c._unit_fits(u,point,false)):continue
			if c.command(owner,{"type":"move","ids":[u.id],"pos":ACData.packed(point)})=="":u._ai_kite_until=c.time+.55;return true
	return false
