extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena(race):
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":race},{"race":0}]})
	c.players[0].as=10000;c.players[0].tera=10000
	return c
func _initialize():call_deferred("run")
func run():
	for race in range(3):
		var c=arena(race);var b=c.add_building(0,5 if race==1 else 6,Vector2(60,60),true)
		check(c.command(0,{"type":"research","id":b.id,"stat":"attack"})=="","start research")
		check(c.command(0,{"type":"research","id":b.id,"stat":"armor"})=="","queue different research")
		check(c.command(0,{"type":"research","id":b.id,"stat":"attack"})=="","queue next level")
		var before=float(c.players[0].as)
		check(c.command(0,{"type":"cancel_research","id":b.id,"queue_index":1})=="" and b.research_queue.size()==2,"cancel waiting research")
		check(c.players[0].as==before+100,"refund exact paid resources")
		ACResearch.tick(c,b,45)
		check(c.players[0].attack==1 and b.research=="attack" and b.research_queue.size()==1,"finish first and advance")
		check(c.command(0,{"type":"cancel","id":b.id})=="" and b.research=="","generic cancel current research")
		check(c.command(0,{"type":"research","id":b.id,"stat":"attack"})=="","requeue level after cancel")
		ACResearch.tick(c,b,60)
		check(c.players[0].attack==2,"research second level")
		c=arena(race)
		for building in c.buildings:
			if int(building.owner)==0:building.hp=0
		c._check_end();var deadline=float(c.players[0].hq_deadline)
		check(not c.players[0].lost and deadline==60,"workers can rebuild even with no buildings")
		c.time=59.99;c._check_end();check(not c.players[0].lost,"grace period")
		var hq=c.add_building(0,0,Vector2(60,60),false);hq.progress=.99
		c.time=60;c._check_end();check(c.players[0].lost,"unfinished HQ does not reset deadline")
		c=arena(race)
		for building in c.buildings:
			if int(building.owner)==0:building.hp=0
		c._check_end();c.time=50;c.add_building(0,0,Vector2(60,60),true);c._check_end()
		check(not c.players[0].lost and c.players[0].hq_deadline<0,"completed HQ clears countdown")
	var c=arena(1)
	var hq=c.buildings.filter(func(b):return b.owner==0 and b.kind==0)[0]
	for i in range(5):
		var pod=c.add_unit(0,13,c.center(hq)+Vector2(i,4));pod.brood_parent=hq.id;pod.brood_mother=hq.id;pod.brood_state="idle"
	c.players[0].cap=200
	for i in range(6):check(c.command(0,{"type":"train","id":hq.id,"kind":0})=="","more than five independent morphs")
	check(hq.queue.size()==6,"six concurrent morphs")
	var core=arena(0);core._update_vision();var revision=core.fog_revision
	core._update_vision();check(core.fog_revision==revision,"stationary vision reuses result")
	print("UPDATE_FOUNDATION ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
