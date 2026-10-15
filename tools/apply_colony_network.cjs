const fs=require('fs');const f='scripts/citrus_brood.gd';let s=fs.readFileSync(f,'utf8');s=s.replace('const MAX_QUEUE := 5','const MAX_QUEUE := 5\nconst LINK_RADIUS := 12.0');let a=s.indexOf('static func idle_pods'),b=s.indexOf('static func producer',a);s=s.slice(0,a)+`static func mother(core, building: Dictionary) -> Dictionary:
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

`+s.slice(b);s=s.replace('if not bool(building.get("brood_initialized",false)):','var authority := mother(core,building)\n\tbuilding.brood_active=not authority.is_empty()\n\tbuilding.brood_mother=int(authority.get("id",-1))\n\tif authority.is_empty():building.larva=0;return\n\tif not bool(building.get("brood_initialized",false)):');s=s.replace('var idle := idle_pods(core,building).size()','var idle := idle_pods(core,building,true).size()');a=s.indexOf('\tvar mother: Dictionary={}');b=s.indexOf('\tvar definition :=',a);s=s.slice(0,a)+'\tvar mother := mother(core,building)\n\tif mother.is_empty():return {}\n'+s.slice(b);
s=s.replace('if not parent.is_empty() and parent.queue.size()>=MAX_QUEUE:', 'var authority := mother(core,parent)\n\tif authority.is_empty():return "12칸 이내의 완성된 군체모수 연결이 필요합니다"\n\t_sync(core,authority)\n\tif authority.queue.size()>=MAX_QUEUE:');s=s.replace('pod.morph_rally=parent.get("rally",pod.pos).duplicate() if parent.get("rally",pod.pos) is Array else ACData.packed(ACData.point(parent.get("rally",pod.pos)))','pod.morph_rally=authority.rally.duplicate()\n\tpod.brood_mother=int(authority.id)');s=s.replace('\t\t_sync(core,parent)\n\treturn ""','\t\t_sync(core,parent)\n\t_sync(core,authority)\n\treturn ""'); // only train; cancel uses different block
s=s.replace('\tpod.morph_left=maxf(0.0,float(pod.morph_left)-maxf(0.0,dt))','\tvar authority := mother(core,_parent(core,pod))\n\tpod.brood_active=not authority.is_empty()\n\tif authority.is_empty():return\n\tpod.brood_mother=int(authority.id)\n\tpod.morph_rally=authority.rally.duplicate()\n\tpod.morph_left=maxf(0.0,float(pod.morph_left)-maxf(0.0,dt))');
s=s.replace('var idle := idle_pods(core,parent)','var idle := idle_pods(core,parent,true)');
a=s.indexOf('static func _sync(');s=s.slice(0,a)+`static func _sync(core, building: Dictionary) -> void:
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
`;
// Ensure a released job is removed from every mirrored queue immediately.
s=s.replace('parent.queue.remove_at(index)','parent.queue.remove_at(index)\n\trefresh(core)');
// cancel's final sync does not have an authority variable.
s=s.replace('\t\t_sync(core,parent)\n\t_sync(core,authority)\n\treturn ""\n\nstatic func cancel_queue','\t\t_sync(core,parent)\n\trefresh(core)\n\treturn ""\n\nstatic func cancel_queue');fs.writeFileSync(f,s);
const c='scripts/core.gd';s=fs.readFileSync(c,'utf8');s=s.replace('func placement(owner:',`func in_roots(owner: int, pos: Vector2) -> bool:
	for building in buildings:
		if int(building.owner)!=owner or int(building.race)!=1 or int(building.kind) not in [0,12] or building.hp<=0 or building.progress<1:continue
		if center(building).distance_squared_to(pos)<=169.0:return true
	return false

func placement(owner:`);s=s.replace('if race==1 and kind not in [0,1,12] and not in_field(owner,rect.get_center(),13):\n\t\treturn "뿌리망 범위가 필요합니다"',`if race==1 and kind!=0:
		for x in range(int(rect.position.x),int(rect.end.x)):
			for y in range(int(rect.position.y),int(rect.end.y)):
				if not in_roots(owner,Vector2(x,y)):return "건물 전체가 뿌리 지대 안에 있어야 합니다"
		if kind==3:
			var linked=false
			for building in buildings:
				if int(building.owner)==owner and int(building.race)==1 and int(building.kind)==0 and building.hp>0 and building.progress>=1 and center(building).distance_squared_to(rect.get_center())<=144.0:linked=true;break
			if not linked:return "추가배양낭은 군체모수 12칸 이내에 건설하세요"`);s=s.replace('func snapshot(owner: int = -1) -> Dictionary:', 'func snapshot(owner: int = -1) -> Dictionary:\n\tCITRUS_BROOD.refresh(self)');s=s.replace('\t\t\t\tb.rally=ACData.packed(rally)','\t\t\t\tif CITRUS_BROOD.is_producer(b):\n\t\t\t\t\tvar authority=CITRUS_BROOD.mother(self,b)\n\t\t\t\t\tif authority.is_empty():continue\n\t\t\t\t\tauthority.rally=ACData.packed(rally)\n\t\t\t\tb.rally=ACData.packed(rally)');fs.writeFileSync(c,s);
