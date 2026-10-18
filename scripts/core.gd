class_name ACCore
extends RefCounted

const CITRUS_BROOD=preload("res://scripts/citrus_brood.gd")
const ROOT_FIELD=preload("res://scripts/root_field.gd")
var roots=ROOT_FIELD.new()

var map := ACMap.new()
var players: Array = []
var units: Array = []
var buildings: Array = []
var effects: Array = []
var corpses: Array = []
var events: Array = []
var explored: Array = []
var visibility: Array = []
var resource_memory: Array = []
var building_memory: Array = []
var spawn_slots: Array=[]
var match_seed: int=0
var time: float = 0.0
var next_id: int = 1
var ended: bool = false
var winners: Array = []
var mode: String = "ffa"
var ai_clock: float = 0.0
var vision_clock: float = 0.0
var rng := RandomNumberGenerator.new()
var next_effect_id: int = 1
var collision_index: Dictionary={}
var collision_index_valid: bool=false
var clearance_paths: Dictionary={}
var clearance_revision: int=-1
var entity_lookup: Dictionary={}
var resource_lookup: Dictionary={}
var entity_spatial: Dictionary={}
var building_spatial: Dictionary={}
var resource_spatial: Dictionary={}
var owned_buildings: Dictionary={}
var field_nodes: Dictionary={}
var worker_assignments: Dictionary={}
var mining_claims: Dictionary={}
var vision_spans: Dictionary={}
var path_cache: Dictionary={}
var path_cache_revision: int=-1
var indexed_units: int=-1
var indexed_buildings: int=-1
var indexed_resources: int=-1
var resource_obstacle_signature: String=""
var collision_recovery_revision: int=-1
var max_collision_half: float=.32
var navigation_solids=PackedByteArray()
var navigation_revision: int=-1
var paths_this_tick: int=0
var perf: Dictionary={"path_requests":0,"path_cache_hits":0,"spatial_queries":0,"target_candidates":0,"vision_sources":0,"ticks":0,"building_us":0,"unit_us":0,"collision_us":0,"cleanup_us":0,"vision_us":0,"ai_us":0}

# Unit positions are always ground-contact centers in map coordinates. Rendering
# offsets, aircraft altitude and sprite trimming never change this anchor.
const TERA_INTERVAL: float = 3.0
const TERA_AMOUNT: int = 8
const AS_INTERVAL: float = 2.2
const AS_AMOUNT: int = 5
const ENERGY_REGEN: float = .3
const TERA_HQ_RADIUS: float = 14.0
const MAX_EFFECTS: int = 512
const COLLISION_GROUND: int = 1
const COLLISION_AIR: int = 2
const COLLISION_ATTACHED: int = 0
const COLLISION_CELL: float = 1.5
const COLLISION_SKIN: float = .004
const ENTITY_CELL: float = 8.0
const MAX_PATH_REQUESTS: int = 48
const MAX_PRODUCTION_QUEUE: int = 5
const MAX_BUILD_PLANS: int = 32
const CONSTRUCTION_TOOL_REACH: float = .35
const AS_UNLOAD_REACH: float = .35

static func resource_size(type: String) -> Vector2:
	# Build-tile dimensions: SC1 minerals 64x32 px, geysers 128x64 px.
	return Vector2(4,2) if type=="tera" else Vector2(2,1)

static func resource_rect(node: Dictionary) -> Rect2:
	var dimensions=resource_size(str(node.type))
	return Rect2(ACData.point(node.pos)-dimensions*.5,dimensions)

static func _body_size(unit: Dictionary) -> Vector2:
	return unit._body_size if unit.has("_body_size") else collision_size(int(unit.race),int(unit.kind))

static func _body_layer(unit: Dictionary) -> int:
	return int(unit.collision_layer) if unit.has("collision_layer") else collision_layer(int(unit.race),int(unit.kind))

static func collision_size(race: int, kind: int) -> Vector2:
	var definition=ACData.unit(race,kind)
	var base=clampf(float(definition.size)*.64,.42,1.9)
	if definition.air:return Vector2(base,base*.8)
	# Oversized artwork must not give ground units a two-build-tile chassis:
	# the original diagonal ramp neck is narrower than that bounding box.
	base=minf(base,1.25)
	var vehicle=definition.role in ["siege","missile","fortress","golem","tree","tank"]
	return Vector2(base*(1.04 if vehicle else 1.0),base*(.88 if vehicle else .84))

static func collision_layer(race: int, kind: int) -> int:
	if ACData.unit(race,kind).get("technical",false):return COLLISION_ATTACHED
	return COLLISION_AIR if ACData.unit(race,kind).air else COLLISION_GROUND

static func collision_rect(unit: Dictionary, at: Vector2=Vector2.INF) -> Rect2:
	var pos=ACData.point(unit.pos) if not at.is_finite() else at
	var dimensions=_body_size(unit)
	return Rect2(pos-dimensions*.5,dimensions)

static func units_overlap(a: Dictionary, b: Dictionary) -> bool:
	if collision_layer(int(a.race),int(a.kind))!=collision_layer(int(b.race),int(b.kind)):return false
	return collision_rect(a).intersects(collision_rect(b))

static func start_slots(player_count: int, seed: int, requested=[]) -> Array:
	var result: Array=[]
	if requested is Array and requested.size()==player_count:
		for value in requested:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=float(int(value)) or int(value)<0 or int(value)>3 or int(value) in result:
				result.clear()
				break
			result.append(int(value))
		if result.size()==player_count:return result
	var random=RandomNumberGenerator.new()
	random.seed=seed
	result=[0,1,2,3]
	for index in range(3,0,-1):
		var other=random.randi_range(0,index)
		var value=result[index]
		result[index]=result[other]
		result[other]=value
	return result.slice(0,clampi(player_count,0,4))

func setup(config: Dictionary) -> void:
	if config.has("seed"):rng.seed=int(config.seed)
	else:rng.randomize()
	match_seed=int(rng.seed)
	map.make(int(config.get("map", 0)))
	mode = str(config.get("mode", "ffa"))
	spawn_slots=start_slots(config.players.size(),int(rng.seed),config.get("spawn_slots",[]))
	for i in range(config.players.size()):
		var spec = config.players[i]
		var p = {"name":str(spec.get("name","연구원")),"race":int(spec.get("race",0)),"team":int(spec.get("team",i)),"bot":bool(spec.get("bot",false)),"difficulty":int(spec.get("difficulty",1)),"as":50.0,"tera":0.0,"used":0.0,"cap":0.0,"reserved":0.0,"attack":0,"armor":0,"shield":0,"lost":false,"kills":0,"spent":0,"gathered":0,"ai_goal":0}
		players.append(p)
		var fog := PackedByteArray()
		fog.resize(ACMap.SIZE * ACMap.SIZE)
		fog.fill(0)
		explored.append(fog)
		visibility.append(fog.duplicate())
		resource_memory.append({})
		building_memory.append({})
		var start_index=int(spawn_slots[i])
		p.spawn_slot=start_index
		var headquarters=ACData.building(int(p.race),0)
		var hq = add_building(i,0,map.start_building_anchor(start_index,Vector2(headquarters.w,headquarters.h)),true)
		map.reset_solids(buildings)
		_sync_resource_obstacles()
		for worker_pos in starting_worker_row(hq):
			add_unit(i,0,worker_pos)
		p.home = hq.id
	map.reset_solids(buildings)
	_sync_resource_obstacles()
	for building in buildings:CITRUS_BROOD.producer(self,building)
	for worker in units:
		if int(worker.kind)==0:
			worker.auto_mine_hq=int(players[worker.owner].home)
			worker.target=_home_ore(worker)
			if worker.target>=0:worker.order="gather"
	_recalculate_supply()
	_update_vision()

func starting_worker_row(hq: Dictionary) -> Array:
	var race=int(hq.race)
	var definition=ACData.building(race,0)
	var spacing=maxf(1.0,collision_size(race,0).x+COLLISION_SKIN+.1)
	var origin=ACData.point(hq.pos)+Vector2((float(definition.w)-1)*.5,float(definition.h)+.6)
	var probe={"id":-1,"race":race,"kind":0}
	for row in range(16):
		for shift in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6]:
			var positions: Array=[]
			for index in range(4):
				var point=origin+Vector2(float(shift)+(index-1.5)*spacing,row*.5)
				if point.x<1 or point.x>126 or point.y<1 or point.y>126 or not _unit_fits(probe,point):break
				positions.append(point)
			if positions.size()==4:return positions
	push_error("No safe starting worker row at headquarters %s"%hq.id)
	return []

func add_building(owner: int, kind: int, pos: Vector2, complete: bool = false) -> Dictionary:
	var race = int(players[owner].race)
	var d = ACData.building(race,kind)
	var b = {"id":next_id,"owner":owner,"race":race,"kind":kind,"pos":ACData.packed(pos.floor()),"hp":float(d.hp if complete else d.hp*.1),"shield":float(d.shield if complete else 0),"progress":1.0 if complete else 0.0,"queue":[],"rally":ACData.packed(pos+Vector2(d.w+2,d.h+2)),"worker":-1,"cooldown":0.0,"damaged":-99.0,"larva":3 if complete and race==1 and kind==0 else 0,"larva_clock":0.0,"research":"","research_left":0.0,"research_total":0.0,"tera_clock":0.0,"tera_resource":-1,"fired":-99.0}
	next_id += 1
	buildings.append(b)
	collision_index_valid=false
	return b

func add_unit(owner: int, kind: int, pos: Vector2) -> Dictionary:
	var race = int(players[owner].race)
	var d = ACData.unit(race,kind)
	pos=unit_free_position(race,kind,pos)
	var u = {"id":next_id,"owner":owner,"race":race,"kind":kind,"pos":ACData.packed(pos),"hp":float(d.hp),"shield":float(d.shield),"energy":100.0,"order":"idle","target":-1,"goal":ACData.packed(pos),"path":[],"path_rev":map.revision,"repath":0.0,"cooldown":0.0,"damaged":-99.0,"fired":-99.0,"facing":[0.0,1.0],"moving":false,"anchored":false,"slow_until":0.0,"ability_cd":0.0,"carried":0,"cargo_type":"as","gather_clock":0.0,"container":-1,"cargo":[],"heal_stock":25.0,"action":"idle","action_started":time,"action_clock":0.0,"activity_clock":0.0,"action_intent":"idle"}
	next_id += 1
	u.collision_size=ACData.packed(collision_size(race,kind))
	u.collision_layer=collision_layer(race,kind)
	u._body_size=collision_size(race,kind)
	u._body_half=u._body_size*.5
	u._definition=d
	u.mining_state="idle"
	u.path_failed=false
	u._auto_target=-1
	u._scan_at=time+float(int(u.id)%5)*.035
	u.max_energy=ACData.unit_max_energy(race,kind)
	u.energy=minf(100,u.max_energy)
	u.cloak_active=false
	if race==0 and kind==7:u.energy=50.0
	u.healing=false
	u.heal_target=-1
	u.heal_kind=""
	u.heal_started=-99.0
	u.heal_pulse=-99.0
	u.fleeing=false
	u.flee_started=-99.0
	u.flee_until=-99.0
	u.technical=bool(d.get("technical",false))
	if u.technical:
		u.anchored=true
		u.brood_parent=-1
		u.brood_state="idle"
		u.morph_kind=-1
		u.morph_left=0.0
		u.morph_total=0.0
	u.blocked_clock=0.0
	u.nav_blocked=0.0
	u.build_queue=[]
	u.body_direction=[0.0,1.0]
	u.turret_direction=[0.0,1.0]
	units.append(u)
	collision_index_valid=false
	return u

func transform_brood(pod: Dictionary, kind: int) -> Dictionary:
	var preserved_id=int(pod.id)
	var owner=int(pod.owner)
	var pos=ACData.point(pod.pos)
	pod.hp=0
	collision_index_valid=false
	var fresh=add_unit(owner,kind,pos)
	units.erase(fresh)
	pod.clear()
	pod.merge(fresh,true)
	pod.id=preserved_id
	collision_index_valid=false
	return pod

func entity(id: int) -> Dictionary:
	if indexed_units!=units.size() or indexed_buildings!=buildings.size():_rebuild_collision_index()
	var result=entity_lookup.get(id,{})
	return result if not result.is_empty() and result.hp>0 else {}

func resource(id: int) -> Dictionary:
	if indexed_resources!=map.resources.size():_rebuild_resources()
	return resource_lookup.get(id,{})

func _rebuild_resources() -> void:
	resource_lookup.clear()
	resource_spatial.clear()
	for node in map.resources:
		if not node.has("initial_amount"):node.initial_amount=maxi(0,int(node.amount))
		resource_lookup[int(node.id)]=node
		var key=Vector2i((ACData.point(node.pos)/ENTITY_CELL).floor())
		if not resource_spatial.has(key):resource_spatial[key]=[]
		resource_spatial[key].append(node)
	indexed_resources=map.resources.size()

func _sync_resource_obstacles() -> void:
	_rebuild_resources()
	var rectangles: Array=[]
	var signature=""
	for node in map.resources:
		if node.type=="as" and node.amount<=0:continue
		rectangles.append(resource_rect(node))
		signature+=str(node.id)+":"+str(node.pos)+":"+str(resource_size(str(node.type)))+";"
	if signature!=resource_obstacle_signature:
		resource_obstacle_signature=signature
		map.set_resource_obstacles(rectangles)
		collision_index_valid=false

func refinery_anchor(node_or_id) -> Vector2:
	var node=resource(int(node_or_id)) if node_or_id is int else node_or_id
	if not node is Dictionary or node.is_empty() or node.type!="tera":return Vector2.INF
	# Integer coordinates are tile centers. A 4x2 vent centered at (n+.5,m+.5)
	# has its first tile at pos-(1.5,.5). Never round the vent itself sideways.
	var anchor=resource_rect(node).position+Vector2(.5,.5)
	return anchor.round() if anchor.distance_squared_to(anchor.round())<.000001 else Vector2.INF

func snap_refinery(owner: int, pos: Vector2, tolerance: float=2.0) -> Vector2:
	var best=tolerance*tolerance
	var result=Vector2.INF
	for node in map.resources:
		if node.type!="tera":continue
		var anchor=refinery_anchor(node)
		if not anchor.is_finite():continue
		var distance=pos.distance_squared_to(anchor)
		if distance<=best:
			best=distance
			result=anchor
	return result

func mining_worker(unit: Dictionary) -> bool:
	if float(unit.get("hp",0))<=0 or int(unit.get("container",-1))>=0:return false
	if int(unit.get("kind",-1))!=0 or unit.get("order","")!="gather":return false
	if int(unit.get("carried",0))>0:return unit.get("cargo_type","as")=="as"
	var node=resource(int(unit.get("target",-1)))
	return not node.is_empty() and node.type=="as" and node.amount>0

func working_worker(unit: Dictionary) -> bool:
	return mining_worker(unit) or (int(unit.get("kind",-1))==0 and float(unit.get("hp",0))>0 and int(unit.get("container",-1))<0 and unit.get("order","") in ["build_move","construct"])

func _workers_can_overlap(a: Dictionary, b: Dictionary) -> bool:
	return working_worker(a) or working_worker(b)

func center(e: Dictionary) -> Vector2:
	var p = ACData.point(e.pos)
	if e.has("progress"):
		var d = ACData.building(int(e.race),int(e.kind))
		p += Vector2(d.w,d.h)*.5
	return p

