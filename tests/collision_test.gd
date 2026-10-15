extends SceneTree

var failures: Array=[]
var checks=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func arena() -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":22441,"players":[{"race":0},{"race":2}]})
	c.units.clear()
	c.buildings.clear()
	c.map.terrain.fill(0)
	c.map.buildable_map.fill(1)
	c.map.resources.clear()
	c._sync_resource_obstacles()
	c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(8,8),true).id
	c.players[1].home=c.add_building(1,0,Vector2(115,115),true).id
	c.map.reset_solids(c.buildings)
	c.collision_index_valid=false
	c._update_vision()
	return c

func violations(c: ACCore) -> Dictionary:
	var result={"overlaps":0,"terrain":0}
	for a in c.units:
		if a.hp<=0 or a.container>=0 or ACCore.collision_layer(a.race,a.kind)!=ACCore.COLLISION_GROUND:continue
		var rect=ACCore.collision_rect(a)
		# The entire box must remain outside every blocked navigation cell.
		for x in range(int(floor(rect.position.x+.5)),int(ceil(rect.end.x+.5))):
			for y in range(int(floor(rect.position.y+.5)),int(ceil(rect.end.y+.5))):
				if not c.map.walkable(Vector2i(x,y)) and rect.intersects(Rect2(Vector2(x,y)-Vector2(.5,.5),Vector2.ONE)):
					result.terrain+=1
		for b in c.units:
			if b.id<=a.id or b.hp<=0 or b.container>=0 or ACCore.collision_layer(b.race,b.kind)!=ACCore.COLLISION_GROUND:continue
			if c._workers_can_overlap(a,b):continue
			var intersection=rect.intersection(ACCore.collision_rect(b))
			if intersection.size.x>.003 and intersection.size.y>.003:result.overlaps+=1
	return result

func simulate(c: ACCore, seconds: float, dt: float=.05) -> Dictionary:
	var invalid={"overlaps":0,"terrain":0}
	for i in range(ceili(seconds/dt)):
		c.step(dt)
		c.resolve_spells()
		var audit=violations(c)
		invalid.overlaps+=audit.overlaps
		invalid.terrain+=audit.terrain
	return invalid

