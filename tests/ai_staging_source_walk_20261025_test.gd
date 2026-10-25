extends SceneTree
const AI=preload("res://scripts/bot_ai.gd")
var records=[]
var failures=[]
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args();var level=int(args[0]) if not args.is_empty() else 5
	var maps=[int(args[1])] if args.size()>1 else range(3)
	for map_id in maps:
		for race in range(3):
			var c=ACCore.new();c.setup({"map":map_id,"seed":251025,"spawn_slots":[0,2],"players":[{"race":race,"bot":true,"difficulty":5},{"race":(race+1)%3}]})
			c.units.clear();c.collision_index_valid=false;c.ai_clock=100000;c.time=20
			var home=c.entity(c.players[0].home);var enemy=c.entity(c.players[1].home);var army=[]
			for i in range(int(AI.PROFILES[level].attack)):army.append(c.add_unit(0,[5,3,7][race] if i%4==3 else 1,c.center(home)+Vector2(3+i%5,4+i/5)))
			var first_wait=-1.0;var push=-1.0;var passable=true
			for tick in range(6000):
				c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._rebuild_collision_index()
				if tick%7==0:AI.combat(c,0,army,[home],[enemy],AI.PROFILES[level])
				for u in army:
					c._tick_unit(u,.05)
					passable=passable and c._ground_fits_size(c._body_size(u),c.center(u))
				c._separate_units(.05,false)
				if first_wait<0 and army.any(func(u):return u.order=="hold"):first_wait=c.time
				if not c.players[0].get("_ai_wave",[]).is_empty():push=c.time;break
			var r={"map":map_id,"race":race,"first_wait":first_wait,"push":push,"passable":passable,"stage":c.players[0]._ai_stage_pos,"units":army.map(func(u):return {"pos":u.pos,"goal":u.goal,"order":u.order,"blocked":u.blocked_clock})}
			records.append(r);print("SOURCE_STAGE ",JSON.stringify(r))
			if push<0 or not passable:failures.append("source staging walk %d:%d"%[map_id,race])
	var result={"passed":failures.is_empty(),"cases":records.size(),"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/ai-staging-20261025")
	FileAccess.open("res://build/ai-staging-20261025/source-walk%s.json"%("" if level==5 else "-level%d"%level),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("AI_SOURCE_STAGE ",JSON.stringify({"passed":result.passed,"cases":records.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
