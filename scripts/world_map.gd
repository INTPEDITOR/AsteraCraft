class_name ACMap
extends RefCounted

const SIZE := 128
const ELEVATION_PIXELS := 24.0
const HQ_MINERAL_GAP := 3.0
var terrain := PackedByteArray()
var height_map := PackedByteArray()
var surface_map := PackedByteArray()
var detail_map := PackedByteArray()
var buildable_map := PackedByteArray()
var resources: Array = []
var starts: Array = []
var theme := 0
var navigator := AStarGrid2D.new()
var revision := 0
var render_regions: Array = []
var ramps: Array = []
var bridges: Array = []
var bases: Array = []
var decorations: Array = []
var source_info: Dictionary = {}
var resource_obstacles: Array = []
var _last_buildings: Array = []
var _definition: Dictionary = {}
var visual_ramps: Array = []
var visual_roles := PackedByteArray()
var _visual_elevations := PackedFloat32Array()
var _visual_vertices: Dictionary = {}
var source_walk_masks := PackedInt32Array()
var source_ramp_regions: Array = []
var source_detail_active := false
var _detail_prefix := PackedInt32Array()

func rotate(p: Vector2i, turns: int) -> Vector2i:
	var q = p
	for _i in range(posmod(turns,4)):q=Vector2i(SIZE-1-q.y,q.x)
	return q

## Slot order NW, NE, SE, SW. Reflection preserves horizontal resource sizes.
func reflect(p: Vector2, slot: int) -> Vector2:
	return Vector2(SIZE-1-p.x if slot in [1,2] else p.x,SIZE-1-p.y if slot in [2,3] else p.y)

