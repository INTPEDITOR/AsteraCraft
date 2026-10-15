extends SceneTree

# Unassisted opening-phase matches. This does not claim full-match, GPU or network QA.
const DT=.05
const SECONDS=180.0
var checks=0
var failures: Array=[]
var reports: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func same_rect(a: Rect2,b: Rect2) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)

func observe(c: ACCore,stats: Array,seen: Dictionary,starts: Dictionary,violations: Dictionary,refineries: Dictionary) -> void:
	var counts=[0,0,0,0]
	for owner in range(4):
		var p=c.players[owner]
		for field in ["as","tera","used","reserved","cap","gathered","spent"]:
			if not is_finite(float(p[field])):violations["nonfinite_player_%d_%s"%[owner,field]]=true
		if p.as<-.00001 or p.tera<-.00001:violations["negative_wallet_%d"%owner]=true
		if p.used<0 or p.reserved<0 or p.cap<0 or p.used+p.reserved>200.0001 or p.cap>200.0001:violations["population_%d"%owner]=true
		stats[owner].min_as=minf(stats[owner].min_as,float(p.as))
		stats[owner].min_tera=minf(stats[owner].min_tera,float(p.tera))
		stats[owner].peak_population=maxf(stats[owner].peak_population,float(p.used+p.reserved))
	for unit in c.units:
		var owner=int(unit.owner)
		var technical=bool(ACData.unit(int(unit.race),int(unit.kind)).get("technical",false))
		if not technical:counts[owner]+=1
		var pos=ACData.point(unit.pos)
		if not pos.is_finite() or not is_finite(float(unit.hp)) or not is_finite(float(unit.shield)):violations["nonfinite_unit_%d"%unit.id]=true
		if pos.x<-.001 or pos.y<-.001 or pos.x>ACMap.SIZE-.999 or pos.y>ACMap.SIZE-.999:violations["outside_unit_%d"%unit.id]=true
		if not seen.has(unit.id):
			seen[unit.id]=true
			starts[unit.id]=pos
		if not technical and unit.id not in stats[owner].initial_units and not stats[owner].completed_units.has(unit.id):
			stats[owner].completed_units[unit.id]=true
			if int(unit.kind)==0:stats[owner].trained_workers+=1
			else:stats[owner].trained_army+=1
		if pos.distance_squared_to(starts[unit.id])>.1225:stats[owner].moved_units[unit.id]=true
		stats[owner].orders[str(unit.order)]=true
	for building in c.buildings:
		var owner=int(building.owner)
		if not ACData.point(building.pos).is_finite() or not is_finite(float(building.hp)) or not is_finite(float(building.progress)):violations["nonfinite_building_%d"%building.id]=true
		stats[owner].peak_queue=maxi(stats[owner].peak_queue,building.queue.size())
		if building.id not in stats[owner].initial_buildings:
			stats[owner].new_buildings[building.id]=true
			stats[owner].new_progress=maxf(stats[owner].new_progress,float(building.progress))
			if building.progress>=.999:stats[owner].completed_new_buildings[building.id]=true
		if int(building.kind)==1 and not refineries.has(building.id):
			var matched=false
			var actual=c.footprint(building)
			for vent in c.map.resources:
				if vent.type=="tera" and same_rect(actual,c.resource_rect(vent)):matched=true;break
			if actual.size!=Vector2(4,2) or not matched:violations["refinery_overlap_%d"%building.id]=true
			refineries[building.id]=true
	for node in c.map.resources:
		if not is_finite(float(node.amount)) or node.amount<0:violations["negative_or_invalid_resource_%d"%node.id]=true
	for owner in range(4):stats[owner].peak_units=maxi(stats[owner].peak_units,counts[owner])

func opening_access(c: ACCore,map_id: int) -> void:
	for owner in range(4):
		var hq=c.entity(int(c.players[owner].home))
		var home=c.center(hq)
		var near_vents: Array=[]
		for vent in c.map.resources:
			if vent.type=="tera" and ACData.point(vent.pos).distance_to(home)<20:near_vents.append(vent)
		near_vents.sort_custom(func(a,b):return ACData.point(a.pos).distance_squared_to(home)<ACData.point(b.pos).distance_squared_to(home))
		check(not near_vents.is_empty(),"map%d owner%d has local Tera"%[map_id,owner])
		if not near_vents.is_empty():
			var vent=near_vents[0]
			var anchor=c.refinery_anchor(vent)
			var d=ACData.building(int(c.players[owner].race),1)
			check(anchor.is_finite() and same_rect(Rect2(anchor-Vector2(.5,.5),Vector2(d.w,d.h)),c.resource_rect(vent)) and Vector2(d.w,d.h)==Vector2(4,2),"map%d owner%d exact 4x2 Tera footprint"%[map_id,owner])
			check(c.placement(owner,1,anchor,false)=="","map%d owner%d aligned local Tera can accept refinery"%[map_id,owner])
		for worker in c.units:
			if int(worker.owner)!=owner or int(worker.kind)!=0:continue
			var pos=ACData.point(worker.pos)
			var id=c.nearest_resource(pos,"as",owner)
			var ore=c.resource(id)
			check(not ore.is_empty(),"map%d owner%d worker%d can identify As"%[map_id,owner,worker.id])
			if not ore.is_empty():
				var approach=c._resource_approach(ore,pos,c.collision_size(int(worker.race),0))
				check(approach.is_finite() and (not c.map.path(pos,approach).is_empty() or pos.distance_to(approach)<.25),"map%d owner%d worker%d has initial As approach path"%[map_id,owner,worker.id])

