extends SceneTree
var checks=0
var failures=[]
var reports=[]
var starts=[]
var violations=[]
var output="res://build/base-resource-spacing-20261025/"
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output+=args[0]+"/"
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func gaps(c,rect: Rect2,nodes: Array) -> Dictionary:
	var result={"as":INF,"tera":INF}
	for node in nodes:
		if node.type=="as" and node.amount<=0:continue
		result[node.type]=minf(result[node.type],ACMap.footprint_gap(rect,c.resource_rect(node)))
	return result
func run() -> void:
	var source_files=["res://data/original_maps.json","res://data/source_terrain_detail.json","res://data/terrain_visual_roles.json"]
	var hashes={}
	for file in source_files:hashes[file]=FileAccess.get_sha256(file)
	for map_id in range(3):
		var c=ACCore.new();c.setup({"map":map_id,"seed":251025,"spawn_slots":[0,1,2,3],"players":[{"race":0},{"race":1},{"race":2},{"race":0}]})
		for race in range(3):
			var d=ACData.building(race,0)
			check(Vector2(d.w,d.h)==Vector2(4,3),"common headquarters footprint race=%d"%race)
		for owner in range(4):
			var hq=c.entity(c.players[owner].home)
			var measured=gaps(c,c.footprint(hq),c.map.resources)
			check(measured["as"]>=3 and measured["as"]<4,"starting headquarters mineral gap map=%d slot=%d"%[map_id,owner])
			check(is_equal_approx(measured.tera,3.0),"starting headquarters tera gap map=%d slot=%d"%[map_id,owner])
			starts.append({"map":map_id,"slot":owner,"anchor":hq.pos.duplicate(),"gaps":measured})
		c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		# Exhaust placement after the two authored one-mineral gates are mined.
		# Their actual gather/build sequence has a separate regression.
		for node in c.map.resources:
			if node.type=="as" and int(node.amount)==1:node.amount=0
		c._sync_resource_obstacles()
		var candidates=[];var too_close=0
		# Exhaust actual construction validation over every on-map 4x3 anchor.
		# Source resources, buildability and 8-pixel terrain masks remain active.
		for y in range(0,126):
			for x in range(0,125):
				var pos=Vector2(x,y)
				var error=c.placement(0,0,pos,false)
				if not error.is_empty():continue
				var rect=Rect2(pos-Vector2.ONE*.5,Vector2(4,3))
				var near=gaps(c,rect,c.map.resources)
				if near.tera<3:
					too_close+=1
					if violations.size()<15:violations.append({"map":map_id,"anchor":ACData.packed(pos),"gaps":near})
				candidates.append({"anchor":pos,"rect":rect})
		check(too_close==0,"all legal headquarters keep tera clearance map=%d violating_anchors=%d"%[map_id,too_close])
		var base_count=0
		for base_index in range(c.map.bases.size()):
			var base=c.map.bases[base_index];var nodes=[];var ore=[]
			for node in c.map.resources:
				if node.id not in base.resources:continue
				nodes.append(node)
				if node.type=="as" and node.amount>=500:ore.append(node)
			if ore.size()<3:continue # A single blocking mineral is not a base.
			var site=ACData.point(base.pos);var best={};var score=INF;var paired_gas={};var closest_tera=INF
			for choice in candidates:
				if choice.rect.get_center().distance_to(site)>18:continue
				var measured=gaps(c,choice.rect,nodes)
				closest_tera=minf(closest_tera,float(measured.tera))
				var average=0.0
				for node in ore:
					var p=ACData.point(node.pos);average+=p.distance_squared_to(p.clamp(choice.rect.position,choice.rect.end))
				var value=(measured["as"]-3)*100000+average/ore.size()+choice.rect.get_center().distance_squared_to(site)*.01
				if value<score:score=value;best={"anchor":ACData.packed(choice.anchor),"gaps":measured}
				if is_equal_approx(float(measured["as"]),3.0) and is_finite(float(measured.tera)):
					var key=str(measured.tera)
					if not paired_gas.has(key) or average<float(paired_gas[key].score):paired_gas[key]={"anchor":ACData.packed(choice.anchor),"score":average}
			var label="map=%d base=%d access=%s"%[map_id,base_index,base.access]
			if c.map.headquarters_sites.has(base_index):
				var anchor=ACData.point(c.map.headquarters_sites[base_index])
				best={"anchor":ACData.packed(anchor),"gaps":gaps(c,Rect2(anchor-Vector2.ONE*.5,Vector2(4,3)),nodes)}
			check(not best.is_empty(),"source base has a legal headquarters "+label)
			if not best.is_empty():
				check(best.gaps["as"]>=3 and best.gaps["as"]<4,"expansion matches starting mineral distance "+label)
				var has_tera=nodes.any(func(n):return n.type=="tera")
				check(not has_tera or is_equal_approx(best.gaps.tera,closest_tera),"expansion permits the closest source-terrain Tera placement "+label)
				var anchor=ACData.point(best.anchor)
				for race in range(3):check(c.placement(race,0,anchor,false)=="","same base anchor accepted for race=%d "%race+label)
				reports.append({"map":map_id,"base":base_index,"kind":base.kind,"access":base.access,"pos":base.pos,"minerals":ore.size(),"best":best,"closest_tera_gap":closest_tera,"tera_gaps_with_as3":paired_gas})
			base_count+=1
		print("BASE_SPACING_MAP ",JSON.stringify({"map":map_id,"bases":base_count,"legal_anchors":candidates.size(),"tera_violations":too_close}))
	for file in source_files:check(FileAccess.get_sha256(file)==hashes[file],"original map file preserved "+file)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"bases":reports,"starts":starts,"too_close_samples":violations,"source_sha256":hashes}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASE_RESOURCE_SPACING ",JSON.stringify({"passed":result.passed,"checks":checks,"bases":reports.size(),"starts":starts.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