func footprint(e: Dictionary) -> Rect2:
	# Navigation cells are centered on integer coordinates; the blocked footprint
	# runs from the first cell's -0.5 edge to the last cell's +0.5 edge.
	if e.has("progress"):
		var d=ACData.building(int(e.race),int(e.kind))
		return Rect2(ACData.point(e.pos)-Vector2(.5,.5),Vector2(d.w,d.h))
	return Rect2(ACData.point(e.pos),Vector2.ZERO)

func footprint_distance(e: Dictionary, from: Vector2) -> float:
	var rect=footprint(e)
	return from.distance_to(from.clamp(rect.position,rect.end))

func body_footprint_gap(worker: Dictionary, building: Dictionary) -> float:
	var body=collision_rect(worker)
	var rect=footprint(building)
	var gap=Vector2(maxf(0,maxf(rect.position.x-body.end.x,body.position.x-rect.end.x)),maxf(0,maxf(rect.position.y-body.end.y,body.position.y-rect.end.y)))
	return gap.length()

func combat_body_gap(attacker: Dictionary, target: Dictionary) -> float:
	if target.has("progress"):return body_footprint_gap(attacker,target)
	var body=collision_rect(attacker)
	var rect=collision_rect(target)
	return Vector2(maxf(0,maxf(rect.position.x-body.end.x,body.position.x-rect.end.x)),maxf(0,maxf(rect.position.y-body.end.y,body.position.y-rect.end.y))).length()

func _melee_approach(attacker: Dictionary, target: Dictionary) -> Vector2:
	var rect=footprint(target) if target.has("progress") else collision_rect(target)
	var half=_body_size(attacker)*.5+Vector2.ONE*.04
	var border=rect.grow_individual(half.x,half.y,half.x,half.y)
	var origin=ACData.point(attacker.pos)
	var middle=border.get_center()
	if int(attacker.get("_surround_target",-1))==int(target.id) and time<float(attacker.get("_surround_retry",0)):
		var retained=middle+ACData.point(attacker._surround_offset)
		if _unit_fits(attacker,retained,false):return retained
	# Keep a claimed angle while approaching. Re-select only after obstruction
	# or substantial target displacement; do not chase a new edge every tick.
	if int(attacker.get("_surround_target",-1))==int(target.id) and time<float(attacker.get("_surround_until",0)) and float(attacker.blocked_clock)<.65:
		var retained=middle+ACData.point(attacker._surround_offset)
		if _unit_fits(attacker,retained):return retained
	var facing=(origin-middle).angle()
	var best=INF
	var result=origin.clamp(border.position,border.end)
	var neighbours=_nearby_units(middle,maxf(border.size.x,border.size.y)+2)
	var choices: Array=[]
	for index in range(24):
		var ray=Vector2.from_angle(facing+float(index)*TAU/24.0)
		var radius=minf(border.size.x*.5/maxf(.001,absf(ray.x)),border.size.y*.5/maxf(.001,absf(ray.y)))
		var candidate=middle+ray*radius
		if not _unit_fits(attacker,candidate):continue
		var claimed=false
		for other in neighbours:
			if other.id==attacker.id or other.hp<=0 or int(other.get("_surround_target",-1))!=int(target.id) or time>=float(other.get("_surround_until",0)):continue
			var reserved=middle+ACData.point(other._surround_offset)
			if collision_rect(attacker,candidate).grow(.05).intersects(collision_rect(other,reserved)):claimed=true;break
		if claimed:continue
		var score=origin.distance_squared_to(candidate)
		choices.append({"point":candidate,"score":score})
	choices.sort_custom(func(a,b):return a.score<b.score)
	var inspected=0
	for choice in choices:
		if inspected>=4:break
		inspected+=1
		var candidate: Vector2=choice.point
		if _ground_sweep(_body_size(attacker),origin,candidate):
			result=candidate;best=float(choice.score);break
		# Compare reachable approaches around walls, not merely the closest edge.
		var route=_clearance_path(attacker,origin,candidate)
		if route.is_empty() or ACData.point(route.back()).distance_to(candidate)>.8:continue
		var length=0.0;var previous=origin
		for waypoint in route:
			var point=ACData.point(waypoint);length+=previous.distance_to(point);previous=point
		if length*length<best:best=length*length;result=candidate
	attacker._surround_target=int(target.id)
	attacker._surround_offset=ACData.packed(result-middle)
	attacker._surround_until=time+1.25
	attacker._surround_retry=time+.3
	return result

func building_contact(worker: Dictionary, building: Dictionary, reach: float=CONSTRUCTION_TOOL_REACH) -> bool:
	if worker.is_empty() or worker.hp<=0 or worker.get("container",-1)>=0:return false
	return not collision_rect(worker).intersects(footprint(building)) and body_footprint_gap(worker,building)<=reach

func construction_reach(worker: Dictionary, building: Dictionary) -> bool:
	return building_contact(worker,building,CONSTRUCTION_TOOL_REACH)

func building_approach(b: Dictionary, from: Vector2, unit: Dictionary={}) -> Vector2:
	var d=ACData.building(int(b.race),int(b.kind))
	var p=Vector2i(ACData.point(b.pos))
	var candidates: Array=[]
	for x in range(p.x,p.x+int(d.w)):
		for y in [p.y-1,p.y+int(d.h)]:
			var q=Vector2i(x,y)
			if map.walkable(q):candidates.append(Vector2(q))
	for y in range(p.y,p.y+int(d.h)):
		for x in [p.x-1,p.x+int(d.w)]:
			var q=Vector2i(x,y)
			if map.walkable(q):candidates.append(Vector2(q))
	if not unit.is_empty():
		var rect=footprint(b)
		var half=_body_size(unit)*.5
		for index in range(candidates.size()):
			var candidate: Vector2=candidates[index]
			if candidate.x<p.x:candidate.x=rect.position.x-half.x-.15
			elif candidate.x>=p.x+int(d.w):candidate.x=rect.end.x+half.x+.15
			if candidate.y<p.y:candidate.y=rect.position.y-half.y-.15
			elif candidate.y>=p.y+int(d.h):candidate.y=rect.end.y+half.y+.15
			candidates[index]=candidate
	candidates.sort_custom(func(a,bp):return from.distance_squared_to(a)<from.distance_squared_to(bp))
	var fallback=from
	for candidate in candidates:
		if fallback==from:fallback=candidate
		if not unit.is_empty() and not _unit_fits(unit,candidate,false):continue
		if from.distance_to(candidate)<.7 or not map.path(from,candidate).is_empty():
			return candidate
	return fallback

func _move_to_building(u: Dictionary, b: Dictionary, dt: float, reach: float=.12) -> bool:
	if int(u.get("approach_target",-1))!=int(b.id) or int(u.get("approach_revision",-1))!=map.revision or (float(u.blocked_clock)>.6 and time>=float(u.get("_approach_retry",0))):
		u.approach_target=b.id
		u.approach_revision=map.revision
		u._approach_retry=time+.75
		u.approach_goal=ACData.packed(building_approach(b,ACData.point(u.pos),u))
		u.path=[]
		u.repath=0.0
	return _move(u,ACData.point(u.approach_goal),dt,reach)

func _ground_sweep(dimensions: Vector2, from: Vector2, to: Vector2) -> bool:
	var samples=maxi(1,ceili(from.distance_to(to)/.2))
	for index in range(samples+1):
		if not _ground_fits_size(dimensions,from.lerp(to,float(index)/samples)):return false
	return true

func _resource_approach(res: Dictionary, from: Vector2, dimensions: Vector2=Vector2(.52,.44), home: Vector2=Vector2.INF) -> Vector2:
	var p=ACData.point(res.pos)
	var body=resource_rect(res)
	var half=dimensions*.5+Vector2.ONE*.06
	var border=body.grow_individual(half.x,half.y,half.x,half.y)
	var nearest=from.clamp(border.position,border.end)
	var candidates=[Vector2(border.position.x,nearest.y),Vector2(border.end.x,nearest.y),Vector2(nearest.x,border.position.y),Vector2(nearest.x,border.end.y),border.position,Vector2(border.end.x,border.position.y),Vector2(border.position.x,border.end.y),border.end]
	var best=INF
	var goal=Vector2.INF if home.is_finite() else Vector2(map.nearest_free(p))
	for candidate in candidates:
		if home.is_finite() and (candidate-p).dot(home-p)<0:continue
		if not _ground_fits_size(dimensions,candidate):continue
		if Rect2(candidate-dimensions*.5,dimensions).intersects(body):continue
		var distance=from.distance_to(candidate)
		if not _ground_sweep(dimensions,from,candidate):
			var route=map.path(from,candidate)
			if route.is_empty():continue
			var last=ACData.point(route[-1])
			if not _ground_sweep(dimensions,last,candidate):continue
			distance=0.0
			var previous=from
			for step in route:
				var point=ACData.point(step)
				distance+=previous.distance_to(point);previous=point
			distance+=previous.distance_to(candidate)
		if distance<best:
			best=distance
			goal=candidate
	return goal

func _effect(type: String, source: Dictionary, to: Vector2, duration: float, extra: Dictionary={}) -> void:
	var effect={"id":next_effect_id,"type":type,"owner":int(source.get("owner",-1)),"race":int(source.get("race",0)),"kind":int(source.get("kind",-1)),"unit":int(source.get("id",-1)),"source_building":source.has("progress"),"from":ACData.packed(center(source)),"to":ACData.packed(to),"pos":ACData.packed(to),"started":time,"until":time+duration}
	next_effect_id+=1
	effect.merge(extra,true)
	effects.append(effect)
	if effects.size()>MAX_EFFECTS:effects.pop_front()

func _set_action(u: Dictionary, action: String, restart: bool=false) -> void:
	if u.action!=action or restart:
		u.action=action
		u.action_started=time
	u.action_clock=maxf(0,time-float(u.action_started))

func allied(a: int, b: int) -> bool:
	return a==b or (mode=="teams" and players[a].team==players[b].team)

func has_building(owner: int, kind: int) -> bool:
	if not collision_index_valid:_rebuild_collision_index()
	for b in owned_buildings.get(Vector2i(owner,kind),[]):
		if b.progress>=1 and b.hp>0:
			return true
	return false

func prerequisites(owner: int, list: Array) -> bool:
	for kind in list:
		if not has_building(owner,int(kind)):
			return false
	return true

func in_field(owner: int, pos: Vector2, radius: float = 10.0) -> bool:
	if not collision_index_valid:_rebuild_collision_index()
	for node in field_nodes.get(owner,[]):
		if node.hp<=0 or (node.has("progress") and node.progress<1):continue
		if center(node).distance_squared_to(pos)<=radius*radius:return true
	return false

func tera_headquarters(owner: int, pos: Vector2) -> int:
	# Consult live HP/progress directly so a destroyed headquarters cannot
	# keep supplying extraction through a stale spatial-index entry.
	for headquarters in buildings:
		if int(headquarters.owner)==owner and int(headquarters.kind)==0 and headquarters.hp>0 and headquarters.progress>=1 and center(headquarters).distance_squared_to(pos)<=TERA_HQ_RADIUS*TERA_HQ_RADIUS:
			return int(headquarters.id)
	return -1

func in_roots(owner: int, pos: Vector2) -> bool:
	return roots.contains(self,owner,pos)

func in_owl_power(owner: int, pos: Vector2) -> bool:
	for tower in buildings:
		if int(tower.owner)==owner and int(tower.race)==2 and int(tower.kind)==2 and tower.hp>0 and tower.progress>=1 and center(tower).distance_squared_to(pos)<=144.0:return true
	return false

func placement(owner: int, kind: int, pos: Vector2, require_worker: bool = true) -> String:
	if owner<0 or owner>=players.size() or kind<0 or kind>=13:
		return "잘못된 건설 명령"
	var race = int(players[owner].race)
	var d = ACData.building(race,kind)
	if not prerequisites(owner,d.requires):
		return "선행 건물이 필요합니다"
	var rect = Rect2(pos.floor(),Vector2(d.w,d.h))
	var physical_rect=Rect2(pos.floor()-Vector2(.5,.5),Vector2(d.w,d.h))
	var matched_vent=-1
	if kind==1:
		if Vector2(d.w,d.h)!=resource_size("tera"):return "정제 건물과 테라 매장지의 규격이 다릅니다"
		for node in _query_resources(physical_rect.get_center(),4):
			if node.type=="tera" and pos.distance_squared_to(refinery_anchor(node))<.000001:matched_vent=int(node.id);break
		if matched_vent<0:return "테라 분출구에 정확히 맞춰 건설하세요"
		if tera_headquarters(owner,physical_rect.get_center())<0:return "14칸 이내에 완성된 본진 건물이 필요합니다"
	for x in range(int(rect.position.x),int(rect.end.x)):
		for y in range(int(rect.position.y),int(rect.end.y)):
			var tile=Vector2i(x,y)
			var passable=(map.inside(tile) and map.terrain[y*ACMap.SIZE+x]==0) if kind==1 else map.walkable(tile)
			if not passable or not map.buildable(tile):
				return "건설할 수 없는 지형입니다"
	if kind==1:
		for building in buildings:
			if building.hp<=0:continue
			var bd=ACData.building(int(building.race),int(building.kind))
			if rect.intersects(Rect2(ACData.point(building.pos),Vector2(bd.w,bd.h))):return "다른 건물과 겹칩니다"
	for r in map.resources:
		if r.type=="as" and r.amount>0 and physical_rect.intersects(resource_rect(r).grow(ACMap.HQ_MINERAL_GAP if kind==0 else 0.0)):
			return "본진은 아스 광물 가장자리에서 3칸 이상 떨어져야 합니다" if kind==0 else "아스 광물과 겹칩니다"
		if r.type=="tera" and int(r.id)!=matched_vent and physical_rect.intersects(resource_rect(r)):
			return "테라 매장지입니다"
	if race==1 and kind!=0:
		for x in range(int(rect.position.x),int(rect.end.x)):
			for y in range(int(rect.position.y),int(rect.end.y)):
				if not in_roots(owner,Vector2(x,y)):return "건물 전체가 뿌리 지대 안에 있어야 합니다"
		if kind==3:
			var linked=false
			for building in buildings:
				if int(building.owner)==owner and int(building.race)==1 and int(building.kind)==0 and building.hp>0 and building.progress>=1 and center(building).distance_squared_to(rect.get_center())<=144.0:linked=true;break
			if not linked:return "추가배양낭은 군체모수 12칸 이내에 건설하세요"
	if race==2 and kind!=2:
		for x in range(int(rect.position.x),int(rect.end.x)):
			for y in range(int(rect.position.y),int(rect.end.y)):
				if not in_owl_power(owner,Vector2(x,y)):return "건물 전체가 완성된 규율탑 12칸 이내에 있어야 합니다"
	if require_worker:
		var found=false
		for u in units:
			if int(u.owner)==owner and int(u.kind)==0 and u.hp>0 and u.container<0:
				found=true
		if not found:
			return "건설 일꾼이 필요합니다"
	return ""

func pay(owner: int, a: float, t: float) -> bool:
	var p = players[owner]
	if p.as+.001<a or p.tera+.001<t:
		return false
	p.as-=a
	p.tera-=t
	p.spent+=a+t
	return true

func resource_error(owner: int, a: float, t: float) -> String:
	if float(players[owner].as)+.001<a:return "아스가 부족합니다"
	if float(players[owner].tera)+.001<t:return "테라가 부족합니다"
	return ""

