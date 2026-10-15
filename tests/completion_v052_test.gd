extends SceneTree
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func arena(race: int=0) -> ACCore:
	var c=ACCore.new()
	c.setup({"map":0,"seed":57,"players":[{"race":race},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear()
	c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c._sync_resource_obstacles();c.map.reset_solids([])
	c.players[0].home=c.add_building(0,0,Vector2(44,24),true).id
	c.players[1].home=c.add_building(1,0,Vector2(100,100),true).id
	c.players[0].as=5000;c.players[0].tera=5000
	c.map.reset_solids(c.buildings);c._recalculate_supply()
	return c
func tick(c: ACCore,n: int) -> void:
	for i in range(n):c.step(.05)
func order(c: ACCore,w: Dictionary,p: Vector2,queued: bool=false) -> String:
	return c.command(0,{"type":"build","kind":2,"ids":[w.id],"pos":ACData.packed(p),"queued":queued})
func run() -> void:
	for race in range(3):
		var c=arena(race);var w=c.add_unit(0,0,Vector2(35,35))
		check(order(c,w,Vector2(50,35))=="","long travel accepted r%d"%race)
		tick(c,20)
		check(c.buildings.size()==2 and c.players[0].as==5000,"no building or payment during real travel r%d"%race)
		check(ACData.point(w.pos).distance_to(Vector2(35,35))>1,"worker actually moves r%d"%race)
		for i in range(1000):
			tick(c,1)
			if c.buildings.size()>2:break
		check(c.buildings.size()==3 and c.players[0].as==5000-ACData.building(race,2).as,"arrival creates and pays exactly once r%d"%race)
		for scenario in ["dead","stop","blocked","poor"]:
			c=arena(race);w=c.add_unit(0,0,Vector2(35,35));order(c,w,Vector2(50,35));tick(c,10)
			if scenario=="dead":w.hp=0
			elif scenario=="stop":c.command(0,{"type":"stop","ids":[w.id]})
			elif scenario=="blocked":c.add_building(0,2,Vector2(50,35),true);c.map.reset_solids(c.buildings)
			else:c.players[0].as=0
			var count=c.buildings.size();var money=c.players[0].as
			tick(c,800)
			check(c.buildings.size()==count and c.players[0].as==money,"pending "+scenario+" never creates or charges r%d"%race)
	for race in [0,2]:
		var c=arena(race);var w=c.add_unit(0,0,Vector2(35,35))
		order(c,w,Vector2(40,35),true);order(c,w,Vector2(48,35),true)
		tick(c,2000)
		check(c.buildings.size()==4 and c.buildings.all(func(b):return b.progress>=1),"same worker completes Shift queue r%d"%race)
		check(c.players[0].as==5000-2*ACData.building(race,2).as,"Shift pays twice r%d"%race)
	var c=arena();var w=c.add_unit(0,0,Vector2(35,35));order(c,w,Vector2(40,35))
	while c.buildings.size()==2:tick(c,1)
	var b=c.buildings[-1];tick(c,20);c.command(0,{"type":"stop","ids":[w.id]});var progress=b.progress
	tick(c,20);check(b.progress==progress,"abandoned hyrax construction pauses")
	c.command(0,{"type":"context","ids":[w.id],"target":b.id,"pos":b.pos});tick(c,1000)
	check(b.progress==1,"abandoned construction resumes")
	var scout=c.add_unit(0,7,Vector2(35,35));scout.energy=50
	var enemy=c.add_unit(1,1,Vector2(36,35));var home=c.entity(c.players[0].home)
	load("res://scripts/bot_ai.gd").combat(c,0,[scout],[home],[enemy],{"attack":1,"retreat":.2})
	check(scout.cloak_active and scout.energy==25,"AI uses energy cloak")
	var audio=ACAudio.new();root.add_child(audio);await process_frame
	for race in range(3):
		for kind in range(13):
			var stream=audio._stream("death_%d_%d"%[race,kind])
			check(stream!=null and stream.get_length()>.6,"death audio %d:%d"%[race,kind])
	c=arena();var victim=c.add_unit(0,1,Vector2(35,35));var killer=c.add_unit(1,1,Vector2(36,35))
	c._damage(killer,victim,10000,false)
	var state=c.snapshot(-1);audio.process_state(state,0,Vector2(35,35),1)
	check(audio.last_cue=="death_0_1","fatal event plays unit death sound")
	var played=audio.debug_stats.played;audio.process_state(state,0,Vector2(35,35),1)
	check(audio.debug_stats.played==played,"repeated snapshot does not repeat death")
	audio.clear();audio.process_state(state,0,Vector2(110,110),1)
	check(audio.debug_stats.played==played,"distant death is inaudible")
	audio.clear();audio.queue_free();await process_frame
	print("COMPLETION_V052 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
