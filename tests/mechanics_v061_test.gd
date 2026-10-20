extends "res://tests/abilities_v060_test.gd"
func run():
	var c=arena();var u=c.add_unit(0,5,Vector2(40,40));var victim=c.add_unit(1,1,Vector2(46,40));reveal(c)
	c._ability(u,Vector2.ZERO)
	check(not u.anchored and u.deploy_until==2.5,"tank starts timed deployment")
	var old=u.pos.duplicate();u.order="move";u.goal=[50,40];c._tick_unit_behavior(u,.05)
	check(u.pos==old and c.effects.is_empty(),"transform prevents movement and shooting")
	c.time=2.49;c._tick_unit_behavior(u,.05);check(not u.anchored,"deployment is not instant")
	c.time=2.5;c._tick_unit_behavior(u,.05);check(u.anchored and not u.has("deploy_until"),"deploy completes at 2.5 seconds")
	u.order="attack";u.target=victim.id;victim.pos=[41.5,40];victim.hp=1000;c._rebuild_collision_index();reveal(c)
	u.cooldown=0;c._tick_unit_behavior(u,.05);check(victim.hp==1000,"deployed cannon cannot hit inside minimum range")
	victim.pos=[49,40];c.add_unit(0,8,Vector2(47,41));c._rebuild_collision_index();reveal(c);c._tick_unit_behavior(u,.05)
	check(victim.hp<1000 or victim.shield<float(victim._definition.shield),"deployed cannon attacks extended range")
	u.ability_cd=0;c._ability(u,Vector2.ZERO);check(u.anchored and is_equal_approx(u.deploy_until,4.3),"packing takes 1.8 seconds")
	c.time=4.3;c._tick_unit_behavior(u,.05);check(not u.anchored,"packing returns to mobile mode")
	c=arena();var scout=c.add_unit(0,7,Vector2(40,40));scout.energy=0;c.players[0].technologies.nuclear=1;c.players[0].nukes=1;reveal(c)
	check(cast(c,scout,"nuclear",{},Vector2(44,40))=="" and scout.energy==0,"nuclear guidance works at zero energy")
	c=arena();var mother=c.add_unit(0,14,Vector2(40,40));victim=c.add_unit(1,1,Vector2(44,40));victim.hp=10000
	var drone=c.add_unit(0,15,Vector2(43,40));drone.mother=mother.id;mother.drone_target=victim.id;reveal(c)
	var moving_samples=0;var previous=ACData.point(drone.pos);var positions=[]
	for i in range(100):
		c.time+=.05;drone.cooldown=maxf(0,drone.cooldown-.05);ACNewUnits.tick(c,drone,.05)
		var p=ACData.point(drone.pos)
		if p.distance_to(previous)>.01:moving_samples+=1
		positions.append(p);previous=p
	check(moving_samples>90 and victim.hp<10000,"carrier drone keeps flying throughout its firing circuit")
	check(positions.any(func(p):return p.y>40.5) and positions.any(func(p):return p.y<39.5),"drone flies around both sides of target")
	mother.drone_target=-1;var before=victim.hp
	for i in range(100):c.time+=.05;ACNewUnits.tick(c,drone,.05)
	check(drone.container==mother.id and victim.hp==before,"recalled drone docks without firing")
	print("MECHANICS_V061 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
