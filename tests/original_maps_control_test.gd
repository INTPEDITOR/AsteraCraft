extends SceneTree
var checks=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func run() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	for theme in range(3):
		var m=ACMap.new();m.make(theme);var d=catalog.maps[theme]
		check(m.source_info.origin=="source_chk_cv5_vf4","source map %d"%theme)
		check(m.starts==d.starts and m.starts.size()==4,"four original starts %d"%theme)
		check(m.resources.size()==d.resources.size(),"all resources %d"%theme)
		check(m.terrain==PackedByteArray(d.terrain) and m.height_map==PackedByteArray(d.height_map) and m.buildable_map==PackedByteArray(d.buildable_map),"full terrain grids %d"%theme)
		for slot in range(4):
			var anchor=m.start_building_anchor(slot,Vector2(4,3))
			var valid=true
			for y in range(int(anchor.y),int(anchor.y)+3):
				for x in range(int(anchor.x),int(anchor.x)+4):valid=valid and m.buildable(Vector2i(x,y))
			check(valid,"source HQ footprint %d:%d"%[theme,slot])
			for other in range(slot):check(not m.path(ACData.point(m.starts[slot]),ACData.point(m.starts[other])).is_empty(),"ground route %d:%d>%d"%[theme,slot,other])
		var c=ACCore.new();c.setup({"map":theme,"seed":1,"spawn_slots":[0,1,2,3],"players":[{"race":0},{"race":1},{"race":2},{"race":0}]})
		for worker in c.units:
			if worker.kind==0:worker.order="gather";worker.target=c.nearest_resource(ACData.point(worker.pos),"as",int(worker.owner))
		for n in range(400):c.step(.05)
		for owner in range(4):check(c.players[owner].gathered>0,"workers mine from original start %d:%d"%[theme,owner])
		check(c.snapshot(-1).map_layout=="source_chk_cv5_vf4","snapshot layout %d"%theme)
	var legacy=ACMap.new();legacy.make(0,"reference_inspired_original")
	check(legacy.source_info.origin=="reference_inspired_original","old replay map preserved")
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":1},{"race":0},{"race":2}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles()
	var caster=c.add_unit(0,8,Vector2(40,40));var victim=c.add_unit(1,6,Vector2(43,40))
	caster.energy=200;c.players[0].technologies={"mind_control":1}
	c._recalculate_supply();c._update_vision();var hp=victim.hp;var id=victim.id
	check(c.command(0,{"type":"ability","ids":[caster.id],"target":id})=="","targeted control accepted")
	check(victim.owner==0 and victim.race==0 and victim.kind==6 and victim.hp==hp and victim.id==id,"identity and HP preserved, ownership transferred")
	check(caster.energy==0 and caster.ability_cd==20 and not c.is_cloaked(caster),"cost cooldown and exposure")
	check(c.players[1].used==0 and c.players[0].used==ACData.unit(1,8).pop+ACData.unit(0,6).pop,"supply transfers")
	c.command(1,{"type":"move","ids":[id],"pos":[80,80]});check(victim.order=="idle","previous owner cannot command")
	c.command(0,{"type":"move","ids":[id],"pos":[80,80]});check(victim.order=="move","new owner can command")
	var second=c.add_unit(1,1,Vector2(42,40));c._update_vision()
	check(c._mind_control(caster,second.id)!="" and second.owner==1,"cooldown rejects")
	caster.ability_cd=0;check(c._mind_control(caster,second.id)!="" and caster.energy==0,"energy rejects")
	caster.energy=200
	for scenario in ["ally","far","fog","dead","loaded","passengers","building","cloaked"]:
		var target=c.add_unit(1,1,Vector2(42,40));c.vision_signatures.clear();c._update_vision()
		if scenario=="ally":target.owner=0
		if scenario=="far":target.pos=[60,40]
		if scenario=="fog":c.visibility[0].fill(0)
		if scenario=="dead":target.hp=0
		if scenario=="loaded":target.container=999
		if scenario=="passengers":target.cargo=[second.id]
		if scenario=="building":target=c.add_building(1,2,Vector2(42,40),true)
		if scenario=="cloaked":target=c.add_unit(2,10,Vector2(42,40))
		check(c._mind_control(caster,target.id)!="" and caster.energy==200,"invalid target no cost "+scenario)
	c.vision_signatures.clear();c._update_vision();caster.energy=200;caster.ability_cd=0
	var worker=c.add_unit(1,0,Vector2(42,41));worker.build_queue=[{"kind":2,"pos":[50,50]}];worker.build_plan={"kind":2,"pos":[50,50]}
	check(c._mind_control(caster,worker.id)=="" and worker.build_queue.is_empty() and not worker.has("build_plan"),"captured worker clears old construction")
	check(c._start_construction(worker,2,Vector2(50,50))!="","foreign worker cannot build wrong faction structures")
	caster.hp=0;c.time+=25
	check(victim.owner==0 and worker.owner==0,"control persists after caster death")
	var frame=c.snapshot(-1);var packed=var_to_bytes(frame).compress(FileAccess.COMPRESSION_FASTLZ)
	var restored=bytes_to_var(packed.decompress(var_to_bytes(frame).size(),FileAccess.COMPRESSION_FASTLZ))
	check(restored.units.any(func(u):return u.id==id and u.owner==0),"replay snapshot preserves captured ownership")
	print("ORIGINAL_MAPS_CONTROL "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
