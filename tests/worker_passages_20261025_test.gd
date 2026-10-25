extends "res://tests/abilities_v060_test.gd"
var records=[]
func walk(c,u,goal,seam: Rect2=Rect2()):
	c.command(int(u.owner),{"type":"move","ids":[u.id],"pos":ACData.packed(goal)})
	var crossed=false
	for tick in range(400):
		c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index()
		c._tick_unit(u,.05);c._separate_units(.05)
		var p=ACData.point(u.pos)
		if seam.has_area() and seam.has_point(p):crossed=true
		check(c._unit_fits(u,p,false),"body remains legal throughout passage")
		if p.distance_to(goal)<.55:return {"arrived":true,"crossed":crossed,"ticks":tick+1}
	return {"arrived":false,"crossed":crossed,"pos":u.pos}
func run():
	for race in range(3):
		var c=arena(race,race)
		# Every race's supply footprint is 2x2; align the actual shared edge.
		var d=ACData.building(race,2)
		var a=c.add_building(0,2,Vector2(40,40),true)
		var b=c.add_building(0,2,Vector2(40+float(d.w),40),true)
		c.map.reset_solids(c.buildings)
		var edge=40+float(d.w)-.5
		var middle=Vector2(edge,40+(float(d.h)-1)*.5)
		var w=c.add_unit(0,0,Vector2(edge,37))
		check(c._unit_fits(w,middle,false),"own worker fits shared edge race "+str(race))
		check(not c._ground_fits_size(c._body_size(w),middle),"shared raw solid mask stays blocked")
		check(not c._unit_fits(w,Vector2(40,40),false),"own building interior remains solid")
		var enemy=c.add_unit(1,0,Vector2(48,40))
		check(not c._unit_fits(enemy,middle,false),"foreign worker blocked")
		c.players[1].team=c.players[0].team
		check(not c._unit_fits(enemy,middle,false),"allied other owner's worker blocked")
		var soldier=c.add_unit(0,1,Vector2(46,40))
		check(not c._unit_fits(soldier,middle,false),"own soldier blocked")
		enemy.hp=0;soldier.hp=0
		var goal=Vector2(edge,43+float(d.h))
		var moved=walk(c,w,goal,Rect2(edge-.25,40,.5,float(d.h)-1));records.append({"race":race,"vertical":moved})
		check(moved.arrived,"worker actually traverses vertical seam "+str(race))
		check(moved.crossed,"worker takes seam rather than detour")
		# Warm path caches, then change ownership: no permission leaks.
		b.owner=1;c.map.reset_solids(c.buildings)
		check(not c._unit_fits(w,middle,false),"ownership change closes seam")
		b.owner=0;c.map.reset_solids(c.buildings)
		check(c._unit_fits(w,middle,false),"ownership restored opens seam")
		c.map.set_resource_obstacles([Rect2(middle-Vector2.ONE*.5,Vector2.ONE)])
		check(not c._unit_fits(w,middle,false),"resource cannot be bypassed")
		c.map.set_resource_obstacles([])
		c.map.terrain[ACMap.ground_cell(middle).y*128+ACMap.ground_cell(middle).x]=1;c.map.reset_solids(c.buildings)
		check(not c._unit_fits(w,middle,false),"stone terrain cannot be bypassed")
		c.map.terrain.fill(0)
		b.pos=ACData.packed(Vector2(40,40+float(d.h)));c.map.reset_solids(c.buildings)
		var horizontal=Vector2(40+(float(d.w)-1)*.5,40+float(d.h)-.5)
		check(c._unit_fits(w,horizontal,false),"horizontal seam fits")
		c._set_unit_position(w,Vector2(37,horizontal.y))
		var horizontal_walk=walk(c,w,Vector2(43+float(d.w),horizontal.y),Rect2(40,horizontal.y-.25,float(d.w)-1,.5))
		records.back().horizontal=horizontal_walk
		check(horizontal_walk.arrived,"worker traverses horizontal seam")
		check(horizontal_walk.crossed,"worker uses horizontal seam")
		b.pos=ACData.packed(Vector2(40+float(d.w),40+float(d.h)));c.map.reset_solids(c.buildings)
		check(not c.map.worker_has_passages(0),"corner-only contact opens no corridor")
		b.hp=0;c.map.reset_solids(c.buildings)
		check(not c.map.worker_has_passages(0),"destroyed neighbor closes passage")
	for map_id in range(3):
		var c=ACCore.new();c.setup({"map":map_id,"players":[{"race":0},{"race":1},{"race":2}]})
		c.units.clear();c.buildings.clear();c.map.reset_solids([])
		var field=Vector2.INF
		for y in range(20,108,3):
			for x in range(20,108,3):
				if c._ground_fits_size(Vector2(14,12),Vector2(x,y)):field=Vector2(x,y);break
			if field.is_finite():break
		check(field.is_finite(),"real source field exists")
		if not field.is_finite():continue
		for race in range(3):
			c.units.clear();c.buildings.clear();c.collision_index_valid=false
			var d=ACData.building(race,2);var a=c.add_building(race,2,field,true);var b=c.add_building(race,2,field+Vector2(d.w,0),true)
			c.map.reset_solids(c.buildings)
			var edge=field.x+float(d.w)-.5
			var u=c.add_unit(race,0,Vector2(edge,field.y-3))
			var r=walk(c,u,Vector2(edge,field.y+float(d.h)+3),Rect2(edge-.25,field.y,.5,float(d.h)-1))
			records.append({"map":map_id,"race":race,"source_walk":r})
			check(r.arrived and r.crossed,"real source route passes seam %d:%d"%[map_id,race])
			check(c.map.source_detail_active,"source collision masks remain active")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/worker-passages-20261025")
	FileAccess.open("res://build/worker-passages-20261025/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WORKER_PASSAGES ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