func _command_build(owner: int, cmd: Dictionary) -> String:
	var kind=int(cmd.get("kind",-1))
	var raw=cmd.get("pos",[])
	if not ((raw is Array and raw.size()==2) or raw is Vector2):return "건설 위치가 필요합니다"
	var pos=ACData.point(raw)
	if not pos.is_finite():return "잘못된 건설 위치입니다"
	if kind!=1:pos=pos.floor()
	var error=placement(owner,kind,pos,false)
	if error!="":return error
	var chosen: Dictionary={}
	var selected=cmd.get("ids",[])
	var queued=bool(cmd.get("queued",false))
	# An explicit selection binds all Shift plans to its first valid worker.
	# Never replace a busy selected worker with an unrelated idle worker.
	if queued and selected.is_empty():return "연속 건설을 수행할 일꾼을 선택하세요"
	for id in (selected.slice(0,1) if queued else selected):
		var worker=entity(int(id))
		if not worker.is_empty() and not worker.has("progress") and int(worker.owner)==owner and int(worker.kind)==0 and worker.hp>0 and worker.container<0:
			chosen=worker
			break
	if chosen.is_empty() and selected.is_empty() and not queued:
		var definition=ACData.building(int(players[owner].race),kind)
		var rect=Rect2(pos-Vector2(.5,.5),Vector2(definition.w,definition.h))
		var best=INF
		for worker in units:
			if int(worker.owner)!=owner or int(worker.kind)!=0 or worker.hp<=0 or worker.container>=0 or worker.order in ["construct","build_move"]:continue
			var point=ACData.point(worker.pos)
			var distance=point.distance_to(point.clamp(rect.position,rect.end))
			if distance<best:best=distance;chosen=worker
	if chosen.is_empty():return "명령을 수행할 일꾼을 선택하세요"
	if int(chosen.race)!=int(players[owner].race):return "조종한 타 종족 일꾼은 채취와 전투만 수행할 수 있습니다"
	if int(chosen.race)==1 and queued and (chosen.order in ["construct","build_move"] or not chosen.build_queue.is_empty()):
		return "일귤은 건물로 변이하며 소모됩니다. 다른 일귤을 선택하세요"
	if queued and (chosen.order in ["construct","build_move"] or not chosen.build_queue.is_empty()):
		if chosen.build_queue.size()>=MAX_BUILD_PLANS:return "연속 건설 대기열이 가득 찼습니다"
		var definition=ACData.building(int(chosen.race),kind)
		var rect=Rect2(pos-Vector2(.5,.5),Vector2(definition.w,definition.h))
		var plans=chosen.build_queue.duplicate()
		if chosen.order=="build_move":plans.append(chosen.build_plan)
		for plan in plans:
			var planned=ACData.building(int(chosen.race),int(plan.kind))
			if rect.intersects(Rect2(ACData.point(plan.pos)-Vector2(.5,.5),Vector2(planned.w,planned.h))):return "다른 건설 계획과 겹칩니다"
		chosen.build_queue.append({"kind":kind,"pos":ACData.packed(pos)})
		return ""
	var result=_start_construction(chosen,kind,pos)
	if result=="":chosen.build_queue=[]
	return result

func _start_construction(worker: Dictionary, kind: int, pos: Vector2) -> String:
	var owner=int(worker.owner)
	if int(worker.race)!=int(players[owner].race):return "조종한 타 종족 일꾼은 건설할 수 없습니다"
	var error=placement(owner,kind,pos,false)
	if error!="":return error
	var definition=ACData.building(int(worker.race),kind)
	if players[owner].as<definition.as or players[owner].tera<definition.tera:return resource_error(owner,definition.as,definition.tera)
	var plan={"id":-1000000-int(worker.id),"owner":owner,"race":worker.race,"kind":kind,"pos":ACData.packed(pos),"progress":0.0}
	var approach=building_approach(plan,ACData.point(worker.pos),worker)
	if not construction_reach(worker,plan) and (not _unit_fits(worker,approach,false) or (not _ground_sweep(_body_size(worker),ACData.point(worker.pos),approach) and map.path(ACData.point(worker.pos),approach).is_empty())):return "건설 위치까지 이동할 수 없습니다"
	var previous=entity(int(worker.target)) if worker.order=="construct" else {}
	if not previous.is_empty() and previous.has("progress") and int(previous.worker)==int(worker.id):previous.worker=-1
	_release_mining_claim(worker)
	worker.build_plan=plan
	worker.order="build_move";worker.target=-1;worker.path=[]
	worker.approach_target=-1;worker.repath=0.0;worker.path_failed=false
	worker.blocked_clock=0.0;worker.nav_blocked=0.0
	worker.fleeing=false;worker._flee_manual_until=time+2.0
	return ""

func _arrive_construction(worker: Dictionary) -> String:
	var plan: Dictionary=worker.get("build_plan",{})
	if plan.is_empty() or not construction_reach(worker,plan):return "건설 위치에 도착하지 않았습니다"
	var owner=int(worker.owner)
	var error=placement(owner,int(plan.kind),ACData.point(plan.pos),false)
	if error!="":return error
	var definition=ACData.building(int(worker.race),int(plan.kind))
	if not pay(owner,definition.as,definition.tera):return resource_error(owner,definition.as,definition.tera)
	var building=add_building(owner,int(plan.kind),ACData.point(plan.pos))
	building.worker=worker.id
	worker.erase("build_plan")
	worker.order="construct";worker.target=building.id;worker.path=[];worker.approach_target=-1
	map.reset_solids(buildings)
	return ""

func _advance_build_queue(worker: Dictionary) -> void:
	if worker.hp<=0 or int(worker.kind)!=0 or worker.container>=0 or worker.order!="idle":return
	while not worker.build_queue.is_empty():
		var plan=worker.build_queue.pop_front()
		var error=_start_construction(worker,int(plan.kind),ACData.point(plan.pos))
		if error=="":return
		events.append({"owner":worker.owner,"text":"연속 건설 건너뜀: "+error,"created":time})

func command(owner: int, cmd: Dictionary) -> String:
	if ended or owner<0 or owner>=players.size() or players[owner].lost:
		return ""
	var ids=cmd.get("ids",[])
	if not ids is Array:
		return "잘못된 유닛 선택입니다"
	# Human commands represent a selection group. AI controls its whole army
	# directly and may also issue larger trusted groups through this API.
	if ids.size()>12 and not bool(players[owner].bot):
		return "한 번에 최대 12기까지 선택할 수 있습니다"
	var type = str(cmd.get("type",""))
	if type=="morph":return CITRUS_BROOD.train(self,owner,entity(int(cmd.get("id",-1))),int(cmd.get("kind",-1)),cmd.get("ids",[]))
	if type=="cancel_morph":return CITRUS_BROOD.cancel(self,owner,entity(int(cmd.get("id",-1))))
	if type=="surrender":
		players[owner].lost=true
		_check_end()
		return ""
	if type=="build":
		return _command_build(owner,cmd)
	if type=="train":
		var b=entity(int(cmd.get("id",-1)))
		var kind=int(cmd.get("kind",-1))
		if not b.is_empty() and int(b.race)==1:return CITRUS_BROOD.train(self,owner,b,kind)
		if b.is_empty() or not b.has("queue") or int(b.owner)!=owner or b.progress<1 or kind<0 or kind>=13:
			return "생산 건물을 선택하세요"
		var d=ACData.unit(int(b.race),kind)
		var producer=int(d.producer)
		if int(b.race)==1:
			if int(b.kind) not in [0,3]:
				return "배양체가 있는 건물을 선택하세요"
		else:
			if int(b.kind)!=producer:
				return "이 건물에서 생산할 수 없습니다"
		if not prerequisites(owner,d.requires):
			return "선행 기술 건물이 필요합니다"
		if b.queue.size()>=MAX_PRODUCTION_QUEUE:
			return "생산 대기열이 가득 찼습니다"
		if players[owner].used+players[owner].reserved+d.pop>minf(200,players[owner].cap):
			return "인구 한도가 부족합니다"
		if int(b.race)==1 and b.larva<1:
			return "배양체가 부족합니다"
		if not pay(owner,d.as,d.tera):
			return resource_error(owner,d.as,d.tera)
		if int(b.race)==1:
			b.larva-=1
		b.queue.append({"kind":kind,"left":float(d.time),"total":float(d.time)})
		players[owner].reserved+=d.pop
		return ""
	if type=="cancel":
		var b=entity(int(cmd.get("id",-1)))
		if CITRUS_BROOD.is_pod(b):return CITRUS_BROOD.cancel(self,owner,b)
		if b.is_empty() or not b.has("progress") or int(b.owner)!=owner or b.hp<=0:
			return ""
		if b.progress<1:
			var d=ACData.building(int(b.race),int(b.kind))
			players[owner].as+=d.as*.75
			players[owner].tera+=d.tera*.75
			b.hp=0
			if int(b.race)==1 and b.get("initiated",false):
				# Restore only an actually consumed builder, exactly once.
				b.initiated=false
				map.reset_solids(buildings.filter(func(item):return item.hp>0))
				collision_index_valid=false
				var restored=add_unit(owner,0,unit_free_position(1,0,center(b)))
				var worker_data=ACData.unit(1,0)
				restored.hp=clampf(float(b.get("builder_hp",worker_data.hp)),1,float(worker_data.hp))
				restored.carried=int(b.get("builder_carried",0))
				_recalculate_supply()
		else:
			if not b.queue.is_empty():
				if int(b.race)==1:return CITRUS_BROOD.cancel_queue(self,owner,b,int(cmd.get("queue_index",-1)))
				var index=int(cmd.get("queue_index",b.queue.size()-1))
				if index<0 or index>=b.queue.size():return "생산 대기열 번호가 잘못되었습니다"
				var q=b.queue.pop_at(index)
				var d=ACData.unit(int(b.race),int(q.kind))
				players[owner].as+=d.as
				players[owner].tera+=d.tera
				players[owner].reserved=maxf(0,players[owner].reserved-d.pop)
				if int(b.race)==1:
					b.larva+=1
		return ""
	if type=="research":
		var b=entity(int(cmd.get("id",-1)))
		var stat=str(cmd.get("stat","attack"))
		if b.is_empty() or not b.has("research") or int(b.owner)!=owner or b.progress<1 or b.research!="":
			return "연구 가능한 건물을 선택하세요"
		if stat not in ACData.research_stats(int(b.race),int(b.kind)):
			return "이 건물에서 연구할 수 없습니다"
		var level=int(players[owner][stat])
		if level>=3:
			return "최대 연구 단계입니다"
		for other in buildings:
			if int(other.owner)==owner and other.research==stat:
				return "이미 연구 중입니다"
		if not pay(owner,100+level*75,100+level*75):
			return resource_error(owner,100+level*75,100+level*75)
		b.research=stat
		b.research_left=45+level*15
		b.research_total=b.research_left
		return ""
	if type=="rally":
		var raw=cmd.get("pos",[])
		if not ((raw is Array and raw.size()==2) or raw is Vector2):return "집결 위치가 필요합니다"
		var rally=ACData.point(raw)
		if not rally.is_finite() or rally.x<0 or rally.y<0 or rally.x>=ACMap.SIZE or rally.y>=ACMap.SIZE:return "잘못된 집결 위치입니다"
		var rally_ids=cmd.get("ids",[cmd.id] if cmd.has("id") else [])
		for id in rally_ids:
			var b=entity(int(id))
			if not b.is_empty() and b.has("rally") and int(b.owner)==owner:
				if CITRUS_BROOD.is_producer(b):
					var authority=CITRUS_BROOD.mother(self,b)
					if authority.is_empty():continue
					authority.rally=ACData.packed(rally)
				b.rally=ACData.packed(rally)
		return ""
	var order_index=0
	var energy_blocked=false
	var ability_accepted=false
	var columns=ceili(sqrt(maxi(1,cmd.get("ids",[]).size())))
	var spacing=.8
	if cmd.get("formation",false):
		for id in ids:
			var member=entity(int(id))
			if not member.is_empty() and not member.has("progress"):
				var dimensions=collision_size(int(member.race),int(member.kind))
				spacing=maxf(spacing,maxf(dimensions.x,dimensions.y)+.18)
	for id in cmd.get("ids",[]):
		var u=entity(int(id))
		if u.is_empty() or u.has("progress") or int(u.owner)!=owner or u.container>=0:
			continue
		if u.get("technical",false):continue
		if int(u.kind)==0:u.build_queue=[];u.erase("build_plan")
		var was_fleeing=bool(u.get("fleeing",false))
		u.fleeing=false
		u._flee_manual_until=time+2.0
		if type=="ability":
			var ability_role=str(ACData.unit(int(u.race),int(u.kind)).role)
			if ability_role=="parasite":
				return _mind_control(u,int(cmd.get("target",-1)))
			var energy_cost=75 if ability_role=="mage" else 60 if ability_role=="priest" else 0
			if int(u.race)==0 and int(u.kind)==7 and not u.get("cloak_active",false):energy_cost=25
			if energy_cost>0 and float(u.energy)<energy_cost:
				energy_blocked=true
				continue
			if ability_role in ["siege","fortress","tree","shield","transport","mage","priest"]:ability_accepted=true
			if int(u.race)==0 and int(u.kind)==7:ability_accepted=true
			if was_fleeing:u.order="idle";u.path=[]
			_ability(u,ACData.point(cmd.get("pos",u.pos)))
			continue
		var was_mining=mining_worker(u)
		u.erase("auto_mine_hq")
		u.path=[]
		u.approach_target=-1
		u.repath=0.0
		u.path_failed=false
		_release_mining_claim(u)
		u.target=int(cmd.get("target",-1))
		u.goal=cmd.get("pos",u.pos)
		if cmd.get("formation",false) and type in ["move","context","attack_move"] and int(u.target)<0:
			var offset=Vector2(order_index%columns-(columns-1)*.5,int(order_index/columns)-(columns-1)*.5)*spacing
			u.goal=ACData.packed((ACData.point(u.goal)+offset).clamp(Vector2.ONE,Vector2(126,126)))
			order_index+=1
		if type=="stop" or type=="hold":
			u.order="hold" if type=="hold" else "idle"
			u.target=-1
		else:
			u.order=type
			if type=="context":
				var target=entity(int(u.target))
				var res=resource(int(u.target))
				if not res.is_empty() and int(u.kind)==0:
					u.order="gather"
				elif not target.is_empty():
					if not allied(owner,int(target.owner)):
						if can_see(owner,target):
							u.order="attack"
						else:
							u.order="move"
							u.target=-1
					elif target.has("cargo") and ACData.unit(int(target.race),int(target.kind)).role=="transport" and not ACData.unit(int(u.race),int(u.kind)).air:
						u.order="load"
					elif int(u.kind)==0 and target.has("progress") and float(target.progress)<1 and int(target.owner)==owner and int(target.race)==int(u.race):
						var previous=entity(int(target.get("worker",-1)))
						if not previous.is_empty() and int(previous.id)!=int(u.id) and previous.hp>0 and previous.order=="construct" and int(previous.target)==int(target.id):
							u.order="move"
						else:
							target.worker=int(u.id)
							u.order="construct"
					elif int(u.kind)==0 and int(u.race)==0:
						u.order="repair"
					else:
						u.order="move"
				else:
					u.order="move"
		if was_mining and not mining_worker(u):collision_recovery_revision=-1
	if energy_blocked and not ability_accepted:return "에너지가 부족합니다"
	return ""

