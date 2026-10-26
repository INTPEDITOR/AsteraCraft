extends "res://tests/two_workers_per_as_20261026_test.gd"
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
const M=preload("res://scripts/bot_missions.gd")
const CP=preload("res://scripts/bot_combat_policy.gd")
func run():
	var c=fixture(0);var p=c.players[0];c.time=300
	var army=[]
	for kind in [3,1,5,4]:army.append(c.add_unit(0,kind,Vector2(57,60+kind)))
	var slots=army.map(func(u):return B.staging_slot(c,p,u,Vector2(70,65),Vector2(43,45)))
	var back=(Vector2(43,45)-Vector2(70,65)).normalized()
	check((slots[1]-slots[0]).dot(back)>2 and (slots[2]-slots[1]).dot(back)>2 and (slots[3]-slots[2]).dot(back)>2,"real legal assembly slots place melee in front and ranged siege and healers progressively behind")
	check(army.all(func(u):return c._ground_fits_size(c._body_size(u),slots[army.find(u)])),"every formation slot fits the actual unit body on walkable ground")
	var light=c.add_unit(1,1,Vector2(76,65));var heavy=c.add_unit(1,3,Vector2(76,65));light.hp=100;heavy.hp=100;light.shield=0;heavy.shield=0
	var flame=c.add_unit(0,13,Vector2(71,65));var tank=army[2]
	check(CP.target_score(c,flame,light,[light,heavy])<CP.target_score(c,flame,heavy,[light,heavy]),"flame vehicle prefers an equally healthy light target")
	check(CP.target_score(c,tank,heavy,[light,heavy])<CP.target_score(c,tank,light,[light,heavy]),"tank values its heavy-armour damage on equally healthy targets")
	# Observed splash induces an actual legal spread order, not a hidden threat response.
	var cluster=[]
	for i in range(4):cluster.append(c.add_unit(0,1,Vector2(80+i*.5,80)))
	var enemy_tank=c.add_unit(1,5,Vector2(87,80));c._rebuild_collision_index();c.visibility[0].fill(2)
	check(not CP.spread(c,0,cluster,[],cluster.map(func(u):return u.id),false),"unobserved splash units do not trigger clairvoyant spreading")
	p._ai_spread_next=0
	check(CP.spread(c,0,cluster,[enemy_tank],cluster.map(func(u):return u.id),false),"an observed nearby tank causes a real spread movement order")
	var moving=cluster.filter(func(u):return u.order=="move")
	check(moving.size()==1 and c._ground_sweep(c._body_size(moving[0]),c.center(moving[0]),ACData.point(moving[0].goal)),"spread is bounded to one unit and preserves real terrain clearance")
	# Deployment does not flicker when an enemy briefly leaves range.
	c=fixture(0);p=c.players[0];c.time=300
	tank=c.add_unit(0,5,Vector2(70,65));var foe=c.add_unit(1,1,Vector2(79,65));p._ai_wave=[tank.id]
	var plan=T.activate(c,0,"N7");c.visibility[0].fill(2)
	M.after_combat(c,0,[tank],plan,[foe],Vector2(43,45),Vector2(100,100),false)
	check(tank.deploy_to and float(tank.deploy_until)>300 and float(tank.get("_ai_siege_hold_until",0))>=305,"actual siege command starts a minimum deployment hold")
	for tick in range(52):c.step(.05);c.resolve_spells()
	M.after_combat(c,0,[tank],plan,[],Vector2(43,45),Vector2(100,100),false)
	check(tank.anchored,"brief loss of a target does not immediately undeploy the tank")
	for tick in range(100):c.step(.05);c.resolve_spells()
	M.after_combat(c,0,[tank],plan,[],Vector2(43,45),Vector2(100,100),false)
	for tick in range(38):c.step(.05);c.resolve_spells()
	check(not tank.anchored,"tank really undeploys after the hold and target-absence grace expire")
	# A landing is useful only if unloaded troops can walk to the objective.
	c=fixture(0);var carrier=c.add_unit(0,11,Vector2(50,70));var rider=c.add_unit(0,5,Vector2(51,70))
	var goal=Vector2(80,70)
	var land=M.landing(c,carrier,[rider],goal,Vector2(43,45))
	check(land.is_finite(),"normal landing finds an actual ground-connected approach for its largest rider")
	c.map.source_walk_masks.clear()
	for x in range(77,84):
		for y in range(67,74):
			if x in [77,83] or y in [67,73]:c.map.terrain[y*128+x]=1
	c.map.reset_solids(c.buildings);c.collision_index_valid=false;c.paths_this_tick=0;c.path_time_this_tick=0
	var rejected=M.landing(c,carrier,[rider],goal,Vector2(43,45))
	check(not rejected.is_finite(),"walkable landing tiles outside an enclosed objective are rejected when troops cannot reach it")
	c=fixture(0);carrier=c.add_unit(0,11,Vector2(55,70));rider=c.add_unit(0,1,Vector2(56,70))
	var enemy_hq=c.add_building(1,0,Vector2(80,70),true);c.map.reset_solids(c.buildings)
	check(M.landing(c,carrier,[rider],c.center(enemy_hq),Vector2(43,45)).is_finite(),"occupied headquarters goals use a reachable perimeter rather than rejecting every landing")
	# Suicide value applies to bots only, leaving a human's explicit attack intact.
	c=fixture(1);c.time=300;p=c.players[0]
	var bomb=c.add_unit(0,4,Vector2(80,80));var miner=c.add_unit(1,0,Vector2(80.9,80));miner.order="hold"
	c._rebuild_collision_index();c._update_vision();c.visibility[0].fill(2)
	check(not CP.worthwhile_bomb(c,bomb,miner,[miner]),"a lone cheap worker is not a worthwhile autonomous suicide target")
	c.command(0,{"type":"attack","ids":[bomb.id],"target":miner.id})
	for tick in range(12):c.step(.05);c.resolve_spells()
	check(bomb.hp>0,"bot bomb really survives rather than wasting itself on a lone worker")
	var targets=[miner,c.add_unit(1,1,Vector2(81.2,80.3)),c.add_unit(1,1,Vector2(80.7,81))]
	c._rebuild_collision_index();c.visibility[0].fill(2)
	check(CP.worthwhile_bomb(c,bomb,miner,targets),"a real cluster is a worthwhile blast target")
	c.command(0,{"type":"attack","ids":[bomb.id],"target":miner.id})
	for tick in range(80):c.step(.05);c.resolve_spells()
	check(bomb.hp<=0 and targets.any(func(u):return u.hp<float(c.unit_data(u).hp)),"bot bomb really detonates and damages the observed cluster")
	c=fixture(1);c.time=300;c.players[0].bot=false;bomb=c.add_unit(0,4,Vector2(80,80));miner=c.add_unit(1,0,Vector2(80.9,80));miner.order="hold";c._rebuild_collision_index();c._update_vision()
	c.command(0,{"type":"attack","ids":[bomb.id],"target":miner.id})
	for tick in range(80):c.step(.05);c.resolve_spells()
	check(bomb.hp<=0,"human explicitly ordered suicide attack retains its existing behaviour")
	c=fixture(0);army=[]
	for i in range(12):army.append(c.add_unit(0,1,Vector2(60+i%4,60+i/4)))
	check(B.combat_cohort_size(c,0,army,B.PROFILES[5],[])==10,"uncommitted rifle reinforcements assemble a useful ten-population group")
	army=[]
	for i in range(6):army.append(c.add_unit(0,5,Vector2(60+i%3,60+i/3)))
	check(B.combat_cohort_size(c,0,army,B.PROFILES[5],[])==4,"heavy reinforcements use their real population instead of waiting for ten tanks")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/ai-combat-v3-20261026")
	FileAccess.open("res://build/ai-combat-v3-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_COMBAT_V3 ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
