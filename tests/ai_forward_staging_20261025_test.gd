extends SceneTree
const AI=preload("res://scripts/bot_ai.gd")
var checks=0
var failures=[]
var records=[]
func _initialize():call_deferred("run")
func check(value,label):
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func arena(race):
	var c=ACCore.new();c.setup({"map":0,"spawn_slots":[0,2],"players":[{"race":race,"difficulty":5,"bot":true},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c._sync_resource_obstacles()
	c.map.source_detail_active=false;c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.buildable_map.fill(1)
	c.map.reset_solids([]);c.collision_index_valid=false;c.ai_clock=100000
	var hq=c.add_building(0,0,Vector2(20,20),true);c.players[0].home=hq.id
	var enemy=c.add_building(1,0,Vector2(90,90),true)
	c.time=20
	return {"c":c,"hq":hq,"enemy":enemy}
func decide(a,army,visible=[]):AI.combat(a.c,0,army,[a.hq],visible,AI.PROFILES[5])
func run():
	for race in range(3):
		var a=arena(race);var c=a.c;var p=c.players[0];var army=[]
		for i in range(4):army.append(c.add_unit(0,5 if race==0 and i==3 else 1,Vector2(30+i*2,30)))
		decide(a,army,[a.enemy]);var stage=ACData.point(p._ai_stage_pos)
		check(p._ai_attack_phase=="assemble" and p._ai_wave.is_empty(),"forward assembly before push race %d"%race)
		check(stage.distance_to(c.center(a.enemy))>=15 and stage.distance_to(c.center(a.enemy))<=29 and stage.distance_to(c.center(a.hq))>40,"stage is near enemy, outside firing range")
		check(army.all(func(u):return u.order=="move" and ACData.point(u.goal).distance_to(stage)<7),"cohort moves to stable staging slots")
		var cohort=p._ai_cohort.duplicate();var slots=[]
		for u in army:slots.append(AI.staging_slot(c,p,u,stage,c.center(a.hq)))
		for i in range(3):army[i].pos=ACData.packed(slots[i])
		decide(a,army,[a.enemy])
		check(p._ai_cohort==cohort and p._ai_wave.is_empty(),"fast units keep same cohort and wait for slow unit")
		check(army.slice(0,3).all(func(u):return u.order=="hold"),"arrived units hold position")
		army[3].pos=ACData.packed(slots[3]);decide(a,army,[a.enemy])
		check(p._ai_wave.size()==4 and army.all(func(u):return u.order=="attack_move"),"complete cohort enters in one decision")
		var reinforcement=c.add_unit(0,1,Vector2(35,35));army.append(reinforcement);decide(a,army,[a.enemy])
		check(reinforcement.id not in p._ai_wave and reinforcement.order=="move" and ACData.point(reinforcement.goal).distance_to(stage)<7,"late reinforcement stages instead of feeding")
		for i in range(3):army.append(c.add_unit(0,1,Vector2(36+i*2,35)))
		decide(a,army,[a.enemy])
		for u in army.slice(4):u.pos=ACData.packed(AI.staging_slot(c,p,u,stage,c.center(a.hq)))
		decide(a,army,[a.enemy])
		check(p._ai_wave.size()==8,"next complete reinforcement cohort joins surviving attack")
		army[0].hp=1;army[0].damaged=c.time;decide(a,army,[a.enemy])
		check(army[0].id not in p._ai_wave and army[0].order=="move","wounded member leaves the committed wave")
		c.time+=6;decide(a,army,[a.enemy])
		check(army[0].id not in p._ai_wave and army[0].order in ["move","hold"],"recovering straggler stages with next cohort")
		for u in army.slice(1):u.hp=0
		decide(a,[army[0]],[a.enemy])
		check(p._ai_wave.is_empty() and army[0].order in ["move","hold"],"decimated wave regroups")
		var threat=c.add_unit(1,1,c.center(a.hq)+Vector2(8,0));decide(a,[army[0]],[threat,a.enemy])
		check(p._ai_attack_phase=="defend" and army[0].order=="attack_move" and ACData.point(army[0].goal).distance_to(c.center(threat))<1,"home defense preempts assembly")
		var danger=c.add_unit(1,1,stage)
		check(AI.forward_staging(c,[army[0]],c.center(a.hq),c.center(a.enemy),[a.enemy,danger],stage)!=stage,"visible threat invalidates unsafe staging point")
	# Real movement, no relocation: rifles must wait for a slower tank.
	var a=arena(0);var c=a.c;var army=[]
	for i in range(4):army.append(c.add_unit(0,5 if i==3 else 1,Vector2(45+i*2,45)))
	var held=false;var push_time=-1.0;var first_ready=-1.0;var passable=true
	for step in range(2600):
		c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index()
		if step%7==0:decide(a,army,[a.enemy])
		for u in army:
			c._tick_unit(u,.05)
			passable=passable and c._ground_fits_size(c._body_size(u),c.center(u))
		if army.slice(0,3).any(func(u):return u.order=="hold"):
			held=true
			if first_ready<0:first_ready=c.time
		if not c.players[0].get("_ai_wave",[]).is_empty():push_time=c.time;break
	check(held,"moving mixed-speed cohort waits at staging point")
	check(push_time>first_ready and first_ready>0,"push occurs after slower member arrives")
	check(passable and c.players[0].get("_ai_wave",[]).size()==4,"actual movement reaches staging without blocking")
	records.append({"first_wait":first_ready,"push":push_time,"wait_seconds":push_time-first_ready,"passable":passable})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/ai-staging-20261025")
	FileAccess.open("res://build/ai-staging-20261025/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_FORWARD_STAGING ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
