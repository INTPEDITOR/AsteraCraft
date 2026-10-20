class_name ACCitrusBrood
extends RefCounted
## Each nursery owns real selectable kind-13 bodies. A body carries its own
## single morph job; a producer's queue only mirrors those concurrent jobs.

const RACE := 1
const KIND := 13
const IDLE_CAP := 3
const HQ_INTERVAL := 15.0
const NURSERY_INTERVAL := 25.0
const MAX_QUEUE := 5
const LINK_RADIUS := 12.0

static func is_pod(unit: Dictionary) -> bool:
	return int(unit.get("race",-1))==RACE and int(unit.get("kind",-1))==KIND and not unit.has("progress")

static func is_producer(building: Dictionary) -> bool:
	return int(building.get("race",-1))==RACE and int(building.get("kind",-1)) in [0,3] and building.has("progress")

static func mother(core, building: Dictionary) -> Dictionary:
	if building.is_empty() or not is_producer(building) or building.hp<=0 or building.progress<1:return {}
	if int(building.kind)==0:return building
	var best: Dictionary={}
	var distance := LINK_RADIUS*LINK_RADIUS+0.000001
	for candidate in core.buildings:
		if int(candidate.race)!=RACE or int(candidate.owner)!=int(building.owner) or int(candidate.kind)!=0 or candidate.hp<=0 or candidate.progress<1:continue
		var score: float=core.center(candidate).distance_squared_to(core.center(building))
		if score<distance:distance=score;best=candidate
	return best

static func idle_pods(core, building: Dictionary, local_only: bool=false) -> Array:
	var result: Array=[]
	var authority := mother(core,building)
	if authority.is_empty():return result
	for unit in core.units:
		if not is_pod(unit) or float(unit.get("hp",0))<=0 or int(unit.owner)!=int(building.owner) or str(unit.get("brood_state","idle"))!="idle":continue
		if local_only:
			if int(unit.get("brood_parent",-1))!=int(building.id):continue
		else:
			var linked := mother(core,_parent(core,unit))
			if linked.is_empty() or int(linked.id)!=int(authority.id):continue
		result.append(unit)
	result.sort_custom(func(a,b):return int(a.id)<int(b.id))
	return result

static func producer(core, building: Dictionary, dt: float=0.0) -> void:
	if not is_producer(building) or float(building.get("hp",0))<=0 or float(building.progress)<1.0:
		return
	var authority := mother(core,building)
	building.brood_active=not authority.is_empty()
	building.brood_mother=int(authority.get("id",-1))
	if authority.is_empty():building.larva=0;return
	if not bool(building.get("brood_initialized",false)):
		building.brood_initialized=true
		building.larva_clock=0.0
		for index in range(IDLE_CAP):
			_spawn(core,building,index)
	var idle := idle_pods(core,building,true).size()
	if idle>=IDLE_CAP:
		building.larva_clock=0.0
	else:
		building.larva_clock=float(building.get("larva_clock",0.0))+maxf(0.0,dt)
		var interval := HQ_INTERVAL if int(building.kind)==0 else NURSERY_INTERVAL
		while float(building.larva_clock)+0.000001>=interval and idle<IDLE_CAP:
			if _spawn(core,building,idle).is_empty():
				building.larva_clock=interval
				break
			building.larva_clock=maxf(0.0,float(building.larva_clock)-interval)
			idle+=1
		if idle>=IDLE_CAP:building.larva_clock=0.0
	_sync(core,building)

static func _spawn(core, building: Dictionary, index: int) -> Dictionary:
	# Nurseries still own their queues, but every body emerges in front of a
	# completed mother colony. Never search a full circle around the building.
	var mother := mother(core,building)
	if mother.is_empty():return {}
	var definition := ACData.building(RACE,0)
	var near=Vector2.INF
	var probe={"id":-1,"race":RACE,"kind":KIND}
	var ground_probe={"id":-1,"race":RACE,"kind":KIND,"collision_layer":core.COLLISION_GROUND}
	for row in range(4):
		for offset in [0,-1,1,-2,2]:
			var point: Vector2=core.center(mother)+Vector2(offset*1.05,float(definition.h)*.5+.85+row*.9)
			# Keep a real ground spawn, but ordinary troops do not displace pods.
			# The attached-layer probe reserves spacing only against other pods.
			if core._unit_fits(ground_probe,point,false) and core._unit_fits(probe,point):near=point;break
		if near.is_finite():break
	if not near.is_finite():return {}
	var pod: Dictionary=core.add_unit(int(building.owner),KIND,near)
	pod.brood_mother=int(mother.id)
	pod.brood_parent=int(building.id)
	pod.brood_state="idle"
	pod.morph_kind=-1
	pod.morph_left=0.0
	pod.morph_total=0.0
	pod.morph_as=0.0
	pod.morph_tera=0.0
	pod.morph_pop=0.0
	pod._morph_reserved=false
	pod.anchored=true
	pod.order="idle"
	pod.action="idle"
	pod.action_started=float(core.time)
	pod.moving=false
	return pod

