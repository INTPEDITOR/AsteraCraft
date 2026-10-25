extends SceneTree
var records=[]
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args();var race=int(args[0]) if not args.is_empty() else 0;var seed_value=int(args[1]) if args.size()>1 else 726
	var swap=args.size()>2 and args[2]=="swap"
	var solo=args.size()>3 and args[3]=="solo"
	var c=ACCore.new();c.setup({"map":0,"seed":seed_value,"spawn_slots":[2,0] if swap else [0,2],"players":[{"race":race,"bot":true,"difficulty":5},{"race":race,"bot":true,"difficulty":4}]})
	var first=[-1.0,-1.0];var peak=0;var times=[];var started=Time.get_ticks_msec();var worst={};var checkpoints=[]
	for tick in range(6000):
		var prior=c.perf.duplicate();var t=Time.get_ticks_usec();c.step(.1);var elapsed=Time.get_ticks_usec()-t;times.append(elapsed)
		if elapsed>int(worst.get("us",0)):
			worst={"us":elapsed,"time":c.time,"phases":{}}
			for key in ["building_us","unit_us","collision_us","cleanup_us","vision_us","ai_us"]:worst.phases[key]=c.perf[key]-prior[key]
		peak=maxi(peak,c.units.size())
		for owner in range(2):
			if first[owner]<0 and c.players[owner].get("_ai_has_attacked",false):first[owner]=c.time
		if tick%1000==0:print("MATCH_PROGRESS ",race,"/",seed_value," t=",c.time," armies=",c.units.size()," plans=",c.players.map(func(p):return p.get("_ai_tactic","")))
		if tick%1000==0:checkpoints.append({"time":c.time,"players":c.players.map(func(p):return {"plan":p.get("_ai_tactic",""),"phase":p.get("_ai_attack_phase",""),"wave":p.get("_ai_wave",[]).size(),"stage":p.get("_ai_stage_pos",[]),"resources":[p.as,p.tera],"reserve":p.get("_ai_tech_reserve",[])})})
		if c.ended:break
	times.sort();var people=[]
	for owner in range(2):
		var p=c.players[owner];var units=c.units.filter(func(u):return u.hp>0 and int(u.owner)==owner and not u.get("technical",false))
		people.append({"level":p.difficulty,"lost":p.lost,"army":units.filter(func(u):return int(u.kind)>0).size(),"workers":units.filter(func(u):return int(u.kind)==0).size(),"kills":p.kills,"spent":p.spent,"gathered":p.gathered,"first_attack":first[owner],"first_enemy_seen":p.get("_ai_first_enemy_seen",-1),"plans":p.get("_ai_tactic_history",[]),"actions":p.get("_ai_tactic_actions",{}),"resources":[p.as,p.tera],"buildings":c.buildings.filter(func(b):return b.hp>0 and int(b.owner)==owner).size()})
	var result={"race":race,"seed":seed_value,"swapped_spawns":swap,"seconds":c.time,"ended":c.ended,"winners":c.winners,"players":people,"peak_units":peak,"p95_step_ms":float(times[floori(times.size()*.95)])/1000,"max_step_ms":float(times[-1])/1000,"worst_step":worst,"checkpoints":checkpoints,"wall_seconds":float(Time.get_ticks_msec()-started)/1000,"scope":"Actual unmodified starting economy, native map, Hell versus Very Hard mirror. No extra units/resources/tech or omniscient scouting."}
	result.final_assembly=[]
	result.economy=c.players.map(func(p):return {"owner":p.id if p.has("id") else c.players.find(p),"supply":[p.used,p.reserved,p.cap],"reserve":p.get("_ai_tech_reserve",[]),"buildings":c.buildings.filter(func(b):return int(b.owner)==c.players.find(p)).map(func(b):return {"kind":b.kind,"hp":b.hp,"progress":b.progress,"larva":b.larva,"queue":b.queue,"pos":b.pos}),"workers":c.units.filter(func(u):return int(u.owner)==c.players.find(p) and int(u.kind)==0).map(func(u):return {"order":u.order,"pos":u.pos,"plan":u.get("build_plan",{})})})
	for owner in range(2):
		var p=c.players[owner]
		result.final_assembly.append({"cohort":p.get("_ai_cohort",[]),"wave":p.get("_ai_wave",[]),"scout":p.get("_ai_scout",-1),"guards":p.get("_ai_garrison",[]),"stage":p.get("_ai_stage_pos",[]),"units":c.units.filter(func(u):return int(u.owner)==owner and int(u.kind)>0 and not u.get("technical",false)).map(func(u):return {"id":u.id,"kind":u.kind,"pos":u.pos,"goal":u.goal,"order":u.order,"blocked":u.blocked_clock,"slot":p.get("_ai_stage_slots",{}).get(int(u.id),{}),"failed":u.path_failed,"container":u.container})})
	DirAccess.make_dir_recursive_absolute("res://build/ai-tactics-20261026")
	FileAccess.open("res://build/ai-tactics-20261026/match-%d-%d%s%s.json"%[race,seed_value,"-swap" if swap else "","-solo" if solo else ""],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_MATCH ",JSON.stringify({"race":race,"swapped":swap,"seconds":c.time,"players":people,"max_step_ms":result.max_step_ms}));quit()
