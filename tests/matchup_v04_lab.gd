extends SceneTree
## Controlled combat laboratory. These prebuilt armies are experimental
## fixtures, not a recording of normal economic play or a ranked balance test.

const BUDGET_AS=1200
const BUDGET_TERA=400
const SEEDS=[713,2713,6713]
const RECIPES={
	"combined_arms":[[3,1,1,6],[3,2,2,1],[1,2,3]],
	"melee_rush":[[2,2,3],[1,1,4],[1,1,10]],
	"heavy":[[12,5,1],[12,3,1],[7,8,1]]
}
const FRONTS={
	"combined_arms":[[3],[1,3],[1]],
	"melee_rush":[[2,3],[1,4],[1,10]],
	"heavy":[[12,1],[3,1],[7,1]]
}
var failures: Array=[]
var checks=0

func _initialize() -> void:call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)

func arena(left_race: int, right_race: int, seed: int) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":seed,"spawn_slots":[0,2],"players":[{"race":left_race},{"race":right_race}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear()
	c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c._sync_resource_obstacles();c.map.reset_solids([])
	for owner in range(2):
		var base=Vector2(7,7) if owner==0 else Vector2(112,110)
		c.players[owner].home=c.add_building(owner,0,base,true).id
		for index in range(4):c.add_building(owner,2,base+Vector2((index%2)*5,5+int(index/2)*4),true)
		c.players[owner].as=BUDGET_AS;c.players[owner].tera=BUDGET_TERA
	c.map.reset_solids(c.buildings);c._recalculate_supply()
	return c

func roster(race: int, scenario: String) -> Dictionary:
	var counts={}
	var remaining_as=BUDGET_AS
	var remaining_tera=BUDGET_TERA
	while true:
		var bought=false
		for kind in RECIPES[scenario][race]:
			var d=ACData.unit(race,int(kind))
			if d.as<=remaining_as and d.tera<=remaining_tera:
				remaining_as-=d.as;remaining_tera-=d.tera
				counts[int(kind)]=int(counts.get(int(kind),0))+1
				bought=true
		if not bought:break
	var kinds: Array=[]
	var rows: Array=[]
	var hp=0.0;var shield=0.0;var pop=0.0
	for kind in counts:
		var d=ACData.unit(race,int(kind))
		var count=int(counts[kind])
		for _unit in range(count):kinds.append(int(kind))
		hp+=d.hp*count;shield+=d.shield*count;pop+=d.pop*count
		rows.append({"kind":kind,"name":d.name,"count":count,"as":d.as,"tera":d.tera,"pop":d.pop,"damage":d.damage,"range":d.range,"period":d.period,"speed":d.speed,"targets":d.targets,"air":d.air,"role":d.role})
	kinds.sort_custom(func(a,b):return (0 if a in FRONTS[scenario][race] else 1)<(0 if b in FRONTS[scenario][race] else 1))
	return {"race":race,"kinds":kinds,"units":rows,"count":kinds.size(),"spent_as":BUDGET_AS-remaining_as,"spent_tera":BUDGET_TERA-remaining_tera,"unused_as":remaining_as,"unused_tera":remaining_tera,"population":pop,"initial_hp":hp,"initial_shield":shield}

func spawn(c: ACCore, owner: int, plan: Dictionary, seed: int) -> Array:
	var random=RandomNumberGenerator.new()
	random.seed=seed*101+int(plan.race)*17
	var ids: Array=[]
	var rows=mini(8,plan.kinds.size())
	for index in range(plan.kinds.size()):
		var kind=int(plan.kinds[index])
		var d=ACData.unit(int(plan.race),kind)
		var direction=1.0 if owner==0 else -1.0
		var origin=Vector2(50,64) if owner==0 else Vector2(78,64)
		var position=origin+Vector2(-direction*int(index/rows)*2.2,(index%rows-(rows-1)*.5)*2.2)
		position+=Vector2(direction*random.randf_range(-.08,.08),random.randf_range(-.08,.08))
		check(c.pay(owner,d.as,d.tera),"experimental army pays its declared resource budget")
		ids.append(c.add_unit(owner,kind,position).id)
	return ids

func surviving(c: ACCore, owner: int) -> Dictionary:
	var result={"count":0,"hp":0.0,"shield":0.0,"as":0.0,"tera":0.0,"population":0.0,"by_kind":{}}
	for u in c.units:
		if u.owner!=owner or u.hp<=0 or u.get("technical",false):continue
		var d=ACData.unit(int(u.race),int(u.kind))
		result.count+=1;result.hp+=u.hp;result.shield+=u.shield
		result.as+=d.as;result.tera+=d.tera;result.population+=d.pop
		result.by_kind[str(int(u.kind))]=int(result.by_kind.get(str(int(u.kind)),0))+1
	return result

