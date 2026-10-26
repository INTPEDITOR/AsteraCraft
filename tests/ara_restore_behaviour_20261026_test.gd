extends "res://tests/two_workers_per_as_20261026_test.gd"
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
const P=preload("res://scripts/bot_ara_policy.gd")
const M=preload("res://scripts/bot_missions.gd")
func run():
	check(ACData.unit(2,10).as==275 and ACData.unit(2,10).tera==200 and ACData.unit(2,10).hp==80 and ACData.unit(2,10).shield==55,"approved stealth price partly restores while durability stays unchanged")
	check(ACData.unit(2,1).hp==100 and ACData.unit(2,1).shield==40 and ACData.unit(2,1).damage==13,"only guardian health restores")
	check(ACData.unit(2,2).damage==21 and ACData.unit(2,2).period==1.6 and ACData.unit(2,2).hp==75 and ACData.unit(2,2).shield==40,"only archer attack restores while its period and durability stay unchanged")
	var c=fixture(2);var p=c.players[0];c.time=300;p.as=3000;p.tera=2000
	var tower=c.add_building(0,2,Vector2(50,43),true);var barracks=c.add_building(0,3,Vector2(54,43),true);var research=c.add_building(0,6,Vector2(58,43),true)
	c.map.reset_solids(c.buildings);var army=[c.add_unit(0,1,Vector2(53,54)),c.add_unit(0,2,Vector2(55,54))]
	var plan=T.developed_plan(c,0,T.activate(c,0,"A17"),army)
	check(plan.get("_ai_ara_recovery",false) and plan.primary==[1,2] and T.build_order(2,plan).all(func(k):return int(k) in [1,2,3]),"depleted capital plan really protects the cheap battle line instead of a new advanced tech chain")
	check(not B.research_upgrades(c,0,plan,army) and research.research=="","actual research waits while the fighting line is insufficient")
	var before=Vector2(p.as,p.tera);var counts=T.queued_counts(c,0)
	check(B.queue_unit(c,0,barracks,plan,army,counts,0,5) and int(barracks.queue[0].kind) in [1,2] and Vector2(p.as,p.tera)!=before,"protected recovery buys an actual normally paid basic combat unit")
	for i in range(5):army.append(c.add_unit(0,2,Vector2(58+i,58)))
	plan=T.developed_plan(c,0,T.plan_for(p),army)
	check(not plan.get("_ai_ara_recovery",false) and 12 in plan.primary,"restored battle line releases the advanced plan rather than locking the faction to basics")
	# Known enemy composition is observed physically; its lobby alone cannot trigger counters.
	c=fixture(2);p=c.players[0];c.time=300;c.players[1].race=1
	var enemies=[]
	for i in range(4):enemies.append(c.add_unit(1,2,Vector2(80+i,80)))
	enemies.append(c.add_unit(1,6,Vector2(83,83)))
	check(P.response(c,0)=="","hidden enemy spitter and mortar army does not trigger a counter")
	c.visibility[0].fill(2);T.observe(c,0,enemies)
	check(P.response(c,0)=="mass_splash","real sightings identify the clustered-spitter and mortar threat")
	army=[]
	for i in range(7):army.append(c.add_unit(0,2,Vector2(55+i,57)))
	plan=T.developed_plan(c,0,T.activate(c,0,"A2"),army)
	check(7 in plan.primary and 8 in plan.primary and 5 in plan.support and float(plan.weights["7"])>=6 and float(plan.weights["8"])>=6,"ground counter actually builds a golem orbital and mage combination")
	check(P.choice_weight(c,0,T.by_id.A12)>P.choice_weight(c,0,T.by_id.A13),"observed Citrus mass favours splash tools over a fixed stealth meta")
	var choices=T.transition_choices(c,0,T.repertoire(2,5),army)
	check(choices.any(func(item):return str(item.id)=="A8"),"an observed counter can unlock on one base after a genuine twelve-population line")
	c=fixture(2);p=c.players[0];c.time=300;c.players[1].race=0;enemies=[]
	for i in range(2):var tank=c.add_unit(1,5,Vector2(77+i*2,80));tank.anchored=true;enemies.append(tank)
	c.visibility[0].fill(2);T.observe(c,0,enemies)
	check(P.response(c,0)=="siege_flank" and P.choice_weight(c,0,T.activate(c,0,"A21"))>P.choice_weight(c,0,T.by_id.A2),"observed tank line increases real stealth and transport plan preference")
	# A real guardian returns to the advancing firing line instead of charging alone.
	var guard=c.add_unit(0,1,Vector2(65,60));var archer=c.add_unit(0,2,Vector2(56,60));army=[guard,archer];var wave=army.map(func(u):return int(u.id))
	c.command(0,{"type":"attack_move","ids":[guard.id],"pos":[100,60]});c.command(0,{"type":"move","ids":[archer.id],"pos":[100,60]})
	check(P.escort(c,0,army,[],wave,Vector2(100,60),false) and guard.order=="move" and ACData.point(guard.goal).x<65,"overextended guardian receives a real regroup order towards ranged support")
	var gap=c.center(guard).distance_to(c.center(archer))
	for tick in range(30):c.step(.05);c.resolve_spells()
	check(c.center(guard).distance_to(c.center(archer))<gap-2,"normal movement physically closes the unsupported guardian gap")
	guard.pos=[65,60];archer.pos=[56,60];guard._ai_expendable_owner=0;p._ai_ara_escort_next=0
	check(not P.escort(c,0,army,[],wave,Vector2(100,60),false),"a committed expendable raid is not recalled by main-force escort rules")
	guard.erase("_ai_expendable_owner");guard.erase("_ai_kite_until");var contact=c.add_unit(1,1,Vector2(66.5,60));p._ai_ara_escort_next=0
	check(not P.escort(c,0,army,[contact],wave,Vector2(100,60),false),"guardian already in melee contact keeps fighting instead of repeatedly walking backwards")
	var assassin=c.add_unit(0,10,Vector2(65,70));c._rebuild_collision_index();var flank_wave=[int(assassin.id)]
	check(P.flank(c,0,[assassin],flank_wave,Vector2(43,45),Vector2(95,85),false) and absf(ACData.point(assassin.goal).x-95)>3,"real stealth unit takes an off-axis ground detour against the observed tank line")
	# Ground exposure changes the actual connected landing choice.
	var carrier=c.add_unit(0,11,Vector2(55,80));var rider=c.add_unit(0,7,Vector2(56,80));var goal=Vector2(85,80)
	c.paths_this_tick=0;c.path_time_this_tick=0
	var landing=M.landing(c,carrier,[rider],goal,Vector2(43,45))
	check(landing.is_finite() and P.landing_risk(c,0,landing)<P.landing_risk(c,0,Vector2(78,80)),"actual transport landing avoids the observed tank firing line while remaining ground connected")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/ara-restore-behaviour-20261026")
	FileAccess.open("res://build/ara-restore-behaviour-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ARA_RESTORE_BEHAVIOUR ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
