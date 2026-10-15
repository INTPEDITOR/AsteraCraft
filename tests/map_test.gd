extends SceneTree

var failures: Array=[]
var checks:=0
var results: Array=[]

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error(message)

func path_length(path: Array) -> float:
	var length=0.0
	for i in range(1,path.size()):length+=Vector2(path[i]).distance_to(Vector2(path[i-1]))
	return length

func resource_rect(resource: Dictionary) -> Rect2:
	var size=Vector2(2,1) if resource.type=="as" else Vector2(4,2)
	return Rect2(ACData.point(resource.pos)-size*.5,size)

func approach_distance(map: ACMap, resource: Dictionary, from: Vector2i) -> float:
	var rect=resource_rect(resource)
	var shortest=INF
	for y in range(floori(rect.position.y)-1,ceili(rect.end.y)+2):
		for x in range(floori(rect.position.x)-1,ceili(rect.end.x)+2):
			var candidate=Vector2(x,y)
			if rect.has_point(candidate) or candidate.distance_to(candidate.clamp(rect.position,rect.end))>.8:continue
			if not map.walkable(Vector2i(candidate)):continue
			var path=map.navigator.get_id_path(from,Vector2i(candidate))
			if not path.is_empty():shortest=minf(shortest,path_length(path))
	return shortest

func fortress_navigation(map: ACMap) -> AStarGrid2D:
	var nav=AStarGrid2D.new()
	nav.region=Rect2i(0,0,128,128)
	nav.cell_size=Vector2.ONE
	nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y in range(128):
		for x in range(128):
			var solid=false
			for dy in range(-1,2):
				for dx in range(-1,2):
					if not map.walkable(Vector2i(x+dx,y+dy)):solid=true
			nav.set_point_solid(Vector2i(x,y),solid)
	return nav