func _home_ore(worker: Dictionary) -> int:
	var headquarters=entity(int(worker.get("auto_mine_hq",-1)))
	if headquarters.is_empty():
		headquarters=_nearest_hq(int(worker.owner),ACData.point(worker.pos))
		if headquarters.is_empty():return -1
		worker.auto_mine_hq=int(headquarters.id)
	var home=center(headquarters)
	var best=INF
	var chosen=-1
	for node in _query_resources(home,16):
		if node.type!="as" or node.amount<=0 or home.distance_squared_to(ACData.point(node.pos))>256:continue
		var goal=_resource_approach(node,ACData.point(worker.pos),_body_size(worker),home)
		if not goal.is_finite():continue
		var route=map.path(ACData.point(worker.pos),goal)
		var distance=ACData.point(worker.pos).distance_to(goal)
		if not _ground_sweep(_body_size(worker),ACData.point(worker.pos),goal):
			if route.is_empty():continue
			distance=0.0
			var previous=ACData.point(worker.pos)
			for step in route:
				var point=ACData.point(step);distance+=previous.distance_to(point);previous=point
			distance+=previous.distance_to(goal)
		var assigned=0
		for other in units:
			if other.id!=worker.id and other.owner==worker.owner and other.kind==0 and other.hp>0 and other.order=="gather" and other.target==node.id:assigned+=1
		# Prefer short round trips from this HQ; spread the four starters over
		# nearby faces instead of sending an occupied-node worker behind the line.
		var score=distance+2.0*home.distance_to(goal)+assigned*8.0
		if score<best:best=score;chosen=int(node.id)
	return chosen

func nearest_resource(pos: Vector2, type: String, owner: int = -1) -> int:
	# Tera extractors harvest automatically. Workers only shuttle golden As.
	if type=="tera":return -1
	var best=INF
	var id=-1
	if not collision_index_valid:_rebuild_collision_index()
	var choices=_query_resources(pos,20)
	if choices.is_empty():choices=map.resources
	for r in choices:
		if r.type!=type or r.amount<=0:
			continue
		var dist=pos.distance_squared_to(ACData.point(r.pos))
		dist+=float(worker_assignments.get(int(r.id),0))*16.0
		if dist<best:
			best=dist
			id=int(r.id)
	if id<0 and choices.size()!=map.resources.size():
		for node in map.resources:
			if node.type!=type or node.amount<=0:continue
			var distance=pos.distance_squared_to(ACData.point(node.pos))+float(worker_assignments.get(int(node.id),0))*16.0
			if distance<best:best=distance;id=int(node.id)
	return id

func nearest_available_resource(pos: Vector2, exclude_id: int=-1, worker_id: int=-1, radius: float=20.0) -> int:
	var best=radius*radius
	var result=-1
	for node in _query_resources(pos,radius):
		if node.type!="as" or node.amount<=0 or int(node.id)==exclude_id:continue
		var holder=int(mining_claims.get(int(node.id),-1))
		if holder>=0 and holder!=worker_id:
			var claimant=entity(holder)
			if not claimant.is_empty() and mining_worker(claimant) and int(claimant.target)==int(node.id) and int(claimant.carried)==0:continue
		var distance=pos.distance_squared_to(ACData.point(node.pos))
		if distance<best:best=distance;result=int(node.id)
	return result

func _retarget_busy_resource(worker: Dictionary, current: Dictionary) -> bool:
	if worker.has("auto_mine_hq"):return false
	if time<float(worker.get("_busy_scan_at",-1)):return false
	worker._busy_scan_at=time+.35
	var alternative=nearest_available_resource(ACData.point(worker.pos),int(current.id),int(worker.id))
	if alternative<0:return false
	_release_mining_claim(worker)
	worker.target=alternative
	worker.path=[]
	worker.repath=0.0
	worker.mining_state="travel"
	return true

func _ground_fits_size(dimensions: Vector2, pos: Vector2) -> bool:
	if map.source_detail_active:return map.source_ground_fits(dimensions,pos)
	if navigation_revision!=map.revision:_refresh_navigation_mask()
	var low_x=floori(pos.x-dimensions.x*.5+.5001)
	var low_y=floori(pos.y-dimensions.y*.5+.5001)
	var high_x=floori(pos.x+dimensions.x*.5+.4999)
	var high_y=floori(pos.y+dimensions.y*.5+.4999)
	if low_x<0 or low_y<0 or high_x>=ACMap.SIZE or high_y>=ACMap.SIZE:return false
	if low_x==high_x and low_y==high_y:return navigation_solids[low_y*ACMap.SIZE+low_x]==0
	for x in range(low_x,high_x+1):
		for y in range(low_y,high_y+1):
			if navigation_solids[y*ACMap.SIZE+x]!=0:return false
	return true

func _refresh_navigation_mask() -> void:
	navigation_solids.resize(ACMap.SIZE*ACMap.SIZE)
	for y in range(ACMap.SIZE):
		for x in range(ACMap.SIZE):navigation_solids[y*ACMap.SIZE+x]=int(not map.walkable(Vector2i(x,y)))
	navigation_revision=map.revision

func _rebuild_collision_index() -> void:
	collision_index.clear()
	entity_lookup.clear()
	entity_spatial.clear()
	building_spatial.clear()
	owned_buildings.clear()
	field_nodes.clear()
	worker_assignments.clear()
	max_collision_half=.25
	for unit in units:
		entity_lookup[int(unit.id)]=unit
		if unit.hp<=0 or unit.container>=0:continue
		var pos=ACData.point(unit.pos)
		var half=_body_size(unit)*.5
		max_collision_half=maxf(max_collision_half,maxf(half.x,half.y))
		var key=Vector2i((pos/COLLISION_CELL).floor())
		if not collision_index.has(key):collision_index[key]=[]
		collision_index[key].append(unit)
		_index_entity(unit,pos)
		if int(unit.kind)==0 and unit.order=="gather":worker_assignments[int(unit.target)]=int(worker_assignments.get(int(unit.target),0))+1
		if int(unit.race)==1 and int(unit.kind)==12 and unit.anchored:
			if not field_nodes.has(int(unit.owner)):field_nodes[int(unit.owner)]=[]
			field_nodes[int(unit.owner)].append(unit)
	for building in buildings:
		entity_lookup[int(building.id)]=building
		if building.hp<=0:continue
		_index_entity(building,center(building))
		var key=Vector2i(int(building.owner),int(building.kind))
		if not owned_buildings.has(key):owned_buildings[key]=[]
		owned_buildings[key].append(building)
		if int(building.kind) in [0,2] or (int(building.race)==1 and int(building.kind)==12):
			if not field_nodes.has(int(building.owner)):field_nodes[int(building.owner)]=[]
			field_nodes[int(building.owner)].append(building)
	indexed_units=units.size()
	indexed_buildings=buildings.size()
	collision_index_valid=true

func _index_entity(item: Dictionary, pos: Vector2) -> void:
	var key=Vector2i((pos/ENTITY_CELL).floor())
	if not entity_spatial.has(key):entity_spatial[key]=[]
	entity_spatial[key].append(item)
	if item.has("progress"):
		if not building_spatial.has(key):building_spatial[key]=[]
		building_spatial[key].append(item)

func _query_entities(pos: Vector2, radius: float) -> Array:
	if not collision_index_valid or indexed_units!=units.size() or indexed_buildings!=buildings.size():_rebuild_collision_index()
	perf.spatial_queries+=1
	var result: Array=[]
	var low=Vector2i(((pos-Vector2.ONE*radius)/ENTITY_CELL).floor())
	var high=Vector2i(((pos+Vector2.ONE*radius)/ENTITY_CELL).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):result.append_array(entity_spatial.get(Vector2i(x,y),[]))
	return result

func _query_resources(pos: Vector2, radius: float) -> Array:
	if indexed_resources!=map.resources.size():_rebuild_resources()
	var result: Array=[]
	var low=Vector2i(((pos-Vector2.ONE*radius)/ENTITY_CELL).floor())
	var high=Vector2i(((pos+Vector2.ONE*radius)/ENTITY_CELL).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):result.append_array(resource_spatial.get(Vector2i(x,y),[]))
	return result

func _nearby_units(pos: Vector2, radius: float=2.3) -> Array:
	if not collision_index_valid:_rebuild_collision_index()
	var result: Array=[]
	var low=Vector2i(((pos-Vector2.ONE*radius)/COLLISION_CELL).floor())
	var high=Vector2i(((pos+Vector2.ONE*radius)/COLLISION_CELL).floor())
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):result.append_array(collision_index.get(Vector2i(x,y),[]))
	return result

func _set_unit_position(unit: Dictionary, pos: Vector2) -> void:
	var previous=Vector2i((ACData.point(unit.pos)/COLLISION_CELL).floor())
	var previous_broad=Vector2i((ACData.point(unit.pos)/ENTITY_CELL).floor())
	unit.pos=ACData.packed(pos)
	if not collision_index_valid:return
	var key=Vector2i((ACData.point(unit.pos)/COLLISION_CELL).floor())
	if key!=previous:
		if collision_index.has(previous):collision_index[previous].erase(unit)
		if not collision_index.has(key):collision_index[key]=[]
		collision_index[key].append(unit)
	var broad=Vector2i((ACData.point(unit.pos)/ENTITY_CELL).floor())
	if broad!=previous_broad:
		if entity_spatial.has(previous_broad):entity_spatial[previous_broad].erase(unit)
		if not entity_spatial.has(broad):entity_spatial[broad]=[]
		entity_spatial[broad].append(unit)

func _unit_fits(unit: Dictionary, pos: Vector2, check_units: bool=true) -> bool:
	var layer=_body_layer(unit)
	var dimensions=_body_size(unit)
	if layer==COLLISION_GROUND and not _ground_fits_size(dimensions,pos):return false
	if layer==COLLISION_GROUND and not map.resources.is_empty():
		var body=Rect2(pos-dimensions*.5,dimensions)
		for node in _query_resources(pos,3):
			if node.type=="as" and node.amount<=0:continue
			if body.intersects(resource_rect(node)):return false
	if not check_units:return true
	var half=dimensions*.5
	if not collision_index_valid:_rebuild_collision_index()
	var radius=maxf(half.x,half.y)+max_collision_half+COLLISION_SKIN
	var low=Vector2i(((pos-Vector2.ONE*radius)/COLLISION_CELL).floor())
	var high=Vector2i(((pos+Vector2.ONE*radius)/COLLISION_CELL).floor())
	var worker=int(unit.kind)==0
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for other in collision_index.get(Vector2i(x,y),[]):
				if other.id==unit.id or other.hp<=0 or other.container>=0 or int(other.collision_layer)!=layer:continue
				if _workers_can_overlap(unit,other):continue
				var other_half=other._body_half
				if absf(float(other.pos[0])-pos.x)<half.x+other_half.x+COLLISION_SKIN*.5 and absf(float(other.pos[1])-pos.y)<half.y+other_half.y+COLLISION_SKIN*.5:return false
	return true

func unit_free_position(race: int, kind: int, near: Vector2, ignore_id: int=-1, radius: int=9) -> Vector2:
	var probe={"id":ignore_id,"race":race,"kind":kind,"pos":ACData.packed(near)}
	near=near.clamp(Vector2.ONE,Vector2(126,126))
	if _unit_fits(probe,near):return near
	var candidates: Array=[]
	var origin=near.round()
	for ring in range(1,radius+1):
		candidates.clear()
		for x in range(-ring,ring+1):
			for y in range(-ring,ring+1):
				if maxi(absi(x),absi(y))!=ring:continue
				var pos=origin+Vector2(x,y)
				if pos.x<1 or pos.y<1 or pos.x>126 or pos.y>126:continue
				candidates.append(pos)
		candidates.sort_custom(func(a,b):return near.distance_squared_to(a)<near.distance_squared_to(b))
		for pos in candidates:
			if _unit_fits(probe,pos):return pos
	return near

func _clearance_path(unit: Dictionary, from: Vector2, to: Vector2) -> Array:
	var dimensions=_body_size(unit)
	var large=maxf(dimensions.x,dimensions.y)>1.0
	var detailed=map.source_detail_active
	var body_path=large or detailed
	var crowded=float(unit.blocked_clock)>.8 and not working_worker(unit)
	if path_cache_revision!=map.revision:
		path_cache.clear()
		path_cache_revision=map.revision
	var grid_factor=4 if detailed else (2 if large else 1)
	var route_key="%d,%d>%d,%d:%d,%d"%[roundi(from.x*grid_factor),roundi(from.y*grid_factor),roundi(to.x*grid_factor),roundi(to.y*grid_factor),ceili(dimensions.x*16) if body_path else 0,ceili(dimensions.y*16) if body_path else 0]
	if not crowded and path_cache.has(route_key) and float(path_cache[route_key].until)>time:
		perf.path_cache_hits+=1
		return path_cache[route_key].path.duplicate(false)
	if paths_this_tick>=MAX_PATH_REQUESTS:
		unit._path_deferred=true
		return []
	paths_this_tick+=1
	if not body_path and not crowded:
		perf.path_requests+=1
		var result=map.path(from,to)
		if path_cache.size()>2048:path_cache.clear()
		path_cache[route_key]={"path":result.duplicate(false),"until":time+(2.0 if not result.is_empty() else .5)}
		return result
	if clearance_revision!=map.revision:
		clearance_paths.clear()
		clearance_revision=map.revision
	var key=Vector2i((dimensions*16).ceil())
	if body_path and not clearance_paths.has(key):
		var nav=AStarGrid2D.new()
		nav.region=Rect2i(0,0,ACMap.SIZE*grid_factor,ACMap.SIZE*grid_factor)
		nav.cell_size=Vector2.ONE/grid_factor
		nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
		nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
		nav.update()
		var clearance=Vector2(key)/16.0
		for x in range(ACMap.SIZE*grid_factor):
			for y in range(ACMap.SIZE*grid_factor):nav.set_point_solid(Vector2i(x,y),not _ground_fits_size(clearance,Vector2(x,y)/grid_factor))
		clearance_paths[key]=nav
	var navigator: AStarGrid2D=clearance_paths[key] if body_path else map.navigator
	var temporary: Array=[]
	var grid_scale=1.0/navigator.cell_size.x
	if crowded:
		for other in units:
			if other.id==unit.id or other.hp<=0 or other.container>=0 or collision_layer(int(other.race),int(other.kind))!=COLLISION_GROUND or _workers_can_overlap(unit,other):continue
			if other.moving and other.order not in ["idle","hold"]:continue
			var rect=collision_rect(other)
			rect.position-=dimensions*.5+Vector2.ONE*.05
			rect.size+=dimensions+Vector2.ONE*.1
			for x in range(int(ceil(rect.position.x*grid_scale)),int(floor(rect.end.x*grid_scale))+1):
				for y in range(int(ceil(rect.position.y*grid_scale)),int(floor(rect.end.y*grid_scale))+1):
					var point=Vector2i(x,y)
					if navigator.region.has_point(point) and not navigator.is_point_solid(point):
						navigator.set_point_solid(point,true)
						temporary.append(point)
	var first=_clearance_free(navigator,from)
	var last=_clearance_free(navigator,to)
	var path: Array=[]
	if first.x>=0 and last.x>=0:
		perf.path_requests+=1
		for point in navigator.get_id_path(first,last):path.append(ACData.packed(Vector2(point)*navigator.cell_size))
	for point in temporary:navigator.set_point_solid(point,false)
	if path.is_empty() and crowded:
		first=_clearance_free(navigator,from)
		last=_clearance_free(navigator,to)
		if first.x>=0 and last.x>=0:
			perf.path_requests+=1
			for point in navigator.get_id_path(first,last):path.append(ACData.packed(Vector2(point)*navigator.cell_size))
	if not path.is_empty() and (Vector2(first)*navigator.cell_size).distance_to(from)<.3:path.pop_front()
	if not crowded:path_cache[route_key]={"path":path.duplicate(false),"until":time+(2.0 if not path.is_empty() else .5)}
	return path

