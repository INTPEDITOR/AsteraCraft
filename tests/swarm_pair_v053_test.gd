extends SceneTree
var failures: Array=[]
var checks=0
func _initialize():call_deferred("run")
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func setup():
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":1},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	c.add_building(0,0,Vector2(30,30),true);c.add_building(0,4,Vector2(20,20),true)
	c._recalculate_supply();c.players[0].as=500;c.players[0].tera=500
	ACCitrusBrood.producer(c,c.buildings[0])
	return c
func run():
	var c=setup();var b=c.buildings[0];var p=ACCitrusBrood.idle_pods(c,b)[0];b.rally=[50,50]
	check(ACCitrusBrood.train(c,0,p,1)=="","pair accepted")
	check(c.players[0].as==450 and c.players[0].reserved==1,"50 charged once and 1 supply reserved")
	ACCitrusBrood.tick_pod(c,p,15);c._recalculate_supply()
	var pair=c.units.filter(func(u):return u.kind==1)
	check(pair.size()==2 and c.players[0].used==1 and c.players[0].reserved==0,"two born with total supply one")
	check(pair.all(func(u):return u.order=="attack_move" and ACData.point(u.goal).is_equal_approx(Vector2(50,50))),"both receive rally")
	check(pair[0].id!=pair[1].id and ACData.point(pair[0].pos).distance_to(ACData.point(pair[1].pos))>0,"distinct bodies")
	ACCitrusBrood.tick_pod(c,p,15);check(c.units.filter(func(u):return u.kind==1).size()==2,"no duplicate completion")
	p=ACCitrusBrood.idle_pods(c,b)[0];ACCitrusBrood.train(c,0,p,1);ACCitrusBrood.cancel(c,0,p)
	check(c.players[0].as==450 and c.players[0].reserved==0,"cancel refunds one batch")
	c.players[0].cap=1.5
	check(ACCitrusBrood.train(c,0,p,1)!="" and c.players[0].as==450,"half supply cannot accept pair")
	c.players[0].cap=20;ACCitrusBrood.train(c,0,p,1);p.hp=0;ACCitrusBrood.cleanup_dead(c)
	check(c.players[0].as==400 and c.players[0].reserved==0,"death releases reservation without refund")
	c=setup();b=c.buildings[0];p=ACCitrusBrood.idle_pods(c,b)[0];ACCitrusBrood.train(c,0,p,1)
	c.map.terrain.fill(2);c.map.reset_solids(c.buildings)
	ACCitrusBrood.tick_pod(c,p,15)
	check(p.kind==13 and p.morph_left==0 and c.players[0].reserved==1 and c.units.filter(func(u):return u.kind==1).is_empty(),"blocked pair waits atomically")
	c.map.terrain.fill(0);c.map.reset_solids(c.buildings);ACCitrusBrood.tick_pod(c,p,.05)
	check(c.units.filter(func(u):return u.kind==1).size()==2 and c.players[0].as==450 and c.players[0].reserved==0,"cleared exit releases exactly paid pair")
	print("SWARM_PAIR "+JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