func make(map_id: int, layout: String="source_chk_cv5_vf4") -> void:
	theme=clampi(map_id,0,2)
	for array in [resources,starts,render_regions,ramps,bridges,bases,decorations,resource_obstacles]:array.clear()
	_last_buildings=[]
	visual_roles.clear()
	source_walk_masks.clear()
	source_ramp_regions.clear()
	source_detail_active=false
	if layout=="source_chk_cv5_vf4" and FileAccess.file_exists("res://data/original_maps.json"):
		_make_original(theme)
		return
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	assert(catalog is Dictionary and catalog.maps.size()==3,"Missing original map definitions")
	_definition=catalog.maps[theme]
	source_info={"name":_definition.name,"layout":_definition.layout,"reference":_definition.get("reference",""),"origin":"reference_inspired_original","symmetry":"mirror_xy","players":4,"catalog":"res://data/maps.json","exact_source":false}
	terrain.resize(SIZE*SIZE)
	height_map.resize(SIZE*SIZE)
	surface_map.resize(SIZE*SIZE)
	detail_map.resize(SIZE*SIZE)
	buildable_map.resize(SIZE*SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var point=Vector2(mini(x,SIZE-1-x),mini(y,SIZE-1-y))
			var value=_cell(point)
			var i=y*SIZE+x
			terrain[i]=value[0]
			height_map[i]=value[1]
			surface_map[i]=value[2]
			detail_map[i]=(int(point.x)*193+int(point.y)*37)%16
			buildable_map[i]=int(terrain[i]==0 and surface_map[i] not in [3,4])
			# A flat road may approach an expansion, but its town-hall pocket
			# must remain constructible. Bridges and the main ramp stay reserved.
			if terrain[i]==0 and surface_map[i]!=4:
				for base in _definition.bases:
					var delta=(point-ACData.point(base.center)).abs()
					if delta.x<=4 and delta.y<=3:buildable_map[i]=1
					if int(base.get("tera_count",1))>0:
						var vent=ACData.point(base.center)+ACData.point(base.get("tera_offset",catalog.tera_offset))
						if (point-vent).abs().x<=2 and (point-vent).abs().y<=1:buildable_map[i]=1
	for slot in range(4):
		starts.append(ACData.packed(reflect(ACData.point(_definition.start),slot)))
		var gate=reflect(ACData.point(_definition.gate.center),slot)
		ramps.append({"kind":"main","slot":slot,"center":ACData.packed(gate),"width":int(_definition.gate.width)})
		for base in _definition.bases:_add_base(base,slot,catalog)
		if theme==2 and not _definition.has("lanes"):
			for pair in [[42,42,53,53],[42,18,63.5,18],[18,55,18,63.5]]:
				bridges.append({"slot":slot,"from":ACData.packed(reflect(Vector2(pair[0],pair[1]),slot)),"to":ACData.packed(reflect(Vector2(pair[2],pair[3]),slot)),"width":8 if pair[0]==42 and pair[1]==42 else 7})
	for y in range(5,63,6):
		for x in range(5,63,6):
			if terrain[y*SIZE+x]!=1 or (x*7+y*11)%5!=0:continue
			for slot in range(4):
				var point=reflect(Vector2(x,y),slot)
				decorations.append({"pos":ACData.packed(point),"kind":(x+y+theme)%4,"variant":detail_map[y*SIZE+x],"scale":.72+float((x+y)%3)*.12})
	_build_visual_relief()
	_configure_navigation()

func _make_original(map_id: int) -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	assert(catalog is Dictionary and catalog.maps.size()==3,"Missing imported source maps")
	_definition=catalog.maps[map_id]
	source_info={"name":_definition.name,"origin":"source_chk_cv5_vf4","source":_definition.source,"source_sha256":_definition.source_sha256,"grid_policy":catalog.grid_policy,"players":4,"symmetry":"source","exact_source":true,"collision_resolution":32}
	terrain=PackedByteArray(_definition.terrain)
	height_map=PackedByteArray(_definition.height_map)
	surface_map=PackedByteArray(_definition.surface_map)
	buildable_map=PackedByteArray(_definition.buildable_map)
	detail_map.resize(SIZE*SIZE)
	for i in range(detail_map.size()):detail_map[i]=int(_definition.source_tiles[i])%16
	starts=_definition.starts.duplicate(true)
	resources=_definition.resources.duplicate(true)
	bases=_definition.bases.duplicate(true)
	if FileAccess.file_exists("res://data/terrain_visual_roles.json"):
		var visuals=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain_visual_roles.json"))
		if visuals.get("source_sha256","")==FileAccess.get_sha256("res://data/original_maps.json"):
			visual_roles=PackedByteArray(visuals.maps[map_id].roles)
	if FileAccess.file_exists("res://data/source_terrain_detail.json"):
		var detail=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_terrain_detail.json"))
		assert(detail.source_sha256==FileAccess.get_sha256("res://data/original_maps.json"),"Source geometry metadata mismatch")
		source_walk_masks=PackedInt32Array(detail.maps[map_id].walk_masks)
		for raw in detail.maps[map_id].ramps:
			var region=raw.duplicate(true)
			region.center=ACData.point(raw.center)
			region.direction=ACData.point(raw.direction)
			source_ramp_regions.append(region)
		source_info.collision_resolution=8
		source_info.exact_source=false
		source_info.geometry_policy="Original VF4 8px walk mask; AsteraCraft body clearance and original artwork"
	_build_visual_relief()
	for ramp in visual_ramps:ramps.append({"kind":"source","center":ACData.packed(ramp.center),"width":ramp.width})
	_configure_navigation()

func _build_visual_relief() -> void:
	visual_ramps.clear()
	_visual_vertices.clear()
	var authored=source_ramp_regions if not source_ramp_regions.is_empty() and terrain==PackedByteArray(_definition.terrain) and height_map==PackedByteArray(_definition.height_map) else []
	_visual_elevations.resize(SIZE*SIZE)
	var edges: Dictionary={}
	for y in range(SIZE):
		for x in range(SIZE):
			var index=y*SIZE+x
			_visual_elevations[index]=-18.0 if is_water(index) else float(height_map[index])*ELEVATION_PIXELS+(6.0 if visual_role(index)==1 else 0.0)
			if terrain[index]!=0:continue
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var other=Vector2i(x,y)+offset
				if inside(other) and terrain[other.y*SIZE+other.x]==0 and height_map[index]!=height_map[other.y*SIZE+other.x]:edges[index]=true
	var remaining=edges.duplicate() if authored.is_empty() else {}
	visual_ramps.assign(authored)
	while not remaining.is_empty():
		var queue: Array=[remaining.keys()[0]]
		remaining.erase(queue[0])
		var points: Array=[]
		var gradient=Vector2.ZERO
		var center=Vector2.ZERO
		var cursor=0
		while cursor<queue.size():
			var index=int(queue[cursor])
			cursor+=1
			var point=Vector2i(index%SIZE,index/SIZE)
			points.append(Vector2(point))
			center+=Vector2(point)
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var other=point+offset
				if inside(other) and terrain[other.y*SIZE+other.x]==0:
					gradient+=Vector2(offset)*float(int(height_map[other.y*SIZE+other.x])-int(height_map[index]))
			for dy in range(-1,2):
				for dx in range(-1,2):
					var other=point+Vector2i(dx,dy)
					var next=other.y*SIZE+other.x
					if inside(other) and remaining.has(next):remaining.erase(next);queue.append(next)
		center/=maxi(1,points.size())
		var direction=-gradient.normalized() if gradient.length_squared()>.01 else Vector2.DOWN
		var tangent=Vector2(direction.y,-direction.x)
		var width=0.0
		var length=0.0
		for point in points:
			width=maxf(width,absf((point-center).dot(tangent))*2)
			length=maxf(length,absf((point-center).dot(direction))*2)
		if not points.is_empty():
			visual_ramps.append({"center":center,"direction":direction,"width":maxf(4,width+2),"length":maxf(5,length+3)})
	# Only walkable height interfaces become broad slopes; impassable cliff
	# edges keep their authored steep silhouette and collision unchanged.
	var affected: Dictionary={}
	for raw in edges:
		var point=Vector2i(int(raw)%SIZE,int(raw)/SIZE)
		for dy in range(-2,3):
			for dx in range(-2,3):
				var other=point+Vector2i(dx,dy)
				if inside(other) and terrain[other.y*SIZE+other.x]==0:affected[other.y*SIZE+other.x]=true
	for raw in affected:
		var point=Vector2i(int(raw)%SIZE,int(raw)/SIZE)
		var total=0.0
		var weights=0.0
		for dy in range(-2,3):
			for dx in range(-2,3):
				var other=point+Vector2i(dx,dy)
				if not inside(other) or terrain[other.y*SIZE+other.x]!=0:continue
				var weight=float((3-absi(dx))*(3-absi(dy)))
				total+=float(height_map[other.y*SIZE+other.x])*ELEVATION_PIXELS*weight
				weights+=weight
		_visual_elevations[int(raw)]=total/maxf(1,weights)
	# Explicit source ramps also include partly walkable edge tiles omitted by
	# the old coarse conversion. Blend only inside each authored slope footprint.
	for ramp in authored:
		var axis: Vector2=ramp.direction
		var across=Vector2(axis.y,-axis.x)
		var radius=ceili(maxf(ramp.width,ramp.length))
		for y in range(maxi(0,int(ramp.center.y)-radius),mini(SIZE,int(ramp.center.y)+radius+1)):
			for x in range(maxi(0,int(ramp.center.x)-radius),mini(SIZE,int(ramp.center.x)+radius+1)):
				var i=y*SIZE+x
				if source_walk_masks[i]==0:continue
				var delta=Vector2(x+.5,y+.5)-ramp.center
				var side=absf(delta.dot(across))/(ramp.width*.5)
				var along=.5+delta.dot(axis)/ramp.length
				if side>=1 or along<0 or along>1:continue
				var blend=1.0-smoothstep(.72,1.0,side)
				_visual_elevations[i]=lerpf(_visual_elevations[i],lerpf(ramp.high,ramp.low,smoothstep(0.0,1.0,along))*ELEVATION_PIXELS,blend)

func visual_role(index: int) -> int:
	if terrain[index]==2:return 2
	if terrain[index]==0:return 0
	return int(visual_roles[index]) if visual_roles.size()==SIZE*SIZE else 1

func _cell(p: Vector2) -> Array:
	if _definition.has("lanes"):return _reference_cell(p)
	var result=[0,0,0]
	var radius=p.distance_to(Vector2(63.5,63.5))
	match theme:
		0:
			if _ellipse(p,Vector2(10,41),Vector2(5,8))<1.0:result=[2,0,7]
			if _ellipse(p,Vector2(47,19),Vector2(12,5))<1.0 or _ellipse(p,Vector2(29,52),Vector2(5,7))<1.0:result=[1,1,6]
			if radius<23:result=[0,0,5]
		1:
			var shore=23.0+sin(p.x*.29+p.y*.19)*.6
			if radius<shore:result=[2,0,7]
			elif radius>44 and radius<49:result=[1,1,6]
			elif radius<44:result=[0,0,2]
			if _ellipse(p,Vector2(63.5,14),Vector2(10,6))<1.0:result=[1,1,6]
		2:
			result=[2,0,7]
			if _rounded(p,Vector2(25,25),Vector2(23,23))<1.0:result=[0,1,1]
			if radius<24:result=[0,2,5]
			if _ellipse(p,Vector2(56,49),Vector2(3,5))<1.0 or _ellipse(p,Vector2(49,56),Vector2(5,3))<1.0:result=[1,2,6]
	# All equivalent bases use exactly the same resource room and main gate.
	for base in _definition.bases:
		var score=_rounded(p,ACData.point(base.center),ACData.point(base.radii))
		if score<=1.0:result=[0,int(base.height),1 if int(base.height)>0 else 2]
		elif base.kind=="main" and score<=1.28:result=[1,int(base.height),6]
	var natural=ACData.point(_definition.bases[1].center)
	if _segment_distance(p,Vector2(26,26),natural)<4.0:result=[0,1 if p.x+p.y<66 else int(_definition.bases[1].height),3]
	if theme==0 and _segment_distance(p,Vector2(43,42),Vector2(63.5,63.5))<4.5:result=[0,0,3 if radius>18 else 5]
	if theme==2:
		if _segment_distance(p,Vector2(42,42),Vector2(53,53))<4.0:result=[0,1,4]
		if _segment_distance(p,Vector2(42,18),Vector2(63.5,18))<3.5:result=[0,1,4]
		if _segment_distance(p,Vector2(18,55),Vector2(18,63.5))<3.5:result=[0,1,4]
	if p.x<2 or p.y<2:result=[1,1,6]
	return result

func _ellipse(p: Vector2, center: Vector2, radii: Vector2) -> float:
	var delta=(p-center)/radii
	return delta.length_squared()

func _reference_cell(p: Vector2) -> Array:
	var result=[0,0,0]
	var center=Vector2(63.5,63.5)
	match theme:
		0:
			if _ellipse(p,Vector2(12,40),Vector2(8,7))<1 or _ellipse(p,Vector2(47,16),Vector2(11,6))<1:result=[2,0,7]
			if _ellipse(p,Vector2(50,48),Vector2(5,9))<1:result=[1,1,6]
			if p.distance_to(center)<25:result=[0,0,5]
		1:
			if _ellipse(p,Vector2(20,9),Vector2(16,5))<1 or _ellipse(p,Vector2(35,47),Vector2(9,4))<1:result=[2,0,7]
			if _ellipse(p,Vector2(53,46),Vector2(5,11))<1:result=[1,1,6]
			if p.distance_to(center)<22:result=[0,0,5]
		2:
			result=[2,0,7]
			if p.x>32 and p.y>30:result=[0,0,0]
			var temple=_rounded(p,center,Vector2(24,24))
			if temple<1.12:result=[1,1,6]
			if temple<.88:result=[0,1,5]
	for base in _definition.bases:
		var score=_rounded(p,ACData.point(base.center),ACData.point(base.radii))
		if score<=1:result=[0,int(base.height),1 if int(base.height)>0 else 2]
		elif base.kind=="main" and score<=1.25:result=[1,int(base.height),6]
	var lane_index=0
	for lane in _definition.lanes:
		if _segment_distance(p,ACData.point(lane[0]),ACData.point(lane[1]))<float(lane[2])*.5:
			result=[0,int(lane[3]),3 if lane_index==0 else (5 if p.distance_to(center)<22 else 0)]
		lane_index+=1
	if p.x<2 or p.y<2:result=[1,1,6]
	return result

func _rounded(p: Vector2, center: Vector2, radii: Vector2) -> float:
	var delta=((p-center)/radii).abs()
	return pow(delta.x,4)+pow(delta.y,4)

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))

