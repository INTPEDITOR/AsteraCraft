extends RefCounted
## Local historical priors. New scouting/macro/raiding policy revision in progress.
## No network or hidden opponent inspection.
static var results: Dictionary={}

static func observed_race(c,owner: int) -> int:
	var totals={}
	for item in c.players[owner].get("_ai_sightings",{}).values():
		if c.allied(owner,int(item.owner)):continue
		var race=int(item.race)
		totals[race]=float(totals.get(race,0))+(8.0 if item.building and int(item.kind)==0 else maxf(1,float(item.get("pop",0))))
	var best=-1;var amount=0.0
	for race in totals:
		if float(totals[race])>amount:best=int(race);amount=float(totals[race])
	if best<0:
		for enemy in c.players[owner].get("_ai_confirmed_races",{}):
			if not c.allied(owner,int(enemy)):return int(c.players[owner]._ai_confirmed_races[enemy])
	return best

static func historical_factor(race: int,foe: int,id: String) -> float:
	if results.is_empty():results=JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_tactic_results_20261026.json"))
	var baseline: Dictionary=results.get("matchups",{}).get(str(race)+":"+str(foe),{})
	var entry: Dictionary=results.get("plans",{}).get(id+":"+str(foe),{})
	if baseline.is_empty() or entry.is_empty():return 1.0
	# Eight pseudo-games temper historical and pre-nerf small samples. Compare
	# with this faction's matchup baseline, not an assumed fifty-percent rate.
	var rate=(float(baseline.wins)+2.0)/(float(baseline.games)+4.0)
	var posterior=(float(entry.wins)+rate*8.0)/(float(entry.games)+8.0)
	return clampf(1.0+(posterior-rate)*3.0,.65,1.8)

static func preferred(race: int,foe: int,id: String) -> bool:
	if race!=0:return false
	return id in (["N1","N2","N4","N5"] if foe==1 else ["N7","N8","N9"] if foe==2 else [])

static func weight(c,owner: int,plan: Dictionary) -> float:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<2:return 1.0
	var foe=observed_race(c,owner)
	if foe<0:return 1.0
	var factor=historical_factor(int(p.race),foe,str(plan.id))
	if c.time<480:
		if int(p.race)==0 and foe in [1,2]:factor*=3.5 if preferred(0,foe,str(plan.id)) else .8
		if int(p.race)==1:
			var opening=["E5","E6","E10","E11","E13","E14"] if foe==0 else ["E3","E8","E9","E14","E22"]
			factor*=2.2 if str(plan.id) in opening else .9
	# Technology opens alternatives; it never mandates abandoning a successful
	# opening or blindly buying a capital ship on an impoverished single base.
	var bases=c.buildings.filter(func(b):return int(b.owner)==owner and b.hp>0 and int(b.kind)==0 and b.progress>=1).size()
	if c.time>=480 and bases>=2 and float(p.as)>=250 and float(p.tera)>=100 and int(plan.stage)>=2:factor*=2.2
	var repeats=p.get("_ai_tactic_history",[]).slice(-4).filter(func(item):return str(item.id)==str(plan.id)).size()
	factor*=pow(.75,repeats)
	return factor

static func basic_transition(c,owner: int,army: Array) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.race)!=0 or int(p.difficulty)<2 or c.time<90 or not observed_race(c,owner) in [1,2]:return false
	var workers=c.units.filter(func(u):return int(u.owner)==owner and u.hp>0 and int(u.kind)==0).size()
	var population=army.reduce(func(sum,u):return sum+(float(c.unit_data(u).pop) if float(c.unit_data(u).damage)>0 else 0),0.0)
	return workers>=8 and population>=3

static func composition(c,owner: int,source: Dictionary) -> Dictionary:
	var p: Dictionary=c.players[owner];var foe=observed_race(c,owner)
	if source.is_empty() or int(p.difficulty)<2 or c.time<90 or c.time>=480:return source
	if int(p.race)==1 and foe in [0,2] and not source.drop:
		var citrus=source.duplicate(true)
		citrus.primary=[3,4,6] if foe==0 else [7,2,6]
		citrus.support=[1,10,2,9] if foe==0 else [3,4,1,10,9]
		citrus.weights={"3":7,"4":2,"6":5,"1":3,"10":6,"2":3,"9":.7} if foe==0 else {"7":8,"2":8,"6":7,"3":2,"4":1.5,"1":2,"10":1.5,"9":.7}
		citrus._ai_opening_matchup=foe
		return citrus
	if int(p.race)!=0 or not foe in [1,2]:return source
	if source.drop or not str(source.style) in ["line","rush","mobile","raid","siege","expand","counter_air"]:return source
	var plan=source.duplicate(true)
	plan.primary=[1] if foe==1 else [5,6,13]
	plan.support=[4,3,2,13,5,8] if foe==1 else [1,4,8]
	plan.weights={"1":8,"4":3,"3":1.8,"2":.9,"5":3.5,"13":3,"8":.5} if foe==1 else {"5":9,"6":7,"13":6,"1":.6,"4":.8,"8":.6}
	plan._ai_matchup=foe
	if foe==1:plan._ai_bio=true;plan._ai_opening_matchup=foe
	else:plan._ai_mech=true
	return plan
