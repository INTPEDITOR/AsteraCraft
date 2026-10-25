extends "res://tests/abilities_v060_test.gd"

var adjustments: Array=[]
var records: Array=[]
var cadences: Array=[]
var output="res://build/melee-balance-20261025/"

func phase_values(phase: String) -> void:
	for entry in adjustments:ACData.unit(int(entry.race),int(entry.kind)).period=float(entry[phase])
	ACData._effective_units.clear()

func clean_arena(race: int, enemy: int):
	var c=arena(race,enemy)
	c.map.source_walk_masks.clear();c.map.source_water_masks.clear();c.map.height_map.fill(0)
	c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	for fog in c.visibility:fog.fill(2)
	return c

func cadence(entry: Dictionary, phase: String, mode: String, dt: float) -> Dictionary:
	var race=int(entry.race);var kind=int(entry.kind)
	var c=clean_arena(race,(race+1)%3);c.time=10
	if mode=="research":c.players[0].technologies.claw_overdrive=1
	var attacker=c.add_unit(0,kind,Vector2(55,55))
	var victim=c.add_unit(1,0,Vector2(55.7,55))
	victim.pos=ACData.packed(Vector2(55,55)+Vector2((c._body_size(attacker).x+c._body_size(victim).x)*.5+.06,0))
	victim.hp=100000;victim.shield=0;victim.order="hold"
	attacker.order="attack";attacker.target=victim.id
	if mode=="stim":attacker.stim_until=1000
	if mode=="bloom":attacker.bloom_until=1000
	if mode=="research_bloom":
		c.players[0].technologies.claw_overdrive=1
		attacker._definition=ACData.unit_for_player(race,kind,c.players[0])
		attacker.bloom_until=1000
	if mode=="slowed":attacker.attack_slow_until=1000
	var expected=float(c.unit_data(attacker).period)
	if mode=="stim":expected*=.75
	if mode in ["bloom","research_bloom"]:expected/=1.25
	if mode=="slowed":expected*=1.4
	var times=[];var origin=ACData.point(attacker.pos)
	for tick in range(ceili(12.0/dt)):
		c.time+=dt
		var fired=float(attacker.fired)
		c._tick_unit(attacker,dt)
		if float(attacker.fired)!=fired:times.append(c.time)
	var shortest=100.0;var longest=0.0
	for index in range(1,times.size()):
		var interval=float(times[index])-float(times[index-1])
		shortest=minf(shortest,interval);longest=maxf(longest,interval)
	check(times.size()>=3,"repeated real melee strikes %s %s %s"%[entry.name,phase,mode])
	check(shortest>=expected-.0001 and longest<=expected+dt+.0001,"cooldown respected including tick rounding %s %s %s"%[entry.name,phase,mode])
	check(ACData.point(attacker.pos).distance_to(origin)<.001,"stationary contact does not drag attacker "+str(entry.name))
	return {"race":race,"kind":kind,"phase":phase,"mode":mode,"dt":dt,"strikes":times.size(),"expected_interval":expected,"min_interval":shortest,"max_interval":longest,"damage":100000-victim.hp}

func weighted_cost(d: Dictionary) -> float:
	return (float(d.as)+float(d.tera)*1.5)/maxf(1,float(d.get("production_count",1)))

func battle(spec: Dictionary,phase: String,reverse: bool) -> Dictionary:
	var a: Array=spec.a;var b: Array=spec.b
	var c=clean_arena(int(a[0]),int(b[0]));c.time=10
	c.add_building(0,0,Vector2(8,8),true);c.add_building(1,0,Vector2(112,112),true)
	c.map.reset_solids(c.buildings)
	# Explicitly detected combat, using the same reveal representation as scan.
	for owner in range(2):c.reveals.append({"owner":owner,"pos":[61,58],"until":1000,"radius":30,"detect":true})
	var counts=[];var initial_health=[0.0,0.0];var combat_ids={}
	for owner in range(2):
		var unit_spec=a if owner==0 else b
		var d=ACData.unit(int(unit_spec[0]),int(unit_spec[1]));var count=maxi(1,floori(600.0/weighted_cost(d)))
		counts.append(count)
		var side=1-owner if reverse else owner
		var columns=mini(4,maxi(1,ceili(sqrt(float(count)))))
		var rows=ceili(float(count)/columns)
		for index in range(count):
			var position=Vector2((54-index%columns*1.25) if side==0 else (68+index%columns*1.25),57+(floori(float(index)/columns)-(rows-1)*.5)*1.25)
			var u=c.add_unit(owner,int(unit_spec[1]),position)
			combat_ids[int(u.id)]=true
			u.order="attack_move";u.goal=[71 if side==0 else 51,57]
			initial_health[owner]+=u.hp+u.shield
	var remaining=[0,0];var elapsed=0.0;var attacked=[false,false];var travelled=[false,false]
	for tick in range(800):
		c.step(.05);elapsed+=.05;remaining=[0,0]
		for u in c.units:
			if not combat_ids.has(int(u.id)):continue
			if u.hp>0:remaining[int(u.owner)]+=1
			if float(u.get("_last_attack_time",-99))>=10:attacked[int(u.owner)]=true
			if u.get("moving",false):travelled[int(u.owner)]=true
		if remaining[0]==0 or remaining[1]==0:break
	var health=[0.0,0.0]
	for u in c.units:
		if not combat_ids.has(int(u.id)):continue
		if u.hp>0:health[int(u.owner)]+=u.hp+u.shield
	check(attacked[0] and attacked[1],"both armies actually attack %s %s %s"%[spec.label,phase,reverse])
	check(travelled[0] and travelled[1],"both armies actually approach %s %s %s"%[spec.label,phase,reverse])
	return {"case":spec.label,"phase":phase,"reverse":reverse,"a":a,"b":b,"counts":counts,"remaining":remaining,"initial_health":initial_health,"health":health,"seconds":elapsed,"attacked":attacked,"travelled":travelled}

