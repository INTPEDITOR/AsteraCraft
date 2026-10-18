extends "res://tests/map_photo_tour.gd"
func run():
	root.size=Vector2i(1600,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	for theme in range(3):
		main.network_client=false;main.local_slot=0
		main._start_local({"map":theme,"spawn_slots":[1,3],"players":[{"race":1},{"race":0}]})
		main.paused=true;main.set_process(false);main.spectator=true
		var core=main.core;var home=core.center(core.buildings[0])
		core.roots.update(core)
		for age in [0,4,16]:
			core.time=age;core.roots.update(core);main.state=core.snapshot(-1);main._update_hud()
			await photograph(theme,"roots-%ds"%age,home+Vector2(1,2),1.15)
		# Render a real viewer snapshot with roots visible but their source hidden.
		# First scout the whole rooted ground, including beneath the building.
		core.visibility[1].fill(1);core.snapshot(1)
		core.visibility[1].fill(0);core.explored[1].fill(1)
		for index in core.roots.current:
			var tile=ACRootField.ground_index(index)
			if Vector2(tile%128,tile/128).distance_to(home)>5:core.visibility[1][tile]=1
		main.state=core.snapshot(1);main.local_slot=1;main.network_client=true;main.spectator=false
		check(main.state.buildings.all(func(b):return b.race!=1),"enemy root source is absent from viewer snapshot")
		check(not main.state.roots.is_empty(),"visible roots survive without source entity")
		await photograph(theme,"roots-hidden-source",home+Vector2(5,2),1.15)
		core.visibility[1].fill(0);main.state=core.snapshot(1)
		await photograph(theme,"roots-remembered",home+Vector2(5,2),1.15)
	print("ROOT_GROWTH_VISUAL ",JSON.stringify({"checks":checks,"failures":failures,"captures":records.size()}));quit(0 if failures.is_empty() else 1)
