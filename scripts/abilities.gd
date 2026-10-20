class_name ACAbilities
extends RefCounted

static func catalog(race: int, kind: int) -> Array:
	return ACData.get_data().get("abilities",[]).filter(func(d):return int(d.race)==race and d.kinds.any(func(value):return int(value)==kind))

static func description(key: String) -> String:
	return {
		"stim":"아군 바이오닉 1기를 7초간 강화: 이동 +25%, 공격 주기 -25%.",
		"smoke":"6초간 연막 안 아군이 받는 일반 공격 피해 35% 감소.",
		"nuclear":"상승 4초 → 조준 11초 → 낙하 3초\n반경 5 · 최대 450 피해 · 유도 중 이동 불가",
		"scan":"8초 동안 반경 10의 시야를 확보합니다.",
		"overcharge":"0.5초 후 지정 지점 반경 1.5의 지상 적에게 100 피해.",
		"field_repair":"6초간 정지하여 초당 체력 25 회복. 이동 명령 시 중단.",
		"neural":"5초 동안 적 1기의 공격 주기를 40% 늘립니다.",
		"mind_control":"보이는 적 유닛 1기를 영구 전환. 건물·배양체·탑승객이 있는 수송선 제외.",
		"shed":"이동 둔화·구속 해제 및 3초간 이동·공격 강화.",
		"sap_heal":"자동 치료 켜기/끄기. 주변 귤 아군 1기의 체력을 초당 8 회복하며 마나를 초당 4 소모합니다. 기본 켜짐.",
		"sap_reclaim":"내 지상 유닛 1기를 소모하고 모즙체의 마나 75 회복. 자신·배양체·건물·탑승 중인 유닛·승객이 있는 수송선 제외. 마나가 가득 차면 사용 불가.",
		"sap_bloom":"반경 4 안의 주변 아군 유닛을 6초간 공격속도 25% 증가. 중복 사용해도 효과가 더해지지 않습니다.",
		"carapace":"6초간 받는 일반 공격 피해 45% 감소.",
		"scatter":"10초간 공격 주변에 추가 씨앗 범위 피해.",
		"root_surge":"뿌리 고정 중 사용. 지상 적에게 60 피해 및 2초 둔화.",
		"judgment":"1초 후 반경 1.6에 45 피해. 강화 연구: 반경 2.3, 피해 85.",
		"silence":"적 1기의 능력과 자동 회복을 4초간 봉인.",
		"bind":"적 1기 1.3초 이동 구속. 재구속 저항 4.5초.",
		"discipline":"6초간 반경 3 안의 적 이동 둔화.",
		"march":"주변 아군을 6초간 이동 속도 25% 증가.",
		"barrier":"아군 1기에게 6초 동안 피해 60 흡수 보호막.",
		"purify":"아군 1기의 이동 둔화·구속·공격 둔화를 해제.",
		"shockwave":"반경 2.2의 지상 적에게 45 피해 및 2초 둔화.",
		"pierce":"10초간 포탄이 표적 뒤의 지상 적을 관통.",
		"verdict":"1초 후 전방 길이 11의 광선에 닿은 적에게 180 피해."
	}.get(key,"")

static func unlocked(player: Dictionary, skill: Dictionary) -> bool:
	return bool(skill.get("base",false)) or ACResearch.level(player,str(skill.id))>0

static func command(c,owner: int,cmd: Dictionary) -> String:
	var accepted=false;var error="사용 가능한 유닛을 선택하세요"
	for id in cmd.get("ids",[]):
		var u=c.entity(int(id))
		if u.is_empty() or u.has("progress") or int(u.owner)!=owner or u.hp<=0 or u.container>=0:continue
		var result=use(c,u,str(cmd.get("skill","")),ACData.point(cmd.get("pos",u.pos)),int(cmd.get("target",-1)))
		if result=="":accepted=true
		else:error=result
	return "" if accepted else error

static func effect(c,u: Dictionary,kind: String,point: Vector2,duration: float=.65,extra: Dictionary={}) -> void:
	var payload={"skill":kind,"caster":int(u.id),"projectile":"skill"};payload.merge(extra,true)
	c._effect("skill",u,point,duration,payload)

