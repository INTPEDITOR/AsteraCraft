class_name ACNewUnits
extends RefCounted

static func unload(c,carrier: Dictionary,id: int) -> bool:
	if id not in carrier.cargo:return false
	var rider=c.entity(id)
	if rider.is_empty() or rider.hp<=0 or int(rider.container)!=int(carrier.id):return false
	var spawn=c.unit_free_position(int(rider.race),int(rider.kind),c.center(carrier),id)
	if not c._unit_fits(rider,spawn):return false
	rider.container=-1;carrier.cargo.erase(id);c.collision_index_valid=false
	rider.pos=ACData.packed(spawn);rider.path=[];rider.order="idle"
	c._effect("unboard",carrier,c.center(carrier),.35,{"passenger":id})
	return true

static func command(c,owner: int,cmd: Dictionary) -> String:
	var carrier=c.entity(int(cmd.get("id",-1)))
	if carrier.is_empty() or carrier.has("progress") or carrier.hp<=0 or int(carrier.owner)!=owner or int(carrier.race)!=0 or int(carrier.kind)!=14:return "강철둥지 모함을 선택하세요"
	if not carrier.has("drone_queue"):carrier.drone_queue=[]
	if not carrier.has("drones"):carrier.drones=[]
	if cmd.type=="cancel_drone":
		if carrier.drone_queue.is_empty():return "취소할 드론 생산이 없습니다"
		var index=int(cmd.get("queue_index",carrier.drone_queue.size()-1))
		if index<0 or index>=carrier.drone_queue.size():return "잘못된 대기열입니다"
		carrier.drone_queue.remove_at(index);c.players[owner].as+=25;c.players[owner].tera+=10
		return ""
	if carrier.drones.size()+carrier.drone_queue.size()>=8:return "모함 한 기당 요격 드론은 최대 8기입니다"
	if not c.pay(owner,25,10):return c.resource_error(owner,25,10)
	carrier.drone_queue.append({"kind":15,"left":8.0,"total":8.0})
	return ""

static func tick(c,u: Dictionary,dt: float) -> bool:
	var d: Dictionary=u._definition
	if d.role=="carrier_drone":
		var mother=c.entity(int(u.get("mother",-1)))
		if mother.is_empty() or mother.hp<=0 or int(mother.owner)!=int(u.owner):u.hp=0;return true
		var target=c.entity(int(mother.get("drone_target",-1)))
		if target.is_empty() or target.hp<=0 or not c.can_see(int(u.owner),target) or c.center(target).distance_to(c.center(mother))>11:
			if c._move(u,c.center(mother),dt,1.3):
				u.container=mother.id;u.order="idle";u.air_velocity=[0,0]
				c.collision_index_valid=false
			return true
		u.order="attack";u.target=target.id
		return false
	if d.role!="carrier":return false
	if not u.has("drone_queue"):u.drone_queue=[]
	if not u.has("drones"):u.drones=[]
	u.drones=u.drones.filter(func(id):return not c.entity(int(id)).is_empty() and c.entity(int(id)).hp>0)
	if not u.drone_queue.is_empty():
		var job: Dictionary=u.drone_queue[0];job.left=maxf(0,float(job.left)-dt)
		if job.left<=0:
			var drone=c.add_unit(int(u.owner),15,c.center(u));drone.mother=u.id;drone.container=u.id
			u.drones.append(drone.id);u.drone_queue.pop_front()
	var target=c.entity(int(u.target)) if u.order=="attack" else {}
	if not target.is_empty() and (target.hp<=0 or not c.can_see(int(u.owner),target)):target={}
	if target.is_empty() and u.order in ["idle","hold","attack_move"]:
		if c.time>=float(u.get("_carrier_scan",0)):
			target=c._find_target(u,9,"ga");u._carrier_target=int(target.get("id",-1));u._carrier_scan=c.time+.3
		else:target=c.entity(int(u.get("_carrier_target",-1)))
	u.drone_target=-1
	if not target.is_empty() and target.hp>0 and c.can_see(int(u.owner),target):
		if c.center(target).distance_to(c.center(u))>8:
			if u.order!="hold":c._move(u,c.center(target),dt,7.5)
		else:
			u.drone_target=target.id
			for id in u.drones:
				var drone=c.entity(int(id))
				if drone.get("container",-1)>=0:
					drone.container=-1;drone.pos=u.pos.duplicate();drone.order="attack";drone.target=target.id
					c.collision_index_valid=false
	elif u.order in ["move","attack_move"]:
		if c._move(u,ACData.point(u.goal),dt):u.order="idle"
	return true

static func cleanup(c) -> void:
	for u in c.units:
		if int(u.race)==0 and int(u.kind)==15:
			var mother=c.entity(int(u.get("mother",-1)))
			if mother.is_empty() or mother.hp<=0 or int(mother.owner)!=int(u.owner):u.hp=0

static func pierce(c,u: Dictionary,target: Dictionary,damage: float) -> void:
	var start=c.center(u);var end=c.center(target);var axis=(end-start).normalized()
	for candidate in c._query_entities((start+end)*.5,start.distance_to(end)*.5+3):
		if int(candidate.id)==int(target.id) or candidate.hp<=0 or c.allied(int(u.owner),int(candidate.owner)):continue
		if not candidate.has("progress") and ACData.unit(int(candidate.race),int(candidate.kind)).air:continue
		var delta=c.center(candidate)-start
		if delta.dot(axis)>0 and delta.dot(axis)<start.distance_to(end)+2 and absf(delta.cross(axis))<.65:c._damage(u,candidate,damage,false)
