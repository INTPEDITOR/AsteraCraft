extends SceneTree
var main
var checks=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func frames(n: int=3) -> void:
	for i in range(n):await process_frame
func capture(file: String) -> void:
	main.queue_redraw()
	if is_instance_valid(main.world_canvas):main.world_canvas.queue_redraw()
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)
func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(5)
	main.settings.edge_scroll=false;main.set_process(false)
	main.account={"id":"p0","nickname":"QA","rating":1000,"nickname_confirmed":true};main.session_token="local-qa"
	main.room={"id":"qa-room","name":"4명 + 관전자 4명 검수","owner":"p0","map":0,"mode":"ffa","members":[]}
	for i in range(8):main.room.members.append({"user":"p%d"%i,"nickname":"참가자 %d"%i,"race":i%3,"team":i%2,"ready":i<4,"observer":i>=4})
	main._menus().room_menu();await frames(5)
	var menus=main._menus()
	check(menus.room_rows.size()==8,"eight lobby rows")
	check(main.race_select.get_combined_minimum_size().y<=37,"race selector fits 37px row")
	for i in range(7):
		var row=menus.room_rows[i].nickname.get_parent();var next=menus.room_rows[i+1].nickname.get_parent()
		check(row.position.y+row.size.y<=next.position.y,"lobby rows separated %d"%i)
	await capture("v052-lobby.png")
	for race in range(3):
		main._menus().close();main._start_local({"map":race,"seed":17,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true;main.spectator=true;main.set_process(false);main.camera=Vector2(64,64);main.zoom=1.0
		var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([])
		for fog in c.visibility:fog.fill(1)
		for fog in c.explored:fog.fill(1)
		var kinds=[8,9,10,11] if race==0 else ([10,11] if race==1 else [6,9,11,12])
		for row in range(kinds.size()):
			for column in range(8):
				var pos=main.screen_to_world(Vector2(190+column*145,110+row*115))
				var u=c.add_unit(0,kinds[row],pos);u.facing=ACData.packed(Vector2.UP.rotated(column*PI/4));u.order="hold"
		main.state=c.snapshot(-1);main._accept_visual_snapshot(main.state.units,0,true);main._update_hud();main._sync_world_canvas()
		await capture("v052-air-r%d.png"%race)
		check(main.state.units.size()==kinds.size()*8,"air eight-direction scene r%d"%race)
	# Layered missile vehicle, distinct hull and turret headings.
	main._start_local({"map":0,"players":[{"race":0},{"race":2}]});main.paused=true;main.set_process(false)
	main.spectator=true;main.camera=Vector2(64,64);main.zoom=1.1;main.core.units.clear();main.core.buildings.clear();main.core.map.reset_solids([])
	for i in range(8):
		var u=main.core.add_unit(0,6,main.screen_to_world(Vector2(250+i%4*270,200+i/4*230)))
		u.body_direction=ACData.packed(Vector2.UP.rotated(i*PI/4));u.facing=u.body_direction;u.turret_direction=ACData.packed(Vector2.RIGHT.rotated(i*PI/4))
	main.state=main.core.snapshot(-1);main._accept_visual_snapshot(main.state.units,0,true);main._update_hud();main._sync_world_canvas()
	await capture("v052-vehicle.png")
	var definition=ACData.unit(0,6);var original_extent=definition.visual_extent;definition.visual_extent=120
	var tips=func():
		main._world_transform()
		for u in main.state.units:
			var pos=ACData.point(u.pos);var target=pos+ACData.point(u.turret_direction)*10
			main.world_canvas.draw_circle(main._weapon_tip(u,pos,target),2.0,Color.CYAN)
	main.world_canvas.draw.connect(tips)
	await capture("v052-vehicle-closeup.png")
	main.world_canvas.draw.disconnect(tips);definition.visual_extent=original_extent
	main._start_local({"map":0,"players":[{"race":0},{"race":2}]});main.paused=true;main.set_process(false)
	main.camera=Vector2(64,64);main.zoom=1.2;main.core.units.clear()
	for fog in main.core.visibility:fog.fill(1)
	for fog in main.core.explored:fog.fill(1)
	var friendly=main.core.add_unit(0,7,main.screen_to_world(Vector2(550,350)));friendly.cloak_active=true;friendly.energy=50
	main.core.add_unit(1,10,main.screen_to_world(Vector2(850,350)))
	main.state=main.core.snapshot(0);main.selected=[friendly.id];main._accept_visual_snapshot(main.state.units,0,true);main._update_hud();main._sync_world_canvas()
	check(main.state.shimmers.size()==1,"undetected enemy shown only as shimmer")
	check(main.state.units.any(func(u):return u.id==friendly.id and u.cloaked),"friendly cloak remains translucent selectable unit")
	await capture("v052-cloak.png")
	main.spectator=true;main.state.ended=true;main.state.winners=[1];main._show_result();await frames(3)
	check(main._menus().modal.heading.text=="관전 종료","observer gets neutral result")
	check(main._menus().modal.content.get_node("ResultRating").text.contains("관전"),"observer no ladder result")
	await capture("v052-observer-result.png")
	print("VISUAL_V052 "+JSON.stringify({"checks":checks,"failures":failures}))
	main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
