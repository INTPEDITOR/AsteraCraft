extends SceneTree

var failures: Array=[]
var checks=0

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
	return c

func node(c: ACCore, pos: Vector2, type: String="as", amount: int=1500, initial: int=-1) -> Dictionary:
	var r={"id":100000+c.map.resources.size(),"pos":ACData.packed(pos),"type":type,"amount":amount,"busy":0.0}
	if initial>=0:r.initial_amount=initial
	c.map.resources.append(r)
	c._sync_resource_obstacles()
	return r

func tick(c: ACCore, count: int=1) -> void:
	for _i in range(count):
		c.step(.05)
		c.resolve_spells()

func resource_snapshot() -> void:
	var c=arena()
	var ore=node(c,Vector2(25.5,25),"as",73,1500)
	c.visibility[0].fill(0)
	var hidden=c.snapshot(0).resources[0]
	check(hidden.id==ore.id and hidden.initial_amount==1500,"snapshot retains resource identity and map-defined initial amount")
	check(hidden.amount==1500 and not hidden.amount_known and not hidden.visible,"never-seen resource exposes initial amount without current depletion")
	check(not hidden.depleted and hidden.collision_size==[2.0,1.0],"unseen depletion and collision schema use public/remembered information")
	# Reveal only the far footprint tile, rather than the center's first tile.
	c.visibility[0][25*ACMap.SIZE+26]=1
	var visible=c.snapshot(0).resources[0]
	check(visible.visible and visible.amount_known and visible.amount==73,"visibility of any occupied tile reveals the resource amount")
	c.visibility[0].fill(0)
	ore.amount=0
	c._sync_resource_obstacles()
	var stale=c.snapshot(0).resources[0]
	check(stale.amount==73 and not stale.depleted and not stale.visible,"fog preserves the last observed amount and cannot leak new exhaustion")
	var omniscient=c.snapshot().resources[0]
	check(omniscient.amount==0 and omniscient.depleted and omniscient.initial_amount==1500,"authoritative observer sees exhaustion without losing initial amount")
	c.visibility[0][25*ACMap.SIZE+26]=1
	var exhausted=c.snapshot(0).resources[0]
	check(exhausted.id==ore.id and exhausted.amount==0 and exhausted.depleted,"depleted As remains in snapshots under the same selectable ID")
	check(not exhausted.has("busy") and not exhausted.has("_worked_at"),"resource snapshot omits reservation internals")
	exhausted.pos[0]=0
	exhausted.collision_size[0]=100
	check(ACData.point(ore.pos)==Vector2(25.5,25) and ACCore.resource_rect(ore).size==Vector2(2,1),"editing a snapshot cannot move or resize an authoritative resource")
	var legacy=node(c,Vector2(60.5,60),"as",420)
	check(legacy.initial_amount==420,"legacy/custom resources initialize their own starting amount")
	legacy.amount=0
	c._sync_resource_obstacles()
	check(legacy.initial_amount==420,"initial amount stays fixed after exhaustion")

func exact_bodies_and_refineries(race: int) -> void:
	var c=arena(race)
	var ore=node(c,Vector2(70.5,45))
	var vent=node(c,Vector2(50.5,45.5),"tera",5000)
	for r in [ore,vent]:
		var rect=ACCore.resource_rect(r)
		var blocked=0
		for x in range(floori(rect.position.x)-1,ceili(rect.end.x)+1):
			for y in range(floori(rect.position.y)-1,ceili(rect.end.y)+1):
				if not c.map.walkable(Vector2i(x,y)):blocked+=1
		check(blocked==(2 if r.type=="as" else 8),"resource blocks exactly its SC1 build tiles, %s race %d"%[r.type,race])
		check(ACCore.resource_rect(r).get_center()==ACData.point(r.pos),"resource collision remains centered, %s race %d"%[r.type,race])
	var anchor=c.refinery_anchor(vent)
	check(anchor==Vector2(49,45),"even-sized Tera yields an exact integer building anchor, race %d"%race)
	check(c.placement(0,1,anchor,false)=="","exact 4x2 refinery may overlap only its own vent, race %d"%race)
	var refinery=c.add_building(0,1,anchor,true)
	c.map.reset_solids(c.buildings)
	check(c.footprint(refinery)==ACCore.resource_rect(vent),"refinery and vent occupy identical physical rectangles, race %d"%race)
	check(c.placement(0,2,Vector2(50,45),false)!="","ordinary building cannot occupy a catalyst deposit, race %d"%race)
	check(c.placement(0,1,anchor+Vector2(.5,0),false)!="","half-tile placement cannot silently floor onto a vent, race %d"%race)
	var malformed={"id":200000,"pos":[80,80],"type":"tera","amount":5000}
	check(not c.refinery_anchor(malformed).is_finite(),"misaligned vent cannot manufacture a rounded anchor, race %d"%race)
	var tera_before=c.players[0].tera
	tick(c,61)
	check(c.players[0].tera==tera_before+8 and vent.amount==4992,"4x2 extractor automatically credits its exact matched deposit, race %d"%race)
	var snap=c.snapshot().resources.filter(func(r):return r.id==vent.id)[0]
	check(snap.initial_amount==5000 and snap.collision_size==[4.0,2.0],"Tera snapshot carries initial reserve and physical size, race %d"%race)
	refinery.hp=0
	tick(c)
	check(not c.map.walkable(Vector2i(50,45)),"destroyed extractor leaves the gas vent collision intact, race %d"%race)

