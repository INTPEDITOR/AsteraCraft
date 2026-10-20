extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena():
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":1},{"race":0},{"race":2}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	c.players[0].technologies={};return c
func reveal(c):c._rebuild_collision_index();c._update_vision()
func cast(c,u,key,target={}):
	return c.command(int(u.owner),{"type":"skill","skill":key,"ids":[u.id],"pos":target.get("pos",u.pos),"target":target.get("id",-1)})
func _initialize():call_deferred("run")
func run():
	var c=arena();var support=c.add_unit(0,9,Vector2(40,40));var patient=c.add_unit(0,3,Vector2(42,40));patient.hp-=100;reveal(c)
	check(support.energy==25 and support.max_energy==200 and not support.has("heal_stock"),"one mana resource, low initial mana")
	check(ACAbilities.catalog(1,9).size()==3 and ACAbilities.catalog(1,9).filter(func(s):return s.get("base",false)).size()==1,"one basic heal and two research skills")
	var hp=patient.hp;c._support(support,support._definition,1)
	check(patient.hp==hp+8 and support.energy==21,"automatic heal spends four mana for eight health")
	check(cast(c,support,"sap_heal")=="" and not support.sap_heal_enabled,"heal button disables autocast")
	hp=patient.hp;c._support(support,support._definition,1)
	check(patient.hp==hp and support.energy==21,"disabled heal spends nothing")
	c.time=1;check(cast(c,support,"sap_heal")=="" and support.sap_heal_enabled,"heal button enables autocast")
	support.energy=.5;c._support(support,support._definition,1)
	check(patient.hp==hp+1 and support.energy==0,"partial mana cannot over-heal or go negative")
	patient.hp=patient._definition.hp;support.energy=20;c._support(support,support._definition,1)
	check(support.energy==20,"full health does not consume mana")
	var victim=c.add_unit(0,1,Vector2(41,40));reveal(c)
	check(cast(c,support,"sap_reclaim",victim)!="" and victim.hp>0,"sacrifice is research gated")
	c.players[0].technologies.sap_reclaim=1;support.energy=190
	check(cast(c,support,"sap_reclaim",victim)=="" and victim.hp==0 and support.energy==200,"sacrifice restores capped mana")
	check(c.players[0].kills==0 and c.players[1].kills==0,"sacrifice grants no kill")
	var another=c.add_unit(0,1,Vector2(41,41));reveal(c)
	check(cast(c,support,"sap_reclaim",another)!="" and another.hp>0,"sacrifice cooldown prevents repeated consumption")
	c.time=30
	check(cast(c,support,"sap_reclaim",another)!="" and another.hp>0,"full mana cannot waste a unit")
	support.energy=0
	for scenario in ["self","air","brood","enemy","building","loaded","passengers","far","dead","teammate"]:
		var target=c.add_unit(0,1,Vector2(42,40))
		if scenario=="self":target=support
		if scenario=="air":target=c.add_unit(0,10,Vector2(42,41))
		if scenario=="brood":target=c.add_unit(0,13,Vector2(42,41))
		if scenario=="enemy":target=c.add_unit(1,1,Vector2(42,41))
		if scenario=="building":target=c.add_building(0,2,Vector2(42,41),true)
		if scenario=="loaded":target.container=99
		if scenario=="passengers":target.cargo=[another.id]
		if scenario=="far":target.pos=[60,60]
		if scenario=="dead":target.hp=0
		if scenario=="teammate":
			c.mode="teams";c.players[0].team=0;c.players[1].team=0
			target=c.add_unit(1,1,Vector2(42,41))
		reveal(c)
		var before=target.hp
		check(cast(c,support,"sap_reclaim",target)!="" and target.hp==before and support.energy==0,"invalid sacrifice no mutation "+scenario)
	reveal(c)
	check(cast(c,support,"sap_reclaim",another)=="" and support.energy==75 and another.hp==0,"empty mana can reclaim exactly seventy five")
	c=arena();support=c.add_unit(0,9,Vector2(40,40));support.energy=100
	var shooter=c.add_unit(0,7,Vector2(42,40));var distant=c.add_unit(0,7,Vector2(49,40));var aircraft=c.add_unit(0,10,Vector2(40,42));var enemy=c.add_unit(1,1,Vector2(44,40));reveal(c)
	check(cast(c,support,"sap_bloom")!="" and support.energy==100,"attack speed skill research gated")
	c.players[0].technologies.sap_bloom=1
	check(cast(c,support,"sap_bloom")=="" and support.energy==25,"bloom exact mana cost")
	check(shooter.bloom_until==6 and aircraft.bloom_until==6 and not distant.has("bloom_until") and not enemy.has("bloom_until"),"bloom affects nearby allied ground and air only")
	enemy.hp=10000;enemy.shield=0;shooter.order="attack";shooter.target=enemy.id;shooter.cooldown=0
	c._tick_unit_behavior(shooter,0)
	check(is_equal_approx(shooter.cooldown,float(shooter._definition.period)/1.25),"bloom increases actual attack frequency by twenty five percent")
	c.time=6;shooter.cooldown=0;c._tick_unit_behavior(shooter,0)
	check(is_equal_approx(shooter.cooldown,float(shooter._definition.period)),"attack speed expires at six seconds")
	c=arena();var caster=c.add_unit(0,8,Vector2(40,40));enemy=c.add_unit(1,1,Vector2(43,40));c.players[0].technologies.mind_control=1;reveal(c)
	check(caster._definition.as==100 and caster._definition.tera==150,"graft unit increased production cost")
	caster.energy=199
	check(cast(c,caster,"mind_control",enemy)!="" and enemy.owner==1 and caster.energy==199,"mind control rejects under full mana")
	caster.energy=200
	check(cast(c,caster,"mind_control",enemy)=="" and enemy.owner==0 and caster.energy==0,"mind control consumes full two hundred mana")
	print("CITRUS_SUPPORT_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
