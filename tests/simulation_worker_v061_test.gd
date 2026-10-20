extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=ACCore.new();c.setup({"map":0,"seed":611,"players":[{"race":0},{"race":1}]})
	var worker=ACSimulationWorker.new();worker.start(c)
	var ids=[];for u in c.units:if int(u.owner)==0 and int(u.kind)==0:ids.append(u.id)
	worker.command(0,{"type":"move","ids":ids,"pos":[60,60]})
	var failures=[];var counts=0;var max_poll=0;var previous={}
	for i in range(20):
		while not worker.submit(1,0):await process_frame
		var packet={}
		while packet.is_empty():
			var begin=Time.get_ticks_usec();packet=worker.poll();max_poll=maxi(max_poll,Time.get_ticks_usec()-begin)
			if packet.is_empty():await process_frame
		counts+=1
		if not previous.is_empty() and not is_equal_approx(float(previous.time),float(i)*.05):failures.append("prior snapshot mutated")
		previous=packet.state
		if packet.state.units.any(func(u):return u.has("path") or u.has("_definition")):failures.append("internal mutable state leaked")
	worker.stop()
	var core_unit=c.units[0];core_unit.skill_ready={"nuclear":12.0};core_unit.drone_queue=[{"left":8.0}]
	var isolated=c.snapshot(0);var captured=isolated.units.filter(func(u):return int(u.id)==int(core_unit.id))[0]
	core_unit.skill_ready.nuclear=99.0;core_unit.drone_queue[0].left=0.0
	if captured.skill_ready.nuclear!=12 or captured.drone_queue[0].left!=8:failures.append("mutable nested ability/production state leaked between worker and display")
	if absf(c.time-1.0)>.001:failures.append("fixed simulation time")
	if c.units.filter(func(u):return int(u.owner)==0 and u.order=="move").size()!=ids.size():failures.append("queued commands lost")
	var report={"packets":counts,"max_poll_us":max_poll,"failures":failures};print("SIMULATION_WORKER_V061 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
