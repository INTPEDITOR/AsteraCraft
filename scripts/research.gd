class_name ACResearch
extends RefCounted

const CAPACITY=5

static func definition(race: int, building: int, key: String) -> Dictionary:
	if key in ACData.research_stats(race,building):
		return {"id":key,"name":{"attack":"공격 강화","armor":"장갑 강화","shield":"보호막 강화"}[key],"as":100,"tera":100,"time":45,"max_level":3,"step":75}
	for item in ACData.get_data().get("research",[]):
		if int(item.race)==race and int(item.building)==building and str(item.id)==key:return item
	return {}

static func catalog(race: int, building: int) -> Array:
	var items=[]
	for key in ACData.research_stats(race,building):items.append(definition(race,building,str(key)))
	for item in ACData.get_data().get("research",[]):
		if int(item.race)==race and int(item.building)==building:items.append(item)
	return items

static func level(player: Dictionary, key: String) -> int:
	return int(player.get(key,0)) if key in ["attack","armor","shield"] else int(player.get("technologies",{}).get(key,0))

static func enqueue(core, owner: int, b: Dictionary, key: String) -> String:
	if b.is_empty() or not b.has("progress") or int(b.owner)!=owner or b.hp<=0 or b.progress<1:return "완성된 연구 건물을 선택하세요"
	var d=definition(int(b.race),int(b.kind),key)
	if d.is_empty():return "이 건물에서 연구할 수 없습니다"
	var queue: Array=b.get("research_queue",[])
	if queue.size()>=CAPACITY:return "연구 대기열이 가득 찼습니다"
	var next=level(core.players[owner],key)
	for other in core.buildings:
		if int(other.owner)!=owner or other.hp<=0:continue
		for job in other.get("research_queue",[]):
			if str(job.kind)!=key:continue
			if int(other.id)!=int(b.id):return "다른 건물에서 같은 연구를 진행하거나 예약하고 있습니다"
			next+=1
	if next>=int(d.get("max_level",1)):return "최대 연구 단계이거나 이미 예약한 기술입니다"
	if not core.prerequisites(owner,d.get("requires",[])):return "선행 연구 건물이 필요합니다"
	var a=float(d.as)+float(d.get("step",0))*next;var t=float(d.tera)+float(d.get("step",0))*next
	if not core.pay(owner,a,t):return core.resource_error(owner,a,t)
	var duration=float(d.time)+(15*next if key in ["attack","armor","shield"] else 0)
	queue.append({"kind":key,"name":str(d.name),"level":next+1,"as":a,"tera":t,"left":duration,"total":duration})
	b.research_queue=queue;sync(b)
	return ""

static func cancel(core, owner: int, b: Dictionary, index: int=-1) -> String:
	if b.is_empty() or not b.has("progress") or int(b.owner)!=owner or b.hp<=0:return "연구 건물을 선택하세요"
	var queue: Array=b.get("research_queue",[])
	if queue.is_empty():return "취소할 연구가 없습니다"
	if index<0:index=queue.size()-1
	if index>=queue.size():return "연구 대기열 번호가 잘못되었습니다"
	var chosen: Dictionary=queue[index];var removed=[]
	for i in range(queue.size()-1,-1,-1):
		var job: Dictionary=queue[i]
		if i==index or (str(job.kind)==str(chosen.kind) and int(job.level)>int(chosen.level)):
			removed.append(queue.pop_at(i))
	for job in removed:
		core.players[owner].as+=float(job.as);core.players[owner].tera+=float(job.tera)
	b.research_queue=queue;sync(b)
	return ""

static func sync(b: Dictionary) -> void:
	var queue: Array=b.get("research_queue",[])
	b.research="" if queue.is_empty() else str(queue[0].kind)
	b.research_left=0.0 if queue.is_empty() else float(queue[0].left)
	b.research_total=0.0 if queue.is_empty() else float(queue[0].total)

static func tick(core,b: Dictionary,dt: float) -> void:
	var queue: Array=b.get("research_queue",[])
	if queue.is_empty():sync(b);return
	queue[0].left=maxf(0,float(queue[0].left)-dt)
	if float(queue[0].left)<=0:
		var job=queue.pop_front();var player: Dictionary=core.players[b.owner]
		if str(job.kind) in ["attack","armor","shield"]:player[job.kind]=int(job.level)
		else:
			if not player.has("technologies"):player.technologies={}
			player.technologies[job.kind]=int(job.level)
			var researched=definition(int(b.race),int(b.kind),str(job.kind))
			if researched.has("unit_kind"):
				for unit in core.units:
					if int(unit.owner)==int(b.owner) and int(unit.race)==int(researched.race) and int(unit.kind)==int(researched.unit_kind):
						var old: Dictionary=unit.get("_definition",ACData.unit(int(unit.race),int(unit.kind)))
						var effective=ACData.unit_for_player(int(unit.race),int(unit.kind),player)
						unit._definition=effective
						if unit.hp>0:unit.hp=minf(float(effective.hp),float(unit.hp)+maxf(0,float(effective.hp)-float(old.hp)))
						unit.cooldown=float(unit.cooldown)*float(effective.period)/maxf(.01,float(old.period))
		core.events.append({"owner":b.owner,"text":"연구 완료: "+str(job.name)})
	b.research_queue=queue;sync(b)
