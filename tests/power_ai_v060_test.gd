extends SceneTree
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func arena(race=2):
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":race,"difficulty":1},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.source_detail_active=false
	c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.buildable_map.fill(1);c.map.reset_solids([]);c.collision_index_valid=false
	return c
func _initialize():
	var c=arena();var tower=c.add_building(0,2,Vector2(30,30),true)
	var factory=c.add_building(0,3,Vector2(35,30),true)
	var defense=c.add_building(0,11,Vector2(35,35),true)
	var enemy=c.add_unit(1,1,Vector2(39,36));var hp=enemy.hp
	factory.queue=[{"kind":1,"left":10.0,"total":10.0}]
	factory.research_queue=[{"kind":"attack","name":"test","level":1,"left":10.0,"total":10.0}]
	c._tick_building(factory,1)
	check(factory.queue[0].left==9 and factory.research_queue[0].left==9,"powered production and research progress normally")
	tower.hp=0;c._tick_building(factory,1);c._tick_building(defense,1)
	check(not factory.powered and factory.queue[0].left==9 and factory.research_queue[0].left==9,"lost tower fully pauses production and research without losing queues")
	check(not defense.powered and enemy.hp==hp,"unpowered defense tower cannot shoot")
	for kind in [0,1,2]:check(c.building_powered(c.add_building(0,kind,Vector2(90,50+kind*7),true)),"owl independent building %d"%kind)
	c.add_building(1,2,Vector2(30,30),true)
	check(not c.building_powered(factory),"enemy tower cannot supply power")
	var restored=c.add_building(0,2,Vector2(30,30),true);c._tick_building(factory,1)
	check(factory.powered and factory.queue[0].left==8 and factory.research_queue[0].left==8,"replacement tower resumes saved queues")
	var support=c.add_building(0,2,Vector2(35,31),true);restored.hp=0
	check(c.building_powered(factory),"overlapping surviving tower preserves power")
	support.progress=.5
	check(not c.building_powered(factory),"unfinished tower supplies no power")
	for level in range(3):
		c=arena(0);c.players[0].difficulty=level
		var hq=c.add_building(0,0,Vector2(20,20),true);c.players[0].home=hq.id
		var profile=load("res://scripts/bot_ai.gd").PROFILES[level]
		var rally=c.map.nearest_free(c.center(hq)+(Vector2(63.5,63.5)-c.center(hq)).normalized()*7)
		var army=[]
		for i in range(int(profile.attack)):army.append(c.add_unit(0,1,Vector2(40+i%5,40+i/5)))
		var ai=load("res://scripts/bot_ai.gd")
		ai.combat(c,0,army,[hq],[],profile)
		check(c.players[0]._ai_wave.is_empty() and army.all(func(u):return ACData.point(u.goal).distance_to(rally)<.01),"difficulty %d assembles scattered units before attacking"%level)
		for u in army:u.pos=ACData.packed(rally);u.order="idle"
		ai.combat(c,0,army,[hq],[],profile)
		check(c.players[0]._ai_wave.size()==army.size() and army.all(func(u):return ACData.point(u.goal).distance_to(rally)>10),"difficulty %d launches the assembled wave together"%level)
		var reinforcement=c.add_unit(0,1,Vector2(24,24));army.append(reinforcement)
		ai.combat(c,0,army,[hq],[],profile)
		check(not int(reinforcement.id) in c.players[0]._ai_wave and ACData.point(reinforcement.goal).distance_to(rally)<.01,"difficulty %d holds reinforcements for the next wave"%level)
		var threat=c.add_unit(1,1,c.center(hq)+Vector2(5,0));ai.combat(c,0,army,[hq],[threat],profile)
		check(c.players[0]._ai_wave.is_empty() and ACData.point(reinforcement.goal).distance_to(c.center(threat))<.01,"difficulty %d immediately responds to base threats"%level)
	# Use actual source navigation and resource layouts for all maps and races.
	var choices=0
	for map_id in range(3):
		for race in range(3):
			c=ACCore.new();c.setup({"map":map_id,"players":[{"race":race},{"race":0}]})
			var workers=c.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==0)
			var hq=c.entity(c.players[0].home)
			var site=load("res://scripts/bot_ai.gd").expansion_site(c,0,workers,hq)
			if site.is_empty():continue
			choices+=1;check(ACData.point(site.base.pos).distance_to(c.center(hq))<=48,"AI expands within a nearby base's reach %d:%d"%[map_id,race])
	check(choices>=6,"nearby expansion remains possible across actual maps")
	print("POWER_AI_V060 ",JSON.stringify({"checks":checks,"failures":failures,"expansion_choices":choices}));quit(0 if failures.is_empty() else 1)