func dense_mining(race: int) -> void:
	var c=arena(race)
	var fields: Array=[]
	for i in range(8):fields.append(node(c,Vector2(42.5+i*2,29)))
	for i in range(12):
		var worker=c.add_unit(0,0,Vector2(42+i,32+int(i/8)))
		worker.order="gather"
		worker.target=fields[i%8].id
	var body_errors=0
	var claim_errors=0
	var harvested: Dictionary={}
	for _step in range(700):
		tick(c)
		var active: Dictionary={}
		for worker in c.units:
			for field in fields:
				if ACCore.collision_rect(worker).intersects(ACCore.resource_rect(field)):body_errors+=1
			if worker.mining_state=="harvest":
				active[worker.target]=int(active.get(worker.target,0))+1
				harvested[worker.target]=true
		for amount in active.values():
			if int(amount)>1:claim_errors+=1
	check(body_errors==0,"dense adjacent 2x1 minerals never overlap workers, race %d"%race)
	check(claim_errors==0,"dense mineral line retains one active miner per node, race %d"%race)
	check(harvested.size()>=6 and c.players[0].gathered>=64,"twelve workers use the dense mineral line and deliver repeated cargo, race %d"%race)
	for field in fields:field.amount=0
	c._sync_resource_obstacles()
	tick(c,500)
	for worker in c.units:
		if worker.carried>0 or worker.order!="idle":
			print("PENDING_CARGO race=",race," pos=",worker.pos," cargo=",worker.carried," goal=",worker.get("approach_goal",[])," fits=",c._unit_fits(worker,ACData.point(worker.pos))," path=",worker.path.slice(0,3)," gap=",c.body_footprint_gap(worker,c.entity(c.players[0].home)))
			for other in c.units:
				if other.id!=worker.id and ACData.point(other.pos).distance_to(ACData.point(worker.pos))<3:print(" CARGO_NEIGHBOR ",other.id," ",other.pos," ",other.order," cargo=",other.carried)
	check(c.units.all(func(u):return u.carried==0 and u.order=="idle"),"exhausted mineral line deposits final cargo and leaves workers idle, race %d"%race)
	check(c.mining_claims.is_empty(),"depleted mineral line releases every mining reservation, race %d"%race)
	check(c.map.walkable(Vector2i(42,29)) and c.map.walkable(Vector2i(57,29)),"depleted mineral line restores its entire navigation footprint, race %d"%race)
	var earned=c.players[0].gathered
	tick(c,100)
	check(c.players[0].gathered==earned,"exhausted workers cannot produce phantom resources, race %d"%race)

func leaving_mineral_passage() -> void:
	var c=arena()
	var ore=node(c,Vector2(45.5,40))
	var a=c.add_unit(0,0,Vector2(42,40))
	a.order="gather";a.target=ore.id
	var b=c.add_unit(0,0,Vector2(41,40))
	b.order="gather";b.target=ore.id
	# This overlap is legal while both workers are on the mineral shuttle.
	b.pos=a.pos.duplicate()
	c.collision_index_valid=false
	c._separate_units(.05,true)
	check(ACCore.units_overlap(a,b),"active mineral passage can retain a legal overlapping pair")
	c.command(0,{"type":"stop","ids":[a.id]})
	tick(c)
	check(not ACCore.units_overlap(a,b),"stopping a mineral worker restores physical separation on the next tick")
	check(c._unit_fits(a,ACData.point(a.pos)) and c._unit_fits(b,ACData.point(b.pos)),"leaving mineral passage never traps either worker inside a newly solid body")

func live_map_placements() -> void:
	for theme in range(3):
		var c=ACCore.new()
		c.setup({"map":theme,"spawn_slots":[0,1,2,3],"players":[{"race":0},{"race":1},{"race":2},{"race":0}]})
		var origin=c.footprint(c.entity(c.players[0].home)).get_center()
		for slot in range(4):
			var hq=c.entity(c.players[slot].home)
			check(c.footprint(hq).get_center()==c.map.reflect(origin,slot),"physical starting headquarters reflects exactly, map %d slot %d"%[theme,slot])
			var workers=c.units.filter(func(u):return u.owner==slot and int(u.kind)==0)
			var spawn_positions=c.map.start_worker_positions(slot)
			check(workers.size()==4 and workers.all(func(u):return ACData.point(u.pos) in spawn_positions),"starting workers preserve symmetric map spawn positions, map %d slot %d"%[theme,slot])
		for r in c.map.resources:
			check(r.initial_amount==(1500 if r.type=="as" else 5000),"new map resource starts at its declared reserve, map %d resource %d"%[theme,r.id])
			if r.type=="tera":
				var anchor=c.refinery_anchor(r)
				check(anchor.is_finite() and c.placement(0,1,anchor,false)=="","new map catalyst permits an exact 4x2 refinery, map %d resource %d"%[theme,r.id])

func run() -> void:
	resource_snapshot()
	leaving_mineral_passage()
	live_map_placements()
	for race in range(3):
		exact_bodies_and_refineries(race)
		dense_mining(race)
	print("RESOURCE_SNAPSHOT_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
