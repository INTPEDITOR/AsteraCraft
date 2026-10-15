extends SceneTree

var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)

func trial(race: int, kind: int, building: bool, offset: Vector2) -> void:
	var c=ACCore.new()
	c.setup({"seed":58,"spawn_slots":[0,2],"players":[{"race":race},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0)
	c._sync_resource_obstacles();c.map.reset_solids([])
	var attacker=c.add_unit(0,kind,Vector2(60,60)+offset)
	var target=c.add_building(1,0,Vector2(58,58),true) if building else c.add_unit(1,12,Vector2(60,60))
	target.hp=10000;target.shield=0;target.cooldown=1000
	if not building:target.anchored=true;target.order="hold"
	c.map.reset_solids(c.buildings)
	attacker.order="attack";attacker.target=target.id;c.visibility[0].fill(1)
	for _step in range(400):
		c.time+=.05;c.paths_this_tick=0
		c._tick_unit(attacker,.05)
		if attacker.fired>=0:break
	var definition=ACData.unit(race,kind)
	var allowed_range=float(definition.range)+(minf(ACData.building(0,0).w,ACData.building(0,0).h)*.45 if building else 0.0)
	var in_reach=c.center(attacker).distance_to(c.center(target))<=allowed_range+.002 or c.combat_body_gap(attacker,target)<=.122
	if attacker.fired<0:print("MELEE_PENDING ",race,"/",kind," target=",building," origin=",offset," pos=",attacker.pos," gap=",c.combat_body_gap(attacker,target)," goal=",c._melee_approach(attacker,target)," path=",attacker.path.slice(0,3)," blocked=",attacker.blocked_clock)
	check(attacker.fired>=0 and target.hp<10000 and in_reach,"melee reaches a large %s from %s without an impossible center-distance requirement, race %d kind %d"%["building" if building else "vehicle",offset,race,kind])
	var overlaps=ACCore.collision_rect(attacker).intersects(c.footprint(target)) if building and not definition.air else ACCore.units_overlap(attacker,target) if not building else false
	check(not overlaps,"melee attack preserves independent physical bodies, race %d kind %d %s %s"%[race,kind,building,offset])

func run() -> void:
	for race in range(3):
		for kind in range(13):
			var definition=ACData.unit(race,kind)
			if definition.damage<=0 or definition.range>1.5:continue
			for building in [false,true]:
				for offset in [Vector2(-5,0),Vector2(0,-5),Vector2(-5,-5)]:trial(race,kind,building,offset)
	print("MELEE_CONTACT_V04_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
