extends "res://tests/abilities_v060_test.gd"
const B=preload("res://scripts/bot_ai.gd")
const T=preload("res://scripts/bot_tactics.gd")
const M=preload("res://scripts/bot_missions.gd")
var records=[]

func fixture(race: int):
	var c=arena(race,(race+1)%3)
	c.map.source_detail_active=false;c.map.source_walk_masks.clear();c.map.source_water_masks.clear();c.map.height_map.fill(0);c.map.buildable_map.fill(1);c.map.reset_solids([])
	var p=c.players[0];p.difficulty=5;p.bot=false
	var hq=c.add_building(0,0,Vector2(12,12),true);p.home=hq.id
	c.add_building(1,0,Vector2(96,96),true)
	for kind in range(1,13):c.add_building(0,kind,Vector2(22+(kind%4)*7,16+floori(kind/4.0)*7),true)
	if race==2:
		for point in [Vector2(22,22),Vector2(40,22),Vector2(22,40),Vector2(40,40)]:c.add_building(0,2,point,true)
	for index in range(8):c.add_unit(0,0,Vector2(55+index,20))
	c.time=600;c.roots.update(c);c.time+=20;c.roots.update(c)
	p.as=10000;p.tera=10000;p.cap=200;p._ai_has_attacked=true
	c._rebuild_collision_index();c._update_vision()
	return c

func run() -> void:
	check(T.catalog().size()==75,"75 runtime plans available from exportable data")
	for race in range(3):
		var previous=[]
		for level in range(6):
			var ids=T.repertoire(race,level).map(func(t):return str(t.id))
			check(ids.size()==[3,6,12,18,23,25][level],"strictly growing repertoire race %d level %d"%[race,level])
			check(previous.all(func(id):return id in ids),"all previous tactics retained")
			previous=ids
	for plan in T.catalog():
		var c=fixture(int(plan.race));var p=c.players[0]
		var selected=T.activate(c,0,str(plan.id));p._ai_plan_next=1000000
		check(str(selected.id)==str(plan.id),"select approved "+str(plan.id))
		var before=Vector2(p.as,p.tera)
		B.tick(c,0)
		p._ai_next=0;c.time+=1;B.tick(c,0)
		var queued=[]
		for b in c.buildings:
			if int(b.owner)==0:queued.append_array(b.queue)
		check(queued.any(func(q):return int(q.kind) in plan.primary),"real primary production queued "+str(plan.id))
		check(Vector2(p.as,p.tera)!=before and p.as<=before.x and p.tera<=before.y,"real resources paid without grants "+str(plan.id))
		check(p.used+p.reserved<=200,"population respected "+str(plan.id))
		var counts=T.queued_counts(c,0)
		for kind in plan.primary:
			check(T.production_score(c,0,plan,int(kind),{},12)>0,"every primary participates in production mix %s/%d"%[plan.id,kind])
		var snap=c.snapshot(1)
		check(not snap.players[0].has("_ai_tactic") and not snap.players[0].has("_ai_sightings"),"enemy cannot read AI private plan "+str(plan.id))
		records.append({"id":plan.id,"queued":queued.map(func(q):return int(q.kind)),"spent":ACData.packed(before-Vector2(p.as,p.tera)),"style":plan.style})
	var c=fixture(0);var p=c.players[0];var army=c.units.filter(func(u):return u.owner==0 and u.kind>0)
	for fog in c.visibility:fog.fill(0)
	T.observe(c,0,[]);c.rng.seed=726;var first=T.choose(c,0,army).id
	p.erase("_ai_tactic");p.erase("_ai_plan_next")
	for index in range(8):c.add_unit(1,10,Vector2(110,110+index))
	T.observe(c,0,[]);c.rng.seed=726;var second=T.choose(c,0,army).id
	check(first==second and p._ai_sightings.is_empty(),"hidden army cannot influence plan selection")
	c.visibility[0].fill(2)
	var visible=c.units.filter(func(u):return int(u.owner)==1)
	T.observe(c,0,visible)
	check(float(p._ai_intel.air)>0,"visible air army enters scouting memory")
	check(T.selection_weight(c,0,T.by_id.N8,army)>T.selection_weight(c,0,T.by_id.N9,army),"scouted air army favors anti-air primary over ground siege")
	c.time+=200;T.observe(c,0,[])
	check(p._ai_sightings.is_empty(),"scouting memory expires instead of tracking hidden enemies forever")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"production_cases":records}
	DirAccess.make_dir_recursive_absolute("res://build/ai-tactics-20261026")
	FileAccess.open("res://build/ai-tactics-20261026/plans.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_TACTICS ",JSON.stringify({"passed":result.passed,"checks":checks,"cases":records.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
