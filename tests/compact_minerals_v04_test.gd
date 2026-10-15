extends SceneTree

var checks=0
var failures: Array=[]
var rows: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)

func rect_gap(a: Rect2,b: Rect2) -> float:
	return Vector2(maxf(0,maxf(a.position.x-b.end.x,b.position.x-a.end.x)),maxf(0,maxf(a.position.y-b.end.y,b.position.y-a.end.y))).length()

func scenario(theme: int, rotation: int) -> void:
	var c=ACCore.new()
	var players: Array=[]
	for slot in range(4):players.append({"race":(slot+rotation)%3})
	c.setup({"map":theme,"seed":7400+theme*10+rotation,"spawn_slots":[0,1,2,3],"players":players})
	var main_ids={}
	var harvested={}
	for owner in range(4):
		var home=c.entity(c.players[owner].home)
		var nodes=c.map.resources.filter(func(node):return int(node.slot)==owner and node.type=="as" and c.map.bases[int(node.base)].main)
		check(nodes.size()==8,"compact main keeps eight minerals, map %d owner %d"%[theme,owner])
		main_ids[owner]=nodes.map(func(node):return int(node.id));harvested[owner]={}
		var bounds=ACCore.resource_rect(nodes[0])
		for node in nodes:
			var body=ACCore.resource_rect(node)
			bounds=bounds.merge(body)
			check(rect_gap(body,c.footprint(home))<=3.01,"every mineral body stays within three tiles of the new 4x3 headquarters")
			check(not body.intersects(c.footprint(home)),"compact minerals never overlap the headquarters")
			for other in nodes:
				if other.id>node.id:check(not body.intersects(ACCore.resource_rect(other)),"compact 2x1 mineral bodies never overlap")
		check(bounds.size.x<=14.01 and bounds.size.y<=4.01,"compact eight-node arc occupies at most 14x4 tiles")
		for extra in range(8):
			var canonical=c.map.start_worker_positions(0)[extra%4]+Vector2(0,1+int(extra/4))
			var worker=c.add_unit(owner,0,c.map.reflect(canonical,owner))
			worker.order="gather";worker.target=c.nearest_resource(ACData.point(worker.pos),"as",owner)
	var errors=0
	for _step in range(800):
		c.step(.05)
		var active={}
		for worker in c.units:
			if int(worker.kind)!=0:continue
			if worker.mining_state=="harvest":
				active[int(worker.target)]=int(active.get(int(worker.target),0))+1
				if int(worker.target) in main_ids[int(worker.owner)]:harvested[int(worker.owner)][int(worker.target)]=true
		for count in active.values():
			if int(count)>1:errors+=1
	check(errors==0,"compact main retains one active worker per node, map %d rotation %d"%[theme,rotation])
	var earned: Array=[]
	for owner in range(4):
		check(harvested[owner].size()==8,"twelve workers actually use every compact node, map %d race %d slot %d"%[theme,players[owner].race,owner])
		check(c.players[owner].gathered>=160,"compact line sustains repeated real deliveries, map %d race %d slot %d"%[theme,players[owner].race,owner])
		earned.append(c.players[owner].gathered)
	for node in c.map.resources:
		if node.type=="as":node.amount=0
	c._sync_resource_obstacles()
	for _step in range(700):c.step(.05)
	for owner in range(4):
		var workers=c.units.filter(func(unit):return int(unit.owner)==owner and int(unit.kind)==0)
		check(workers.size()==12 and workers.all(func(unit):return unit.carried==0 and unit.order=="idle"),"all final compact-line cargo reaches the HQ without blocked workers, map %d race %d slot %d"%[theme,players[owner].race,owner])
		check(workers.all(func(unit):return c._unit_fits(unit,ACData.point(unit.pos))),"depleted compact-line workers finish in valid separate bodies")
	var final_earnings=c.players.map(func(player):return player.gathered)
	for _step in range(100):c.step(.05)
	check(c.players.map(func(player):return player.gathered)==final_earnings and c.mining_claims.is_empty(),"depleted compact line neither produces phantom cargo nor retains reservations")
	rows.append({"map":theme,"rotation":rotation,"races":players.map(func(player):return player.race),"workers_per_owner":12,"harvested_nodes":harvested.values().map(func(ids):return ids.size()),"gathered_at_40_seconds":earned,"all_final_cargo_delivered":c.units.filter(func(unit):return int(unit.kind)==0).all(func(unit):return unit.carried==0 and unit.order=="idle")})
	print("COMPACT_MINERALS_ROW ",JSON.stringify(rows[-1]))

func run() -> void:
	for theme in range(3):
		for rotation in range(3):
			scenario(theme,rotation)
			await process_frame
	var report={"checks":checks,"failures":failures,"passed":failures.is_empty(),"maps_sha256":FileAccess.get_sha256("res://data/maps.json"),"results":rows}
	var output=FileAccess.open("res://build/compact-minerals-v04-audit.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "));output.close()
	print("COMPACT_MINERALS_V04_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