func terminal_contact(c: ACCore) -> Dictionary:
	var units=c.units.filter(func(u):return u.hp>0 and not u.get("technical",false))
	var closest=INF
	var visible=false
	for left in units:
		if int(left.owner)!=0:continue
		for right in units:
			if int(right.owner)!=1:continue
			closest=minf(closest,c.center(left).distance_to(c.center(right)))
			visible=visible or c.can_see(0,right) or c.can_see(1,left)
	var rows: Array=[]
	for unit in units:rows.append({"owner":unit.owner,"race":unit.race,"kind":unit.kind,"pos":unit.pos,"order":unit.order,"target":unit.target,"fired":unit.fired,"hp":unit.hp,"shield":unit.shield})
	return {"nearest_opponents":closest if closest<INF else -1,"any_enemy_visible":visible,"classification":"separated_after_engagement" if closest>9 else ("undetected_contact" if not visible else "visible_contact_stalled"),"units":rows}

func battle(scenario: String, race_a: int, race_b: int, seed: int, swap: bool) -> Dictionary:
	var left=race_b if swap else race_a
	var right=race_a if swap else race_b
	var c=arena(left,right,seed)
	var plans=[roster(left,scenario),roster(right,scenario)]
	for owner in range(2):
		var ids=spawn(c,owner,plans[owner],seed)
		# Every army receives its order in legal selection groups of twelve.
		for offset in range(0,ids.size(),12):c.command(owner,{"type":"attack_move","ids":ids.slice(offset,offset+12),"pos":[78,64] if owner==0 else [50,64],"formation":true})
	c._recalculate_supply();c._update_vision()
	var shots=[0,0]
	var first=-1.0;var last=-1.0;var newest_effect=0
	var remaining=[surviving(c,0),surviving(c,1)]
	while c.time<90:
		c.step(.05);c.resolve_spells()
		for effect in c.effects:
			if int(effect.id)<=newest_effect:continue
			if effect.type in ["shot","explosion"] and int(effect.owner) in [0,1]:
				shots[int(effect.owner)]+=1
				if first<0:first=c.time
				last=c.time
		if not c.effects.is_empty():newest_effect=maxi(newest_effect,int(c.effects[-1].id))
		remaining=[surviving(c,0),surviving(c,1)]
		if remaining[0].count==0 or remaining[1].count==0:break
	var winner=-1
	if remaining[0].count>0 and remaining[1].count==0:winner=left
	elif remaining[1].count>0 and remaining[0].count==0:winner=right
	check(c.units.all(func(u):return ACData.point(u.pos).is_finite() and u.hp>=0 and u.energy>=0),"combat laboratory maintains finite nonnegative unit state")
	check(c.players.all(func(p):return p.as>=0 and p.tera>=0 and p.used<=200),"combat laboratory never overspends or exceeds 200 population")
	for plan in plans:plan.erase("kinds")
	return {"scenario":scenario,"pair":[race_a,race_b],"seed":seed,"swapped":swap,"left_race":left,"right_race":right,"budget_each":{"as":BUDGET_AS,"tera":BUDGET_TERA},"rosters":plans,"winner_race":winner,"outcome":"elimination" if winner>=0 else ("mutual_elimination" if remaining[0].count==0 and remaining[1].count==0 else "timeout"),"elapsed":snappedf(c.time,.05),"first_shot":snappedf(first,.05),"engagement_seconds":snappedf(c.time-first,.05) if first>=0 else 0,"shots":shots,"remaining":remaining,"no_fire_stall":shots[0]+shots[1]==0 and remaining[0].count>0 and remaining[1].count>0,"shotless_tail_seconds":snappedf(c.time-last,.05) if last>=0 else c.time,"terminal_contact":terminal_contact(c) if remaining[0].count>0 and remaining[1].count>0 else {}}