func _add_base(definition: Dictionary, slot: int, catalog: Dictionary) -> void:
	var center=ACData.point(definition.center)
	var ids: Array=[]
	for type in ["as","tera"]:
		var offsets: Array=definition.get("mineral_offsets",catalog.mineral_offsets) if type=="as" else ([definition.get("tera_offset",catalog.tera_offset)] if int(definition.get("tera_count",1))>0 else [])
		for raw in offsets:
			var point=reflect(center+ACData.point(raw),slot)
			var amount=int(catalog.resources[type].initial_amount)
			var id=100000+resources.size()
			resources.append({"id":id,"pos":ACData.packed(point),"type":type,"amount":amount,"initial_amount":amount,"busy":0.0,"base":bases.size(),"slot":slot,"collision_size":catalog.resources[type].footprint.duplicate()})
			ids.append(id)
	bases.append({"kind":definition.kind,"access":definition.get("access","ground"),"pos":ACData.packed(reflect(center+Vector2(0,.5),slot)),"grid_center":ACData.packed(reflect(center,slot)),"slot":slot,"turn":slot,"main":definition.kind=="main","resources":ids})

func start_building_anchor(slot: int, size: Vector2) -> Vector2:
	if source_info.get("origin","")=="source_chk_cv5_vf4":return _closest_start_anchor(slot,size)
	var canonical=(ACData.point(starts[0])-(size-Vector2.ONE)*.5).round()
	if slot in [1,2]:canonical.x=SIZE-1-canonical.x-(size.x-1)
	if slot in [2,3]:canonical.y=SIZE-1-canonical.y-(size.y-1)
	return canonical