func _clearance_free(navigator: AStarGrid2D, near: Vector2) -> Vector2i:
	var origin=Vector2i((near/navigator.cell_size).round())
	for ring in range(ceili(9.0/navigator.cell_size.x)):
		var best=INF
		var result=Vector2i(-1,-1)
		for x in range(-ring,ring+1):
			for y in range(-ring,ring+1):
				if maxi(absi(x),absi(y))!=ring:continue
				var point=origin+Vector2i(x,y)
				if navigator.region.has_point(point) and not navigator.is_point_solid(point):
					var distance=(Vector2(point)*navigator.cell_size).distance_squared_to(near)
					if distance<best:best=distance;result=point
		if result.x>=0:return result
	return Vector2i(-1,-1)

func _crowd_arrived(unit: Dictionary, goal: Vector2, reach: float) -> bool:
	if unit.order not in ["move","attack_move"]:return false
	var count=0
	var largest=maxf(collision_size(int(unit.race),int(unit.kind)).x,.5)
	for other in _nearby_units(goal,3):
		if other.id==unit.id or other.hp<=0 or other.container>=0:continue
		if collision_layer(int(other.race),int(other.kind))!=COLLISION_GROUND:continue
		var same_destination=ACData.point(other.get("goal",other.pos)).distance_to(goal)<.7
		var occupying_goal=ACData.point(other.pos).distance_to(goal)<.55
		if (same_destination or occupying_goal) and ACData.point(other.pos).distance_to(goal)<3 and (not other.moving or other.order in ["idle","hold"]):
			count+=1
			largest=maxf(largest,collision_size(int(other.race),int(other.kind)).x)
	if count==0:return false
	var arrival=maxf(reach,clampf(sqrt(float(count+1))*largest*1.1+.7,1.0,3.0))
	return ACData.point(unit.pos).distance_to(goal)<=arrival

func _request_room(unit: Dictionary, goal: Vector2, dt: float) -> void:
	if working_worker(unit):return
	var pos=ACData.point(unit.pos)
	var direction=(goal-pos).normalized()
	# Include the whole short approach: a blocker beside the current body
	# can be skipped by testing only the box at the far end of this step.
	var next_box=collision_rect(unit,pos).merge(collision_rect(unit,pos+direction*.65)).grow(.04)
	var lateral=direction.orthogonal()
	for other in _nearby_units(pos+direction*.5):
		if other.id==unit.id or other.hp<=0 or other.container>=0 or other.anchored or other.order!="idle":continue
		if not allied(int(unit.owner),int(other.owner)) or collision_layer(int(other.race),int(other.kind))!=COLLISION_GROUND:continue
		if not next_box.intersects(collision_rect(other)):continue
		var sign_side=signf(lateral.dot(ACData.point(other.pos)-pos))
		if sign_side==0:sign_side=1.0 if int(other.id)%2==0 else -1.0
		for delta in [lateral*sign_side, direction, -lateral*sign_side]:
			var next=ACData.point(other.pos)+delta*minf(.13,dt*2.0)
			# Settled troops may yield locally, but repeated arrivals must not
			# push an idle formation indefinitely away from its own orders.
			# Mining workers keep their independent delivery/idle lane behavior.
			if int(other.kind)!=0:
				var assigned=ACData.point(other.goal)
				if next.distance_to(assigned)>maxf(2.75,ACData.point(other.pos).distance_to(assigned)+.001):continue
			if _unit_fits(other,next):
				_set_unit_position(other,next)
				other.yield_visual_until=time+.12
				break

func _advance_ground(unit: Dictionary, desired: Vector2, goal: Vector2, dt: float) -> Vector2:
	var original=ACData.point(unit.pos)
	var count=maxi(1,ceili(desired.length()/.2))
	var part=desired/count
	var direct=true
	for i in range(count):
		var pos=ACData.point(unit.pos)
		var avoiding=time<float(unit.get("avoid_until",-1.0))
		var movement_goal=(goal-pos).normalized()*part.length() if avoiding else part
		var next=pos+movement_goal
		var lookahead=pos+movement_goal.normalized()*maxf(.8,collision_size(int(unit.race),int(unit.kind)).x)
		if _unit_fits(unit,next) and (not avoiding or _unit_fits(unit,lookahead)):
			_set_unit_position(unit,next)
			unit.avoid_until=-1.0
			continue
		direct=false
		if not avoiding:unit._avoid_side=float(unit.get("_avoid_side",1.0))
		unit.avoid_until=time+1.1
		_request_room(unit,goal,dt/count)
		var alternatives: Array=[]
		# Every unit uses the same handedness, so opposing traffic chooses
		# opposite world sides instead of repeatedly mirroring the same dodge.
		var side=float(unit.get("_avoid_side",1.0))
		for angle in [side*PI/6,side*PI/3,side*PI/2]:
			alternatives.append(movement_goal.rotated(angle))
		# Keep one avoidance side until genuinely blocked, instead of flipping
		# left/right on alternating ticks beside an occupied destination.
		if float(unit.blocked_clock)>.65:
			for angle in [-side*PI/6,-side*PI/3,-side*PI/2]:alternatives.append(movement_goal.rotated(angle))
		if absf(movement_goal.x)>movement_goal.length()*.4:alternatives.append(Vector2(movement_goal.x,0))
		if absf(movement_goal.y)>movement_goal.length()*.4:alternatives.append(Vector2(0,movement_goal.y))
		alternatives.append(movement_goal*.45)
		var moved=false
		for movement in alternatives:
			if _unit_fits(unit,pos+movement):
				_set_unit_position(unit,pos+movement)
				if absf(movement_goal.cross(movement))>.000001:unit._avoid_side=signf(movement_goal.cross(movement))
				moved=true
				break
		if not moved:break
	if direct:
		unit.blocked_clock=0.0
		unit.nav_blocked=0.0
	else:
		unit.blocked_clock+=dt
		unit.nav_blocked+=dt
		if unit.nav_blocked>1.1:
			unit.path=[]
			unit.repath=0.0
			unit.nav_blocked=0.0
	return ACData.point(unit.pos)-original

func _move(u: Dictionary, goal: Vector2, dt: float, reach: float = .5) -> bool:
	var p=ACData.point(u.pos)
	var d=ACData.unit(int(u.race),int(u.kind))
	if p.distance_to(goal)<=reach:
		return true
	if u.anchored:
		return false
	if not d.air and _crowd_arrived(u,goal,reach):return true
	if not d.air and float(u.blocked_clock)>.3:_request_room(u,goal,dt)
	var next=goal
	if not d.air:
		if p.distance_squared_to(goal)<=144 and _ground_sweep(_body_size(u),p,goal):
			u.path=[ACData.packed(goal)];u.path_failed=false;u.path_rev=map.revision;u.repath=3.0;u._path_goal=ACData.packed(goal)
		u.repath-=dt
		if u.path.is_empty() and u.path_failed and u.repath>0 and int(u.path_rev)==map.revision and ACData.point(u.get("_path_goal",ACData.packed(goal))).distance_squared_to(goal)<.01:return false
		var goal_shifted=ACData.point(u.get("_path_goal",ACData.packed(goal))).distance_squared_to(goal)>1.0
		if u.path.is_empty() or int(u.path_rev)!=map.revision or u.repath<=0 or goal_shifted:
			u._path_deferred=false
			u.path=_clearance_path(u,p,goal)
			if u._path_deferred:return false
			u._path_goal=ACData.packed(goal)
			u.path_failed=u.path.is_empty()
			u.avoid_until=-1.0
			u.path_rev=map.revision
			u.repath=(.6 if u.path_failed else 3.0)+rng.randf()*.4
		if u.path.is_empty():
			# AStar has no steps when start and destination round to the same
			# clearance cell. A large body can still have almost one tile left
			# to its valid continuous edge goal. Verify that short sweep before
			# finishing it directly instead of stopping at the grid center.
			var direct=p.distance_to(goal)<=1.5
			if direct:
				var samples=maxi(1,ceili(p.distance_to(goal)/.2))
				for sample in range(samples+1):
					if not _unit_fits(u,p.lerp(goal,float(sample)/samples),false):direct=false;break
			if direct:
				u.path=[ACData.packed(goal)]
			else:
				return false
		if not u.path.is_empty():
			for index in range(mini(u.path.size()-1,16),0,-1):
				var point=ACData.point(u.path[index])
				if p.distance_squared_to(point)<=64 and _ground_sweep(_body_size(u),p,point):
					u.path=u.path.slice(index);break
		next=ACData.point(u.path[0])
		# Skip already-passed grid corners with a checked body sweep. Avoidance
		# can move beyond a waypoint; walking backwards to it causes oscillation.
		while u.path.size()>1:
			var ahead=ACData.point(u.path[1])
			if p.distance_to(ahead)>1.8:break
			var clear=true
			for sample in range(1,9):
				if not _unit_fits(u,p.lerp(ahead,float(sample)/8.0),false):clear=false;break
			if not clear:break
			u.path.pop_front()
			next=ahead
		if p.distance_to(next)<.22:
			if u.path.size()==1:
				if p.distance_to(goal)<=reach:return true
				if not _unit_fits(u,goal,false):return true
				next=goal
			elif _ground_sweep(_body_size(u),p,ACData.point(u.path[1])):
				u.path.pop_front()
				next=ACData.point(u.path[0])
	var direction=(next-p).normalized()
	var speed=float(d.speed)*(.45 if time<u.slow_until else 1.0)
	var step=direction*minf(speed*dt,p.distance_to(next))
	var movement=step
	if d.air:
		_set_unit_position(u,(p+step).clamp(Vector2.ONE,Vector2(126,126)))
	else:
		movement=_advance_ground(u,step,goal,dt)
	if movement.length_squared()>.00001:
		u.facing=ACData.packed(movement.normalized())
		u.moving=true
	return false

func _nearest_hq(owner: int, pos: Vector2) -> Dictionary:
	var result: Dictionary={}
	var best=INF
	if not collision_index_valid:_rebuild_collision_index()
	for b in owned_buildings.get(Vector2i(owner,0),[]):
		if b.progress>=1 and b.hp>0:
			var dist=footprint_distance(b,pos)
			if dist<best:
				result=b
				best=dist
	return result

func step(dt: float) -> void:
	if ended:
		return
	time+=dt
	paths_this_tick=0
	var phase_start=Time.get_ticks_usec()
	perf.ticks+=1
	effects=effects.filter(func(e): return e.until>time)
	corpses=corpses.filter(func(e): return e.until>time)
	# Text notices and completed spell records should not accumulate forever.
	for event in events:
		if not event.has("created"):event.created=time
	events=events.filter(func(e):return time-float(e.created)<30 or (e.get("spell",false) and not e.get("resolved",false)))
	for node_id in mining_claims.keys():
		var holder=entity(int(mining_claims[node_id]))
		if holder.is_empty() or not mining_worker(holder) or int(holder.target)!=int(node_id) or int(holder.carried)>0:
			mining_claims.erase(node_id)
			if not holder.is_empty():holder.gather_clock=0.0;holder.mining_state="idle"
	for r in map.resources:
		r.busy=maxf(0,r.busy-dt)
	for b in buildings:
		if b.hp<=0 or players[b.owner].lost:
			continue
		_tick_building(b,dt)
	_rebuild_collision_index()
	perf.building_us+=Time.get_ticks_usec()-phase_start
	phase_start=Time.get_ticks_usec()
	for u in units:
		if u.hp<=0 or u.container>=0 or players[u.owner].lost:
			continue
		_tick_unit(u,dt)
	perf.unit_us+=Time.get_ticks_usec()-phase_start
	phase_start=Time.get_ticks_usec()
	_separate_units(dt,false)
	perf.collision_us+=Time.get_ticks_usec()-phase_start
	phase_start=Time.get_ticks_usec()
	CITRUS_BROOD.cleanup_dead(self)
	var dead_buildings=buildings.filter(func(b):return b.hp<=0)
	for b in dead_buildings:
		for q in b.queue:
			if q.has("brood"):continue
			players[b.owner].reserved=maxf(0,players[b.owner].reserved-ACData.unit(int(b.race),int(q.kind)).pop)
	if not dead_buildings.is_empty():
		buildings=buildings.filter(func(b): return b.hp>0)
		map.reset_solids(buildings)
	for u in units:
		if u.hp<=0 and not u.get("dead_processed",false):
			u.dead_processed=true
			if int(u.race)==1:
				corpses.append({"pos":u.pos,"until":time+20,"value":float(ACData.unit(1,int(u.kind)).pop)*12})
			for cargo_id in u.cargo:
				var rider=entity(int(cargo_id))
				if not rider.is_empty():
					rider.container=-1
					collision_index_valid=false
					rider.pos=ACData.packed(unit_free_position(int(rider.race),int(rider.kind),ACData.point(u.pos),int(rider.id)))
					collision_index_valid=false
					rider.hp*=.5
	units=units.filter(func(u):return u.hp>0)
	_recalculate_supply()
	perf.cleanup_us+=Time.get_ticks_usec()-phase_start
	roots.update(self)
	phase_start=Time.get_ticks_usec()
	vision_clock-=dt
	if vision_clock<=0:
		vision_clock=.35
		_update_vision()
	perf.vision_us+=Time.get_ticks_usec()-phase_start
	phase_start=Time.get_ticks_usec()
	ai_clock-=dt
	if ai_clock<=0:
		ai_clock=.5
		for owner in range(players.size()):
			if players[owner].bot and not players[owner].lost:
				_ai(owner)
	if time>2:
		_check_end()
	perf.ai_us+=Time.get_ticks_usec()-phase_start

