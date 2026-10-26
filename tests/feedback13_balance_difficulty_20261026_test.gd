extends "res://tests/two_workers_per_as_20261026_test.gd"
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
const D=preload("res://scripts/bot_difficulty.gd")
const CP=preload("res://scripts/bot_combat_policy.gd")
func run():
	check(ACData.unit(0,13).damage==10 and ACData.unit(1,3).hp==290 and is_equal_approx(ACData.unit(1,7).range,6.3) and ACData.unit(2,1).as==110,"approved conservative unit adjustments are loaded")
	check(ACData.unit(2,7).hp==100 and ACData.unit(2,7).shield==280 and ACData.unit(0,3).ranged_damage_reduction==5,"golem shield design and shield infantry mitigation are preserved")
	for level in range(6):
		check(D.APM[level]==[50,100,150,200,250,300][level] and D.supply_target(level)==[50,80,120,160,180,200][level],"difficulty action and operating supply goals "+str(level))
		check(D.workers(level,16,1)==[8,12,16,16,16,16][level] and D.workers(level,10,2)<=10,"worker targets respect actual mineral slots "+str(level))
		check(T.repertoire(0,level).size()==[3,6,12,18,23,25][level],"tactic repertoire increases with difficulty "+str(level))
	var c=fixture(0);var p=c.players[0];c.time=300;p.as=2000;p.tera=2000
	var factory=c.add_building(0,3,Vector2(50,50),true);var plan=T.activate(c,0,"N1")
	p.difficulty=0;p.used=50;p.reserved=0;p.cap=200
	check(not B.queue_unit(c,0,factory,plan,[],{},0,0),"very easy stops at its operating goal even if actual supply is larger")
	p.difficulty=5
	check(B.queue_unit(c,0,factory,plan,[],{},0,5) and p.as<2000,"Hell buys a real reinforcement in the same affordable position")
	c=fixture(2);p=c.players[0];c.time=300;p.as=5000;p.tera=5000
	for kind in [1,2,3,4,7]:c.add_building(0,kind,Vector2(48+kind*5,48),true)
	var army=[]
	for i in range(4):army.append(c.add_unit(0,7,Vector2(60+i*2,70)))
	plan=T.activate(c,0,"A7");c.map.reset_solids(c.buildings)
	check(not c.has_building(0,6) and B.research_infrastructure(c,0,plan,army),"actual golem army orders its missing research infrastructure")
	var builder_order=c.units.filter(func(u):return int(u.owner)==0 and u.order=="build_move" and int(u.build_plan.kind)==6)
	check(builder_order.size()==1,"only one worker is assigned to the missing lab")
	c.add_building(0,6,Vector2(75,55),true);p._ai_research_next=0
	check(B.research_upgrades(c,0,plan,army) and c.buildings.any(func(b):return int(b.owner)==0 and str(b.research)=="golem_range"),"real paid golem range research is selected")
	c=fixture(0);p=c.players[0];c.time=300;p.as=2000;p.tera=2000
	c.add_building(0,7,Vector2(55,55),true);army=[]
	for i in range(8):army.append(c.add_unit(0,1,Vector2(60+i,70)))
	plan=T.activate(c,0,"N1");p.technologies={"frontline_vitality":1}
	check(B.research_upgrades(c,0,plan,army) and c.buildings.any(func(b):return str(b.research)=="stim"),"an actual rifle force researches combat stim through its legal lab")
	var tank=c.add_unit(0,5,Vector2(60,60));var foes=[]
	for i in range(6):foes.append(c.add_unit(1,1,Vector2(65+i*.25,60)))
	var cache={}
	for foe in foes:check(is_equal_approx(CP.target_score(c,tank,foe,foes),CP.target_score(c,tank,foe,foes,cache)),"cached splash targeting preserves the actual target score")
	check(cache.size()==foes.size(),"one cluster count per target and radius is shared across attackers")
	var support_plan=T.activate(c,0,"N2")
	check(T.production_score(c,0,support_plan,4,{1:6,4:1,5:30},37)<0,"mechanical armies do not justify excess biological medics")
	c.players[0].race=2
	support_plan=T.activate(c,0,"A12")
	check(T.production_score(c,0,support_plan,5,{1:8,2:4,5:2},14)<0,"fragile casters do not outgrow their actual fighting screen")
	c.players[0].race=0
	var origin=Vector2(70,70);var point=Vector2(85,70)
	check(B.staging_connected(c,0,Vector2.ONE,origin,point) and B.staging_connected(c,0,Vector2.ONE,origin+Vector2(.2,0),point),"checked connected-origin movement reuses staging reachability")
	c.map.source_walk_masks.clear()
	for y in range(128):c.map.terrain[y*128+78]=1
	c.map.reset_solids(c.buildings)
	check(not B.staging_connected(c,0,Vector2.ONE,origin,point),"a new wall invalidates cached connectivity rather than allowing passage")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/feedback13-checks-20261026")
	FileAccess.open("res://build/feedback13-checks-20261026/balance-difficulty.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FEEDBACK13_BALANCE_DIFFICULTY ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