static func footprint_gap(a: Rect2, b: Rect2) -> float:
	# Build-grid exclusion uses edge-to-edge distance, not sprite centers.
	return maxf(maxf(a.position.x-b.end.x,b.position.x-a.end.x),maxf(a.position.y-b.end.y,b.position.y-a.end.y))

func _closest_start_anchor(slot: int, size: Vector2) -> Vector2:
	var original=(ACData.point(starts[slot])-size*.5).floor()
	var home_ore=[]
	for node in resources:
		if node.type=="as" and int(node.slot)==slot:home_ore.append(node)
	if home_ore.is_empty():return original
	var result=Vector2.INF;var best=INF
	var home_height=height_map[int(starts[slot][1])*SIZE+int(starts[slot][0])]
	for y in range(maxi(1,int(original.y)-10),mini(SIZE-int(size.y),int(original.y)+11)):
		for x in range(maxi(1,int(original.x)-10),mini(SIZE-int(size.x),int(original.x)+11)):
			var valid=true
			for yy in range(y,y+int(size.y)):
				for xx in range(x,x+int(size.x)):
					if not buildable(Vector2i(xx,yy)) or height_map[yy*SIZE+xx]!=home_height:valid=false
			if not valid:continue
			var rect=Rect2(Vector2(x,y)-Vector2.ONE*.5,size)
			for node in resources:
				var body=Rect2(ACData.point(node.pos)-ACData.point(node.collision_size)*.5,ACData.point(node.collision_size))
				if rect.intersects(body.grow(HQ_MINERAL_GAP if node.type=="as" and node.amount>0 else 0.0)):valid=false;break
			if not valid:continue
			var nearest=INF;var average=0.0
			for node in home_ore:
				var body=Rect2(ACData.point(node.pos)-Vector2(1,.5),Vector2(2,1))
				nearest=minf(nearest,footprint_gap(rect,body))
				var closest=ACData.point(node.pos).clamp(rect.position,rect.end)
				average+=closest.distance_squared_to(ACData.point(node.pos))
			# First meet the closest legal perimeter, then face the whole mineral
			# line rather than hugging an outlying crystal. Source location breaks ties.
			var score=(nearest-HQ_MINERAL_GAP)*100000+average/home_ore.size()+Vector2(x,y).distance_squared_to(original)*.01
			if score<best:best=score;result=Vector2(x,y)
	assert(result.is_finite(),"No legal starting headquarters near source start")
	return result if result.is_finite() else original