func _tick_building(b: Dictionary, dt: float) -> void:
	var d=ACData.building(int(b.race),int(b.kind))
	if b.progress<1:
		var w=entity(int(b.worker))
		if int(b.race)==0:
			if w.is_empty() or w.order!="construct" or int(w.target)!=int(b.id) or not construction_reach(w,b):
				return
		elif not b.get("initiated",false):
			if w.is_empty() or w.order!="construct" or int(w.target)!=int(b.id) or not construction_reach(w,b):
				return
			b.initiated=true
			if int(b.race)==1:
				# Morph only on arrival. This is consumption, not a combat death.
				b.builder_hp=w.hp
				b.builder_carried=w.get("carried",0)
				_release_mining_claim(w)
				w.hp=0.0;w.dead_processed=true;w.order="consumed"
				w.target=-1;w.path=[];w.build_queue=[]
				b.worker=-1
				collision_index_valid=false
			else:w.order="idle"
		var amount=minf(dt/float(d.time),1.0-float(b.progress))
		b.progress+=amount
		b.hp=minf(d.hp,b.hp+d.hp*.9*amount)
		b.shield=minf(d.shield,b.shield+d.shield*amount)
		if b.progress>=1:
			if not w.is_empty() and int(b.race)==0:
				w.order="idle"
			events.append({"owner":b.owner,"text":d.name+" 건설 완료"})
		return
	_regenerate(b,d,dt)
	if int(b.kind)==1:_tick_tera(b,dt)
	var powered=not (int(b.race)==2 and int(b.kind) not in [0,1,2,11,12] and not in_field(int(b.owner),center(b),12))
	var rate=1.0 if powered else .5
	if int(b.race)==1 and int(b.kind) in [0,3]:
		CITRUS_BROOD.producer(self,b,dt)
	if b.research!="":
		b.research_left-=dt*rate
		if b.research_left<=0:
			players[b.owner][b.research]+=1
			events.append({"owner":b.owner,"text":"연구 완료: "+str(b.research)})
			b.research=""
	if not b.queue.is_empty() and int(b.race)!=1:
		var q=b.queue[0]
		q.left=maxf(0,q.left-dt*rate)
		if q.left<=0:
			var ud=ACData.unit(int(b.race),int(q.kind))
			var spawn=center(b)+Vector2(0,float(d.h)*.5+1.4)
			if not ud.air:
				spawn=map.nearest_free(spawn)
			if ud.air or map.walkable(Vector2i(spawn.round())):
				var u=add_unit(int(b.owner),int(q.kind),spawn)
				players[b.owner].reserved=maxf(0,players[b.owner].reserved-ud.pop)
				b.queue.pop_front()
				if int(u.kind)==0:
					u.order="gather"
					u.target=nearest_resource(spawn,"as",int(u.owner))
				else:
					u.order="attack_move"
					u.goal=b.rally
	if int(b.kind) in [11,12] and int(b.race)!=1 or int(b.race)==1 and int(b.kind) in [10,11]:
		b.cooldown=maxf(0,b.cooldown-dt)
		var aa=int(b.kind)==(11 if int(b.race)==1 else 12)
		var target=_find_target(b,7 if aa else 6,"a" if aa else "g")
		if not target.is_empty() and b.cooldown<=0:
			_damage(b,target,24 if aa else 15)
			b.cooldown=1.0
			b.fired=time
	if int(b.race)==2 and int(b.kind)==10:
		var count=0
		for u in units:
			if allied(int(b.owner),int(u.owner)) and time-u.damaged>5 and center(b).distance_to(ACData.point(u.pos))<5:
				var ud=ACData.unit(int(u.race),int(u.kind))
				if u.hp<ud.hp:
					u.hp=minf(ud.hp,u.hp+ud.hp*.01*dt)
					count+=1
					if count>=3:
						break

func _tick_tera(b: Dictionary, dt: float) -> void:
	b.tera_hq=tera_headquarters(int(b.owner),footprint(b).get_center())
	b.tera_active=int(b.tera_hq)>=0
	if not b.tera_active:
		b.tera_clock=0.0
		return
	var res=resource(int(b.tera_resource))
	if res.is_empty():
		for vent in map.resources:
			if vent.type=="tera" and ACData.point(b.pos).distance_squared_to(refinery_anchor(vent))<.000001:
				res=vent
				b.tera_resource=vent.id
				break
	if res.is_empty() or res.amount<=0:
		b.tera_clock=0.0
		return
	b.tera_clock+=dt
	while b.tera_clock>=TERA_INTERVAL and res.amount>0:
		b.tera_clock-=TERA_INTERVAL
		var amount=mini(TERA_AMOUNT,int(res.amount))
		res.amount-=amount
		players[b.owner].tera+=amount
		players[b.owner].gathered+=amount
		_effect("tera",b,center(b),.75,{"amount":amount,"resource":res.id})

func _displace_unit(unit: Dictionary, delta: Vector2) -> bool:
	if unit.anchored:return false
	var next=(ACData.point(unit.pos)+delta).clamp(Vector2.ONE,Vector2(126,126))
	if collision_layer(int(unit.race),int(unit.kind))==COLLISION_GROUND and not _ground_fits_size(collision_size(int(unit.race),int(unit.kind)),next):return false
	_set_unit_position(unit,next)
	return true

func _resolve_unit_pair(a: Dictionary, b: Dictionary, soft: bool, dt: float) -> bool:
	if _body_layer(a)!=_body_layer(b):return false
	if _workers_can_overlap(a,b):return false
	var delta=ACData.point(a.pos)-ACData.point(b.pos)
	var sum=(_body_size(a)+_body_size(b))*.5
	var penetration=sum-delta.abs()
	if penetration.x<=0 or penetration.y<=0:return false
	var axes=[Vector2.RIGHT,Vector2.DOWN] if penetration.x<penetration.y else [Vector2.DOWN,Vector2.RIGHT]
	for axis in axes:
		var component=delta.dot(axis)
		var direction=axis*(-1.0 if component<0 or (absf(component)<.0001 and a.id<b.id) else 1.0)
		var amount=(penetration.x if axis==Vector2.RIGHT else penetration.y)+COLLISION_SKIN
		if soft:amount=minf(amount,dt*1.8)
		if a.anchored and b.anchored:return false
		var a_share=0.0 if a.anchored else amount if b.anchored else amount*.5
		var b_share=amount-a_share
		var a_next=ACData.point(a.pos)+direction*a_share
		var b_next=ACData.point(b.pos)-direction*b_share
		var a_fits=soft or _ground_fits_size(collision_size(int(a.race),int(a.kind)),a_next)
		var b_fits=soft or _ground_fits_size(collision_size(int(b.race),int(b.kind)),b_next)
		if a_fits and b_fits:
			if a_share>0:_displace_unit(a,direction*a_share)
			if b_share>0:_displace_unit(b,-direction*b_share)
			return true
		if not a.anchored and (soft or _ground_fits_size(collision_size(int(a.race),int(a.kind)),ACData.point(a.pos)+direction*amount)):
			_displace_unit(a,direction*amount)
			return true
		if not b.anchored and (soft or _ground_fits_size(collision_size(int(b.race),int(b.kind)),ACData.point(b.pos)-direction*amount)):
			_displace_unit(b,-direction*amount)
			return true
	return false

func _separate_units(dt: float, force_recovery: bool=true) -> void:
	if not collision_index_valid:_rebuild_collision_index()
	if not force_recovery and collision_recovery_revision==map.revision:
		# Ground movement, spawns and unloads already preserve hard bounds.
		# Re-projecting every ground pair each tick needlessly repeats all
		# collision checks; only the independent soft aircraft layer needs it.
		for aircraft in units:
			if aircraft.hp<=0 or aircraft.container>=0 or _body_layer(aircraft)!=COLLISION_AIR:continue
			for other in _nearby_units(ACData.point(aircraft.pos)):
				if other.id<=aircraft.id or other.hp<=0 or other.container>=0 or _body_layer(other)!=COLLISION_AIR:continue
				_resolve_unit_pair(aircraft,other,true,dt)
		return
	collision_recovery_revision=map.revision
	for unit in units:
		if unit.hp<=0 or unit.container>=0 or collision_layer(int(unit.race),int(unit.kind))!=COLLISION_GROUND:continue
		if not _ground_fits_size(collision_size(int(unit.race),int(unit.kind)),ACData.point(unit.pos)):
			_set_unit_position(unit,unit_free_position(int(unit.race),int(unit.kind),ACData.point(unit.pos),int(unit.id)))
			unit.path=[]
	# Movement already rejects occupied boxes. The projection pass primarily
	# handles unloads, scaffolds placed over units and legacy overlapping states.
	for iteration in range(6):
		var changed=false
		for unit in units:
			if unit.hp<=0 or unit.container>=0:continue
			var layer=collision_layer(int(unit.race),int(unit.kind))
			if layer==COLLISION_AIR and iteration>0:continue
			for other in _nearby_units(ACData.point(unit.pos)):
				if other.id<=unit.id or other.hp<=0 or other.container>=0:continue
				if _body_layer(other)!=layer:continue
				var sum=(unit._body_half if unit.has("_body_half") else _body_size(unit)*.5)+(other._body_half if other.has("_body_half") else _body_size(other)*.5)
				if absf(float(unit.pos[0])-float(other.pos[0]))>=sum.x or absf(float(unit.pos[1])-float(other.pos[1]))>=sum.y:continue
				if _resolve_unit_pair(unit,other,layer==COLLISION_AIR,dt):changed=true
		if not changed:break
	# A dense initial overlap has no valid continuous displacement at its
	# center; recover those exceptional states onto nearby unoccupied ground.
	for unit in units:
		if unit.hp<=0 or unit.container>=0 or unit.anchored or collision_layer(int(unit.race),int(unit.kind))!=COLLISION_GROUND:continue
		if not _unit_fits(unit,ACData.point(unit.pos)):
			_set_unit_position(unit,unit_free_position(int(unit.race),int(unit.kind),ACData.point(unit.pos),int(unit.id)))
			unit.path=[]

func _regenerate(e: Dictionary, d: Dictionary, dt: float) -> void:
	var pos=center(e)
	if int(e.race)==1:
		if e.hp>=d.hp:return
		var field=in_field(int(e.owner),pos,13)
		var rate=0.0
		if time-e.damaged>=4:
			rate=.02 if field else .01
		elif field:
			rate=.003
		e.hp=minf(d.hp,e.hp+d.hp*rate*dt)
	elif int(e.race)==2:
		if e.shield>=d.shield:return
		var wait=7.0
		if not e.has("progress"):
			var nearby=0
			for u in _query_entities(pos,4):
				if not u.has("progress") and u.hp>0 and u.container<0 and u.id!=e.id and allied(int(e.owner),int(u.owner)) and ACData.point(u.pos).distance_squared_to(pos)<16:
					nearby+=1
					if nearby>=2:
						wait=5
						break
		if time-e.damaged>=wait:
			e.shield=minf(d.shield,e.shield+d.shield*.04*dt)

func _tick_unit(u: Dictionary, dt: float) -> void:
	if u.get("technical",false):
		_regenerate(u,u._definition,dt)
		CITRUS_BROOD.tick_pod(self,u,dt)
		return
	u.action_intent="idle"
	u._healing_was=bool(u.get("healing",false))
	u._heal_previous_target=int(u.get("heal_target",-1))
	u.healing=false
	u.heal_target=-1
	u.heal_kind=""
	var previous_pos=ACData.point(u.pos)
	u._aiming=false
	_tick_unit_behavior(u,dt)
	var displacement=ACData.point(u.pos)-previous_pos
	if displacement.length_squared()>.000001:u.body_direction=ACData.packed(displacement.normalized())
	if not u._aiming:u.turret_direction=u.body_direction.duplicate()
	var action=str(u.action_intent)
	if u.moving:
		action="walk"
	elif time<float(u.get("yield_visual_until",-1.0)):
		action="walk"
	elif time-float(u.fired)<minf(.55,float(ACData.unit(int(u.race),int(u.kind)).period)*.65):
		action="attack"
	_set_action(u,action)
	u.activity_clock=maxf(0,float(u.activity_clock)-dt)
	if action in ["harvest","construct","repair"] and u.activity_clock<=0:
		u.activity_clock=.72
		var target=resource(int(u.target)) if action=="harvest" else entity(int(u.target))
		var pos=ACData.point(target.pos) if action=="harvest" and not target.is_empty() else center(target) if not target.is_empty() else ACData.point(u.pos)
		_effect(action,u,pos,.55,{"target":int(u.target)})

func _tick_unit_behavior(u: Dictionary, dt: float) -> void:
	var d=u._definition if u.has("_definition") else ACData.unit(int(u.race),int(u.kind))
	u.moving=false
	u.cooldown=maxf(0,u.cooldown-dt)
	u.ability_cd=maxf(0,u.ability_cd-dt)
	if int(u.race)==0 and int(u.kind)==7 and u.get("cloak_active",false):
		u.energy=maxf(0,float(u.energy)-dt)
		if u.energy<=0:u.cloak_active=false
	else:u.energy=clampf(u.energy+dt*ENERGY_REGEN,0,float(u.max_energy)) if u.max_energy>0 else 0.0
	if u.fleeing and (time>=float(u.flee_until) or u.order!="move"):
		u.fleeing=false
		if u.order=="move":u.order="idle";u.path=[]
	_regenerate(u,d,dt)
	if int(u.kind)==0 and u.order=="idle":_advance_build_queue(u)
	if not u.fleeing and d.role in ["medic","healer_detector","priest"]:
		_support(u,d,dt)
	var pos=ACData.point(u.pos)
	if u.order=="build_move":
		var plan: Dictionary=u.get("build_plan",{})
		var error=""
		if plan.is_empty():error="건설 계획이 취소되었습니다"
		elif construction_reach(u,plan):error=_arrive_construction(u)
		else:
			_move_to_building(u,plan,dt)
			if float(u.blocked_clock)>6.0:error="건설 위치까지 이동할 수 없습니다"
		if error!="":
			u.erase("build_plan");u.order="idle";u.target=-1;u.path=[]
			events.append({"owner":u.owner,"text":error,"created":time})
			_advance_build_queue(u)
		return
	if u.order=="construct":
		var b=entity(int(u.target))
		if b.is_empty() or not b.has("progress") or b.hp<=0 or b.progress>=1:
			u.order="idle"
			_advance_build_queue(u)
		else:
			if construction_reach(u,b):
				u.action_intent="construct"
			else:
				_move_to_building(u,b,dt)
		return
	if u.order=="gather":
		_gather(u,dt)
		return
	if u.order=="repair":
		var t=entity(int(u.target))
		if t.is_empty() or int(u.race)!=0:
			u.order="idle"
			return
		var td=ACData.building(int(t.race),int(t.kind)) if t.has("progress") else ACData.unit(int(t.race),int(t.kind))
		if int(t.race)!=0 or (not t.has("progress") and int(t.kind) in [0,1,2,3,4,7]):
			u.order="idle"
			return
		var repairing=footprint_distance(t,pos)<=1.2 if t.has("progress") else pos.distance_to(center(t))<=1.8
		if not repairing:
			if t.has("progress"):_move_to_building(u,t,dt)
			else:_move(u,center(t),dt,1.8)
		else:
			var amount=minf(td.hp-t.hp,td.hp*.02*dt)
			if amount>0 and pay(int(u.owner),amount*.05,0):
				t.hp+=amount
				u.action_intent="repair"
		return
	if u.order=="load":
		var carrier=entity(int(u.target))
		if carrier.is_empty() or not carrier.has("cargo"):
			u.order="idle"
		elif _move(u,ACData.point(carrier.pos),dt,1.5):
			var used=0.0
			for id in carrier.cargo:
				var rider=entity(int(id))
				if not rider.is_empty():
					used+=ACData.unit(int(rider.race),int(rider.kind)).pop
			if used+d.pop<=8:
				u.container=carrier.id
				carrier.cargo.append(u.id)
				u.order="idle"
		return
	var target: Dictionary={}
	if u.order=="attack":
		target=entity(int(u.target))
		if target.is_empty() or not can_see(int(u.owner),target):
			u.order="attack_move"
			u.target=-1
			target={}
	if target.is_empty() and d.damage>0 and u.order in ["idle","hold","attack_move"]:
		if time>=float(u.get("_scan_at",0.0)):
			target=_find_target(u,maxf(float(d.range),7.0),str(d.targets))
			u._auto_target=int(target.get("id",-1))
			u._scan_at=time+.22+float(int(u.id)%5)*.012
		else:
			target=entity(int(u.get("_auto_target",-1)))
			if not target.is_empty() and not can_see(int(u.owner),target):target={}
	if not target.is_empty() and _can_attack(d,target):
		u._aiming=true
		u.turret_direction=ACData.packed((center(target)-pos).normalized())
		var distance=pos.distance_to(center(target))
		var attack_range=float(d.range)
		if u.anchored and d.role in ["siege","fortress"]:
			attack_range+=3
		if target.has("progress"):
			var bd=ACData.building(int(target.race),int(target.kind))
			attack_range+=minf(bd.w,bd.h)*.45
		var melee=float(d.range)<=1.5
		if distance<=attack_range or (melee and combat_body_gap(u,target)<=.12):
			u.facing=ACData.packed((center(target)-pos).normalized())
			if u.cooldown<=0:
				if d.role=="suicide":
					_area_damage(u,center(target),float(d.get("splash_radius",2.3)),float(d.damage))
					_effect("explosion",u,center(target),.65,{"projectile":"explosion"})
					u.hp=0
				else:
					_damage(u,target,float(d.damage)+players[u.owner].attack*2)
					if d.role in ["siege","bomber","golem","tree"]:
						_area_damage(u,center(target),1.3,float(d.damage)*.4,int(target.id))
					if d.role in ["root","officer"]:
						target.slow_until=time+2.0
				u.cooldown=float(d.period)
				u.fired=time
				_set_action(u,"attack",true)
		elif u.order!="hold":
			if melee:_move(u,_melee_approach(u,target),dt,.04)
			else:_move(u,center(target),dt,attack_range*.85)
	elif u.order in ["move","attack_move"]:
		if _move(u,ACData.point(u.goal),dt):
			u.order="idle"
			u.fleeing=false

