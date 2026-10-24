extends SceneTree
const DT=.1
var failures=[]
var report=[]
func _initialize():call_deferred("run")
func percentile(values: Array,fraction: float):
	values.sort();return values[mini(values.size()-1,int(values.size()*fraction))]
func run():
	DirAccess.make_dir_recursive_absolute("res://build/qa-v060")
	var selected_map=-1;var selected_race=-1;var ticks=3000;var output="long-battle"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):selected_map=int(arg.trim_prefix("--map="))
		if arg.begins_with("--race="):selected_race=int(arg.trim_prefix("--race="))
		if arg.begins_with("--seconds="):ticks=maxi(1,roundi(float(arg.trim_prefix("--seconds="))/(4*DT)))
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	for theme in range(3):
		if selected_map>=0 and selected_map!=theme:continue
		for race in range(3):
			if selected_race>=0 and selected_race!=race:continue
			var c=load("res://tests/core_profile_probe_v060.gd").new() if OS.get_environment("ASTERA_PROFILE")=="1" else ACCore.new();c.setup({"map":theme,"seed":6020,"spawn_slots":[0,2],"players":[{"race":race},{"race":race}]});c.ai_clock=100000
			for node in c.map.resources:node.amount=1000000
			var battle=c.map.nearest_free(Vector2(64,64));var windows=[]
			for phase in range(4):
				var population=[50,100,150,200][phase]
				while c.units.filter(func(u):return not u.get("technical",false)).size()<population:
					var count=c.units.size();var owner=count%2
					var home=c.entity(c.players[owner].home)
					var worker=c.units.filter(func(u):return int(u.owner)==owner and int(u.kind)==0).size()<16
					var p=c.center(home)+Vector2((count%6)-2,5+int(count/12)%4) if worker else battle+Vector2(-5 if owner==0 else 5,((count/2)%10)-5)
					var kind=0 if worker else [1,2,3,7,10][int(count/2)%5]
					var u=c.add_unit(owner,kind,p);u.hp=100000;u.shield=100000
					if worker:u.order="gather";u.target=c.nearest_resource(ACData.point(u.pos),"as",owner)
					else:u.order="attack_move";u.goal=ACData.packed(battle)
				c._recalculate_supply()
				var times=[];var start_gathered=c.players[0].gathered+c.players[1].gathered
				if c.has_method("profile_report"):c.timings.clear()
				for tick in range(ticks):
					if tick%300==0:
						for u in c.units:
							if int(u.kind)!=0 and not u.get("technical",false):u.order="attack_move";u.goal=ACData.packed(battle+Vector2(0,2 if (tick/300)%2==0 else -2))
					var started=Time.get_ticks_usec();c.step(DT);c.resolve_spells();times.append((Time.get_ticks_usec()-started)/1000.0)
					if c.ended:failures.append("unexpected end %d/%d/%d"%[theme,race,phase]);break
				var total=0.0
				for value in times:total+=value
				var result={"population":population,"simulated_seconds":c.time,"mean_ms":total/times.size(),"p95_ms":percentile(times,.95),"max_ms":times[-1],"gathered":c.players[0].gathered+c.players[1].gathered-start_gathered,"effects":c.effects.size(),"events":c.events.size(),"resident_bytes":OS.get_static_memory_usage()}
				if result.gathered<=0:failures.append("mining stalled %d/%d/%d"%[theme,race,phase])
				if c.effects.size()>1500 or c.events.size()>1000:failures.append("unbounded effects/events %d/%d"%[theme,race])
				windows.append(result);print("LONG_WINDOW ",JSON.stringify({"map":theme,"race":race,"window":result}))
				if c.has_method("profile_report"):print("LONG_PROFILE ",population," ",JSON.stringify(c.profile_report()))
				FileAccess.open("res://build/qa-v060/%s-progress.json"%output,FileAccess.WRITE).store_string(JSON.stringify({"completed":report,"current":{"map":theme,"race":race,"windows":windows},"failures":failures}))
			report.append({"map":theme,"race":race,"windows":windows})
	FileAccess.open("res://build/qa-v060/%s.json"%output,FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"failures":failures,"timing_scope":"concurrent stability load; not player FPS" if OS.get_environment("ASTERA_STRESS_CONCURRENT")=="1" else "headless simulation"},"  "))
	print("LONG_BATTLE_V060 ",JSON.stringify({"cases":report.size(),"minutes_each":ticks*DT*4/60,"failures":failures}));quit(0 if failures.is_empty() else 1)
