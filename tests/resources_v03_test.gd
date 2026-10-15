extends SceneTree

# v0.3 economy/body regressions. Resource fixtures explicitly refresh physical
# obstacles; visual decoration and generated art never determine collisions.
var failures: Array=[]
var checks: int=0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures.append(message)
		if failures.size()<=20:printerr("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func arena(race: int=0) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":20261015,"players":[{"race":race},{"race":(race+1)%3}]})
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
	c.collision_index_valid=false
	c._update_vision()
	return c

func mineral(c: ACCore, pos: Vector2, type: String="as", amount: int=1500) -> Dictionary:
	pos=Vector2(floorf(pos.x)+.5,floorf(pos.y)+(.5 if type=="tera" else 0.0))
	var node={"id":100000+c.map.resources.size(),"pos":ACData.packed(pos),"type":type,"amount":amount,"busy":0.0}
	c.map.resources.append(node)
	c._sync_resource_obstacles()
	return node

func tick(c: ACCore, count: int=1) -> void:
	for _i in range(count):
		c.step(.05)
		c.resolve_spells()

func worker_collision(race: int) -> void:
	var c=arena(race)
	var ore=mineral(c,Vector2(43,41))
	var a=c.add_unit(0,0,Vector2(40,40))
	var b=c.add_unit(0,0,Vector2(42,40))
	var soldier=c.add_unit(0,1,Vector2(40,43))
	a.order="gather";a.target=ore.id
	b.order="gather";b.target=ore.id
	check(c.mining_worker(a) and c.mining_worker(b),"traveling As workers are eligible for mineral passage, race %d"%race)
	check(c._unit_fits(a,ACData.point(b.pos)),"active As workers may cross one another, race %d"%race)
	check(not c._unit_fits(a,ACData.point(soldier.pos)),"mineral passage cannot pass through a soldier, race %d"%race)
	check(not c._unit_fits(soldier,ACData.point(a.pos)),"soldiers still collide with active miners, race %d"%race)
	b.order="idle"
	check(not c.mining_worker(b) and not c._unit_fits(a,ACData.point(b.pos)),"idle worker remains solid to active miner, race %d"%race)
	b.order="gather";b.target=ore.id;b.carried=8;b.cargo_type="as"
	check(c.mining_worker(b) and c._unit_fits(a,ACData.point(b.pos)),"returning As worker retains passage eligibility, race %d"%race)
	b.cargo_type="tera"
	check(not c.mining_worker(b),"Tera cargo never grants As passage, race %d"%race)
	b.carried=0;b.target=-1
	check(not c.mining_worker(b),"missing As target never grants passage, race %d"%race)
	b.target=ore.id;b.order="move"
	check(not c.mining_worker(b),"moving worker without gather order stays solid, race %d"%race)
	b.order="gather";b.container=999
	check(not c.mining_worker(b),"embarked worker never receives mineral passage, race %d"%race)
	b.container=-1;b.hp=0
	check(not c.mining_worker(b),"dead worker never receives mineral passage, race %d"%race)
	ore.amount=0
	check(not c.mining_worker(a),"empty As target cannot grant passage to empty-handed worker, race %d"%race)

func mining_exclusivity(race: int) -> void:
	var c=arena(race)
	var ore=mineral(c,Vector2(26,31),"as",500)
	for i in range(8):
		var worker=c.add_unit(0,0,Vector2(24+(i%2),28+int(i/2)*.85))
		worker.order="gather";worker.target=ore.id
	var max_active=0
	var invalid_clock=0
	var invalid_body=0
	var progress_states: Dictionary={}
	for _i in range(600):
		tick(c)
		var active=0
		for worker in c.units:
			if worker.action=="harvest":
				active+=1
				if int(c.mining_claims.get(ore.id,-1))!=int(worker.id):invalid_clock+=1
			if worker.get("mining_state","") in ["travel","waiting"] and float(worker.gather_clock)>.001:invalid_clock+=1
			if ACCore.collision_rect(worker).intersects(ACCore.resource_rect(ore)):invalid_body+=1
			progress_states[worker.get("mining_state","")]=true
		max_active=maxi(max_active,active)
	check(max_active==1,"exactly one worker actively harvests one node, race %d"%race)
	check(invalid_clock==0,"only the current claimant advances harvest clock, race %d"%race)
	check(invalid_body==0,"harvesting workers keep full bodies outside mineral, race %d"%race)
	check(c.players[0].gathered>=40,"crowded mining line keeps delivering As, race %d"%race)
	check(500-int(ore.amount)<=8*(floori(30.0/1.8)+1),"one-node output remains bounded by harvest interval, race %d"%race)
	check(progress_states.has("waiting") and progress_states.has("return"),"mining exposes wait and return phases, race %d"%race)
	# A removed/dead claimant must not lock the resource indefinitely.
	for _i in range(100):
		if int(c.mining_claims.get(ore.id,-1))>=0:break
		tick(c)
	var claimant=int(c.mining_claims.get(ore.id,-1))
	var victim=c.entity(claimant)
	check(not victim.is_empty(),"an occupied mining node has a live claimant, race %d"%race)
	if not victim.is_empty():victim.hp=0
	var before=int(ore.amount)
	tick(c,100)
	check(int(ore.amount)<before,"dead claimant releases node for another miner, race %d"%race)

