extends RefCounted

static func plan(c,owner: int,workers: Array,bases: Array) -> Dictionary:
	var patches={};var by_base={};var assigned={};var spare=[]
	for base in bases:by_base[int(base.id)]={"target":0,"assigned":0}
	for node in c.map.resources:
		if node.type!="as" or node.amount<=0:continue
		var closest=-1;var distance=169.0
		for base in bases:
			# Match the actual ground footprint: a wide headquarters' outer
			# mineral patches must not disappear from its worker target merely
			# because their distance from the sprite/center exceeds the cutoff.
			var value=pow(c.footprint_distance(base,ACData.point(node.pos)),2)
			if value<distance:closest=int(base.id);distance=value
		if closest<0:continue
		patches[int(node.id)]={"node":node,"base":closest};assigned[int(node.id)]=0;by_base[closest].target+=2
	for worker in workers:
		if worker.get("_ai_scouting",false) or worker.order in ["construct","build_move"] or not worker.build_queue.is_empty():continue
		if worker.order=="gather" and patches.has(int(worker.target)) and int(assigned[int(worker.target)])<2:
			var id=int(worker.target);assigned[id]+=1;by_base[int(patches[id].base)].assigned+=1
			worker._ai_mining_assignment=id;worker.auto_mine_hq=int(patches[id].base)
		elif worker.order in ["gather","idle","hold"] or worker.get("_ai_mining_wait",false) or worker.get("_ai_scout_return",false):spare.append(worker)
	return {"target":patches.size()*2,"patches":patches,"assigned":assigned,"by_base":by_base,"spare":spare}

static func vacancy(c,worker: Dictionary,mining: Dictionary,base: int=-1) -> int:
	var chosen=-1;var distance=INF
	for id in mining.patches:
		var patch: Dictionary=mining.patches[id]
		if int(mining.assigned[id])>=2 or base>=0 and int(patch.base)!=base:continue
		var value=c.center(worker).distance_squared_to(ACData.point(patch.node.pos))
		if value<distance:distance=value;chosen=int(id)
	return chosen

static func assign(c,owner: int,worker: Dictionary,mining: Dictionary,node_id: int) -> bool:
	if int(worker.carried)>0:return false
	var error=c.command(owner,{"type":"gather","ids":[worker.id],"target":node_id})
	if error!="":worker._ai_mining_last_error=error;return false
	worker.erase("_ai_mining_last_error")
	worker._ai_mining_assignment=node_id;worker.auto_mine_hq=int(mining.patches[node_id].base)
	for key in ["mining_anchor","mining_base","_ai_scout_return","_ai_mining_wait","_ai_mining_wait_pos"]:worker.erase(key)
	return true

static func park(c,owner: int,worker: Dictionary,bases: Array) -> bool:
	if int(worker.carried)>0 or c.time-float(worker.damaged)<3 or bases.is_empty():return false
	var point=ACData.point(worker.get("_ai_mining_wait_pos",[-999,-999]))
	if not worker.get("_ai_mining_wait",false):
		var hq=bases[0]
		for base in bases:
			if c.center(worker).distance_squared_to(c.center(base))<c.center(worker).distance_squared_to(c.center(hq)):hq=base
		point=c.unit_free_position(int(worker.race),0,c.center(hq)+Vector2(4+int(worker.id)%4,6+int(worker.id)/4%3),int(worker.id))
	if c.center(worker).distance_squared_to(point)<=1:
		if worker.order=="hold":return false
		if c.command(owner,{"type":"hold","ids":[worker.id]})!="":return false
	else:
		if worker.order=="move" and ACData.point(worker.goal).distance_squared_to(point)<.01:return false
		if c.command(owner,{"type":"move","ids":[worker.id],"pos":ACData.packed(point)})!="":return false
	worker._ai_mining_wait=true;worker._ai_mining_wait_pos=ACData.packed(point);worker.erase("_ai_mining_assignment")
	return true

static func balance(c,owner: int,workers: Array,bases: Array,mining: Dictionary) -> void:
	# One actual command per planning pass; preserve workers carrying cargo,
	# builders and the bounded scout instead of resetting their orders.
	for worker in mining.spare:
		if int(worker.carried)>0:continue
		var node=vacancy(c,worker,mining)
		if node>=0:
			if assign(c,owner,worker,mining,node):return
		elif park(c,owner,worker,bases):return
	var fullest=-1;var emptiest=-1;var high=-1.0;var low=2.0
	for id in mining.by_base:
		var base: Dictionary=mining.by_base[id]
		if int(base.target)<=0:continue
		var ratio=float(base.assigned)/float(base.target)
		if ratio>high:high=ratio;fullest=int(id)
		if ratio<low:low=ratio;emptiest=int(id)
	if fullest<0 or emptiest<0 or fullest==emptiest or high-low<=.25:return
	for worker in workers:
		if worker.order!="gather" or int(worker.carried)>0 or float(worker.gather_clock)>.05 or worker.get("_ai_scouting",false):continue
		var patch: Dictionary=mining.patches.get(int(worker.target),{})
		if patch.is_empty() or int(patch.base)!=fullest:continue
		var target=vacancy(c,worker,mining,emptiest)
		if target>=0 and assign(c,owner,worker,mining,target):return

static func worker_queue(c,owner: int) -> int:
	var total=0;var seen={}
	for building in c.buildings:
		if int(building.owner)!=owner or building.hp<=0:continue
		for job in building.queue:
			if int(job.kind)!=0:continue
			if job.has("brood"):
				if seen.has(int(job.brood)):continue
				seen[int(job.brood)]=true
			total+=1
	return total