func _initialize() -> void:
	var hashes: Array=[]
	for theme in range(3):
		var map=ACMap.new()
		map.make(theme)
		check(map.source_info.origin=="original_design","Map must describe its original design")
		check(not map.source_info.has("exact_source"),"Legacy map-copy metadata must not be active")
		check(map.starts.size()==4 and map.bases.size()==12,"Exactly four starts and twelve equivalent bases")
		check(map.symmetric(),"Collision/elevation/material/detail/buildability must reflect on both axes")
		for reflection in [1,2,3]:check(map.resources_symmetric(reflection),"Resource amount and position reflection")
		var signature=hash([map.terrain,map.height_map,map.surface_map])
		check(signature not in hashes,"Maps must have different actual terrain and height masks")
		hashes.append(signature)
		var counts={"as":0,"tera":0}
		var amounts={"as":0,"tera":0}
		var obstacles: Array=[]
		for resource in map.resources:
			counts[resource.type]+=1
			amounts[resource.type]+=int(resource.initial_amount)
			check(resource.amount==resource.initial_amount,"Explicit untouched initial deposit")
			check(resource.initial_amount==(1500 if resource.type=="as" else 5000),"Standard per-node initial amount")
			var rect=resource_rect(resource)
			var anchor=rect.position+Vector2(.5,.5)
			check(anchor.is_equal_approx(anchor.round()),"Resource footprint must align exactly to tile centers")
			for y in range(ceili(rect.position.y),ceili(rect.end.y)):
				for x in range(ceili(rect.position.x),ceili(rect.end.x)):
					check(map.terrain[y*128+x]==0,"Resource body must fit on navigable terrain")
					if resource.type=="tera":check(map.buildable(Vector2i(x,y)),"Refinery footprint must remain fully buildable")
			for previous in obstacles:check(not rect.intersects(previous),"Resource bodies may not overlap")
			obstacles.append(rect)
		check(counts=={"as":96,"tera":12} and amounts=={"as":144000,"tera":60000},"Equal twelve-base map economy")
		var buildings: Array=[]
		var headquarters=ACData.building(0,0)
		var hq_size=Vector2(headquarters.w,headquarters.h)
		var canonical_center=Rect2(map.start_building_anchor(0,hq_size)-Vector2(.5,.5),hq_size).get_center()
		for slot in range(4):
			var anchor=map.start_building_anchor(slot,hq_size)
			var footprint=Rect2(anchor-Vector2(.5,.5),hq_size)
			check(footprint.get_center().is_equal_approx(map.reflect(canonical_center,slot)),"Starting headquarters has the exact reflected physical center at its current dimensions")
			for y in range(int(anchor.y),int(anchor.y)+int(hq_size.y)):
				for x in range(int(anchor.x),int(anchor.x)+int(hq_size.x)):check(map.buildable(Vector2i(x,y)),"Starting headquarters fully buildable")
			for rect in obstacles:check(not footprint.intersects(rect),"Starting headquarters may not cover resources")
			buildings.append({"hp":1,"race":0,"kind":0,"pos":ACData.packed(anchor)})
			for i in range(4):check(map.start_worker_positions(slot)[i].is_equal_approx(map.reflect(map.start_worker_positions(0)[i],slot)),"Initial workers must reflect exactly")
		for base in map.bases:
			var base_counts={"as":0,"tera":0}
			var base_amounts={"as":0,"tera":0}
			for id in base.resources:
				var resource=map.resources[int(id)-100000]
				base_counts[resource.type]+=1
				base_amounts[resource.type]+=resource.initial_amount
			check(base_counts=={"as":8,"tera":1} and base_amounts=={"as":12000,"tera":5000},"Every equivalent base has eight minerals and one catalyst")
			var center=map.reflect(ACData.point(base.grid_center),int(base.slot))
			var canonical_anchor=(center+Vector2(0,.5)-(hq_size-Vector2.ONE)*.5).round()
			var physical_center=map.reflect(canonical_anchor-Vector2(.5,.5)+hq_size*.5,int(base.slot))
			var anchor=(physical_center-hq_size*.5+Vector2(.5,.5)).round()
			for y in range(int(anchor.y),int(anchor.y)+int(hq_size.y)):
				for x in range(int(anchor.x),int(anchor.x)+int(hq_size.x)):check(map.buildable(Vector2i(x,y)),"Expansion headquarters pocket fully buildable")
		map.set_resource_obstacles(obstacles)
		map.reset_solids(buildings)
		# Compare every indexed deposit's shortest harvest approach from the same
		# reflected departure point, with resource and town-hall bodies blocking.
		var mining_distances: Array=[]
		for slot in range(4):
			var values: Array=[]
			for resource in map.resources:
				if int(resource.slot)!=slot:continue
				var distance=approach_distance(map,resource,Vector2i(map.reflect(Vector2(18,23),slot)))
				check(is_finite(distance),"Every resource must have a reachable harvest perimeter")
				values.append(distance)
			mining_distances.append(values)
		for slot in range(1,4):
			for i in range(27):check(absf(mining_distances[0][i]-mining_distances[slot][i])<.0001,"Resource approach path distances must be fair at all four starts")
		var fortress=fortress_navigation(map)
		var horizontal: Array=[]
		var vertical: Array=[]
		var diagonal: Array=[]
		for slot in range(4):
			var origin=Vector2i(map.reflect(Vector2(25,25),slot))
			for group in [[1,horizontal],[3,vertical],[2,diagonal]]:
				# Reflect this slot's staging point across the requested world axis.
				var goal=Vector2i(map.reflect(Vector2(origin),int(group[0])))
				var path=fortress.get_id_path(origin,goal)
				check(not path.is_empty(),"Size-three fortress unit must pass between starting quarters")
				group[1].append(path_length(path))
		for values in [horizontal,vertical,diagonal]:check(float(values.max())-float(values.min())<.0001,"Reflected fortress rush paths must have identical lengths")
		var gate_widths: Array=[]
		for slot in range(4):
			var passable=0
			for sample in range(-24,25):
				var point=map.reflect(Vector2(31,31)+Vector2(-1,1).normalized()*float(sample)*.25,slot)
				if map.walkable(Vector2i(point.round())):passable+=1
			gate_widths.append(float(passable)*.25)
		check(float(gate_widths.max())-float(gate_widths.min())<.001 and gate_widths[0]>=7,"Main entrance widths must be equal and usable")
		var center_blocked=map.terrain[63*128+63]!=0
		check(center_blocked==(theme==1),"Each original layout retains its intended central arena/lake/citadel")
		for prop in map.decorations:
			var point=Vector2i(ACData.point(prop.pos))
			check(map.terrain[point.y*128+point.x]==1,"Tall decoration stays on blocked rock")
			for slot in [1,3]:
				var wanted=map.reflect(Vector2(point),slot)
				check(map.decorations.any(func(other):return ACData.point(other.pos)==wanted and other.kind==prop.kind and other.variant==prop.variant and other.scale==prop.scale),"Decorations must reflect with identical settings")
		var summary={"id":theme,"name":map.source_info.name,"layout":map.source_info.layout,"bases":12,"resource_nodes":counts,"total_resources":amounts,"main_gate_width_samples":gate_widths,"size3_horizontal":horizontal,"size3_vertical":vertical,"size3_diagonal":diagonal,"water_cells":map.terrain.count(2),"cliff_cells":map.terrain.count(1),"high_cells":map.height_map.count(1)+map.height_map.count(2),"bridges":map.bridges.size(),"center_blocked":center_blocked,"mask_signature":signature,"main_mining_approach_tiles":mining_distances[0].slice(0,9)}
		results.append(summary)
	print("ORIGINAL_MAP_TEST ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"maps":results}))
	var output=FileAccess.open("res://build/original-map-audit.json",FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"maps":results},"  "))
	quit(0 if failures.is_empty() else 1)