static func use(c,u: Dictionary,key: String,point: Vector2,target_id: int=-1) -> String:
	var found=catalog(int(u.race),int(u.kind)).filter(func(s):return str(s.id)==key)
	if found.is_empty():return "이 유닛의 기술이 아닙니다"
	var s: Dictionary=found[0];var player: Dictionary=c.players[u.owner]
	if not unlocked(player,s):return "관련 건물에서 기술을 먼저 연구하세요"
	if float(u.get("silenced_until",0))>c.time:return "능력이 봉인되어 있습니다"
	if u.get("channel",{}).size()>0:return "유도 또는 시전 중입니다"
	if float(u.get("skill_ready",{}).get(key,0))>c.time:return "기술 재사용 대기 중입니다"
	if float(u.energy)<float(s.energy):return "에너지가 부족합니다"
	if not point.is_finite() or not c.map.inside(Vector2i(point)):return "맵 안의 위치를 지정하세요"
	var target=c.entity(target_id)
	if str(s.target) in ["ally","enemy"]:
		if target.is_empty() and target_id<0:
			for candidate in c._query_entities(point,2):
				if candidate.has("progress") or candidate.hp<=0 or candidate.get("container",-1)>=0:continue
				if (str(s.target)=="ally")==c.allied(int(u.owner),int(candidate.owner)) and c.can_see(int(u.owner),candidate):target=candidate;break
		if target.is_empty() or target.has("progress") or target.hp<=0 or target.get("container",-1)>=0:return "보이는 유닛을 지정하세요"
		if (str(s.target)=="ally")!=c.allied(int(u.owner),int(target.owner)) or not c.can_see(int(u.owner),target):return "대상 진영 또는 시야 조건이 맞지 않습니다"
		point=c.center(target)
	if str(s.target)!="self" and c.center(u).distance_to(point)>float(s.range):return "기술 사거리 밖입니다"
	if key=="mind_control":return c._mind_control(u,int(target.id))
	if key=="stim" and ACData.unit(int(target.race),int(target.kind)).get("material","")!="biological":return "바이오닉 유닛에게만 사용할 수 있습니다"
	if key=="bind" and float(target.get("control_guard_until",0))>c.time:return "대상이 구속 저항 중입니다"
	if key=="root_surge" and not u.anchored:return "뿌리내린 상태에서 사용하세요"
	if key=="nuclear" and int(player.get("nukes",0))<=0:return "전술정보국에서 핵미사일을 생산하세요"
	if key=="sap_reclaim":
		if int(target.owner)!=int(u.owner) or int(target.id)==int(u.id) or target.get("technical",false) or ACData.unit(int(target.race),int(target.kind)).air or not target.get("cargo",[]).is_empty():return "내 지상 유닛을 지정하세요 (자신·배양체·탑승 유닛 제외)"
		if float(u.energy)>=float(u.max_energy):return "마나가 이미 가득 찼습니다"
	u.energy-=float(s.energy)
	if not u.has("skill_ready"):u.skill_ready={}
	u.skill_ready[key]=c.time+float(s.cooldown)
	u.fired=c.time;u._aiming=true
	match key:
		"stim":target.stim_until=c.time+7
		"smoke","discipline":
			c.ability_zones.append({"owner":u.owner,"caster":u.id,"skill":key,"pos":ACData.packed(point),"until":c.time+6,"next":c.time})
			effect(c,u,key,point,6)
		"scan":
			c.reveals.append({"owner":u.owner,"pos":ACData.packed(point),"until":c.time+8,"radius":10,"detect":true})
			c.vision_clock=0;effect(c,u,key,point,8)
		"field_repair":u.self_repair_until=c.time+6;u.order="hold";u.path=[]
		"neural":target.attack_slow_until=c.time+5
		"shed":u.slow_until=0;u.rooted_until=0;u.stim_until=c.time+3
		"carapace":u.carapace_until=c.time+6
		"scatter":u.scatter_until=c.time+10
		"pierce":u.pierce_until=c.time+10
		"bind":target.rooted_until=c.time+1.3;target.control_guard_until=c.time+4.5
		"silence":target.silenced_until=c.time+4
		"barrier":target.ward=60.0;target.ward_until=c.time+6
		"purify":target.slow_until=0;target.rooted_until=0;target.attack_slow_until=0
		"march":
			for ally in c._query_entities(c.center(u),4):
				if not ally.has("progress") and c.allied(int(u.owner),int(ally.owner)):ally.march_until=c.time+6
		"sap_heal":
			u.sap_heal_enabled=not bool(u.get("sap_heal_enabled",true))
			if not u.sap_heal_enabled:u.healing=false;u.heal_target=-1;u.heal_kind=""
		"sap_reclaim":
			c._release_mining_claim(target)
			for b in c.buildings:
				if int(b.get("worker",-1))==int(target.id):b.worker=-1
			target.hp=0;target.healing=false;target.moving=false
			c._death_visual(target)
			c.collision_index_valid=false
			u.energy=minf(float(u.max_energy),float(u.energy)+75)
			c._recalculate_supply()
			effect(c,u,key,c.center(target),.9)
		"sap_bloom":
			for ally in c._query_entities(c.center(u),4):
				if not ally.has("progress") and ally.hp>0 and ally.get("container",-1)<0 and c.allied(int(u.owner),int(ally.owner)) and c.center(ally).distance_squared_to(c.center(u))<=16:ally.bloom_until=c.time+6
			effect(c,u,key,c.center(u),1.2,{"radius":4})
		"nuclear":
			player.nukes=int(player.nukes)-1
			var source=c.center(u);var stock: Dictionary={}
			if not player.get("nuke_stock",[]).is_empty():stock=player.nuke_stock.pop_front();source=ACData.point(stock.pos)
			else:
				for silo in c.buildings:
					if int(silo.owner)==int(u.owner) and int(silo.race)==0 and int(silo.kind)==8 and silo.hp>0 and silo.progress>=1:source=c.center(silo);break
			u.channel={"skill":key,"started":c.time,"until":c.time+15,"impact":c.time+18,"pos":ACData.packed(point),"source":ACData.packed(source),"stock":stock,"owner":u.owner}
			u.order="channel";u.path=[]
			c._effect("nuclear_marker",{"owner":u.owner,"race":0,"id":u.id,"pos":ACData.packed(point)},point,18,{"caster":u.id})
			c._effect("nuclear_ascent",{"owner":u.owner,"race":0,"pos":ACData.packed(source)},source,4,{"caster":u.id})
			c._effect("nuclear_notice",{"owner":u.owner,"race":0,"pos":[0,0]},Vector2.ZERO,3,{"global":true})
		"judgment","overcharge","root_surge","shockwave","verdict":
			var delay=1.0 if key in ["judgment","verdict"] else .5
			c.ability_events.append({"owner":u.owner,"caster":u.id,"skill":key,"when":c.time+delay,"pos":ACData.packed(point)})
			effect(c,u,key+"_warning",point,delay)
	if key not in ["nuclear","smoke","discipline","scan","sap_heal","sap_reclaim","sap_bloom","judgment","overcharge","root_surge","shockwave","verdict"]:effect(c,u,key,point if str(s.target)!="self" else c.center(u))
	return ""

