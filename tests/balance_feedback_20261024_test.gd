extends SceneTree
var changes=[]
var reports=[]
func _initialize():call_deferred("run")
func cost(d):return (float(d.as)+float(d.tera)*1.5)/maxf(1,float(d.get("production_count",1)))
func apply_phase(phase):
	for change in changes:
		var d=ACData.unit(int(change.race),int(change.kind))
		for field in change.changes:d[field]=change.changes[field][phase]
func battle(a: Array,b: Array,phase: String,role: String):
	var budget=2400 if role=="fighter" else 1800 if role=="siege" else 1200
	var c=ACCore.new();c.setup({"map":0,"seed":825,"players":[{"race":a[0]},{"race":b[0]}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.height_map.fill(0);c._sync_resource_obstacles();c.map.reset_solids([]);c.collision_index_valid=false
	c.add_building(0,0,Vector2(8,8),true);c.add_building(1,0,Vector2(112,112),true);c.map.reset_solids(c.buildings)
	var counts=[];var combat_ids={}
	for owner in range(2):
		var spec=a if owner==0 else b;var d=ACData.unit(spec[0],spec[1]);var count=maxi(1,floori(budget/cost(d)));counts.append(count)
		for index in range(count):
			var u=c.add_unit(owner,spec[1],Vector2((54+index%4*.9) if owner==0 else (73-index%4*.9),58+(index/4)*.9));u.order="attack_move";u.goal=[71 if owner==0 else 57,63];combat_ids[int(u.id)]=true
	var remaining=[0,0];var elapsed=0.0
	for tick in range(1200):
		c.step(.05);elapsed+=.05;remaining=[0,0]
		for unit in c.units:
			if unit.hp>0 and combat_ids.has(int(unit.id)):remaining[unit.owner]+=1
		if remaining[0]==0 or remaining[1]==0:break
	var health=[0.0,0.0]
	for u in c.units:
		if u.hp>0 and combat_ids.has(int(u.id)):health[u.owner]+=u.hp+u.shield
	return {"phase":phase,"role":role,"budget":budget,"a":a,"b":b,"counts":counts,"remaining":remaining,"health":health,"seconds":elapsed}
func run():
	changes=JSON.parse_string(FileAccess.get_file_as_string("res://docs/balance-adjustments-20261024.json")).changes
	for phase in ["before","after"]:
		apply_phase(phase)
		for group in [{"role":"basic ranged","kinds":[1,2,2]},{"role":"basic melee","kinds":[2,1,1]},{"role":"siege","kinds":[5,6,8]},{"role":"fighter","kinds":[9,10,9]}]:
			for pair in [[0,1],[1,2],[2,0]]:reports.append(battle([pair[0],group.kinds[pair[0]]],[pair[1],group.kinds[pair[1]]],phase,group.role))
		print("BALANCE_PHASE_DONE ",phase)
	var audit=[]
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			var d=ACData.unit(race,kind);var burst=1 if d.get("burst_split_total",false) else int(d.get("burst_count",1))
			audit.append({"race":race,"kind":kind,"name":d.name,"role":d.role,"as":d.as,"tera":d.tera,"effective_cost_per_body":cost(d),"population":d.pop,"hp":d.hp,"shield":d.shield,"armor":d.armor,"damage":d.damage,"period":d.period,"sustained_dps_before_armor":float(d.damage)*burst/maxf(.01,float(d.period)),"range":d.range,"speed":d.speed,"targets":d.targets,"abilities":ACAbilities.catalog(race,kind).map(func(skill):return skill.id),"splash_radius":d.get("splash_radius",0),"bonus_heavy":d.get("bonus_heavy",0),"bonus_light":d.get("bonus_light",0)})
	var output={"scope":"Equal resource budgets1200 infantry/1800 siege/2400 fighter; gas weighted1.5; real production count; four roles; only initial combat bodies counted; no spell micro. First-pass regression, not final competitive balance.","duels":reports,"all_units":audit}
	FileAccess.open("res://build/player_colors_20261024/balance.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("BALANCE_AUDIT units=",audit.size()," duels=",reports.size());quit()
