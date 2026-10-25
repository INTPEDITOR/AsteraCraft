extends SceneTree
var main: Control
var failures=[]
var checks=0
var OUT="res://build/feedback10-visual/"
func _initialize():
	if not OS.get_cmdline_user_args().is_empty():OUT=OS.get_cmdline_user_args()[0].trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT);call_deferred("run")
func frames(count=3):
	for i in range(count):await process_frame
func check(value,message):
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func capture(file):
	main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+file)
func run():
	main=load("res://scripts/main.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(5);main.set_process(false)
	main.set_process_input(false);main.set_process_unhandled_input(false)
	for connection in root.mouse_exited.get_connections():
		if connection.callable.get_object()==main:root.mouse_exited.disconnect(connection.callable)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames()
	main._main_menu();main._menus().single();await frames()
	var select: OptionButton
	for child in main.menu_pages.modal.content.get_children():
		if child is OptionButton and child.item_count==6 and child.get_item_text(5)=="헬":select=child
	check(select!=null,"all six difficulty entries are displayed")
	if select!=null:
		for i in range(6):
			select.select(i);select.item_selected.emit(i)
			check(main.difficulty==i,"selected difficulty is forwarded "+str(i))
		select.show_popup();await frames();await capture("six-difficulties.png");select.get_popup().hide()
	for race in range(3):
		main._start_local({"map":0,"players":[{"race":race},{"race":(race+1)%3}]});main._stop_simulation_worker();main.set_process(false)
		var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		var field=Vector2.INF
		for y in range(30,100,3):
			for x in range(30,100,3):
				if c._ground_fits_size(Vector2(14,12),Vector2(x,y)):field=Vector2(x,y);break
			if field.is_finite():break
		var d=ACData.building(race,2)
		c.add_building(0,2,field,true);c.add_building(0,2,field+Vector2(d.w,0),true);c.map.reset_solids(c.buildings)
		var pos=field+Vector2(float(d.w)-.5,(float(d.h)-1)*.5)
		var u=c.add_unit(0,0,pos)
		check(c._unit_fits(u,pos,false),"actual displayed worker fits own shared edge "+str(race))
		c._update_vision();c.visibility[0].fill(1);c.explored[0].fill(1);c.vision_revisions[0]=int(c.vision_revisions.get(0,0))+1
		main.selected=[u.id];main.camera=pos;main.zoom=1.7
		main.camera.y-=(main._view_rect().get_center().y+24*main.zoom-main._ground_point(main.camera).y)/(32*main.zoom)
		main.state=c.snapshot(0);main._accept_visual_snapshot(main.state.units,c.time,true);main.battle_hud.update_hud(true);main._sync_world_canvas()
		await capture("worker-passage-r%d.png"%race)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual menu and worker/building renderer, 1920x1080; deterministic paused QA scene."}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FEEDBACK10_VISUAL ",JSON.stringify(result));main._release_pointer();quit(0 if failures.is_empty() else 1)
