extends "res://tests/abilities_v060_test.gd"
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
const M=preload("res://scripts/bot_missions.gd")
const S=preload("res://scripts/bot_skills.gd")
var records=[]

func world(race: int,allied: bool=false):
	var c=arena(race,0)
	if allied:
		c=ACCore.new();c.setup({"map":0,"mode":"teams","players":[{"race":race,"team":0},{"race":0,"team":1},{"race":0,"team":0}]})
		c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c._sync_resource_obstacles()
	c.map.source_detail_active=false;c.map.source_walk_masks.clear();c.map.source_water_masks.clear();c.map.height_map.fill(0);c.map.buildable_map.fill(1);c.map.reset_solids([])
	var home=c.add_building(0,0,Vector2(12,38),true);c.players[0].home=home.id;c.players[0].difficulty=5;c.players[0].bot=false
	var enemy=c.add_building(1,0,Vector2(76,38),true);enemy.hp=100000
	if allied:c.add_building(2,0,Vector2(12,100),true)
	c.map.reset_solids(c.buildings);c.collision_index_valid=false;c.time=600;c.ai_clock=100000
	c.players[0].as=0;c.players[0].tera=0
	c.players[0].technologies={};c.players[0].nukes=0
	c.reveals=[{"owner":0,"pos":[78,40],"until":10000,"radius":16,"detect":true}]
	c._update_vision();return {"c":c,"home":home,"enemy":enemy}

func visible(c) -> Array:
	return (c.units+c.buildings).filter(func(e):return e.hp>0 and int(e.owner)!=0 and c.can_see(0,e))

func drop_trial(race: int,id: String,kind: int) -> void:
	var a=world(race);var c=a.c;var p=c.players[0];var plan=T.activate(c,0,id)
	var carrier=c.add_unit(0,int(plan.transport),Vector2(22,44));var units=[carrier]
	for index in range(2):units.append(c.add_unit(0,kind,Vector2(21+index*2,46)))
	var money=Vector2(p.as,p.tera);var ground_ok=true
	for step in range(1300):
		var seen=visible(c);T.observe(c,0,seen)
		M.before_combat(c,0,units,plan,c.center(a.home),c.center(a.enemy),seen,false)
		c.step(.1)
		for u in units:
			if u.hp>0 and not c.unit_data(u).air and u.container<0:ground_ok=ground_ok and c._ground_fits_size(c._body_size(u),c.center(u))
		if int(p.get("_ai_tactic_actions",{}).get("drop:return",0))>0:break
	var actions=p.get("_ai_tactic_actions",{})
	if actions.is_empty():print("DROP_DEBUG ",id," plan=",plan," memory=",p.get("_ai_sightings",{})," carrier=",carrier.pos," members=",units.map(func(u):return [u.kind,u.hp,u.pos,u.container])," ended=",c.ended)
	for phase in ["prepare","launch","unload","extract","return"]:check(int(actions.get("drop:"+phase,0))>0,"physical drop lifecycle %s %s"%[id,phase])
	check(ground_ok,"payload never unloads on illegal ground "+id)
	check(carrier.cargo.is_empty() and units.slice(1).all(func(u):return int(u.container)<0),"living passengers returned and unloaded "+id)
	check(Vector2(p.as,p.tera)==money,"mission execution grants no resources "+id)
	records.append({"id":id,"time":c.time-600,"actions":actions,"passable":ground_ok})

func run() -> void:
	for plan in T.catalog():
		if plan.drop:drop_trial(int(plan.race),str(plan.id),int(plan.payload[0]))
	var a=world(0);var c=a.c;var p=c.players[0];T.activate(c,0,"N21")
	p.technologies.nuclear=1;p.nukes=1
	var scout=c.add_unit(0,7,Vector2(67,40));scout.energy=200
	var friend=c.add_unit(0,1,Vector2(76,43));var enemy=c.add_unit(1,1,Vector2(78,42))
	enemy.order="hold";enemy.anchored=true;enemy.cooldown=100000
	var army=[scout,friend];c._update_vision()
	var reserved=M.nuclear(c,0,army,c.center(a.home),c.center(a.enemy),visible(c),false)
	check(p.nukes==1 and friend.order=="move" and scout.id in reserved,"nuclear waits for actual friendly evacuation and reserves guide")
	for step in range(160):
		c.step(.1);M.nuclear(c,0,army,c.center(a.home),c.center(a.enemy),visible(c),false)
		if int(p.get("_ai_tactic_actions",{}).get("nuclear:launch",0))>0:break
	check(p.nukes==0 and not scout.channel.is_empty(),"nuclear uses a real paid-stock missile after evacuation")
	if p.nukes>0:print("NUCLEAR_DEBUG stock=",p.nukes," caster=",scout.pos," friend=",friend.pos," pending=",p.get("_ai_nuclear_until",0)," time=",c.time," visible=",visible(c).map(func(e):return e.id))
	var before=a.enemy.hp
	for step in range(200):c.step(.1);M.nuclear(c,0,army,c.center(a.home),c.center(a.enemy),visible(c),false)
	check(a.enemy.hp<before and friend.hp>0,"real nuclear impact damages enemy while evacuated friend lives")
	# The planner cannot move another human/AI owner's units to clear its shot.
	a=world(0,true);c=a.c;p=c.players[0];p.technologies.nuclear=1;p.nukes=1
	scout=c.add_unit(0,7,Vector2(67,40));var other=c.add_unit(2,1,Vector2(77,43));var original=other.order
	c.add_unit(1,1,Vector2(78,42));c._update_vision()
	M.nuclear(c,0,[scout],c.center(a.home),c.center(a.enemy),visible(c),false)
	check(other.order==original and p.nukes==1,"allied owner retains control; unsafe nuclear shot is withheld")
	# Actual autonomous skill calls use research, mana, legal targets and cooldowns.
	a=world(1);c=a.c;p=c.players[0];p.technologies.mind_control=1
	var caster=c.add_unit(0,8,Vector2(50,50));caster.energy=200
	var victim=c.add_unit(1,12,Vector2(54,50));c.reveals.append({"owner":0,"pos":[54,50],"until":10000,"radius":8,"detect":true});c._update_vision()
	S.tick(c,0,[caster],visible(c),T.by_id.E15,true,c.center(victim))
	check(int(victim.owner)==0 and caster.energy==0,"AI mind control performs real ownership conversion and mana payment")
	a=world(2);c=a.c;p=c.players[0]
	caster=c.add_unit(0,5,Vector2(50,50));caster.energy=200
	for index in range(3):c.add_unit(1,1,Vector2(54+index*.7,50))
	c.reveals.append({"owner":0,"pos":[54,50],"until":10000,"radius":8,"detect":true});c._update_vision()
	S.tick(c,0,[caster],visible(c),T.by_id.A11,true,Vector2(54,50))
	check(not c.ability_events.is_empty() and caster.energy<200,"AI area spell spends mana and uses actual delayed event")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/ai-tactics-20261026")
	FileAccess.open("res://build/ai-tactics-20261026/missions.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_MISSIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