func run_case(map_id: int) -> Dictionary:
	var specifications: Array=[]
	for owner in range(4):specifications.append({"name":"QA Bot %d"%owner,"race":(map_id+owner)%3,"bot":true,"difficulty":1,"team":owner})
	var c=ACCore.new()
	c.setup({"map":map_id,"seed":202610150+map_id,"mode":"ffa","players":specifications})
	var initial_workers=c.units.filter(func(unit):return int(unit.kind)==0)
	var initial_normal=c.units.filter(func(unit):return not ACData.unit(int(unit.race),int(unit.kind)).get("technical",false))
	check(c.players.size()==4 and c.buildings.size()==4 and initial_workers.size()==16 and initial_normal.size()==16,"map%d starts a normal four-player match"%map_id)
	opening_access(c,map_id)
	var stats: Array=[]
	for owner in range(4):
		var initial_units: Dictionary={}
		var initial_buildings: Dictionary={}
		for unit in c.units:
			if int(unit.owner)==owner and not ACData.unit(int(unit.race),int(unit.kind)).get("technical",false):initial_units[unit.id]=true
		for building in c.buildings:
			if int(building.owner)==owner:initial_buildings[building.id]=true
		stats.append({"initial_units":initial_units,"initial_buildings":initial_buildings,"completed_units":{},"trained_workers":0,"trained_army":0,"peak_units":0,"peak_population":0.0,"peak_queue":0,"min_as":50.0,"min_tera":0.0,"new_buildings":{},"completed_new_buildings":{},"new_progress":0.0,"moved_units":{},"orders":{}})
	var seen: Dictionary={}
	var starts: Dictionary={}
	var violations: Dictionary={}
	var refineries: Dictionary={}
	observe(c,stats,seen,starts,violations,refineries)
	var started=Time.get_ticks_usec()
	var ticks=0
	for tick in range(ceili(SECONDS/DT)):
		c.step(DT)
		c.resolve_spells()
		ticks+=1
		observe(c,stats,seen,starts,violations,refineries)
		if tick%400==399:
			print("RELEASE_BOT_PROGRESS map=%d sim_seconds=%.1f units=%d buildings=%d"%[map_id,c.time,c.units.size(),c.buildings.size()])
			await process_frame
		if c.ended:break
	var result={"map":map_id,"name":c.map.source_info.get("name",str(map_id)),"seed":202610150+map_id,"players":[],"sim_seconds":snappedf(c.time,.001),"ticks":ticks,"dt":DT,"wall_seconds":snappedf((Time.get_ticks_usec()-started)/1000000.0,.001),"ended":c.ended,"winners":c.winners,"resources":c.map.resources.size(),"actual_refineries_checked":refineries.size(),"violations":violations.keys(),"warnings":[]}
	check(violations.is_empty(),"map%d has finite state, nonnegative resources, population<=200 and exact refineries"%map_id)
	for owner in range(4):
		var p=c.players[owner]
		var s=stats[owner]
		check(p.gathered>=64,"map%d owner%d completes repeated resource deliveries"%[map_id,owner])
		check(s.trained_workers>0 and p.spent>0,"map%d owner%d starts normal production"%[map_id,owner])
		check(s.moved_units.size()>=4 and s.orders.has("gather"),"map%d owner%d moves its starting workers and gathers"%[map_id,owner])
		check(s.completed_new_buildings.size()>0 or s.new_progress>.5,"map%d owner%d progresses additional construction"%[map_id,owner])
		check(s.trained_army>0,"military stage: map%d owner%d race%d produces army in normal opening"%[map_id,owner,int(p.race)])
		result.players.append({"owner":owner,"race":int(p.race),"economy_active":p.gathered>=64 and s.trained_workers>0 and p.spent>0,"army_produced":s.trained_army>0,"gathered":p.gathered,"spent":p.spent,"as":p.as,"tera":p.tera,"min_as":s.min_as,"min_tera":s.min_tera,"trained_workers":s.trained_workers,"trained_army":s.trained_army,"peak_units":s.peak_units,"peak_population":s.peak_population,"peak_queue":s.peak_queue,"new_buildings":s.new_buildings.size(),"completed_new_buildings":s.completed_new_buildings.size(),"moved_units":s.moved_units.size(),"orders":s.orders.keys(),"kills":p.kills,"lost":p.lost})
	if refineries.is_empty():result.warnings.append("no actual extractor was created in this opening window; initial exact-footprint placement was checked separately")
	print("RELEASE_BOT_CASE "+JSON.stringify(result))
	return result

func run() -> void:
	var inputs: Dictionary={}
	for path in ["res://scripts/core.gd","res://scripts/world_map.gd","res://scripts/data.gd","res://data/game.json","res://data/maps.json"]:inputs[path]=FileAccess.get_sha256(path)
	for map_id in range(3):reports.append(await run_case(map_id))
	for path in inputs:check(inputs[path]==FileAccess.get_sha256(path),"input stayed fixed during QA: "+path)
	var report={"kind":"unassisted_opening_simulation","engine":Engine.get_version_info().string,"input_sha256":inputs,"maps":reports,"checks":checks,"failures":failures,"network_tested":false,"gpu_tested":false,"full_match_tested":false}
	var file=FileAccess.open("res://build/release-bot-smoke.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"))
	else:check(false,"write quantitative QA report")
	print("RELEASE_BOT_SMOKE checks=%d failures=%d simulated_total=%.1f"%[checks,failures.size(),reports.reduce(func(sum,item):return sum+float(item.sim_seconds),0.0)])
	quit(0 if failures.is_empty() else 1)