static func train(core, owner: int, source: Dictionary, kind: int, selected: Array=[]) -> String:
	if owner<0 or owner>=core.players.size() or source.is_empty() or kind<0 or kind>=13:
		return "변태할 유닛을 선택하세요"
	if int(source.get("owner",-1))!=owner or int(source.get("race",-1))!=RACE or float(source.get("hp",0))<=0:
		return "자신의 배양체를 선택하세요"
	var pod: Dictionary={}
	var parent: Dictionary={}
	if is_pod(source):
		pod=source
		parent=_parent(core,pod)
		if str(pod.get("brood_state","idle"))!="idle":
			# Prefer other selected idle bodies, then siblings of the same source.
			pod={}
			for selected_id in selected:
				var candidate := _pod(core,int(selected_id))
				if not candidate.is_empty() and int(candidate.owner)==owner and candidate.get("brood_state","idle")=="idle" and int(candidate.get("container",-1))<0:
					pod=candidate;parent=_parent(core,pod);break
			if pod.is_empty() and not parent.is_empty():
				var siblings := idle_pods(core,parent)
				if not siblings.is_empty():pod=siblings[0]
	elif is_producer(source) and float(source.progress)>=1.0:
		parent=source
		producer(core,parent)
		var available := idle_pods(core,parent)
		if not available.is_empty():pod=available[0]
	else:
		return "배양체 또는 배양 건물을 선택하세요"
	if pod.is_empty():return "사용 가능한 배양체가 없습니다"
	if str(pod.get("brood_state","idle"))!="idle":return "이미 변태 중인 배양체입니다"
	if int(pod.get("container",-1))>=0:return "수송 중인 배양체는 변태할 수 없습니다"
	var authority := mother(core,parent)
	if authority.is_empty():return "12칸 이내의 완성된 군체모수 연결이 필요합니다"
	_sync(core,authority)
	var definition := ACData.unit(RACE,kind)
	if not core.prerequisites(owner,definition.requires):return "선행 기술 건물이 필요합니다"
	var count := maxi(1,int(definition.get("production_count",1)))
	var population := float(definition.pop)*count
	var player: Dictionary=core.players[owner]
	if float(player.used)+float(player.reserved)+population>minf(200.0,float(player.cap))+0.000001:
		return "인구 한도가 부족합니다"
	if not core.pay(owner,float(definition.as),float(definition.tera)):
		return core.resource_error(owner,float(definition.as),float(definition.tera))
	player.reserved=float(player.reserved)+population
	pod.brood_state="morph"
	pod.morph_kind=kind
	pod.morph_left=maxf(0.01,float(definition.time))
	pod.morph_total=pod.morph_left
	pod.morph_as=float(definition.as)
	pod.morph_tera=float(definition.tera)
	pod.morph_pop=population
	pod.morph_count=count
	pod.morph_started=float(core.time)
	pod._morph_reserved=true
	pod.morph_rally=authority.rally.duplicate()
	pod.brood_mother=int(authority.id)
	pod.order="morph"
	pod.action="morph"
	pod.action_started=float(core.time)
	pod.action_clock=0.0
	pod.anchored=true
	pod.moving=false
	pod.target=-1
	pod.path=[]
	pod.healing=false
	pod.fleeing=false
	if not parent.is_empty():
		parent.queue.append({"kind":kind,"left":pod.morph_left,"total":pod.morph_total,"brood":int(pod.id),"count":count})
		_sync(core,parent)
	_sync(core,authority)
	return ""

static func tick_pod(core, pod: Dictionary, dt: float) -> void:
	if not is_pod(pod) or float(pod.get("hp",0))<=0:return
	pod.moving=false
	pod.anchored=true
	pod.action_clock=maxf(0.0,float(core.time)-float(pod.get("action_started",core.time)))
	if str(pod.get("brood_state","idle"))!="morph":return
	var authority := mother(core,_parent(core,pod))
	pod.brood_active=not authority.is_empty()
	if authority.is_empty():return
	pod.brood_mother=int(authority.id)
	pod.morph_rally=authority.rally.duplicate()
	pod.morph_left=maxf(0.0,float(pod.morph_left)-maxf(0.0,dt))
	var parent := _parent(core,pod)
	if not parent.is_empty():_sync(core,parent)
	if float(pod.morph_left)>0.000001:return
	var kind := int(pod.morph_kind)
	var owner := int(pod.owner)
	var rally := ACData.point(pod.get("morph_rally",pod.pos))
	var count := maxi(1,int(pod.get("morph_count",1)))
	var positions: Array[Vector2]=[]
	if count>1:
		var probe={"id":int(pod.id),"race":RACE,"kind":kind}
		var origin := ACData.point(pod.pos)
		var dimensions: Vector2=core.collision_size(RACE,kind)+Vector2.ONE*core.COLLISION_SKIN
		for ring in range(10):
			for x in range(-ring,ring+1):
				for y in range(-ring,ring+1):
					if maxi(absi(x),absi(y))!=ring or positions.size()>=count:continue
					var point := origin+Vector2(x,y)
					if not core._unit_fits(probe,point):continue
					var overlaps := false
					for chosen in positions:
						if absf(point.x-chosen.x)<dimensions.x and absf(point.y-chosen.y)<dimensions.y:overlaps=true;break
					if not overlaps:positions.append(point)
			if positions.size()>=count:break
		# Keep the paid job and its reservation until the entire pair fits.
		if positions.size()<count:return
	_release(core,pod,false)
	if not positions.is_empty():pod.pos=ACData.packed(positions[0])
	core.transform_brood(pod,kind)
	var born: Array=[pod]
	for index in range(1,count):born.append(core.add_unit(owner,kind,positions[index]))
	for unit in born:
		if kind==0:
			unit.order="gather"
			unit.target=core.nearest_resource(ACData.point(unit.pos),"as",owner)
		else:
			unit.order="attack_move"
			unit.goal=ACData.packed(rally)
	core.events.append({"owner":owner,"text":str(ACData.unit(RACE,kind).name)+(" %d마리"%count if count>1 else "")+" 변태 완료"})

