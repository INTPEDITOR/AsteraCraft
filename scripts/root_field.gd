class_name ACRootField
extends RefCounted

# 16px ground cells. Coverage belongs to the simulation, not visible buildings.
const WIDTH=256
const RADIUS=13.0
const SEED_RADIUS=3.0
const SPEED=.9
const FADE_TIME=.55
const DIRECTIONS=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]
var sources={}
var coverage={}
var memories={}
var current={}
var source_signature=0
var geometry_signature=0
var last_tick=-1
var revision=0
var allowed=PackedByteArray()

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(((point+Vector2.ONE*.5)*2).floor())

static func point_at(cell: Vector2i) -> Vector2:
	return Vector2(cell)*.5-Vector2.ONE*.25

static func ground_index(index: int) -> int:
	return (index/WIDTH/2)*128+(index%WIDTH/2)

static func terrain_allows(map: ACMap, cell: Vector2i) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=WIDTH or cell.y>=WIDTH:return false
	var tile=cell/2;var index=tile.y*128+tile.x
	if map.is_water(index):return false
	if map.source_detail_active and map.source_walk_masks.size()==128*128:
		var bit=(cell.y%2)*8+(cell.x%2)*2
		var mask=0x33<<bit
		return (map.source_walk_masks[index]&mask)==mask
	return map.terrain[index]==0

func _can_cross(map: ACMap, from: Vector2i, to: Vector2i) -> bool:
	if to.x<0 or to.y<0 or to.x>=WIDTH or to.y>=WIDTH or not allowed[to.y*WIDTH+to.x]:return false
	var a=from/2;var b=to/2
	if map.height_map[a.y*128+a.x]==map.height_map[b.y*128+b.x]:return true
	# Cross levels only on a real walkable ramp, never jump a cliff seam.
	var midpoint=(point_at(from)+point_at(to))*.5
	for ramp in map.visual_ramps:
		var delta=midpoint-ramp.center;var axis: Vector2=ramp.direction
		if absf(delta.dot(axis))<=ramp.length*.5+.25 and absf(delta.dot(Vector2(axis.y,-axis.x)))<=ramp.width*.5:return true
	return false

func _distances(map: ACMap, building: Dictionary, origin: Vector2) -> Dictionary:
	var result={};var buckets=[]
	for i in range(261):buckets.append([])
	var definition=ACData.building(1,int(building.kind))
	var first=cell_at(ACData.point(building.pos)-Vector2.ONE*.49)
	for y in range(first.y,first.y+int(definition.h)*2):
		for x in range(first.x,first.x+int(definition.w)*2):
			var cell=Vector2i(x,y)
			if not terrain_allows(map,cell):continue
			var cost=roundi(point_at(cell).distance_to(origin)*20)
			var index=y*WIDTH+x;result[index]=cost;buckets[cost].append(cell)
	for cost in range(261):
		for cell in buckets[cost]:
			if result[cell.y*WIDTH+cell.x]!=cost:continue
			for offset in DIRECTIONS:
				var next=cell+offset;var diagonal=offset.x!=0 and offset.y!=0
				var distance=cost+(14 if diagonal else 10)
				if distance>260 or point_at(next).distance_squared_to(origin)>RADIUS*RADIUS or not _can_cross(map,cell,next):continue
				if diagonal and (not _can_cross(map,cell,cell+Vector2i(offset.x,0)) or not _can_cross(map,cell,cell+Vector2i(0,offset.y))):continue
				var index=next.y*WIDTH+next.x
				if distance>=int(result.get(index,99999)):continue
				result[index]=distance;buckets[distance].append(next)
	return result

func update(core) -> void:
	var active=[];var signature_data=[]
	for building in core.buildings:
		if int(building.race)!=1 or int(building.kind) not in [0,12] or building.hp<=0 or building.progress<1:continue
		if core.players[int(building.owner)].lost:continue
		active.append(building);signature_data.append([building.id,building.owner,building.pos])
	var signature=hash(signature_data);var tick=floori(core.time*4)
	if tick==last_tick and signature==source_signature:return
	var geometry=hash([core.map.terrain,core.map.height_map,core.map.source_detail_active])
	if geometry==geometry_signature and signature==source_signature and last_tick>=0:
		var mature=true
		for source in sources.values():
			if float(last_tick)/4.0<float(source.started)+(RADIUS-SEED_RADIUS)/SPEED+.25+FADE_TIME:mature=false;break
		if mature:last_tick=tick;return
	if geometry!=geometry_signature:
		geometry_signature=geometry;sources.clear();allowed.resize(WIDTH*WIDTH)
		for y in range(WIDTH):
			for x in range(WIDTH):allowed[y*WIDTH+x]=int(terrain_allows(core.map,Vector2i(x,y)))
	source_signature=signature;last_tick=tick
	var kept={}
	for building in active:
		var key=hash([building.id,building.owner,building.pos])
		if not sources.has(key):
			sources[key]={"owner":int(building.owner),"started":core.time,"distances":_distances(core.map,building,core.center(building))}
		kept[key]=sources[key]
	sources=kept;coverage.clear();current.clear()
	for source in sources.values():
		var owner=int(source.owner)
		if not coverage.has(owner):coverage[owner]={}
		for index in source.distances:
			var distance=float(source.distances[index])/20.0
			var jitter=float(posmod(index*173+owner*31,17))*.012
			var born=float(source.started)+maxf(0,(distance-SEED_RADIUS)/SPEED)+(jitter if distance>SEED_RADIUS else -.55)
			if born>core.time:continue
			coverage[owner][index]=minf(float(coverage[owner].get(index,INF)),born)
	for owner in coverage:
		for index in coverage[owner]:
			var maturity=clampi(roundi((core.time-coverage[owner][index])/FADE_TIME*255),1,255)
			var packed=int(index)|(int(owner)<<16)|(maturity<<18)
			if not current.has(index) or maturity>int(current[index])>>18:current[index]=packed
	revision+=1

func contains(core, owner: int, point: Vector2) -> bool:
	update(core)
	var cell=cell_at(point)
	return cell.x>=0 and cell.y>=0 and cell.x<WIDTH and cell.y<WIDTH and coverage.get(owner,{}).has(cell.y*WIDTH+cell.x)

func snapshot(core, viewer: int) -> PackedInt32Array:
	update(core)
	if viewer<0:return PackedInt32Array(current.values())
	if not memories.has(viewer):memories[viewer]={}
	var memory: Dictionary=memories[viewer]
	# Remember only roots actually observed at this location, independently
	# of source/entity visibility. Exploring bare ground does not reveal later
	# growth. The building footprint participates exactly like any other tile.
	for index in memory.keys():
		if core.visibility[viewer][ground_index(index)] and not current.has(index):memory.erase(index)
	for index in current:
		if core.visibility[viewer][ground_index(index)]:memory[index]=current[index]
	return PackedInt32Array(memory.values())