static func update(c,dt: float) -> void:
	c.reveals=c.reveals.filter(func(r):return float(r.until)>c.time)
	for u in c.units:
		if float(u.get("ward_until",0))<=c.time:u.ward=0.0
		if float(u.get("self_repair_until",0))>c.time and u.hp>0:u.hp=minf(ACData.unit(int(u.race),int(u.kind)).hp,float(u.hp)+dt*25)
		var channel: Dictionary=u.get("channel",{})
		if channel.is_empty():continue
		if u.hp<=0 or u.order!="channel" or int(u.owner)!=int(channel.owner) or float(u.get("silenced_until",0))>c.time:
			if c.time<float(channel.started)+4:
				c.players[channel.owner].nukes=int(c.players[channel.owner].get("nukes",0))+1
				if not channel.get("stock",{}).is_empty():
					if not c.players[channel.owner].has("nuke_stock"):c.players[channel.owner].nuke_stock=[]
					c.players[channel.owner].nuke_stock.push_front(channel.stock)
			u.channel={}
			for fx in c.effects:
				if fx.get("type","") in ["nuclear_marker","nuclear_ascent"] and int(fx.get("caster",-1))==int(u.id):fx.until=c.time
		elif c.time>=float(channel.until):
			c.ability_events.append({"owner":u.owner,"caster":u.id,"skill":"nuclear","when":channel.impact,"pos":channel.pos,"source":channel.source,"committed":true})
			c._effect("nuclear_descent",{"owner":u.owner,"race":0,"pos":channel.pos},ACData.point(channel.pos),3)
			u.channel={};u.order="idle"
	for event in c.ability_events:
		if event.when>c.time:continue
		var caster=c.entity(int(event.caster))
		if caster.is_empty() or caster.hp<=0 or int(caster.owner)!=int(event.owner):
			if event.get("committed",false) and event.skill=="nuclear":caster={"id":-1,"owner":event.owner,"race":0,"kind":7,"pos":event.source}
			else:event.when=-1;continue
		var key=str(event.skill);var point=ACData.point(event.pos)
		var radius=2.0;var damage=55.0
		match key:
			"judgment":
				var mastery=ACResearch.level(c.players[event.owner],"judgment_mastery")>0
				radius=2.3 if mastery else 1.6;damage=85 if mastery else 45
			"overcharge":radius=1.5;damage=100
			"shockwave":radius=2.2;damage=45
			"root_surge":radius=2.2;damage=60
			"verdict":radius=1.5;damage=180
			"nuclear":radius=5.0;damage=450
		var query_center=(c.center(caster)+point)*.5 if key=="verdict" else point
		var query_radius=c.center(caster).distance_to(point)*.5+2 if key=="verdict" else radius+2
		for target in c._query_entities(query_center,query_radius):
			if target.hp<=0 or target.get("container",-1)>=0 or c.allied(int(event.owner),int(target.owner)):continue
			if key in ["root_surge","shockwave","overcharge"] and not target.has("progress") and ACData.unit(int(target.race),int(target.kind)).air:continue
			var distance=c.center(target).distance_to(point)
			if key=="verdict":
				var axis=(point-c.center(caster)).normalized();var delta=c.center(target)-c.center(caster)
				if delta.dot(axis)<0 or delta.dot(axis)>11 or absf(delta.cross(axis))>1:continue
			elif distance>radius:continue
			var amount=damage*clampf(1-distance/radius*.65,.25,1) if key=="nuclear" else damage
			c._damage(caster,target,amount,false,"spell")
			if key in ["root_surge","shockwave"]:target.slow_until=c.time+2
		var visual_source={"id":caster.id,"owner":event.owner,"race":0,"kind":7,"pos":event.pos} if key=="nuclear" else caster
		effect(c,visual_source,key,point,16.0 if key=="nuclear" else .8,{"radius":radius})
		event.when=-1
	c.ability_events=c.ability_events.filter(func(e):return float(e.when)>=0)
	for zone in c.ability_zones:
		if c.time<float(zone.next) or c.time>=float(zone.until):continue
		zone.next=c.time+.25
		for target in c._query_entities(ACData.point(zone.pos),3):
			if target.hp<=0 or c.center(target).distance_to(ACData.point(zone.pos))>3:continue
			var friendly=c.allied(int(zone.owner),int(target.owner))
			if zone.skill=="smoke" and friendly:target.smoke_until=c.time+.35
			elif zone.skill=="discipline" and not friendly:target.slow_until=c.time+.4
	c.ability_zones=c.ability_zones.filter(func(z):return float(z.until)>c.time)