static func cancel(core, owner: int, pod: Dictionary) -> String:
	if not is_pod(pod) or int(pod.get("owner",-1))!=owner or float(pod.get("hp",0))<=0:
		return "자신의 배양체를 선택하세요"
	if str(pod.get("brood_state","idle"))!="morph":return "진행 중인 변태가 없습니다"
	_release(core,pod,true)
	pod.brood_state="idle"
	pod.morph_kind=-1
	pod.morph_left=0.0
	pod.morph_total=0.0
	pod.morph_as=0.0
	pod.morph_tera=0.0
	pod.morph_pop=0.0
	pod.order="idle"
	pod.action="idle"
	pod.action_started=float(core.time)
	pod.action_clock=0.0
	var parent := _parent(core,pod)
	if not parent.is_empty():
		# A regenerated free body may have filled this slot during the morph.
		# Preserve the cancelled, selected ID and retire only a surplus free body.
		var idle := idle_pods(core,parent,true)
		for index in range(idle.size()-1,-1,-1):
			if idle.size()<=IDLE_CAP:break
			var excess: Dictionary=idle[index]
			if int(excess.id)==int(pod.id):continue
			core.units.erase(excess)
			idle.remove_at(index)
			core.collision_index_valid=false
		_sync(core,parent)
	return ""

static func cancel_queue(core, owner: int, building: Dictionary, index: int=-1) -> String:
	if not is_producer(building) or int(building.get("owner",-1))!=owner:return "자신의 배양 건물을 선택하세요"
	if building.queue.is_empty():return ""
	if index==-1:index=building.queue.size()-1
	if index<0 or index>=building.queue.size():return "생산 대기열 번호가 잘못되었습니다"
	var item: Dictionary=building.queue[index]
	var pod := _pod(core,int(item.get("brood",-1)))
	if pod.is_empty():return "변태 중인 배양체가 없습니다"
	return cancel(core,owner,pod)

static func cleanup_dead(core) -> void:
	for pod in core.units:
		if is_pod(pod) and float(pod.get("hp",0))<=0 and bool(pod.get("_morph_reserved",false)):
			_release(core,pod,false)

static func _release(core, pod: Dictionary, refund: bool) -> void:
	if bool(pod.get("_morph_reserved",false)):
		var owner := int(pod.owner)
		if owner>=0 and owner<core.players.size():
			var player: Dictionary=core.players[owner]
			player.reserved=maxf(0.0,float(player.reserved)-float(pod.get("morph_pop",0)))
			if refund:
				player.as=float(player.as)+float(pod.get("morph_as",0))
				player.tera=float(player.tera)+float(pod.get("morph_tera",0))
		pod._morph_reserved=false
	var parent := _parent(core,pod)
	if not parent.is_empty():
		for index in range(parent.queue.size()-1,-1,-1):
			if int(parent.queue[index].get("brood",-1))==int(pod.id):parent.queue.remove_at(index)
	refresh(core)

static func _parent(core, pod: Dictionary) -> Dictionary:
	for building in core.buildings:
		if int(building.id)==int(pod.get("brood_parent",-1)) and float(building.get("hp",0))>0 and int(building.owner)==int(pod.owner):return building
	return {}

static func _pod(core, id: int) -> Dictionary:
	for unit in core.units:
		if int(unit.id)==id and is_pod(unit) and float(unit.get("hp",0))>0:return unit
	return {}

static func _sync(core, building: Dictionary) -> void:
	building.larva=idle_pods(core,building).size()
	building.queue=[]
	var authority := mother(core,building)
	building.brood_active=not authority.is_empty()
	building.brood_mother=int(authority.get("id",-1))
	if authority.is_empty():return
	for pod in core.units:
		if not is_pod(pod) or pod.hp<=0 or str(pod.get("brood_state","idle"))!="morph" or not bool(pod.get("_morph_reserved",false)):continue
		var linked := mother(core,_parent(core,pod))
		if linked.is_empty() or linked.id!=authority.id:continue
		building.queue.append({"kind":pod.morph_kind,"left":pod.morph_left,"total":pod.morph_total,"brood":int(pod.id),"count":int(pod.get("morph_count",1))})

static func refresh(core) -> void:
	for building in core.buildings:
		if is_producer(building):_sync(core,building)