func resource_bodies(race: int) -> void:
	for type in ["as","tera"]:
		var c=arena(race)
		var node=mineral(c,Vector2(48,45),type)
		var body=ACCore.resource_rect(node)
		var center=ACData.point(node.pos)
		check(body.get_center()==center,"%s collider uses resource ground center"%type)
		check(body.size==(Vector2(2,1) if type=="as" else Vector2(4,2)),"%s collider has SC1 build-tile dimensions"%type)
		var soldier=c.add_unit(0,1,Vector2(39,45))
		check(not c._unit_fits(soldier,Vector2(48,45),false),"ground body cannot occupy %s, race %d"%[type,race])
		var air_kind=0
		for kind in range(13):
			if ACData.unit(race,kind).air:air_kind=kind;break
		var aircraft=c.add_unit(0,air_kind,center)
		check(ACData.point(aircraft.pos)==center and c._unit_fits(aircraft,center,false),"aircraft may fly above %s, race %d"%[type,race])
		c.command(0,{"type":"move","ids":[soldier.id],"pos":[57,45]})
		var crossed_body=0
		for _i in range(240):
			tick(c)
			if ACCore.collision_rect(soldier).intersects(body):crossed_body+=1
		check(crossed_body==0,"moving ground AABB never cuts through %s, race %d"%[type,race])
		check(ACData.point(soldier.pos).x>54,"ground unit routes around %s, race %d"%[type,race])
		node.amount=0
		c._sync_resource_obstacles()
		check(c._unit_fits(soldier,Vector2(48,45),false)==(type=="as"),"depleted As releases ground; depleted Tera retains vent, race %d"%race)

func refinery_snapping(race: int) -> void:
	var c=arena(race)
	var vent=mineral(c,Vector2(42,35),"tera",100)
	var worker=c.add_unit(0,0,Vector2(37,35))
	var anchor=c.refinery_anchor(vent)
	check(anchor==Vector2(41,35),"4x2 refinery anchor is vent center minus (1.5,.5), race %d"%race)
	check(c.refinery_anchor(int(vent.id))==anchor,"refinery accepts resource ID anchor lookup")
	check(c.snap_refinery(0,anchor+Vector2(1,0))==anchor,"nearby preview snaps onto exact vent anchor, race %d"%race)
	check(not c.snap_refinery(0,Vector2(60,60)).is_finite(),"far preview never invents a refinery anchor, race %d"%race)
	check(c.placement(0,1,anchor)=="","exact refinery anchor is legal, race %d"%race)
	check(c.placement(0,1,anchor+Vector2(1,0))!="","adjacent refinery offset is rejected, race %d"%race)
	check(c.placement(0,1,anchor+Vector2(.1,0))!="","fractional refinery offset is rejected before floor, race %d"%race)
	c.players[0].as=1000;c.players[0].tera=1000
	var before=c.buildings.size()
	var error=c.command(0,{"type":"build","kind":1,"ids":[worker.id],"pos":ACData.packed(anchor+Vector2(.1,0))})
	check(error!="" and c.buildings.size()==before,"command cannot bypass exact anchor by flooring, race %d"%race)
	var refinery=c.add_building(0,1,anchor,true)
	c.map.reset_solids(c.buildings)
	check(c.placement(0,1,anchor)!="","a second extractor cannot occupy one vent, race %d"%race)
	tick(c,61)
	check(c.players[0].tera==1008 and refinery.tera_resource==vent.id,"exactly anchored extractor harvests automatically, race %d"%race)

func run() -> void:
	for race in range(3):
		worker_collision(race)
		mining_exclusivity(race)
		resource_bodies(race)
		refinery_snapping(race)
	print("RESOURCES_V03_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
