extends "res://tests/ai_missions_20261026_test.gd"

func run() -> void:
	var a=world(0);var c=a.c;var p=c.players[0];var plan=T.activate(c,0,"N1")
	var army=[]
	for index in range(16):army.append(c.add_unit(0,1,Vector2(30+index%4*2,28+index/4*2)))
	var hostile=c.add_unit(1,1,c.center(a.home)+Vector2(8,0))
	B.combat(c,0,army,[a.home],[hostile,a.enemy],B.PROFILES[5])
	check(p._ai_local_defense.size()==3 and p._ai_attack_phase!="defend","single scout receives a local squad instead of recalling the army")
	var sent=p._ai_local_defense.duplicate()
	for id in sent:
		var u=c.entity(int(id));u.path=[[44,44]];u.repath=100
	B.combat(c,0,army,[a.home],[hostile,a.enemy],B.PROFILES[5])
	check(sent.all(func(id):return c.entity(int(id)).path==[[44,44]] and c.entity(int(id)).repath==100),"repeated local defense preserves identical attack paths")
	var stage=ACData.point(p._ai_stage_pos)
	var intruder=c.add_unit(1,1,stage)
	check(B.forward_staging(c,army,c.center(a.home),c.center(a.enemy),[intruder],stage)==stage,"one roaming scout cannot drag a large staging army")
	var threats=[]
	for index in range(16):threats.append(c.add_unit(1,1,stage+Vector2(index%4,index/4)))
	check(B.forward_staging(c,army,c.center(a.home),c.center(a.enemy),threats,stage)!=stage,"a credible enemy army still invalidates unsafe assembly")
	var danger=c.add_unit(1,5,c.center(a.home)+Vector2(9,0))
	B.combat(c,0,army,[a.home],[danger,a.enemy],B.PROFILES[5])
	check(p._ai_attack_phase=="defend" and p._ai_wave.is_empty(),"enemy siege at home triggers full defense")
	# Public starting sites remain unknown enemy locations. Search the nearest
	# unsearched site, then continue without skipping a shrinking-list entry.
	a=world(0);c=a.c;p=c.players[0];T.activate(c,0,"N1")
	for index in range(5):c.add_unit(0,0,Vector2(15+index,46))
	c.visibility[0].fill(0);p._ai_sightings={}
	M.scout(c,0,[],c.center(a.home),false)
	var scout=c.entity(int(p._ai_scout));var goal=ACData.point(scout.goal)
	check(scout.kind==0 and scout.order=="move","Hell dispatches a real opening worker scout")
	c.visibility[0][ACMap.ground_cell(goal).y*128+ACMap.ground_cell(goal).x]=2
	c._set_unit_position(scout,goal);M.scout(c,0,[],c.center(a.home),false)
	var options=c.map.starts.map(func(s):return ACData.point(s)).filter(func(point):return point.distance_to(c.center(a.home))>20 and point.distance_to(goal)>1)
	options.sort_custom(func(x,y):return goal.distance_squared_to(x)<goal.distance_squared_to(y))
	check(ACData.point(scout.goal).distance_to(options[0])<.01,"scout searches nearest remaining public site without skipping one")
	# Fresh seen information may force a counter; random timer alone cannot
	# abandon an unfinished opening force before it attacks.
	var first=str(p._ai_tactic);p._ai_plan_started=0;p._ai_plan_next=0;c.time=300
	check(str(T.choose(c,0,[]).id)==first,"Hell retains its opening while assembling the first force")
	# Both assembly legs use actual movement, including a slow tank. Recruits
	# cannot depart one at a time, and the completed cohort still gathers in
	# front of the enemy before it receives its final attack order.
	a=world(0);c=a.c;c.time=100;p=c.players[0];plan=T.activate(c,0,"N5");army=[]
	for index in range(7):army.append(c.add_unit(0,5 if index==6 else 1,Vector2(20+index%3*2,55+index/3*2)))
	var first_march=-1.0;var first_push=-1.0;var first_count=0;var front_gap=0.0
	for tick in range(3000):
		c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index()
		if tick%6==0:
			var seen=[a.enemy];T.observe(c,0,seen);B.combat(c,0,army,[a.home],seen,B.PROFILES[5])
		for u in army:c._tick_unit(u,.05)
		c._separate_units(.05,false)
		if first_march<0 and not p.get("_ai_marching",[]).is_empty():first_march=c.time;first_count=p._ai_marching.size()
		if not p.get("_ai_wave",[]).is_empty():first_push=c.time;front_gap=ACData.point(p._ai_stage_pos).distance_to(c.center(a.enemy));break
	check(first_march>100 and first_count>=6,"six-member cohort physically forms before departure")
	check(first_push>first_march and front_gap>=15 and front_gap<=29,"cohort physically reaches enemy-front assembly before the group attack")
	# Dead members are not slow members. A previously formed six-body group
	# with four survivors waits, then enters together instead of stalling.
	a=world(0);c=a.c;c.time=100;p=c.players[0];plan=T.activate(c,0,"N1");army=[]
	for index in range(6):army.append(c.add_unit(0,1,Vector2(22+index,50)))
	T.observe(c,0,[a.enemy]);B.combat(c,0,army,[a.home],[a.enemy],B.PROFILES[5])
	for u in army:u.pos=p._ai_stage_slots[int(u.id)].pos.duplicate()
	B.combat(c,0,army,[a.home],[a.enemy],B.PROFILES[5])
	check(p._ai_marching.size()==6,"full six-body group has actually formed before attrition")
	army[4].hp=0;army[5].hp=0;army=army.slice(0,4)
	for u in army:u.pos=p._ai_stage_slots[int(u.id)].pos.duplicate()
	B.combat(c,0,army,[a.home],[a.enemy],B.PROFILES[5])
	check(p._ai_wave.is_empty(),"surviving quorum still waits for stragglers first")
	c.time+=16;B.combat(c,0,army,[a.home],[a.enemy],B.PROFILES[5])
	check(p._ai_wave.size()==4 and army.all(func(u):return u.order=="attack_move"),"four arrived survivors advance as a group after the real waiting interval")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/ai-tactics-20261026")
	FileAccess.open("res://build/ai-tactics-20261026/coordination.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_COORDINATION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
