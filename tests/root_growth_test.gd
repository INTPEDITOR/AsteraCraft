extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label);printerr("FAIL ",label)
func arena():
	var core=ACCore.new();core.setup({"map":0,"spawn_slots":[0,2],"players":[{"race":1},{"race":0}]})
	core.units.clear();core.buildings.clear();core.map.resources.clear()
	core.map.terrain.fill(0);core.map.height_map.fill(0);core.map.visual_roles.fill(0);core.map.buildable_map.fill(1)
	core.map._build_visual_relief();core.map.reset_solids([]);core.collision_index_valid=false
	core.roots=ACRootField.new();return core
func mature(core):
	core.roots.update(core);core.time+=20;core.roots.update(core)
func _initialize():
	var core=arena();var hq=core.add_building(0,0,Vector2(30,30),true)
	core.roots.update(core);var seed=core.roots.current.size()
	check(seed>20 and seed<150,"roots start underneath the building, not at full radius")
	check(not core.in_roots(0,Vector2(40,31)),"not-yet-grown ground cannot host buildings")
	core.time=4;core.roots.update(core);var growing=core.roots.current.size()
	core.time=20;core.roots.update(core);var grown=core.roots.current.size()
	check(seed<growing and growing<grown,"small cells progressively spread over time")
	check(core.in_roots(0,Vector2(40,31)) and not core.in_roots(1,Vector2(40,31)),"grown coverage belongs to its faction owner")
	for value in core.roots.current.values():
		var index=int(value)&0xffff
		check(ACRootField.point_at(Vector2i(index%256,index/256)).distance_to(core.center(hq))<=13.001,"growth retains the maximum source radius")
	# The observed tile is visible, but the generating building is not.
	core.visibility[1].fill(0);core.explored[1].fill(0)
	var visible_index=31*128+40;core.visibility[1][visible_index]=1;core.explored[1][visible_index]=1
	var seen=core.snapshot(1)
	check(seen.buildings.is_empty() and not seen.roots.is_empty(),"visible roots are sent even when their generating building is hidden")
	for value in seen.roots:check(ACRootField.ground_index(int(value)&0xffff)==visible_index,"unexplored enemy growth does not leak")
	var home_cell=ACRootField.cell_at(core.center(hq));var home_index=home_cell.y*256+home_cell.x
	core.explored[1][ACRootField.ground_index(home_index)]=1
	check(not Array(core.snapshot(1).roots).any(func(value):return (int(value)&0xffff)==home_index),"explored bare ground does not disclose roots that were never observed")
	core.visibility[1][ACRootField.ground_index(home_index)]=1
	core.snapshot(1);core.visibility[1][ACRootField.ground_index(home_index)]=0
	seen=core.snapshot(1)
	check(seen.buildings.is_empty() and Array(seen.roots).any(func(value):return (int(value)&0xffff)==home_index),"observed ground beneath a hidden HQ retains continuous roots")
	core.visibility[1].fill(0)
	check(core.snapshot(1).roots==seen.roots,"discovered roots remain in explored fog")
	hq.hp=0
	check(not core.in_roots(0,Vector2(40,31)),"dead source loses construction authority immediately")
	check(core.snapshot(1).roots==seen.roots,"hidden source death does not leak through root memory")
	core.visibility[1][visible_index]=1
	core.visibility[1][ACRootField.ground_index(home_index)]=1
	check(core.snapshot(1).roots.is_empty(),"scouting the area again removes obsolete root memory")
	# A full water barrier cannot be jumped by radial distance or diagonals.
	core=arena()
	for y in range(128):core.map.terrain[y*128+37]=2
	core.map._build_visual_relief();hq=core.add_building(0,0,Vector2(30,30),true);mature(core)
	for value in core.roots.current.values():
		var cell=Vector2i((int(value)&0xffff)%256,(int(value)&0xffff)/256)
		check(cell.x<74,"water stops connected root growth")
	var artist=ACRootRenderer.new();artist.load_art()
	artist.build(core.map,core.roots.snapshot(core,-1),func(_index):return 2)
	check(artist.tile_count>0 and artist.mesh!=null,"generated texture produces a batched ground mesh")
	var arrays=artist.mesh.surface_get_arrays(0)
	for p in arrays[Mesh.ARRAY_VERTEX]:check(p.x<=36.5*32+.001,"root mesh stays on the land side of water")
	for corner_y in range(20,90):check(artist._corner_value(Vector2i(74,corner_y),{73+corner_y*256:1.0},core.map)==0,"water edge fades on land with no paint across the wall")
	core=arena()
	for y in range(128):
		for x in range(37,128):core.map.height_map[y*128+x]=2
	core.map.visual_ramps.clear();hq=core.add_building(0,0,Vector2(30,30),true);mature(core)
	check(not core.in_roots(0,Vector2(38,31)),"a cliff blocks growth even when coarse ground is empty")
	# A relay has its own growth clock and does not instantly fill its circle.
	core=arena();hq=core.add_building(0,0,Vector2(30,30),true);mature(core)
	var relay=core.add_building(0,12,Vector2(41,30),true);core.roots.update(core)
	check(not core.in_roots(0,Vector2(51,31)),"a newly completed relay begins locally")
	core.time+=20;check(core.in_roots(0,Vector2(51,31)),"relay extends connected coverage after growing")
	relay.hp=0;check(not core.in_roots(0,Vector2(51,31)) and core.in_roots(0,Vector2(35,31)),"overlap retains the surviving source's roots")
	var report={"checks":checks,"failures":failures,"seed_cells":seed,"growing_cells":growing,"grown_cells":grown,"mesh_vertices":artist.vertex_count}
	FileAccess.open("res://build/source-terrain/root-growth.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ROOT_GROWTH ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
