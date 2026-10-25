extends "res://tests/view_input_v03_test.gd"
var records=[]
func run():
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.set_process(false);main.set_process_input(false);main.set_process_unhandled_input(false)
	for connection in root.mouse_exited.get_connections():
		if connection.callable.get_object()==main:root.mouse_exited.disconnect(connection.callable)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(3)
	var out="res://build/spacing3-20261025/native/";DirAccess.make_dir_recursive_absolute(out)
	for map_id in range(3):
		for race in range(3):
			main._start_local({"map":map_id,"players":[{"race":race},{"race":(race+1)%3}]});main._stop_simulation_worker();main.set_process(false);main.paused=true;main.settings.edge_scroll=false
			var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
			var site=c.map.bases.filter(func(b):return int(b.get("slot",-1))==(map_id+race)%4)[0]
			var index=c.map.bases.find(site);var anchor=ACData.point(c.map.headquarters_sites[index]);var hq=c.add_building(0,0,anchor,true)
			var gas=c.map.resources.filter(func(n):return n.id in site.resources and n.type=="tera")[0]
			var refinery=c.add_building(0,1,c.refinery_anchor(gas),true)
			var ore=INF
			for n in c.map.resources:
				if n.id in site.resources and n.type=="as" and n.amount>0:ore=minf(ore,ACMap.footprint_gap(c.footprint(hq),c.resource_rect(n)))
			var tera=ACMap.footprint_gap(c.footprint(hq),c.resource_rect(gas));var refined=ACMap.footprint_gap(c.footprint(hq),c.footprint(refinery))
			check(ore==3 and tera==3 and refined==3,"native HQ As3/Tera3/refinery3 map%d race%d"%[map_id,race])
			main.spectator=true;main.selected=[hq.id];main.camera=(c.center(hq)+ACData.point(gas.pos))*.5;main.zoom=1.2
			main.state=c.snapshot(0,true);main._accept_visual_snapshot(main.state.units,c.time,true);main._clamp_camera();main.battle_hud.update_hud(true);main._sync_world_canvas();main.queue_redraw()
			await frames(5);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"map%d-race%d.png"%[map_id,race])
			records.append({"map":map_id,"race":race,"anchor":ACData.packed(anchor),"as_gap":ore,"tera_gap":tera,"refinery_gap":refined})
	FileAccess.open(out+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"records":records},"\t"))
	main.queue_free();await frames(2);print("SPACING3_NATIVE ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
