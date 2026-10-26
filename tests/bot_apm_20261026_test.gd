extends "res://tests/abilities_v060_test.gd"
func run():
	var records=[]
	for level in range(6):
		var c=arena();var p=c.players[0];p.difficulty=level
		var u=c.add_unit(0,1,Vector2(40,40));var count=0
		for tick in range(1200):
			c.time=(tick+1)*.05;c.bot_action_budget.begin(c,0);c.bot_planning_owner=0
			for attempt in range(10):
				if c.command(0,{"type":"hold","ids":[u.id]})=="":count+=1
			c.bot_planning_owner=-1
		var target=[50,100,150,200,250,300][level]
		check(count>=target-1 and count<=target+2,"actual one minute accepted AI commands match rate "+str(target))
		records.append({"level":level,"budget":target,"actual":count})
		var before=int(p._ai_actions_total);c.command(0,{"type":"stop","ids":[u.id]})
		check(int(p._ai_actions_total)==before,"human/test commands outside bot planning are excluded level "+str(level))
		if level==5:
			for tick in range(1200):
				c.time+=.05;u.fired=c.time;c.bot_action_budget.begin(c,0);c.bot_planning_owner=0
				for attempt in range(10):c.command(0,{"type":"hold","ids":[u.id]})
				c.bot_planning_owner=-1
			var combat=int(p._ai_actions_total)-before
			check(combat>=449 and combat<=452 and int(p._ai_apm_budget)==450,"Hell uses 450 commands per active combat minute")
			c.time+=10;c.bot_action_budget.begin(c,0);check(int(p._ai_apm_budget)==300,"Hell returns to 300 outside combat")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/bot-apm-20261026")
	FileAccess.open("res://build/bot-apm-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BOT_APM ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
