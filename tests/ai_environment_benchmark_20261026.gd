extends SceneTree

# Reconstructed late-match workloads, never counted as league games. Uses the
# original map, real core/AI and .05-second rules; no renderer or input replay.
const T=preload("res://scripts/bot_tactics.gd")

func _initialize():call_deferred("run")

func fixture(source: Dictionary) -> ACCore:
	var spec: Dictionary=source.spec
	var c=ACCore.new()
	c.setup({"map":int(spec.map),"seed":int(spec.seed),"spawn_slots":spec.slots,"players":[{"race":int(spec.races[0]),"bot":true,"difficulty":5},{"race":int(spec.races[1]),"bot":true,"difficulty":5}]})
	c.units.clear();c.buildings=source.get("final_buildings",source.get("buildings",[])).duplicate(true)
	c.next_id=1
	for b in c.buildings:c.next_id=maxi(c.next_id,int(b.id)+1)
	c.map.reset_solids(c.buildings);c.collision_index_valid=false
	var records: Array=source.get("final_units",source.get("units",[]))
	for record in records:
		if int(record.kind)>=ACData.unit_count(int(spec.races[int(record.owner)])):continue
		var d=ACData.unit(int(spec.races[int(record.owner)]),int(record.kind))
		if d.role in ["carrier_drone","brood"]:continue
		var u=c.add_unit(int(record.owner),int(record.kind),ACData.point(record.pos))
		u.id=int(record.id);c.next_id=maxi(c.next_id,int(u.id)+1)
		for key in ["order","target","goal","anchored"]:
			if record.has(key):u[key]=record[key]
		# Do not inherit obsolete cached routes from a different reconstructed world.
		u.path=[];u.repath=0.0
	c.time=float(source.get("game_seconds",source.get("time",1200)))
	var reports: Array=source.get("final",source.get("players",[]))
	for owner in range(2):
		var p: Dictionary=c.players[owner];var report: Dictionary=reports[owner]
		var bases=c.buildings.filter(func(b):return int(b.owner)==owner and int(b.kind)==0 and b.hp>0)
		if bases.is_empty():continue
		p.home=bases[0].id;p.as=report.bank[0];p.tera=report.bank[1];p.lost=false
		T.activate(c,owner,str(report.plan))
		for index in range(mini(24,int(report.workers))):
			c.add_unit(owner,0,c.center(bases[index%bases.size()])+Vector2(4+index%4,index/4))
	c._rebuild_collision_index();c._update_vision()
	return c

func run():
	var args=OS.get_cmdline_user_args()
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var worlds=[]
	for source in spec.fixtures:worlds.append(fixture(JSON.parse_string(FileAccess.get_file_as_string(source))))
	for c in worlds:c.profile_hotspots=bool(spec.get("hotspots",false))
	FileAccess.open(str(spec.ready),FileAccess.WRITE).store_string("ready")
	var deadline=Time.get_ticks_msec()+120000
	while not FileAccess.file_exists(str(spec.go)):
		if Time.get_ticks_msec()>deadline:quit(2);return
		OS.delay_msec(10)
	var timings=[];var records=[];var start=Time.get_ticks_usec()
	for c in worlds:
		var before=c.perf.duplicate();var unit_count=c.units.size();var tick_start=Time.get_ticks_usec()
		for tick in range(int(spec.ticks)):
			var t=Time.get_ticks_usec();c.step(.05);c.resolve_spells();timings.append(Time.get_ticks_usec()-t)
		var delta={}
		for key in c.perf:delta[key]=c.perf[key]-before[key]
		records.append({"units_start":unit_count,"units_end":c.units.size(),"buildings":c.buildings.size(),"ended":c.ended,"game_seconds":int(spec.ticks)*.05,"wall_seconds":(Time.get_ticks_usec()-tick_start)/1000000.0,"phases":delta,"hot_units":c.hot_units,"hot_paths":c.hot_paths})
	var wall=(Time.get_ticks_usec()-start)/1000000.0
	timings.sort()
	var result={"wall_seconds":wall,"game_seconds":worlds.size()*int(spec.ticks)*.05,"steps":timings.size(),"step_p50_ms":timings[timings.size()/2]/1000.0,"step_p95_ms":timings[int(timings.size()*.95)]/1000.0,"records":records,"valid":records.all(func(r):return not r.ended and r.units_start>50 and r.units_end>50)}
	FileAccess.open(str(spec.output),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_ENVIRONMENT_BENCH ",JSON.stringify(result));quit(0 if result.valid else 1)
