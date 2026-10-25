extends "res://tests/abilities_v060_test.gd"
func field(race):
	var c=arena(race,race);var d=ACData.building(race,2);c.map.buildable_map.fill(1);c.map.height_map.fill(0)
	c.add_building(0,2,Vector2(40,40),true);c.add_building(0,2,Vector2(40+d.w,40),true)
	c.map.reset_solids(c.buildings);c.roots.update(c);c.time=20;c.roots.update(c)
	return c
func run():
	for race in range(3):
		var c=field(race);var d=ACData.building(race,2);var edge=40+float(d.w)-.5
		var worker=c.add_unit(0,0,Vector2(edge,37));var resource={"id":9876,"type":"as","pos":[edge,46],"amount":1500.0,"busy":0.0,"base":-1}
		c.map.resources.append(resource);c._sync_resource_obstacles()
		check(c.command(0,{"type":"gather","ids":[worker.id],"target":9876})=="","gather order accepted")
		var crossed=false
		for tick in range(400):
			c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index();c._tick_unit(worker,.05);c._separate_units(.05)
			var pos=ACData.point(worker.pos)
			if absf(pos.x-edge)<.3 and pos.y>40 and pos.y<41:crossed=true
			if resource.amount<1500:break
		check(crossed and resource.amount<1500,"worker mines after crossing own buildings race "+str(race))
		c=field(race);worker=c.add_unit(0,0,Vector2(edge,37));var kind=0 if race==1 else 2
		var result=c.command(0,{"type":"build","ids":[worker.id],"kind":kind,"pos":[floori(edge)-1,46]})
		check(result=="","build order beyond own seam accepted race %d: %s"%[race,result])
		crossed=false
		for tick in range(400):
			c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index();c._tick_unit(worker,.05);c._separate_units(.05)
			var pos=ACData.point(worker.pos)
			if absf(pos.x-edge)<.3 and pos.y>40 and pos.y<41:crossed=true
			if c.buildings.size()>2:break
		check(crossed and c.buildings.size()>2,"builder crosses seam and creates paid foundation race "+str(race))
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/worker-passages-20261025")
	FileAccess.open("res://build/worker-passages-20261025/jobs.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORKER_PASSAGE_JOBS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
