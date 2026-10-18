extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label)
func _initialize():
	var r=ACTerrainRenderer.new();r.load_art()
	check(r.bank_materials.size()==15,"all biome module art loads")
	for tex in r.bank_materials:
		check(tex.get_width()>=250 and tex.get_height()>=250,"module art source resolution")
		check(tex.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"directional detail retained")
	var chains=r._bank_chains([[Vector2(20,0),Vector2(30,0)],[Vector2(10,0),Vector2(20,0)],[Vector2(40,0),Vector2(30,0)],[Vector2(10,0),Vector2(0,0)]])
	check(chains.size()==1 and chains[0].size()==5,"shuffled open segments form one chain without false endcaps")
	var original=PackedVector2Array()
	for x in range(100):original.append(Vector2(x*4,sin(x*.7)*1.5))
	var clean=r._clean_bank_chain(original)
	check(clean.size()<original.size()/2,"small corrugations are actually simplified")
	for p in original:
		var distance=INF
		for i in range(clean.size()-1):distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,clean[i],clean[i+1])))
		check(distance<=2.001,"simplification stays within two pixels of collision-aligned source")
	var reports=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme)
		var before=hash([map.terrain,map.height_map,map.buildable_map,map.resources,map.starts])
		var data=r._build_cache(map,0);var counts={};var vertices={};var joins=[]
		for layer in data.layers:
			if layer.get("role","") not in ["coast","height_bank","coast_rim","height_bank_rim"]:continue
			var a=layer.mesh.surface_get_arrays(0)
			for p in a[Mesh.ARRAY_VERTEX]:
				var key=p.snapped(Vector2.ONE*.001);vertices[key]=vertices.get(key,0)+1
			if layer.get("role","").ends_with("_rim"):continue
			for c in a[Mesh.ARRAY_COLOR]:check(is_equal_approx(c.a,1),"module faces stay opaque")
			if layer.piece_kind>0:
				for uv in a[Mesh.ARRAY_TEX_UV]:check(uv.x>=0 and uv.x<=1,"corner art uses a bounded dedicated UV region")
			if layer.piece_kind==0:
				joins.append_array(layer.joins)
				for key in layer.modules:counts[key]=counts.get(key,0)+layer.modules[key]
		for join in joins:
			check(vertices.get(join.entry.snapped(Vector2.ONE*.001),0)>=2,"corner entry shares the exact straight connector")
			check(vertices.get(join.exit.snapped(Vector2.ONE*.001),0)>=2,"corner exit shares the exact straight connector")
		check(counts.get("convex",0)>0 and counts.get("concave",0)>0,"both corner directions are used")
		check(counts.get("straight",0)>0,"straight modules are used")
		check(map.visual_ramps.is_empty() or counts.get("ramp_end",0)>0,"authored ramp openings receive end transitions")
		for ramp in map.visual_ramps:
			check(r._near_bank_ramp(map,ramp.center*32),"ramp center recognized")
		for prop in data.props:
			if prop.kind in [14,15,17,23,24,25,26,27]:check(r._bank_decor_clear(map,prop.pos),"tall additions keep wall outlines and ramps clear")
		check(before==hash([map.terrain,map.height_map,map.buildable_map,map.resources,map.starts]),"all gameplay geometry remains unchanged")
		reports.append({"theme":theme,"modules":counts,"connectors":joins.size()*2})
	var output={"checks":checks,"failures":failures,"maps":reports}
	FileAccess.open("res://build/modular-banks/audit.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("MODULAR_BANKS ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
