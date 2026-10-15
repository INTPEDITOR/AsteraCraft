extends SceneTree

var failures: Array=[]
var checks=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		printerr("FAIL: "+message)

func sim(c: ACCore, seconds: float, dt: float=.05) -> void:
	for i in range(ceili(seconds/dt)):
		c.step(dt)
		c.resolve_spells()

func arena(race: int=0) -> ACCore:
	# Keep behavior tests independent of visual map revisions and start locations.
	var c=ACCore.new()
	c.setup({"map":0,"players":[{"race":race},{"race":(race+1)%3}]})
	c.units.clear()
	c.buildings.clear()
	c.map.terrain.fill(0)
	c.map.buildable_map.fill(1)
	c.map.resources.clear()
	c._sync_resource_obstacles()
	c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(30,30),true).id
	c.players[1].home=c.add_building(1,0,Vector2(95,95),true).id
	c.map.reset_solids(c.buildings)
	c._update_vision()
	return c

func mineral(c: ACCore, pos: Vector2, amount: int=1500, type: String="as") -> Dictionary:
	var node={"id":100000+c.map.resources.size(),"pos":ACData.packed(pos),"type":type,"amount":amount,"busy":0.0}
	c.map.resources.append(node)
	c._sync_resource_obstacles()
	return node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for race in range(3):
		var c=arena(race)
		var vent=mineral(c,Vector2(22.5,21.5),10,"tera")
		var refinery=c.add_building(0,1,Vector2(21,21),true)
		c.map.reset_solids(c.buildings)
		sim(c,2.9)
		check(c.players[0].tera==0,"Tera waits for interval, race %d"%race)
		sim(c,.15)
		check(c.players[0].tera==8 and vent.amount==2,"Tera harvests without any worker, race %d"%race)
		sim(c,3)
		check(c.players[0].tera==10 and vent.amount==0,"Tera credits final partial batch, race %d"%race)
		sim(c,5)
		check(c.players[0].tera==10,"depleted Tera cannot generate resources, race %d"%race)
		check(c.nearest_resource(Vector2(22,22),"tera",0)==-1,"workers never reserve automatic Tera, race %d"%race)
		check(refinery.tera_resource==vent.id,"extractor binds to its local vent, race %d"%race)
		var unfinished=c.add_building(0,1,Vector2(40,40),false)
		var other_vent=mineral(c,Vector2(41.5,40.5),100,"tera")
		c._tick_building(unfinished,10)
		check(other_vent.amount==100,"unfinished extractor cannot harvest, race %d"%race)
		var hq=c.entity(int(c.players[0].home))
		var home_rect=c.footprint(hq)
		var home_mid=home_rect.get_center()
		for p in [Vector2(home_rect.position.x-.5,home_mid.y),Vector2(home_rect.end.x+.5,home_mid.y),Vector2(home_mid.x,home_rect.position.y-.5),Vector2(home_mid.x,home_rect.end.y+.5)]:
			var worker=c.add_unit(0,0,p)
			worker.carried=8
			worker.cargo_type="as"
			worker.order="gather"
			var before=c.players[0].as
			c._gather(worker,.05)
			check(c.players[0].as==before+8 and worker.carried==0,"As deposits at closest HQ edge %s, race %d"%[p,race])
			check(ACData.point(worker.pos)==p,"deposit preserves ground-contact anchor")
			worker.hp=0
		var approach=c.building_approach(hq,Vector2(23,31))
		check(approach.x==29 and approach.y==31,"approach chooses facing side instead of top-left detour, race %d"%race)
		for diagonal in [Vector2(27,27),Vector2(37,27),Vector2(27,36),Vector2(37,36)]:
			var diagonal_worker=c.add_unit(0,0,diagonal)
			diagonal_worker.order="gather"
			diagonal_worker.carried=8
			var diagonal_before=c.players[0].as
			sim(c,8)
			check(diagonal_worker.carried==0 and c.players[0].as==diagonal_before+8,"diagonal HQ approach deposits without stopping outside range, race %d"%race)
			diagonal_worker.hp=0
		var diagonal_builder=c.add_unit(0,0,Vector2(62.292,62.292))
		var diagonal_building=c.add_building(0,2,Vector2(60,60),false)
		diagonal_building.worker=diagonal_builder.id
		diagonal_builder.order="construct"
		diagonal_builder.target=diagonal_building.id
		c.map.reset_solids(c.buildings)
		sim(c,60)
		check(diagonal_building.progress>=1,"diagonal builder reaches actual construction range, race %d"%race)
		c.units.clear()
		var ore=mineral(c,Vector2(23.5,31),80)
		var worker=c.add_unit(0,0,Vector2(25,31))
		worker.order="gather"
		worker.target=ore.id
		c.step(.05)
		check(worker.action=="harvest" and worker.action_clock==0,"worker enters harvesting animation, race %d"%race)
		c.step(.2)
		check(worker.action=="harvest" and worker.action_clock>.1,"harvest animation phase advances without restarting")
		var fx=c.effects.filter(func(e):return e.type=="harvest")
		check(not fx.is_empty() and fx[0].race==race and fx[0].unit==worker.id and fx[0].target==ore.id,"harvest effect identifies worker, race and resource")
		var before=c.players[0].as
		sim(c,16)
		check(c.players[0].as>=before+16,"worker completes repeated short As trips, race %d"%race)
		check(c.map.walkable(Vector2i(ACData.point(worker.pos).round())),"worker remains outside solid HQ footprint")
		worker.carried=8
		worker.pos=[29,31]
		ore.amount=0
		var carried_before=c.players[0].as
		c._gather(worker,.05)
		check(c.players[0].as==carried_before+8,"last carried As deposits after all minerals deplete")
		# Manual gas orders redirect a worker to the As economy.
		ore.amount=80
		worker.target=vent.id
		worker.carried=0
		c._gather(worker,.05)
		check(worker.target==ore.id,"manual gas order redirects to As, race %d"%race)

	var c=arena()
	var mover=c.add_unit(0,1,Vector2(40,40))
	c.command(0,{"type":"move","ids":[mover.id],"pos":[44,40]})
	sim(c,.1)
	check(mover.action=="walk" and mover.moving,"movement selects walk animation")
	sim(c,.3)
	check(mover.action_clock>.2,"walk phase persists across simulation ticks")
	sim(c,5)
	check(mover.action=="idle" and not mover.moving,"arrival restores idle animation")
	var foe=c.add_unit(1,1,Vector2(46,40))
	c._update_vision()
	c.command(0,{"type":"attack","ids":[mover.id],"target":foe.id})
	sim(c,.1)
	check(mover.action=="attack" and mover.fired>=c.time-.1,"attack has an animation timestamp")
	var shots=c.effects.filter(func(e):return e.type=="shot")
	check(not shots.is_empty() and shots[0].projectile=="bullet" and shots[0].unit==mover.id and shots[0].target==foe.id,"shot identifies projectile, attacker and target")
	if not shots.is_empty():
		check(shots[0].started<shots[0].until and shots[0].has("id"),"effect has a stable id and lifetime for audio deduplication")
	var hidden=c.add_unit(1,0,Vector2(87,87))
	c._effect("harvest",hidden,Vector2(88,87),.5)
	var hidden_id=c.effects.back().id
	var own_fx=c.snapshot(0).effects
	check(not own_fx.any(func(e):return e.id==hidden_id),"fog hides enemy harvesting effects and sound events")
	var snapshot=c.snapshot(0)
	var snap_mover=snapshot.units.filter(func(u):return u.id==mover.id)[0]
	check(snap_mover.has("action") and snap_mover.has("action_clock") and snap_mover.has("action_started"),"network snapshot preserves animation state")
	check(not snap_mover.has("path") and not snap_mover.has("action_intent"),"snapshot omits navigation and temporary action internals")
	for i in range(ACCore.MAX_EFFECTS+20):c._effect("harvest",mover,Vector2(44,40),1)
	check(c.effects.size()<=ACCore.MAX_EFFECTS,"effect ring stays bounded during large battles")
	var placement_core=arena()
	check(placement_core.placement(0,2,Vector2(42,42),false)=="","open ground permits supply construction")
	placement_core.map.buildable_map[43*ACMap.SIZE+43]=0
	check(placement_core.map.walkable(Vector2i(43,43)),"ramp and bridge mask can remain navigable")
	check(placement_core.placement(0,2,Vector2(42,42),false)!="","every footprint cell must permit building, including ramp and bridge cells")
	placement_core.map.buildable_map[43*ACMap.SIZE+43]=1
	check(placement_core.placement(0,2,Vector2(42,42),false)=="","clearing no-build mask restores valid placement")
	var group: Array=[]
	for i in range(13):group.append(placement_core.add_unit(0,1,Vector2(50+i,50)).id)
	check(placement_core.command(0,{"type":"move","ids":group,"pos":[50,55]})!="","human commands reject groups larger than twelve")
	check(group.all(func(id):return placement_core.entity(id).order=="idle"),"oversized human command changes no orders")
	check(placement_core.command(0,{"type":"move","ids":group.slice(0,12),"pos":[50,55]})=="","human commands accept twelve selected units")
	check(placement_core.entity(group[12]).order=="idle","twelve-unit command does not include the thirteenth unit")
	placement_core.players[0].bot=true
	check(placement_core.command(0,{"type":"attack_move","ids":group,"pos":[50,55]})=="","trusted bot army may command more than twelve units")
	check(group.all(func(id):return placement_core.entity(id).order=="attack_move"),"bot army order reaches every unit")
	print("ECONOMY_ANIMATION_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