func wall(c: ACCore, gap_low: int, gap_high: int) -> void:
	for x in range(50,56):
		for y in range(ACMap.SIZE):
			if y<gap_low or y>gap_high:c.map.terrain[y*ACMap.SIZE+x]=2
	c.map.reset_solids(c.buildings)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for race in range(3):
		for kind in range(13):
			var dimensions=ACCore.collision_size(race,kind)
			check(dimensions.x>0 and dimensions.y>0,"positive collision box %d/%d"%[race,kind])
			check(ACCore.collision_layer(race,kind)==(2 if ACData.unit(race,kind).air else 1),"correct collision layer %d/%d"%[race,kind])
	check(ACCore.collision_size(0,12).x>ACCore.collision_size(0,1).x*2,"fortress has a substantially larger body than infantry")
	var c=arena()
	var packed: Array=[]
	for i in range(12):packed.append(c.add_unit(0,1,Vector2(35,35)))
	check(violations(c).overlaps==0,"simultaneous spawns receive non-overlapping positions")
	var snapshot=c.snapshot()
	check(snapshot.units[0].collision_layer==1 and snapshot.units[0].collision_size.size()==2,"snapshots expose collision dimensions and layer")
	c=arena()
	var group: Array=[]
	for i in range(12):group.append(c.add_unit(0,1,Vector2(30+(i%3)*.9,35+int(i/3)*.9)).id)
	c.command(0,{"type":"move","ids":group,"pos":[42,40]})
	var audit=simulate(c,20)
	check(audit.overlaps==0,"twelve units never overlap while sharing one destination")
	check(audit.terrain==0,"group movement keeps complete boxes on valid ground")
	var arrived=group.filter(func(id):return ACData.point(c.entity(id).pos).distance_to(Vector2(42,40))<3).size()
	var idle=group.filter(func(id):return c.entity(id).order=="idle").size()
	check(arrived==12,"all twelve units gather near the destination")
	check(idle>=10,"crowded arrivals settle instead of walking forever")
	print("SAME_DEST arrived=",arrived," idle=",idle," audit=",audit)
	c=arena()
	var mixed: Array=[]
	for i in range(12):
		var kind=[1,2,3,5,6,7,12,1,2,3,5,6][i]
		mixed.append(c.add_unit(0,kind,Vector2(28+(i%4)*3,28+int(i/4)*3)).id)
	c.command(0,{"type":"move","ids":mixed,"pos":[45,43],"formation":true})
	audit=simulate(c,30)
	check(audit.overlaps==0 and audit.terrain==0,"mixed infantry and vehicles maintain distinct valid boxes")
	for id in mixed:
		var member=c.entity(id)
		if ACData.point(member.pos).distance_to(ACData.point(member.goal))>=3:print("MIXED_WAIT ",member)
	check(mixed.all(func(id):return ACData.point(c.entity(id).pos).distance_to(ACData.point(c.entity(id).goal))<3),"mixed-size formation reaches its own spaced destinations")
	c=arena()
	wall(c,43,45)
	var east: Array=[]
	var west: Array=[]
	for i in range(8):
		east.append(c.add_unit(0,1,Vector2(43+(i%4)*.8,43+int(i/4)*.8)).id)
		west.append(c.add_unit(0,1,Vector2(61+(i%4)*.8,43+int(i/4)*.8)).id)
	c.command(0,{"type":"move","ids":east,"pos":[68,44],"formation":true})
	c.command(0,{"type":"move","ids":west,"pos":[39,44],"formation":true})
	audit=simulate(c,30)
	var east_crossed=east.filter(func(id):return ACData.point(c.entity(id).pos).x>56).size()
	var west_crossed=west.filter(func(id):return ACData.point(c.entity(id).pos).x<50).size()
	check(audit.overlaps==0 and audit.terrain==0,"opposing traffic never overlaps or cuts water at a narrow ramp")
	check(east_crossed==8 and west_crossed==8,"opposing groups pass a narrow ramp without deadlock")
	print("RAMP east=",east_crossed," west=",west_crossed," audit=",audit)
	c=arena()
	wall(c,44,44)
	var east_unit=c.add_unit(0,1,Vector2(47,44))
	var west_unit=c.add_unit(0,1,Vector2(58,44))
	c.command(0,{"type":"move","ids":[east_unit.id],"pos":[61,44]})
	c.command(0,{"type":"move","ids":[west_unit.id],"pos":[44,44]})
	audit=simulate(c,18)
	check(audit.overlaps==0 and audit.terrain==0,"single-cell passage preserves body and terrain collision")
	check(ACData.point(east_unit.pos).x>56 and ACData.point(west_unit.pos).x<50,"two infantry pass a single-cell passage")
	print("SINGLE_FILE ",east_unit.pos," ",west_unit.pos)
	c=arena()
	var obstacle=c.add_building(0,4,Vector2(43,37),true)
	c.map.reset_solids(c.buildings)
	var heavy=c.add_unit(0,12,Vector2(35,39))
	c.command(0,{"type":"move","ids":[heavy.id],"pos":[53,39]})
	audit=simulate(c,28)
	check(audit.overlaps==0 and audit.terrain==0,"large vehicle follows a route with full building clearance")
	check(ACData.point(heavy.pos).x>49,"large vehicle navigates around a building")
	var ground=c.add_unit(0,1,Vector2(65,65))
	var air=c.add_unit(0,9,Vector2(65,65))
	check(ACData.point(ground.pos)==ACData.point(air.pos),"air and ground may occupy the same map coordinate")
	var flyer=c.add_unit(0,9,Vector2(65,65))
	flyer.pos=air.pos.duplicate()
	c.collision_index_valid=false
	simulate(c,2)
	check(not ACCore.units_overlap(air,flyer),"aircraft separate softly within their own layer")
	check(not ACCore.units_overlap(air,ground),"aircraft never collide with the ground layer")
	c=arena()
	var fixed=c.add_unit(0,5,Vector2(40,40))
	fixed.anchored=true
	var fixed_pos=fixed.pos.duplicate()
	var passing=c.add_unit(0,1,Vector2(35,40))
	c.command(0,{"type":"move","ids":[passing.id],"pos":[45,40]})
	audit=simulate(c,12)
	check(audit.overlaps==0 and fixed.pos==fixed_pos,"moving infantry respect an anchored unit's immovable body")
	check(ACData.point(passing.pos).x>43,"infantry route around an anchored siege unit")
	c=arena()
	var held=c.add_unit(0,1,Vector2(40,40))
	held.order="hold"
	var held_pos=held.pos.duplicate()
	var mover=c.add_unit(0,1,Vector2(35,40))
	c.command(0,{"type":"move","ids":[mover.id],"pos":[45,40]})
	audit=simulate(c,12)
	check(audit.overlaps==0 and held.pos==held_pos,"hold-position infantry remain solid stationary obstacles")
	check(ACData.point(mover.pos).x>43,"moving infantry find a route around a held unit")
	c=arena()
	var hq=c.add_building(0,0,Vector2(38,36),true)
	c.map.reset_solids(c.buildings)
	var ore={"id":100000,"pos":[31.0,37.0],"type":"as","amount":1500,"busy":0.0}
	c.map.resources.append(ore)
	c._sync_resource_obstacles()
	for i in range(8):
		var worker=c.add_unit(0,0,Vector2(28+(i%4),39+int(i/4)))
		worker.order="gather"
		worker.target=ore.id
	audit=simulate(c,28)
	check(audit.overlaps==0 and audit.terrain==0,"mining workers ignore unit bodies while respecting static collision")
	print("MINING_FLOW delivered=",c.players[0].gathered," extracted=",1500-ore.amount," claims=",c.mining_claims)
	var expected_min=floori((28.0-5.0)/ACCore.AS_INTERVAL)*ACCore.AS_AMOUNT
	check(c.players[0].gathered>=expected_min,"crowded miners sustain single-node extraction rate after approach and delivery")
	c=arena()
	var carrier=c.add_unit(0,11,Vector2(65,65))
	var riders: Array=[]
	for i in range(8):
		var rider=c.add_unit(0,1,Vector2(30+i,30))
		rider.container=carrier.id
		carrier.cargo.append(rider.id)
		riders.append(rider)
	c.command(0,{"type":"ability","ids":[carrier.id]})
	check(carrier.cargo.is_empty() and riders.all(func(r):return r.container<0),"transport unloads every passenger")
	check(violations(c).overlaps==0 and violations(c).terrain==0,"transport passengers unload into distinct valid boxes immediately")
	for rider in riders:
		rider.container=carrier.id
		carrier.cargo.append(rider.id)
	carrier.hp=0
	c.step(.05)
	check(riders.all(func(r):return r.container<0),"destroyed transport releases its passengers")
	check(violations(c).overlaps==0 and violations(c).terrain==0,"transport destruction cannot expose a frame of stacked passengers")
	c=arena()
	wall(c,44,44)
	var oversized=c.add_unit(0,12,Vector2(46,44))
	c.command(0,{"type":"move","ids":[oversized.id],"pos":[60,44]})
	audit=simulate(c,6)
	check(audit.terrain==0 and ACData.point(oversized.pos).x<50,"oversized bodies cannot squeeze through a physically narrower passage")
	print("COLLISION_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
