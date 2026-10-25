extends SceneTree
var checks=0
var failures=[]
var cases=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func run() -> void:
	var plan=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_spacing_20261025.json"))
	for map_id in range(3):
		var c=ACCore.new();c.setup({"map":map_id,"seed":251025,"spawn_slots":[0,1,2,3],"players":[{"race":0},{"race":1},{"race":2},{"race":0}]})
		for slot in range(4):
			check(c.entity(c.players[slot].home).pos==plan.maps[map_id].starting_headquarters_anchors[slot],"starting headquarters preserved map=%d slot=%d"%[map_id,slot])
		for site in plan.maps[map_id].base_sites:
			for race in range(3):
				c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
				c.players[race].as=10000;c.players[race].tera=10000
				for node in c.map.resources:
					if int(node.id) in site.get("requires_mining",[]).map(func(id):return int(id)):node.amount=0
				c._sync_resource_obstacles()
				var anchor=ACData.point(site.headquarters_anchor)
				var worker=c.add_unit(race,0,anchor+Vector2(1,1))
				var future={"id":-999,"owner":race,"race":race,"kind":0,"pos":site.headquarters_anchor,"progress":0.0}
				var approach=c.building_approach(future,ACData.point(worker.pos),worker)
				c._set_unit_position(worker,approach)
				var label="map=%d base=%d race=%d"%[map_id,int(site.base),race]
				check(c._unit_fits(worker,approach,false) and c.construction_reach(worker,future),"worker can reach construction perimeter "+label)
				var before=c.players[race].as
				var error=c.command(race,{"type":"build","kind":0,"ids":[worker.id],"pos":site.headquarters_anchor})
				check(error=="" and worker.order=="build_move","normal construction command accepted "+label)
				c._tick_unit(worker,.05)
				check(c.buildings.size()==1 and c.buildings[0].pos==site.headquarters_anchor,"actual headquarters construction begins "+label)
				check(is_equal_approx(c.players[race].as,before-float(ACData.building(race,0).as)),"construction charged exactly once "+label)
				if c.buildings.is_empty():continue
				var hq=c.buildings[0];hq.progress=1.0;hq.hp=ACData.building(race,0).hp
				if race==1:c.roots.update(c);c.time+=20.0;c.roots.update(c)
				if site.tera_id!=null:
					var vent=c.resource(int(site.tera_id));var snap=c.refinery_anchor(vent)
					check(c.footprint(hq).grow(3).intersects(c.resource_rect(vent))==false,"headquarters keeps exact Tera boundary "+label)
					check(c.placement(race,1,snap,false)=="","refinery still fits actual Tera anchor "+label)
					var bad=Vector2.INF;var terrain_blocked=Vector2.INF
					c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
					for y in range(maxi(0,int(vent.pos[1])-7),mini(126,int(vent.pos[1])+8)):
						for x in range(maxi(0,int(vent.pos[0])-7),mini(125,int(vent.pos[0])+8)):
							var point=Vector2(x,y)
							if c.placement(race,0,point,false).begins_with("본진은 테라"):bad=point;break
							var distance=ACMap.footprint_gap(Rect2(point-Vector2.ONE*.5,Vector2(4,3)),c.resource_rect(vent))
							if distance>=0 and distance<3 and c.placement(race,0,point,false)!="":terrain_blocked=point
						if bad.is_finite():break
					if not bad.is_finite():bad=terrain_blocked
					check(bad.is_finite(),"near-Tera blocked sample exists "+label)
					if bad.is_finite():
						var saved=c.players[race].as
						error=c.command(race,{"type":"build","kind":0,"ids":[worker.id],"pos":ACData.packed(bad)})
						check(not error.is_empty() and c.buildings.is_empty() and c.players[race].as==saved,"too-close construction rejected without spending "+label)
				cases.append({"map":map_id,"base":site.base,"race":race,"anchor":site.headquarters_anchor,"tera":site.tera_id})
		print("BASE_COMMAND_MAP_DONE ",map_id)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases}
	DirAccess.make_dir_recursive_absolute("res://build/base-resource-spacing-20261025/commands")
	FileAccess.open("res://build/base-resource-spacing-20261025/commands/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASE_COMMANDS ",JSON.stringify({"passed":result.passed,"checks":checks,"cases":cases.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