func start_worker_positions(slot: int) -> Array:
	var result: Array=[]
	if source_info.get("origin","")=="source_chk_cv5_vf4":
		var home=ACData.point(starts[slot])
		var target=Vector2.ZERO;var count=0
		for node in resources:
			if int(node.slot)==slot and node.type=="as":target+=ACData.point(node.pos);count+=1
		var direction=(target/maxi(1,count)-home).normalized() if count>0 else Vector2.DOWN
		var side=direction.orthogonal()
		for offset in [-1.5,-.5,.5,1.5]:result.append(nearest_free(home+direction*4+side*offset))
		return result
	for offset in [Vector2(-2,5),Vector2(-1,5),Vector2(1,5),Vector2(2,5)]:
		result.append(reflect(ACData.point(_definition.bases[0].center)+offset,slot))
	return result

func _configure_navigation() -> void:
	navigator.region=Rect2i(0,0,SIZE,SIZE)
	navigator.cell_size=Vector2.ONE
	navigator.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigator.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	navigator.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	navigator.update()
	reset_solids([])

func buildable(p: Vector2i) -> bool:
	return inside(p) and buildable_map[p.y*SIZE+p.x]!=0

func inside(p: Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<SIZE and p.y<SIZE

func is_water(index: int) -> bool:
	if index<0 or index>=terrain.size():return false
	# Keep the original 8px shoreline/ramp margins. Only wholly impassable
	# obstacle interiors become pools, never their partly walkable edge tiles.
	return terrain[index]==2 or (visual_role(index)==3 and source_walk_masks.size()==SIZE*SIZE and source_walk_masks[index]==0)

## Shared visual plane for terrain, units, resources, picking and rally markers.
## Navigation and authored height levels remain unchanged.
func visual_cell_elevation(x: int, y: int) -> float:
	if x<0 or y<0 or x>=SIZE or y>=SIZE:return 0.0
	var index=y*SIZE+x
	if _visual_elevations.size()==SIZE*SIZE:return _visual_elevations[index]
	return -2.0 if is_water(index) else float(height_map[index])*ELEVATION_PIXELS+(6.0 if terrain[index]==1 else 0.0)

func visual_elevation(point: Vector2) -> float:
	if point.x<0 or point.y<0 or point.x>=SIZE or point.y>=SIZE:return 0.0
	# Match the exact 16px terrain triangles, rather than evaluating a curved
	# field between their vertices. Feet and input now share the visible plane.
	var grid=point*2.0
	var origin=Vector2i(floori(grid.x),floori(grid.y))
	var fraction=grid-Vector2(origin)
	var top_left=_visual_vertex(origin)
	var bottom_right=_visual_vertex(origin+Vector2i.ONE)
	if fraction.x>=fraction.y:
		return top_left*(1-fraction.x)+_visual_vertex(origin+Vector2i.RIGHT)*(fraction.x-fraction.y)+bottom_right*fraction.y
	return top_left*(1-fraction.y)+bottom_right*fraction.x+_visual_vertex(origin+Vector2i.DOWN)*(fraction.y-fraction.x)

func _visual_vertex(grid: Vector2i) -> float:
	var index=grid.y*257+grid.x
	if not _visual_vertices.has(index):
		var point=Vector2(grid)*.5
		var height=_sample_visual_elevation(point)
		_visual_vertices[index]=point.y*32.0-clampf(point.y*32.0-height,0,4096)
	return float(_visual_vertices[index])

## Clockwise outer edge of the actual terrain mesh. Unlike gameplay queries,
## this includes x/y=SIZE vertices and their raised visual boundary height.
## Components are logical tile x, tile y, and world-pixel elevation.
func visual_boundary() -> PackedVector3Array:
	var result=PackedVector3Array()
	for x in range(257):result.append(Vector3(x*.5,0,_visual_vertex(Vector2i(x,0))))
	for y in range(1,257):result.append(Vector3(SIZE,y*.5,_visual_vertex(Vector2i(256,y))))
	for x in range(255,-1,-1):result.append(Vector3(x*.5,SIZE,_visual_vertex(Vector2i(x,256))))
	for y in range(255,0,-1):result.append(Vector3(0,y*.5,_visual_vertex(Vector2i(0,y))))
	return result

func _sample_visual_elevation(point: Vector2) -> float:
	var warp=Vector2(sin(point.y*1.31+point.x*.17),sin(point.x*1.13-point.y*.23))*.18
	var sample=point+warp-Vector2(.5,.5)
	var origin=Vector2i(floori(sample.x),floori(sample.y))
	var fraction=sample-Vector2(origin)
	fraction.x=smoothstep(0.0,1.0,fraction.x)
	fraction.y=smoothstep(0.0,1.0,fraction.y)
	var value=0.0
	for dy in range(2):
		for dx in range(2):
			var weight=(fraction.x if dx==1 else 1.0-fraction.x)*(fraction.y if dy==1 else 1.0-fraction.y)
			value+=weight*visual_cell_elevation(clampi(origin.x+dx,0,SIZE-1),clampi(origin.y+dy,0,SIZE-1))
	return value

func reset_solids(buildings: Array) -> void:
	_last_buildings=buildings
	for y in range(SIZE):
		for x in range(SIZE):navigator.set_point_solid(Vector2i(x,y),terrain[y*SIZE+x]!=0)
	for obstacle in resource_obstacles:
		var rect: Rect2=obstacle
		for y in range(maxi(0,ceili(rect.position.y)),mini(SIZE,ceili(rect.end.y))):
			for x in range(maxi(0,ceili(rect.position.x)),mini(SIZE,ceili(rect.end.x))):navigator.set_point_solid(Vector2i(x,y),true)
	for building in buildings:
		if building.hp<=0:continue
		var definition=ACData.building(int(building.race),int(building.kind))
		var position=Vector2i(ACData.point(building.pos))
		for y in range(position.y,position.y+int(definition.h)):
			for x in range(position.x,position.x+int(definition.w)):
				if inside(Vector2i(x,y)):navigator.set_point_solid(Vector2i(x,y),true)
	# Synthetic test/editor terrain uses its edited coarse geometry. Source
	# detail is active only while the imported terrain itself is unchanged.
	source_detail_active=source_walk_masks.size()==SIZE*SIZE and terrain==PackedByteArray(_definition.terrain)
	if source_detail_active:_rebuild_source_collision(buildings)
	revision+=1

func _rebuild_source_collision(buildings: Array) -> void:
	var solid=PackedByteArray()
	solid.resize(512*512)
	for y in range(512):
		for x in range(512):
			var tile=(y/4)*SIZE+x/4
			# Integers here denote cell centers, matching CHK entity conversion.
			solid[y*512+x]=int((source_walk_masks[tile]&(1<<((y%4)*4+x%4)))==0)
	var obstacles=resource_obstacles.duplicate()
	for building in buildings:
		if building.hp<=0:continue
		var definition=ACData.building(int(building.race),int(building.kind))
		obstacles.append(Rect2(ACData.point(building.pos)-Vector2.ONE*.5,Vector2(definition.w,definition.h)))
	for rect in obstacles:
		var first=Vector2i(((rect.position+Vector2.ONE*.5)*4).floor()).max(Vector2i.ZERO)
		var end=Vector2i(((rect.end+Vector2.ONE*.5)*4).ceil()).min(Vector2i(512,512))
		for y in range(first.y,end.y):
			for x in range(first.x,end.x):solid[y*512+x]=1
	_detail_prefix.resize(513*513)
	_detail_prefix.fill(0)
	for y in range(512):
		var row=0
		for x in range(512):
			row+=solid[y*512+x]
			_detail_prefix[(y+1)*513+x+1]=row+_detail_prefix[y*513+x+1]

func source_ground_fits(dimensions: Vector2, pos: Vector2) -> bool:
	var low=Vector2i(((pos-dimensions*.5+Vector2.ONE*.50001)*4).floor())
	var high=Vector2i(((pos+dimensions*.5+Vector2.ONE*.49999)*4).floor())+Vector2i.ONE
	if low.x<0 or low.y<0 or high.x>512 or high.y>512:return false
	return _detail_prefix[high.y*513+high.x]-_detail_prefix[low.y*513+high.x]-_detail_prefix[high.y*513+low.x]+_detail_prefix[low.y*513+low.x]==0

func set_resource_obstacles(rects: Array) -> void:
	resource_obstacles.clear()
	for obstacle in rects:
		if obstacle is Rect2 and obstacle.has_area():resource_obstacles.append(obstacle)
	if navigator.region.has_area():reset_solids(_last_buildings)

func walkable(p: Vector2i) -> bool:
	return inside(p) and not navigator.is_point_solid(p)

func nearest_free(p: Vector2, radius: int=9) -> Vector2:
	var cell=Vector2i(p.round())
	if walkable(cell):return Vector2(cell)
	for distance in range(1,radius+1):
		for dx in range(-distance,distance+1):
			for dy in range(-distance,distance+1):
				var candidate=cell+Vector2i(dx,dy)
				if walkable(candidate):return Vector2(candidate)
	return p

func path(from: Vector2, to: Vector2) -> Array:
	var a=Vector2i(nearest_free(from))
	var b=Vector2i(nearest_free(to))
	if not walkable(a) or not walkable(b):return []
	var result: Array=[]
	for point in navigator.get_id_path(a,b):result.append(ACData.packed(Vector2(point)))
	if not result.is_empty():result.pop_front()
	return result

func symmetric() -> bool:
	for y in range(SIZE):
		for x in range(SIZE):
			for slot in [1,3]:
				var point=Vector2i(reflect(Vector2(x,y),slot))
				var a=y*SIZE+x
				var b=point.y*SIZE+point.x
				if terrain[a]!=terrain[b] or height_map[a]!=height_map[b] or surface_map[a]!=surface_map[b] or buildable_map[a]!=buildable_map[b] or detail_map[a]!=detail_map[b]:return false
	return true

## Legacy signature retained; 1=x reflection, 2=xy, 3=y for mirror_xy maps.
func resources_symmetric(turns: int=1) -> bool:
	var lookup: Dictionary={}
	for item in resources:lookup["%s:%s:%s:%s"%[item.type,item.pos[0],item.pos[1],item.initial_amount]]=true
	for item in resources:
		var point=reflect(ACData.point(item.pos),turns)
		if not lookup.has("%s:%s:%s:%s"%[item.type,point.x,point.y,item.initial_amount]):return false
	return true
