extends "res://tests/view_input_v03_test.gd"
var records=[]
func nearest_role(map,role,target):
	var best=target;var distance=INF
	for y in range(18,110):
		for x in range(18,110):
			if map.visual_role(y*128+x)!=role:continue
			var p=Vector2(x+.5,y+.5);var d=p.distance_squared_to(target)
			if d<distance:best=p;distance=d
	return best
func photograph(theme,label,point,magnification=1.0):
	main.zoom=magnification;main.camera=point;main._clamp_camera()
	main._sync_world_canvas();main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	var file="map-%d-%s.png"%[theme,label]
	root.get_texture().get_image().save_png("res://build/map-photo-tour/"+file)
	records.append({"theme":theme,"area":label,"file":file,"camera":[main.camera.x,main.camera.y],"zoom":main.zoom})
func run():
	DirAccess.make_dir_recursive_absolute("res://build/map-photo-tour")
	root.size=Vector2i(1600,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	for theme in range(3):
		main._start_local({"map":theme,"seed":413,"players":[{"race":theme},{"race":(theme+1)%3}]})
		main.paused=true;main.set_process(false);main.spectator=true;main.state=main.core.snapshot();main._update_hud()
		var map=main.core.map
		await photograph(theme,"base",ACData.point(map.starts[0]))
		await photograph(theme,"center",Vector2(64,64))
		await photograph(theme,"water",nearest_role(map,2,Vector2(82,44)))
		var point=nearest_role(map,1,Vector2(42,84))
		if not map.visual_ramps.is_empty():
			var nearest=INF
			for ramp in map.visual_ramps:
				var d=ramp.center.distance_squared_to(Vector2(42,84))
				if d<nearest:nearest=d;point=ramp.center
		await photograph(theme,"cliff",point)
		var vent={};var nearest_vent=INF
		for resource in map.resources:
			if resource.type!="tera":continue
			var distance=ACData.point(resource.pos).distance_squared_to(Vector2(64,64))
			if distance<nearest_vent:nearest_vent=distance;vent=resource
		if not vent.is_empty():await photograph(theme,"tera",ACData.point(vent.pos),1.5)
	FileAccess.open("res://build/map-photo-tour/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	print("MAP_PHOTO_TOUR captured ",records.size()," real game views, terrain zoom 1 / Tera zoom 1.5, paused spectator view");quit()