func run() -> void:
	adjustments=JSON.parse_string(FileAccess.get_file_as_string("res://docs/melee-balance-20261025.json")).changes
	var native=ACData.get_data().duplicate(true)
	for entry in adjustments:
		var d=ACData.unit(int(entry.race),int(entry.kind))
		check(is_equal_approx(float(d.period),float(entry.after)),"shipping source uses new period "+str(entry.name))
		check(float(entry.after)<float(entry.before),"all seven melee attack intervals shortened "+str(entry.name))
		check(float(d.range)<=1.5 and d.role not in ["worker","suicide"],"only repeat-attack melee eligible "+str(entry.name))
	var cases=[
		{"label":"assault-v-rifle","a":[0,2],"b":[0,1]},
		{"label":"shield-v-rifle","a":[0,3],"b":[0,1]},
		{"label":"claw-v-rifle","a":[1,1],"b":[0,1]},
		{"label":"heavy-v-archer","a":[1,3],"b":[2,2]},
		{"label":"guardian-v-archer","a":[2,1],"b":[2,2]},
		{"label":"stealth-v-missile-detected","a":[2,10],"b":[0,6]},
		{"label":"caster-v-worker-detected","a":[1,8],"b":[0,0]},
		{"label":"assault-v-claw","a":[0,2],"b":[1,1]},
		{"label":"claw-v-guardian","a":[1,1],"b":[2,1]},
		{"label":"guardian-v-assault","a":[2,1],"b":[0,2]},
		{"label":"shield-v-heavy","a":[0,3],"b":[1,3]},
		{"label":"shield-v-guardian","a":[0,3],"b":[2,1]}
	]
	for phase in ["before","after"]:
		phase_values(phase)
		for entry in adjustments:
			for dt in [.05,.1]:cadences.append(cadence(entry,phase,"base",dt))
			cadences.append(cadence(entry,phase,"slowed",.05))
			if int(entry.race)==0 and int(entry.kind)==2:cadences.append(cadence(entry,phase,"stim",.05))
			if int(entry.race)==1:
				cadences.append(cadence(entry,phase,"bloom",.05))
				if int(entry.kind)==1:
					cadences.append(cadence(entry,phase,"research",.05));cadences.append(cadence(entry,phase,"research_bloom",.05))
		for spec in cases:
			for reverse in [false,true]:records.append(battle(spec,phase,reverse))
		print("MELEE_BALANCE_PHASE ",phase," battles=",records.size())
	phase_values("after")
	for old in cadences:
		if old.phase!="before":continue
		var pair=cadences.filter(func(item):return item.phase=="after" and item.race==old.race and item.kind==old.kind and item.mode==old.mode and item.dt==old.dt)
		check(pair.size()==1 and pair[0].strikes>old.strikes,"actual hit count improves %d:%d %s dt=%s"%[old.race,old.kind,old.mode,old.dt])
	check(ACData.get_data()==native,"test restores all production data and research")
	DirAccess.make_dir_recursive_absolute(output)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real attacks for 7 units, including stim/research/bloom/slow and 50/100ms ticks. 48 equal-resource 600-budget field duels with reversed deployment. No spell micro or macro/economy balance claim.","cadences":cadences,"battles":records}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MELEE_BALANCE ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures,"battles":records.size(),"cadences":cadences.size()}))
	quit(0 if failures.is_empty() else 1)