static func produce_nuke(c,owner: int,b: Dictionary) -> String:
	if b.is_empty() or not b.has("progress") or int(b.owner)!=owner or int(b.race)!=0 or int(b.kind)!=8 or b.progress<1:return "완성된 전술정보국을 선택하세요"
	if ACResearch.level(c.players[owner],"nuclear")==0:return "핵미사일 유도 연구가 필요합니다"
	if not b.get("nuke_job",{}).is_empty():return "핵미사일 생산 중입니다"
	var reserved=int(c.players[owner].get("nukes",0))
	for facility in c.buildings:
		if int(facility.owner)==owner and facility.hp>0 and not facility.get("nuke_job",{}).is_empty():reserved+=1
	for caster in c.units:
		if int(caster.owner)==owner and not caster.get("channel",{}).is_empty():reserved+=1
	if reserved>=3:return "핵미사일은 생산·유도 중인 것을 포함하여 최대 3발입니다"
	if not c.pay(owner,300,200):return c.resource_error(owner,300,200)
	b.nuke_job={"left":75.0,"total":75.0}
	return ""

static func cancel_nuke(c,owner: int,b: Dictionary) -> String:
	if b.is_empty() or int(b.owner)!=owner or not b.has("progress") or b.get("nuke_job",{}).is_empty():return "취소할 핵미사일 생산이 없습니다"
	c.players[owner].as+=300;c.players[owner].tera+=200;b.nuke_job={}
	return ""

static func tick_building(c,b: Dictionary,dt: float) -> void:
	var job: Dictionary=b.get("nuke_job",{})
	if job.is_empty():return
	job.left=maxf(0,float(job.left)-dt)
	if float(job.left)<=0:
		c.players[b.owner].nukes=int(c.players[b.owner].get("nukes",0))+1;b.nuke_job={}
		if not c.players[b.owner].has("nuke_stock"):c.players[b.owner].nuke_stock=[]
		c.players[b.owner].nuke_stock.append({"pos":ACData.packed(c.center(b)),"silo":b.id})
		c.events.append({"owner":b.owner,"text":"핵미사일 생산 완료"})
