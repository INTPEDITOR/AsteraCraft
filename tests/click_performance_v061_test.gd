extends SceneTree
func _initialize():
	var c=ACCore.new();c.setup({"map":0,"seed":611,"players":[{"race":0},{"race":0}]})
	var home=c.center(c.entity(c.players[0].home));var ids=[]
	for i in range(12):ids.append(c.add_unit(0,6,home+Vector2(8+i%4,5+i/4)).id)
	c.snapshot(0) # Match initialization prepares roots before interactive play.
	var frames=[];var commands=[];var slow=[]
	for click in range(80):
		var goal=home+Vector2(10+sin(click*.4)*7,10+cos(click*.4)*7)
		var start=Time.get_ticks_usec();c.command(0,{"type":"context","ids":ids,"pos":ACData.packed(goal),"target":-1,"formation":true});commands.append((Time.get_ticks_usec()-start)/1000.0)
		start=Time.get_ticks_usec();c.step(.05);var duration=(Time.get_ticks_usec()-start)/1000.0;frames.append(duration)
		if duration>25:slow.append({"click":click,"ms":duration,"path_us":c.path_time_this_tick,"paths":c.paths_this_tick})
	var times=frames.duplicate();times.sort();var command_times=commands.duplicate();command_times.sort()
	var report={"steps":frames.size(),"max_ms":times.back(),"p95_ms":times[75],"command_max_ms":command_times.back(),"slow":slow}
	FileAccess.open("res://build/qa-v061-click-performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CLICK_PERFORMANCE_V061 ",JSON.stringify(report));quit()
