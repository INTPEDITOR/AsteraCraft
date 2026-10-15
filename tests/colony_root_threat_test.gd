extends SceneTree
var checks=0
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func run():
	var c=ACCore.new();c.setup({"map":0,"mode":"teams","players":[{"race":1,"team":0},{"race":0,"team":1},{"race":2,"team":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.buildable_map.fill(1);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	var h=c.add_building(0,0,Vector2(30,30),true)
	var n=c.add_building(0,3,Vector2(37,30),true)
	var far=c.add_building(0,3,Vector2(55,30),true)
	c.add_building(0,4,Vector2(25,25),true)
	for b in [h,n,far]:ACCitrusBrood.producer(c,b)
	ACCitrusBrood.refresh(c)
	check(h.larva==6 and n.brood_active and not far.brood_active,"near nursery pooled and distant nursery inactive")
	check(ACCitrusBrood.idle_pods(c,n,true).size()==3 and ACCitrusBrood.idle_pods(c,far,true).is_empty(),"each connected source creates own three bodies")
	c._recalculate_supply();c.players[0].as=2000;c.players[0].tera=1000;h.rally=[60,60]
	for i in range(4):check(c.command(0,{"type":"train","id":h.id,"kind":1})=="","mother commands pooled pod %d"%i)
	var job=c.units.filter(func(u):return u.get("brood_parent",-1)==n.id and u.get("brood_state","")=="morph")[0]
	check(h.queue.size()==4 and job.morph_rally==h.rally,"nursery job visible in mother queue and uses rally")
	var job_id=job.id
	check(ACCitrusBrood.cancel_queue(c,0,h,3)=="" and job.brood_state=="idle" and c.players[0].reserved==3,"mother cancels nursery job")
	c.command(0,{"type":"train","id":h.id,"kind":1});job=c.entity(job_id);var left=job.morph_left
	h.hp=0;ACCitrusBrood.producer(c,n,30);ACCitrusBrood.tick_pod(c,job,5);ACCitrusBrood.refresh(c)
	check(not n.brood_active and job.morph_left==left,"destroyed mother pauses nursery and its morph")
	check(c.command(0,{"type":"train","id":n.id,"kind":1})!="","inactive nursery rejects production")
	check(not c.in_roots(0,Vector2(35,35)),"dead mother removes root source")
	h.hp=1400;ACCitrusBrood.tick_pod(c,job,1);ACCitrusBrood.refresh(c)
	check(n.brood_active and job.morph_left==left-1,"restored connection resumes reserved job")
	check(c.placement(0,2,Vector2(35,37),false)=="","building fits root ground")
	check(c.placement(0,2,Vector2(44,37),false)!="","outside root ground rejected")
	check(c.placement(0,12,Vector2(60,60),false)!="","relay requires existing roots")
	check(c.placement(0,0,Vector2(70,70),false)=="","new mother may establish expansion")
	var relay=c.add_building(0,12,Vector2(41,37),true)
	check(c.in_roots(0,Vector2(51,38)),"relay extends root ground")
	check(c.placement(0,3,Vector2(50,38),false)!="","roots alone cannot link remote nursery")
	relay.hp=0;check(not c.in_roots(0,Vector2(51,38)),"dead relay removes coverage")
	c.units.clear();c.collision_index_valid=false
	var defender=c.add_unit(0,2,Vector2(70,70));defender.order="attack_move"
	var idle=c.add_unit(1,1,Vector2(72,70))
	var enemy=c.add_unit(1,1,Vector2(75,70))
	var friend=c.add_unit(2,1,Vector2(76,70))
	c._update_vision();c._damage(enemy,friend,1,false)
	check(c._find_target(defender,7,"g").id==enemy.id,"attack move prioritizes attacker of allied player over nearer idle enemy")
	defender.order="hold";check(c._find_target(defender,7,"g").id==idle.id,"hold keeps ordinary nearest targeting")
	defender.order="attack_move";c.time+=3
	check(c._find_target(defender,7,"g").id==idle.id,"expired threat returns to nearest")
	enemy.order="attack";enemy.target=friend.id
	check(c._find_target(defender,7,"g").id==enemy.id,"active in-range attack intent has priority")
	defender.order="attack";defender.target=idle.id;c._tick_unit(defender,.05)
	check(defender.order=="attack" and defender.target==idle.id,"explicit target remains authoritative")
	defender.order="attack_move";enemy.pos=[90,70];c.collision_index_valid=false
	check(c._find_target(defender,7,"g").id==idle.id,"distant threat cannot pull unit outside scan radius")
	enemy.pos=[75,70];c.collision_index_valid=false
	c.visibility[0].fill(0);check(c._find_target(defender,7,"g").is_empty(),"fog never leaks threats")
	print("COLONY_ROOT_THREAT "+JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
