extends SceneTree
var checks=0
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: "+label)
func run() -> void:
	for map_id in range(3):
		var c=ACCore.new();c.setup({"map":map_id,"players":[{"race":0},{"race":1},{"race":2}]})
		var own_workers=c.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==0)
		var choice=preload("res://scripts/bot_ai.gd").expansion_site(c,0,own_workers,c.entity(c.players[0].home))
		check(not choice.is_empty(),"AI can find a reachable source expansion map=%d"%map_id)
		if not choice.is_empty():
			var index=c.map.bases.find(choice.base)
			check(choice.pos==c.map.headquarters_sites[index],"AI prefers audited headquarters anchor map=%d"%map_id)
		if map_id!=0:continue
		var anchor=ACData.point(c.map.headquarters_sites[3]);var worker=ACSimulationWorker.new();worker.start(c)
		for race in range(3):
			for allowed in [false,true]:
				var point=anchor if allowed else anchor-Vector2(0,1)
				var key="%d:%s"%[race,allowed]
				worker.placement(race,0,point,key)
				check(worker.submit(0,race),"preview request submitted "+key)
				var response={};var started=Time.get_ticks_msec()
				while response.is_empty() and Time.get_ticks_msec()-started<10000:
					await process_frame;response=worker.poll()
				check(response.get("placement",{}).get("key","")==key and bool(response.get("placement",{}).get("valid",not allowed))==allowed,"background preview agrees with construction "+key)
		worker.stop()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/base-resource-spacing-20261025")
	FileAccess.open("res://build/base-resource-spacing-20261025/preview-worker.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASE_PREVIEW_WORKER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
