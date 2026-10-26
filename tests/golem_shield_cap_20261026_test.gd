extends "res://tests/two_workers_per_as_20261026_test.gd"
const T=preload("res://scripts/bot_tactics.gd")
const P=preload("res://scripts/bot_ara_policy.gd")
func health(u):return maxf(0,float(u.hp))+maxf(0,float(u.shield))
func run():
	var c=fixture(2);c.players[1].race=0;c.time=300
	var golem=c.add_unit(0,7,Vector2(80,80));var tank=c.add_unit(1,5,Vector2(86,80));tank.order="hold"
	check(golem.hp==100 and golem.shield==280 and health(golem)==380,"latest health-to-shield transfer preserves exactly 380 total durability")
	var before=health(golem);c._damage(tank,golem,80,false)
	check(is_equal_approx(before-health(golem),25) and golem.hp==100,"high-damage attack is capped at twenty-five combined real health and shield loss")
	golem.hp=100;golem.shield=5;before=health(golem);c._damage(tank,golem,80,false)
	check(is_equal_approx(before-health(golem),25) and golem.shield==0 and golem.hp==80,"shield-breaking hit shares a single twenty-five budget with health overflow")
	before=health(golem);c._damage(tank,golem,60,false)
	check(before-health(golem)>25,"shieldless golem receives normal uncapped high attack damage")
	golem.hp=100;golem.shield=280;before=health(golem);c._damage(tank,golem,8,false)
	check(before-health(golem)<25,"cap never increases a weak attack's damage")
	golem.shield=280;before=health(golem);c._damage(tank,golem,75,false,"spell")
	check(is_equal_approx(before-health(golem),75),"spell damage remains distinct from the ordinary-attack protection")
	golem.shield=280;before=health(golem)
	for shot in range(3):c._damage(tank,golem,20,false,"attack",1.0/3,1.0/3)
	check(is_equal_approx(before-health(golem),25),"three packets of one volley share the proportional attack cap")
	golem.shield=280;before=health(golem)
	for tick in range(10):c._damage(tank,golem,10,false,"attack",.1,.1)
	check(is_equal_approx(before-health(golem),25),"continuous beam fractions cannot bypass the per-attack shield limit")
	# Other units retain their ordinary damage model.
	var archer=c.add_unit(0,2,Vector2(80,84));before=health(archer);c._damage(tank,archer,60,false)
	check(before-health(archer)>25,"the new protection applies only to golems")
	tank.hp=0;c.time=300;golem.hp=100;golem.shield=280;golem.pos=[60,90];c.command(0,{"type":"move","ids":[golem.id],"pos":[110,90]})
	for tick in range(200):c.step(.05);c.resolve_spells()
	check(c.center(golem).x>80.5 and c.center(golem).x<82.5 and ACData.unit(2,7).base_speed==1.8,"real ten-second ground travel reflects the final 2.16 speed")
	c=fixture(2);c.time=300;c.players[1].race=0
	var enemies=[c.add_unit(1,5,Vector2(80,80)),c.add_unit(1,5,Vector2(83,80))]
	c.visibility[0].fill(2);T.observe(c,0,enemies)
	var army=[]
	for i in range(7):army.append(c.add_unit(0,2,Vector2(50+i,60)))
	var plan=T.developed_plan(c,0,T.activate(c,0,"A14"),army)
	check(7 in plan.primary+plan.support and float(plan.weights.get("7",0))>=5,"observed tanks cause a real golem production preference even in a stealth mix")
	c=fixture(2);c.time=300;c.players[1].race=0
	enemies=[c.add_unit(1,7,Vector2(80,80)),c.add_unit(1,7,Vector2(83,80))]
	c.visibility[0].fill(2);T.observe(c,0,enemies)
	check(P.response(c,0)=="heavy_hits","other observed high-damage ground attackers also request golem protection")
	c=fixture(2);c.time=300;c.players[1].race=0
	enemies=[c.add_unit(1,9,Vector2(80,80)),c.add_unit(1,9,Vector2(83,80)),c.add_unit(1,9,Vector2(86,80))]
	c.visibility[0].fill(2);T.observe(c,0,enemies)
	check(P.response(c,0)=="","air-only attackers do not wastefully trigger a ground-tank counter")
	c=fixture(2);c.time=300;c.players[1].race=0
	golem=c.add_unit(0,7,Vector2(78,80));var direct=c.add_unit(1,1,Vector2(80,80));var near=c.add_unit(1,1,Vector2(80.7,80.4));var far=c.add_unit(1,1,Vector2(81.6,80));c._rebuild_collision_index();c._update_vision()
	c._strike_unit(golem,direct,c.unit_data(golem))
	check(is_equal_approx(60-float(direct.hp),35) and is_equal_approx(60-float(near.hp),17.5) and far.hp==60,"actual golem shot applies full direct damage half splash inside one tile and no damage outside")
	for race in range(3):
		var mirror=CORE.new();mirror.setup({"map":0,"players":[{"race":race,"color_id":0},{"race":race,"color_id":1}]})
		check(int(mirror.players[0].color_id)!=int(mirror.players[1].color_id),"actual mirror setup preserves distinct player colours faction "+str(race))
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/golem-shield-cap-20261026")
	FileAccess.open("res://build/golem-shield-cap-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GOLEM_SHIELD_CAP ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