func _gather(u: Dictionary, dt: float) -> void:
	var pos=ACData.point(u.pos)
	if u.carried>0:
		_release_mining_claim(u)
		u.mining_state="return"
		var hq=_nearest_hq(int(u.owner),pos)
		if hq.is_empty():
			return
		if building_contact(u,hq,AS_UNLOAD_REACH):
			players[u.owner][u.cargo_type]+=u.carried
			players[u.owner].gathered+=u.carried
			_effect("deposit",u,pos,.45,{"amount":u.carried,"target":hq.id,"resource_type":u.cargo_type})
			u.carried=0
			u.path=[]
			u.mining_state="travel"
			# Returning miners can overlap one another. Once the final cargo
			# is deposited, the new solid body must separate from miners still
			# returning, otherwise both may start inside each other's box.
			if not mining_worker(u):collision_recovery_revision=-1
		else:
			_move_to_building(u,hq,dt)
		return
	var res=resource(int(u.target))
	if res.is_empty() or res.amount<=0 or res.type!="as":
		_release_mining_claim(u)
		u.target=_home_ore(u) if u.has("auto_mine_hq") else nearest_resource(pos,"as",int(u.owner))
		u.gather_clock=0.0
		u.path=[]
		res=resource(int(u.target))
		if res.is_empty():
			u.order="idle"
			u.mining_state="idle"
			collision_recovery_revision=-1
			return
	var holder=int(mining_claims.get(int(res.id),-1))
	if holder>=0 and holder!=int(u.id) and _retarget_busy_resource(u,res):return
	if int(u.get("_mining_node",-1))!=int(res.id) or int(u.get("_mining_revision",-1))!=map.revision or (float(u.blocked_clock)>.6 and time>=float(u.get("_mining_retry",0))):
		u._mining_retry=time+.8
		u.path=[];u.repath=0.0
		u._mining_node=res.id
		u._mining_revision=map.revision
		var home=entity(int(u.get("auto_mine_hq",-1)))
		u._mining_goal=_resource_approach(res,pos,_body_size(u),center(home) if not home.is_empty() else Vector2.INF)
		if not u._mining_goal.is_finite():
			u.target=_home_ore(u);u._mining_node=-1;return
	var rect=resource_rect(res)
	var near=pos.distance_to(pos.clamp(rect.position,rect.end))<=maxf(_body_size(u).x,_body_size(u).y)*.5+.43
	if not near:
		_release_mining_claim(u)
		u.mining_state="travel"
		_move(u,u._mining_goal,dt,.12)
		return
	if _claim_miner(u,res):
		u.mining_state="harvest"
		u.action_intent="harvest"
		var direction=(ACData.point(res.pos)-ACData.point(u.pos)).normalized()
		if direction.length_squared()>.01:u.facing=ACData.packed(direction)
		u.gather_clock+=dt
		res._worked_at=time
		if u.gather_clock>=AS_INTERVAL:
			var amount=mini(AS_AMOUNT,int(res.amount))
			res.amount-=amount
			res.busy=0.0
			u.carried=amount
			u.approach_target=-1
			u.cargo_type="as"
			u.gather_clock=0
			u.path=[]
			_release_mining_claim(u)
			u.mining_state="return"
			u.action_intent="idle"
			if res.amount<=0:_sync_resource_obstacles()
	else:
		u.mining_state="waiting"
		u.action_intent="idle"
		u.gather_clock=0.0
		u._mining_wait=float(u.get("_mining_wait",0.0))+dt
		_retarget_busy_resource(u,res)

func _release_mining_claim(unit: Dictionary) -> void:
	var target=int(unit.get("target",-1))
	if int(mining_claims.get(target,-1))==int(unit.id):mining_claims.erase(target)
	unit.gather_clock=0.0
	unit.mining_state="idle"

func _claim_miner(unit: Dictionary, node: Dictionary) -> bool:
	var holder_id=int(mining_claims.get(int(node.id),-1))
	if holder_id>=0 and holder_id!=int(unit.id):
		var holder=entity(holder_id)
		if holder.is_empty() or not mining_worker(holder) or int(holder.target)!=int(node.id) or int(holder.carried)>0:
			mining_claims.erase(int(node.id))
		else:return false
	if int(mining_claims.get(int(node.id),-1))==int(unit.id):return true
	if float(node.get("_worked_at",-1))==time:return false
	mining_claims[int(node.id)]=int(unit.id)
	unit._mining_wait=0.0
	unit.gather_clock=0.0
	return true

func _can_attack(d: Dictionary, target: Dictionary) -> bool:
	var is_air=false
	if not target.has("progress"):
		is_air=bool(ACData.unit(int(target.race),int(target.kind)).air)
	return ("a" if is_air else "g") in str(d.targets)

func _team_threat(candidate: Dictionary, owner: int) -> bool:
	if candidate.has("progress"):return false
	if time-float(candidate.get("_last_attack_time",-99))<=2.0 and allied(owner,int(candidate.get("_last_attack_owner",candidate.owner))):return true
	var victim=entity(int(candidate.get("target",-1)) if candidate.get("order","")=="attack" else int(candidate.get("_auto_target",-1)))
	if victim.is_empty() or not allied(owner,int(victim.owner)):return false
	var definition=ACData.unit(int(candidate.race),int(candidate.kind))
	if float(definition.damage)<=0 or not _can_attack(definition,victim):return false
	return center(candidate).distance_to(center(victim))<=float(definition.range)+1.0

func _find_target(attacker: Dictionary, radius: float, targets: String) -> Dictionary:
	if attacker.get("order","")=="attack_move":
		var threat: Dictionary={}
		var nearest=radius*radius
		for candidate in _query_entities(center(attacker),radius):
			if candidate.hp<=0 or candidate.has("progress") or candidate.get("container",-1)>=0 or allied(int(attacker.owner),int(candidate.owner)) or players[candidate.owner].lost:continue
			if ("a" if _body_layer(candidate)==COLLISION_AIR else "g") not in targets:continue
			var distance=center(attacker).distance_squared_to(center(candidate))
			if distance>nearest or not can_see(int(attacker.owner),candidate) or not _team_threat(candidate,int(attacker.owner)):continue
			nearest=distance;threat=candidate
		if not threat.is_empty():return threat
	var best=radius*radius
	var result: Dictionary={}
	var pos=center(attacker)
	if not collision_index_valid:_rebuild_collision_index()
	perf.spatial_queries+=1
	if "g" in targets:
		var low=Vector2i(((pos-Vector2.ONE*radius)/ENTITY_CELL).floor())
		var high=Vector2i(((pos+Vector2.ONE*radius)/ENTITY_CELL).floor())
		for x in range(low.x,high.x+1):
			for y in range(low.y,high.y+1):
				for target in building_spatial.get(Vector2i(x,y),[]):
					if target.hp<=0 or allied(int(attacker.owner),int(target.owner)) or players[target.owner].lost:continue
					var distance=pos.distance_squared_to(center(target))
					if distance<best and can_see(int(attacker.owner),target):best=distance;result=target
	var origin=Vector2i((pos/COLLISION_CELL).floor())
	for ring in range(ceili(radius/COLLISION_CELL)+1):
		if ring>1 and best<=pow(float(ring-1)*COLLISION_CELL,2):break
		for dx in range(-ring,ring+1):
			for dy in range(-ring,ring+1):
				if maxi(absi(dx),absi(dy))!=ring:continue
				var key=origin+Vector2i(dx,dy)
				var corner=Vector2(key)*COLLISION_CELL
				if pos.distance_squared_to(pos.clamp(corner,corner+Vector2.ONE*COLLISION_CELL))>=best:continue
				for target in collision_index.get(key,[]):
					perf.target_candidates+=1
					if target.hp<=0 or target.container>=0 or allied(int(attacker.owner),int(target.owner)) or players[target.owner].lost:continue
					var tx=float(target.pos[0])-pos.x
					var ty=float(target.pos[1])-pos.y
					var distance=tx*tx+ty*ty
					if distance>=best:continue
					if ("a" if _body_layer(target)==COLLISION_AIR else "g") not in targets:continue
					if can_see(int(attacker.owner),target):best=distance;result=target
	return result

func projectile_style(attacker: Dictionary) -> String:
	if attacker.has("progress"):
		return ["missile","thorn","bolt"][int(attacker.race)]
	var styles=[
		["tool","bullet","shotgun","bash","none","shell","missile","bullet","none","laser","bomb","none","cannon"],
		["drill","claw","acid","slam","explosion","vine","seed","thorn","spore","none","acid","spore","seed"],
		["spark","slash","bolt","blade","none","spell","none","plasma","beam","bolt","slash","none","beam"]
	]
	return styles[int(attacker.get("race",0))][clampi(int(attacker.get("kind",0)),0,12)]

func _damage(attacker: Dictionary, target: Dictionary, amount: float, show_projectile: bool=true) -> void:
	if target.hp<=0 or allied(int(attacker.owner),int(target.owner)):
		return
	attacker._last_attack_owner=int(target.owner)
	attacker._last_attack_time=time
	var d=ACData.building(int(target.race),int(target.kind)) if target.has("progress") else ACData.unit(int(target.race),int(target.kind))
	var left=amount
	if target.shield>0:
		left=maxf(1,left-float(players[target.owner].shield))
		var absorbed=minf(left,target.shield)
		target.shield-=absorbed
		left-=absorbed
	if left>0:
		var armor=(2 if int(target.race)==0 else (0 if int(target.race)==1 else 1)) if target.has("progress") else int(d.armor)+int(players[target.owner].armor)
		left=maxf(1,left-armor)
		if not target.has("progress") and d.role=="shield":
			var facing=ACData.point(target.facing)
			if facing.dot((center(attacker)-center(target)).normalized())>.3:
				left*=.75
		target.hp-=left
	target.damaged=time
	if show_projectile:
		var style=projectile_style(attacker)
		var travel=clampf(center(attacker).distance_to(center(target))/24.0,.12,.6)
		if style in ["beam","laser","tool","bash","claw","slam","slash","blade","drill","spark"]:travel=.18
		_effect("shot",attacker,center(target),travel,{"target":int(target.id),"projectile":style,"damage":amount,"target_air":not target.has("progress") and ACData.unit(int(target.race),int(target.kind)).air})
	if target.hp<=0:
		players[attacker.owner].kills+=1
		_effect("explosion",target,center(target),.6,{"attacker":int(attacker.get("id",-1)),"fatal":true})
	elif not target.has("progress"):
		_flee_from_damage(target,attacker)

func _flee_from_damage(unit: Dictionary, attacker: Dictionary) -> void:
	var definition=unit._definition if unit.has("_definition") else ACData.unit(int(unit.race),int(unit.kind))
	if (float(definition.damage)>0 and str(definition.targets)!="") or unit.container>=0 or unit.anchored or unit.fleeing:return
	if time<float(unit.get("_flee_ready_at",-1)) or time<float(unit.get("_flee_manual_until",-1)):return
	unit._flee_ready_at=time+2.5
	var origin=ACData.point(unit.pos)
	var direction=origin-center(attacker)
	if direction.length_squared()<.0001:direction=-ACData.point(unit.facing)
	if direction.length_squared()<.0001:direction=Vector2.RIGHT
	direction=direction.normalized()
	for distance in [4.0,3.0,2.0]:
		for angle in [0.0,PI*.25,-PI*.25,PI*.5,-PI*.5]:
			var goal=(origin+direction.rotated(angle)*distance).clamp(Vector2.ONE,Vector2.ONE*(ACMap.SIZE-2))
			if origin.distance_squared_to(goal)<.56 or (goal-origin).dot(direction)<-.01:continue
			var route: Array=[]
			if not definition.air:
				if not _unit_fits(unit,goal,false):continue
				unit._path_deferred=false
				route=_clearance_path(unit,origin,goal)
				if route.is_empty() and not unit._path_deferred:continue
			unit.fleeing=true
			unit.flee_started=time
			unit.flee_until=time+5.0
			unit.order="move"
			unit.goal=ACData.packed(goal)
			unit.path=route
			unit.path_rev=map.revision
			unit.repath=3.0
			unit.path_failed=false
			unit._path_goal=unit.goal.duplicate()
			unit.healing=false
			unit.heal_target=-1
			return
	# Completely blocked passive units stay put; repeated damage cannot flood
	# the pathfinder or extend an impossible movement indefinitely.
	unit._flee_ready_at=time+.75

func _area_damage(u: Dictionary, pos: Vector2, radius: float, damage: float, except_id: int = -1) -> void:
	for t in _query_entities(pos,radius):
		if int(t.id)!=except_id and t.hp>0 and t.get("container",-1)<0 and not allied(int(u.owner),int(t.owner)) and center(t).distance_squared_to(pos)<=radius*radius:
			_damage(u,t,damage,false)

func _mind_control(u: Dictionary, target_id: int) -> String:
	# Validate on the authoritative simulation, including fog and concealed units.
	if u.hp<=0 or u.get("container",-1)>=0 or ACData.unit(int(u.race),int(u.kind)).role!="parasite":return "정신 조종을 사용할 수 없습니다"
	if u.ability_cd>0:return "능력 재사용 대기 중입니다"
	if float(u.energy)<100:return "에너지가 부족합니다"
	var target=entity(target_id)
	if target.is_empty() or target.hp<=0 or target.has("progress") or target.get("technical",false):return "적 유닛을 지정하세요"
	if allied(int(u.owner),int(target.owner)):return "적 유닛을 지정하세요"
	if not can_see(int(u.owner),target):return "보이는 적 유닛을 지정하세요"
	if target.get("container",-1)>=0 or not target.get("cargo",[]).is_empty():return "탑승 중인 유닛과 승객이 있는 수송선은 조종할 수 없습니다"
	if center(u).distance_squared_to(center(target))>36:return "정신 조종 사거리 밖입니다"
	_release_mining_claim(target)
	var previous_owner=int(target.owner)
	# A captured builder leaves its former owner's construction available to resume.
	for b in buildings:
		if int(b.get("worker",-1))==int(target.id):b.worker=-1
	target.owner=int(u.owner)
	target.order="idle";target.target=-1;target.goal=target.pos.duplicate();target.path=[]
	target.erase("build_plan");target.build_queue=[];target.approach_target=-1
	target._auto_target=-1;target._scan_at=time;target.fleeing=false
	target.healing=false;target.heal_target=-1;target.heal_kind="";target.moving=false
	target.controlled_by=int(u.id);target.previous_owner=previous_owner
	u.energy-=100;u.ability_cd=20;u.fired=time
	_set_action(u,"attack",true)
	_effect("heal",u,center(target),.8,{"projectile":"mind_control","target":target.id})
	collision_index_valid=false;collision_recovery_revision=-1
	_recalculate_supply();_update_vision()
	return ""

