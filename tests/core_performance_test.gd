extends SceneTree

# Deterministic headless simulation benchmark. Timing excludes world setup,
# command submission and validation. No quadratic collision audit runs per tick.
const DT: float = .05
const WARMUP: int = 8
const SAMPLES: int = 80
var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func arena() -> ACCore:
	var c=load("res://tests/core_profile_probe_v060.gd").new() if OS.get_environment("ASTERA_PROFILE")=="1" else ACCore.new()
	c.setup({"map":0,"seed":20261015,"players":[{"race":0},{"race":2}]})
	c.units.clear()
	c.buildings.clear()
	c.map.terrain.fill(0)
	c.map.buildable_map.fill(1)
	c.map.resources.clear()
	if c.has_method("_sync_resource_obstacles"):c.call("_sync_resource_obstacles")
	c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(3,3),true).id
	c.players[1].home=c.add_building(1,0,Vector2(118,118),true).id
	c.map.reset_solids(c.buildings)
	c.collision_index_valid=false
	c.ai_clock=100000
	return c

func populate(c: ACCore, count: int, mode: String) -> Array:
	var ids: Array=[]
	for i in range(count):
		var owner=0
		var p=Vector2(22+(i%20)*3.2,22+int(i/20)*3.2)
		if mode=="combat":
			owner=i%2
			var index=int(i/2)
			p=Vector2(57+(index%10)*.85+(6 if owner==1 else 0),24+int(index/10)*1.25)
		var u=c.add_unit(owner,1,p)
		# Keep the benchmark population stable while preserving normal combat work.
		if mode=="combat":u.hp=100000.0;u.shield=100000.0
		ids.append(u.id)
	if mode=="move":
		for start in range(0,ids.size(),12):
			c.command(0,{"type":"move","ids":ids.slice(start,mini(start+12,ids.size())),"pos":[97.0,95.0],"formation":true})
	elif mode=="mass_move":
		# A bot may submit an army command larger than a human's 12-unit group.
		c.players[0].bot=true
		c.command(0,{"type":"move","ids":ids,"pos":[97.0,95.0],"formation":true})
	elif mode=="combat":
		for u in c.units:
			u.order="attack_move"
			u.goal=[63.0,38.0]
	c._update_vision()
	return ids

func stats(values: Array) -> Dictionary:
	var sorted=values.duplicate()
	sorted.sort()
	var total: float=0
	for value in values:total+=float(value)
	return {"mean_ms":snappedf(total/values.size(),.001),"p95_ms":snappedf(float(sorted[mini(sorted.size()-1,ceili(sorted.size()*.95)-1)]),.001),"max_ms":snappedf(float(sorted[-1]),.001)}

func run_case(count: int, mode: String) -> void:
	var c=arena()
	var ids=populate(c,count,mode)
	var timings: Array=[]
	var warmup_max: float=0
	var perf_property=false
	for property in c.get_property_list():
		if property.name=="perf":perf_property=true
	for tick in range(WARMUP+SAMPLES):
		var started=Time.get_ticks_usec()
		c.step(DT)
		c.resolve_spells()
		var elapsed=(Time.get_ticks_usec()-started)/1000.0
		if tick>=WARMUP:timings.append(elapsed)
		else:warmup_max=maxf(warmup_max,elapsed)
	var result=stats(timings)
	result.merge({"mode":mode,"units":count,"ticks":SAMPLES,"simulated_seconds":(WARMUP+SAMPLES)*DT,"survivors":c.units.size(),"ended":c.ended,"warmup_max_ms":snappedf(warmup_max,.001)})
	if perf_property:result["perf"]=c.get("perf").duplicate(true)
	if c.has_method("profile_report"):result["profile"]=c.call("profile_report")
	if c.units.size()!=count or c.ended:
		failed=true
		result["invalid"]="benchmark population or active-match invariant changed"
	if mode in ["move","mass_move"]:
		var moved=0
		for u in c.units:
			if ACData.point(u.pos).distance_to(Vector2(22+(ids.find(u.id)%20)*3.2,22+int(ids.find(u.id)/20)*3.2))>1:moved+=1
		result["moved_units"]=moved
		if moved<count:failed=true
	print("CORE_BENCH "+JSON.stringify(result))

func run() -> void:
	print("CORE_BENCH_BEGIN engine="+Engine.get_version_info().string+" debug="+str(OS.is_debug_build()))
	var modes: Array=["idle","move","mass_move","combat"]
	var counts: Array=[100,200,400]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):modes=[argument.trim_prefix("--mode=")]
		if argument.begins_with("--count="):counts=[int(argument.trim_prefix("--count="))]
	for mode in modes:
		for count in counts:run_case(int(count),str(mode))
	print("CORE_BENCH_END valid="+str(not failed))
	quit(1 if failed else 0)
