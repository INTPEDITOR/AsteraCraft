extends SceneTree
var checks=0
var failures=[]
var records=[]
func _initialize():call_deferred("run")
func check(value,label):
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func run():
	var plan=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_spacing_20261025.json"))
	for base_index in [0,10]:
		var site=plan.maps[1].base_sites.filter(func(s):return int(s.base)==base_index)[0]
		for race in range(3):
			var c=ACCore.new();c.setup({"map":1,"players":[{"race":0},{"race":1},{"race":2}]})
			c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
			c.players[race].as=10000;c.players[race].tera=10000;c.players[race].cap=200
			var anchor=ACData.point(site.headquarters_anchor)
			var node=c.resource(int(site.requires_mining[0]));var before=c.placement(race,0,anchor,false)
			check(int(node.amount)==1 and not before.is_empty(),"authored one-mineral blocks normal depot placement")
			var near=c._resource_approach(node,anchor,ACCore.collision_size(race,0))
			check(near.is_finite(),"source one-mineral is accessible race %d base %d"%[race,base_index])
			if not near.is_finite():continue
			var w=c.add_unit(race,0,near);c._update_vision()
			check(c.command(race,{"type":"gather","ids":[w.id],"target":node.id})=="","normal gather order accepted")
			var ticks=0
			while node.amount>0 and ticks<300:
				c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index();c._tick_unit(w,.05);ticks+=1
			check(node.amount==0,"normal mining clears one-mineral gate")
			check(c.placement(race,0,anchor,false)=="","same source anchor becomes buildable after mining")
			var money=c.players[race].as
			check(c.command(race,{"type":"build","ids":[w.id],"kind":0,"pos":site.headquarters_anchor})=="","normal construction follows mining")
			var travel=0
			while c.buildings.is_empty() and travel<600:
				c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index();c._tick_unit(w,.05);travel+=1
			check(c.buildings.size()==1 and c.buildings[0].pos==site.headquarters_anchor,"worker walks and creates depot at original island site")
			check(c.players[race].as==money-float(ACData.building(race,0).as),"depot is paid exactly once")
			if not c.buildings.is_empty():
				var rect=c.footprint(c.buildings[0]);var ore=INF;var gas=INF
				for r in c.map.resources:
					if r.id not in c.map.bases[base_index].resources or r.amount<=0:continue
					if r.type=="as":ore=minf(ore,ACMap.footprint_gap(rect,c.resource_rect(r)))
					else:gas=minf(gas,ACMap.footprint_gap(rect,c.resource_rect(r)))
				check(ore==3 and gas==3,"actual island depot has exact As3/Tera3")
				records.append({"base":base_index,"race":race,"gate":node.id,"mining_ticks":ticks,"travel_ticks":travel,"anchor":site.headquarters_anchor,"as_gap":ore,"tera_gap":gas})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/spacing3-20261025")
	FileAccess.open("res://build/spacing3-20261025/island-mining.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PYTHON_ISLAND_MINING ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