func _ability(u: Dictionary, pos: Vector2) -> void:
	if u.ability_cd>0:
		return
	var d=ACData.unit(int(u.race),int(u.kind))
	if int(u.race)==0 and int(u.kind)==7:
		if u.get("cloak_active",false):u.cloak_active=false
		elif u.energy>=25:u.energy-=25;u.cloak_active=true
		u.ability_cd=.5
	elif d.role in ["siege","fortress","tree","shield"]:
		u.anchored=not u.anchored
		u.ability_cd=1.0
	elif d.role=="transport":
		for id in u.cargo:
			var rider=entity(int(id))
			if not rider.is_empty():
				rider.container=-1
				collision_index_valid=false
				rider.pos=ACData.packed(unit_free_position(int(rider.race),int(rider.kind),ACData.point(u.pos)+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2)),int(rider.id)))
				collision_index_valid=false
		u.cargo=[]
		u.ability_cd=1
	elif d.role=="mage" and u.energy>=75 and ACData.point(u.pos).distance_to(pos)<10:
		u.energy-=75
		u.ability_cd=12
		u.fired=time
		_set_action(u,"attack",true)
		_effect("warning",u,pos,1.1,{"caster":u.id,"projectile":"spell"})
		# Resolve the telegraphed spell in the next scheduled-effect pass.
		events.append({"spell":true,"when":time+1,"owner":u.owner,"pos":ACData.packed(pos),"caster":u.id})
	elif d.role=="priest" and u.energy>=60:
		u.energy-=60
		u.ability_cd=12
		u.fired=time
		_set_action(u,"attack",true)
		_effect("heal",u,ACData.point(u.pos),.6,{"projectile":"shield"})
		for other in units:
			if int(other.race)==2 and allied(int(other.owner),int(u.owner)) and ACData.point(other.pos).distance_to(ACData.point(u.pos))<4:
				other.shield=minf(ACData.unit(2,int(other.kind)).shield,other.shield+45)

func resolve_spells() -> void:
	for e in events:
		if e.get("spell",false) and not e.get("resolved",false) and time>=e.when:
			e.resolved=true
			var caster={"owner":e.owner,"race":2,"pos":e.pos}
			_area_damage(caster,ACData.point(e.pos),2.5,75)
			_effect("explosion",caster,ACData.point(e.pos),.5,{"projectile":"spell","caster":e.caster})

func _support(u: Dictionary, d: Dictionary, dt: float) -> void:
	if d.role=="healer_detector":
		for c in corpses:
			if c.value>0 and ACData.point(c.pos).distance_to(ACData.point(u.pos))<3:
				u.heal_stock+=c.value
				c.value=0
	var candidates=_query_entities(ACData.point(u.pos),4)
	candidates.sort_custom(func(a,b):
		var previous=int(u.get("_heal_previous_target",-1))
		if int(a.id)==previous:return int(b.id)!=previous
		if int(b.id)==previous:return false
		return center(a).distance_squared_to(center(u))<center(b).distance_squared_to(center(u)))
	for t in candidates:
		if t.has("progress") or t.id==u.id or not allied(int(t.owner),int(u.owner)) or t.hp<=0 or t.container>=0 or ACData.point(t.pos).distance_squared_to(ACData.point(u.pos))>16:
			continue
		var td=ACData.unit(int(t.race),int(t.kind))
		if t.hp>=td.hp:
			continue
		# A live healer leases this patient briefly. The lease is renewed only
		# by actual healing; death, range loss and empty reserves release it.
		var holder_id=int(t.get("_heal_owner",-1))
		if holder_id!=int(u.id) and time<float(t.get("_heal_until",-1)):
			var holder=entity(holder_id)
			if not holder.is_empty() and holder.hp>0 and holder.container<0 and not holder.get("fleeing",false) and center(holder).distance_squared_to(center(t))<=16 and (float(holder.energy)>0 or (int(holder.race)==1 and float(holder.heal_stock)>0)):continue
		if float(t.get("_healed_tick",-1))==time and holder_id!=int(u.id):continue
		if d.role=="medic" and int(t.race)==0 and int(t.kind) in [0,1,2,3,4,7] and u.energy>0:
			var amount=minf(td.hp-t.hp,minf(6*dt,float(u.energy)*4.0))
			t.hp+=amount
			u.energy=maxf(0,float(u.energy)-amount*.25)
			_healing_activity(u,t,"medic",amount)
			break
		if d.role=="healer_detector" and int(t.race)==1 and u.heal_stock>0:
			var amount=minf(8*dt,minf(u.heal_stock,td.hp-t.hp))
			t.hp+=amount
			u.heal_stock-=amount
			_healing_activity(u,t,"sap",amount)
			break

func _healing_activity(healer: Dictionary, target: Dictionary, kind: String, amount: float) -> void:
	if amount<=0:return
	target._heal_owner=int(healer.id)
	target._heal_until=time+.15
	target._healed_tick=time
	var changed=not healer.get("_healing_was",false) or int(healer.get("_heal_previous_target",-1))!=int(target.id)
	if changed:healer.heal_started=time;healer._heal_amount=0.0
	healer.healing=true
	healer.heal_target=int(target.id)
	healer.heal_kind=kind
	healer.action_intent="heal"
	var direction=(ACData.point(target.pos)-ACData.point(healer.pos)).normalized()
	if direction.length_squared()>.01:healer.facing=ACData.packed(direction)
	healer._heal_amount=float(healer.get("_heal_amount",0))+amount
	if changed or time-float(healer.heal_pulse)>=.65:
		healer.heal_pulse=time
		_effect("heal",healer,ACData.point(target.pos),.45,{"target":int(target.id),"heal_kind":kind,"projectile":"heal_medical" if kind=="medic" else "heal_sap","amount":healer._heal_amount})
		healer._heal_amount=0.0

func _recalculate_supply() -> void:
	for p in players:
		p.used=0.0
		p.cap=0.0
	for b in buildings:
		if b.hp>0 and b.progress>=1:
			players[b.owner].cap+=ACData.building(int(b.race),int(b.kind)).supply
	for u in units:
		if u.hp>0:
			players[u.owner].used+=(u._definition.pop if u.has("_definition") else ACData.unit(int(u.race),int(u.kind)).pop)
	for p in players:
		p.cap=minf(200,p.cap)

func _update_vision() -> void:
	var sources: Array=[]
	for owner in range(players.size()):sources.append({})
	for list in [units,buildings]:
		for e in list:
			if e.hp<=0 or e.get("container",-1)>=0:
				continue
			var radius=9
			if e.has("progress") and int(e.kind)==0:radius=13
			if not e.has("progress") and ACData.unit(int(e.race),int(e.kind)).role in ["detector","healer_detector"]:
				radius=12
			var p=Vector2i(center(e))
			if not vision_spans.has(radius):
				var spans: Array=[]
				for dy in range(-radius,radius+1):spans.append(Vector2i(dy,int(floor(sqrt(float(radius*radius-dy*dy))))))
				vision_spans[radius]=spans
			for owner in range(players.size()):
				if not allied(owner,int(e.owner)):
					continue
				sources[owner][Vector3i(p.x,p.y,radius)]=true
	for owner in range(players.size()):
		var fog=PackedByteArray()
		fog.resize(ACMap.SIZE*ACMap.SIZE)
		fog.fill(0)
		var seen: PackedByteArray=explored[owner].duplicate()
		for source in sources[owner]:
			perf.vision_sources+=1
			for span in vision_spans[source.z]:
				var y=source.y+span.x
				if y<0 or y>=ACMap.SIZE:continue
				var start=y*ACMap.SIZE+maxi(0,source.x-span.y)
				var finish=y*ACMap.SIZE+mini(ACMap.SIZE-1,source.x+span.y)
				for index in range(start,finish+1):fog[index]=1;seen[index]=1
		visibility[owner]=fog
		explored[owner]=seen

func is_cloaked(e: Dictionary) -> bool:
	if e.has("progress") or e.hp<=0:return false
	if int(e.race)==0 and int(e.kind)==7:return bool(e.get("cloak_active",false)) and float(e.energy)>0
	if int(e.race)==1 and int(e.kind)==8:return time-float(e.fired)>=2.0
	return int(e.race)==2 and int(e.kind)==10

func can_see(owner: int, e: Dictionary) -> bool:
	if allied(owner,int(e.owner)):
		return true
	var p=Vector2i(center(e))
	if not map.inside(p) or visibility[owner][p.y*ACMap.SIZE+p.x]==0:
		return false
	if not e.has("progress"):
		if is_cloaked(e):
			for detector in _query_entities(center(e),9):
				if not allied(owner,int(detector.owner)) or detector.hp<=0 or detector.get("container",-1)>=0:continue
				var detects=false
				if detector.has("progress"):
					detects=detector.progress>=1 and ((int(detector.race)==1 and int(detector.kind)==11) or (int(detector.race)!=1 and int(detector.kind)==12))
				else:detects=ACData.unit(int(detector.race),int(detector.kind)).role in ["detector","healer_detector"]
				if detects and center(detector).distance_squared_to(center(e))<81:return true
			return false
	return true

func _check_end() -> void:
	for i in range(players.size()):
		if players[i].lost:
			continue
		var alive=false
		for b in buildings:
			if int(b.owner)==i and b.hp>0:
				alive=true
		if not alive:
			players[i].lost=true
	var teams: Array=[]
	for i in range(players.size()):
		if not players[i].lost:
			var team=players[i].team if mode=="teams" else i
			if team not in teams:
				teams.append(team)
	if teams.size()<=1:
		ended=true
		winners=[]
		if teams.size()==1:
			for i in range(players.size()):
				if (players[i].team if mode=="teams" else i)==teams[0]:
					winners.append(i)

func _ai(owner: int) -> void:
	preload("res://scripts/bot_ai.gd").tick(self,owner)

func _ai_build(owner: int,kind: int) -> void:
	preload("res://scripts/bot_ai.gd").build(self,owner,kind)

func resource_visible(owner: int, node: Dictionary) -> bool:
	if owner<0:return true
	if owner>=visibility.size():return false
	var rect=resource_rect(node)
	for y in range(ceili(rect.position.y),ceili(rect.end.y)):
		for x in range(ceili(rect.position.x),ceili(rect.end.x)):
			if map.inside(Vector2i(x,y)) and visibility[owner][y*ACMap.SIZE+x]>0:return true
	return false

func _remembered_buildings(owner: int, visible: Array) -> Array:
	if owner<0:return []
	var memory: Dictionary=building_memory[owner];var observed={}
	for building in visible:
		observed[int(building.id)]=true
		if allied(owner,int(building.owner)):
			memory.erase(int(building.id));continue
		memory[int(building.id)]={"id":building.id,"owner":building.owner,"race":building.race,"kind":building.kind,"pos":building.pos.duplicate(),"progress":building.progress,"last_seen":time,"remembered":true}
	var ghosts=[]
	for id in memory.keys():
		if observed.has(id):continue
		var remembered: Dictionary=memory[id];var point=Vector2i(center(remembered))
		# Check only the viewer's present sight. Never query the hidden live
		# entity to refresh ownership, construction, destruction or statistics.
		if map.inside(point) and visibility[owner][point.y*128+point.x]>0:memory.erase(id)
		else:ghosts.append(remembered.duplicate(true))
	return ghosts

func snapshot(owner: int = -1) -> Dictionary:
	CITRUS_BROOD.refresh(self)
	var us: Array=[]
	var bs: Array=[]
	var shimmers: Array=[]
	for u in units:
		if owner<0 or can_see(owner,u):
			# Navigation arrays can be hundreds of waypoints per unit. Omit
			# them before copying rather than deep-copying then discarding them.
			var copy=u.duplicate(false)
			copy.cloaked=is_cloaked(u)
			copy.erase("path")
			for internal in ["action_intent","activity_clock","approach_target","approach_revision","approach_goal","blocked_clock","nav_blocked","avoid_until","yield_visual_until","path_rev","repath","path_failed"]:copy.erase(internal)
			for key in copy.keys():
				if str(key).begins_with("_"):copy.erase(key)
			for key in ["pos","goal","facing","body_direction","turret_direction","cargo","collision_size"]:
				if copy.get(key) is Array:copy[key]=copy[key].duplicate(false)
			copy.build_queue=u.build_queue.duplicate(true) if owner<0 or allied(owner,int(u.owner)) else []
			us.append(copy)
		elif u.hp>0 and int(u.container)<0 and is_cloaked(u):
			var point=Vector2i(center(u))
			if map.inside(point) and visibility[owner][point.y*ACMap.SIZE+point.x]>0:
				# Cosmetic-only contacts have no entity ID, health or command target.
				shimmers.append({"race":u.race,"kind":u.kind,"pos":u.pos.duplicate(),"facing":u.facing.duplicate()})
	for b in buildings:
		if b.hp<=0:continue
		if owner<0 or can_see(owner,b):
			var copy=b.duplicate(true)
			if owner>=0 and not allied(owner,int(b.owner)):
				copy.queue=[]
				copy.research=""
			bs.append(copy)
	var ps=players.duplicate(true)
	if owner>=0:
		for i in range(ps.size()):
			if not allied(owner,i):
				for key in ["as","tera","used","cap","reserved","ai_goal","spent","gathered","attack","armor","shield","home","spawn_slot"]:
					ps[i].erase(key)
	var fog=PackedByteArray()
	var seen=PackedByteArray()
	if owner>=0:
		fog=visibility[owner].duplicate()
		seen=explored[owner].duplicate()
	var rs: Array=[]
	for r in map.resources:
		var copy=r.duplicate(true)
		copy.erase("busy")
		for key in copy.keys():
			if str(key).begins_with("_"):copy.erase(key)
		copy.initial_amount=int(r.get("initial_amount",r.amount))
		copy.collision_size=ACData.packed(resource_size(str(r.type)))
		copy.visible=owner<0 or resource_visible(owner,r)
		copy.amount_known=owner<0
		if owner>=0:
			if copy.visible:resource_memory[owner][r.id]=r.amount
			copy.amount_known=resource_memory[owner].has(r.id)
			copy.amount=resource_memory[owner].get(r.id,copy.initial_amount)
		copy.depleted=int(copy.amount)<=0
		rs.append(copy)
	var fx: Array=[]
	for effect in effects:
		var visible=true
		if owner>=0:
			for key in ["from","to"]:
				var p=Vector2i(ACData.point(effect[key]))
				if not map.inside(p) or visibility[owner][p.y*ACMap.SIZE+p.x]==0:visible=false
		if visible:fx.append(effect.duplicate(true))
	return {"time":time,"mode":mode,"players":ps,"units":us,"buildings":bs,"building_memory":_remembered_buildings(owner,bs),"resources":rs,"roots":roots.snapshot(self,owner),"effects":fx,"shimmers":shimmers,"ended":ended,"winners":winners,"fog":fog,"explored":seen,"theme":map.theme,"map_layout":map.source_info.get("origin","reference_inspired_original")}