func movement_counter(escape: bool) -> Dictionary:
	var c=arena(0,1 if escape else 2,7171)
	var shooter=c.add_unit(0,1,Vector2(52,64))
	var d=ACData.unit(0,1)
	var evader=c.add_unit(1,1,Vector2(52+d.range+.15,64))
	var initial=c.center(shooter).distance_to(c.center(evader))
	c.command(1,{"type":"move","ids":[evader.id],"pos":[112,64]})
	c.command(0,{"type":"attack","ids":[shooter.id],"target":evader.id})
	c._update_vision()
	var first_range=-1.0;var first_time=-1.0
	for _step in range(200):
		c.step(.05)
		if first_range<0:
			for effect in c.effects:
				if effect.type=="shot" and int(effect.unit)==int(shooter.id):
					# The target moves later in the same tick. Measure the frozen
					# impact coordinates, not its post-movement snapshot position.
					first_range=ACData.point(effect.from).distance_to(ACData.point(effect.to));first_time=effect.started
					break
	var final=c.center(shooter).distance_to(c.center(evader))
	var expected=first_range<0 and final>initial if escape else first_range>float(d.base_range) and first_range<=float(d.range)+.02
	check(expected,"faster target escapes without a shot" if escape else "faster pursuer fires at its increased current weapon reach")
	return {"case":"faster_target_escape" if escape else "slower_target_chase","passed":expected,"shooter_speed":d.speed,"target_speed":ACData.unit(int(evader.race),int(evader.kind)).speed,"base_range":d.base_range,"current_range":d.range,"initial_distance":initial,"first_shot_range":first_range,"first_shot_time":first_time,"final_distance":final}

func aggregate(results: Array) -> Array:
	var groups={}
	for result in results:
		var key=result.scenario+":"+str(result.pair)
		if not groups.has(key):groups[key]={"scenario":result.scenario,"pair":result.pair,"games":0,"wins":{},"timeouts":0,"no_fire_stalls":0,"mean_engagement_seconds":0.0,"mean_remaining_hp":{}}
		var group=groups[key]
		group.games+=1;group.mean_engagement_seconds+=result.engagement_seconds
		if result.winner_race>=0:group.wins[str(result.winner_race)]=int(group.wins.get(str(result.winner_race),0))+1
		if result.outcome=="timeout":group.timeouts+=1
		if result.no_fire_stall:group.no_fire_stalls+=1
		for side in range(2):
			var race=str(result.left_race if side==0 else result.right_race)
			group.mean_remaining_hp[race]=float(group.mean_remaining_hp.get(race,0))+result.remaining[side].hp+result.remaining[side].shield
	var rows=groups.values()
	for row in rows:
		row.mean_engagement_seconds=snappedf(row.mean_engagement_seconds/row.games,.01)
		for race in row.mean_remaining_hp:row.mean_remaining_hp[race]=snappedf(row.mean_remaining_hp[race]/row.games,.01)
	return rows

func run() -> void:
	var began=Time.get_ticks_msec()
	if "--movement-only" in OS.get_cmdline_user_args():
		var counters=[movement_counter(false),movement_counter(true)]
		var output=FileAccess.open("res://build/matchup-v04-counters.json",FileAccess.WRITE)
		output.store_string(JSON.stringify({"movement_counters":counters,"checks":checks,"failures":failures},"  "));output.close()
		print("MATCHUP_MOVEMENT_COUNTERS ",JSON.stringify(counters)," failures=",failures.size())
		quit(0 if failures.is_empty() else 1);return
	var results: Array=[]
	for scenario in RECIPES:
		for pair in [[0,1],[0,2],[1,2]]:
			for seed in SEEDS:
				for swapped in [false,true]:results.append(battle(scenario,int(pair[0]),int(pair[1]),int(seed),swapped))
			print("MATCHUP_PROGRESS ",scenario," ",pair," games=",results.size())
			await process_frame
	var counters=[movement_counter(false),movement_counter(true)]
	var report={"schema":1,"fixture_experiment":true,"normal_economic_play":false,"description":"Prebuilt, fully supplied armies bought with identical As/Tera caps; building/technology costs excluded; ordinary authoritative movement, collision, fog and weapon attacks; passive abilities apply, manual Q abilities are not scripted.","limitations":["Three seeds with side swaps measure these roster fixtures, not a global faction win rate.","Different rosters may leave different unspent resources; actual costs and population are reported for every side.","Counters, armor, area attacks and stealth are intentional matchup differences; no tuning is inferred from one scenario."],"seeds":SEEDS,"budget_each":{"as":BUDGET_AS,"tera":BUDGET_TERA},"scenarios":RECIPES.keys(),"games":results.size(),"aggregate":aggregate(results),"movement_counters":counters,"results":results,"checks":checks,"failures":failures,"wall_seconds":(Time.get_ticks_msec()-began)*.001,"data_sha256":FileAccess.get_sha256("res://data/game.json"),"core_sha256":FileAccess.get_sha256("res://scripts/core.gd")}
	var output=FileAccess.open("res://build/matchup-v04-lab.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "));output.close()
	print("MATCHUP_V04_LAB games=",results.size()," checks=",checks," failures=",failures.size()," wall=",report.wall_seconds)
	for row in report.aggregate:print("MATCHUP_ROW ",JSON.stringify(row))
	quit(0 if failures.is_empty() else 1)
