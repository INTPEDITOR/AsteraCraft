extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/feedback4-20261024/edges/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var uniform=ACCore.new();uniform.setup({"map":0,"players":[{"race":0},{"race":1}]})
	uniform.map._visual_elevations.fill(30);uniform.map._visual_vertices.clear()
	var y0=-uniform.map._visual_vertex(Vector2i(0,0));var y1=16-uniform.map._visual_vertex(Vector2i(0,1))
	check(is_equal_approx(y1-y0,16),"north terrain triangles retain their real height instead of collapsing into a line")
	check(is_equal_approx(uniform.map._visual_vertex(Vector2i(0,0)),30),"true raised boundary height is preserved")
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	var points=[Vector2(64,0),Vector2(128,64),Vector2(64,128),Vector2(0,64),Vector2.ZERO,Vector2(128,0),Vector2(128,128),Vector2(0,128)]
	var records=[]
	for map_index in range(3):
		main._start_local({"map":map_index,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false);main.spectator=true
		var c=main.core;var before=hash([c.map.source_walk_masks,c.map.source_water_masks,c.map.height_map,c.map.resources]);c.units.clear();c.buildings.clear();main.selected=[];main.zoom=1.75
		for index in range(points.size()):
			main.camera=points[index];main._clamp_camera();main.state=c.snapshot(0);main._sync_world_canvas();main.queue_redraw();await frames(3)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"map%d-edge%d.png"%[map_index,index])
			check(main.camera.is_finite(),"finite edge camera map%d/%d"%[map_index,index])
			if index==2:
				var mini=main._mini_rect();check(absf(main._minimap_camera_rect(mini).end.y-(mini.end.y-1))<.1,"southern minimap outline reaches map border")
		check(hash([c.map.source_walk_masks,c.map.source_water_masks,c.map.height_map,c.map.resources])==before,"edge rendering preserves original walk/water/heights/resources map "+str(map_index))
		records.append({"map":map_index,"boundary_and_corner_screens":8,"source_data_unchanged":true})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"maps":records,"scope":"Raised edge geometry and24 actual rendered perimeter views; original navigation/water/height/resource data unchanged."}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("EDGE_RENDER ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
