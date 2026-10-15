extends "res://tests/resources_ui_v03_test.gd"

# Rendering-only refresh for HUD art changes after the interaction tests pass.
# Resource amounts still come from actual worker / automatic extractor ticks.
func run() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	for race in range(3):
		main._start_local({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true
		main.settings.edge_scroll=false
		var core=main.core
		var ore: Dictionary={}
		var vent: Dictionary={}
		for node in core.map.resources:
			if node.type=="as" and ore.is_empty():ore=node
			if node.type=="tera" and vent.is_empty():vent=node
		if ore.is_empty() or vent.is_empty():printerr("Missing resource preview fixture");quit(1);return
		var workers: Array=[]
		for unit in core.units:
			if int(unit.owner)==0 and int(unit.kind)==0:workers.append(unit.id)
		core.command(0,{"type":"stop","ids":workers})
		core.command(0,{"type":"context","ids":[workers[0]],"target":ore.id,"pos":ore.pos})
		var before=float(ore.amount)
		for tick in range(400):
			core.step(.05)
			if float(ore.amount)<before:break
		main.state=core.snapshot(0)
		await focus_resource(ore)
		main._select_resource(main.state.resources.filter(func(node):return node.id==ore.id)[0])
		await capture("resources-race%d-as.png"%race)
		var origin=core.refinery_anchor(vent)
		if not origin.is_finite() or core.placement(0,1,origin)!="":printerr("Invalid refinery preview fixture");quit(1);return
		var refinery=core.add_building(0,1,origin,true)
		core.map.reset_solids(core.buildings)
		for tick in range(80):core.step(.05)
		main.state=core.snapshot(0)
		main.selected_resource=-1
		main.selected=[refinery.id]
		await focus_resource(vent)
		await capture("resources-race%d-tera.png"%race)
	print("RESOURCE_PREVIEW_V03 rendered=6 actual_mining_and_extraction=true")
	quit(0)
