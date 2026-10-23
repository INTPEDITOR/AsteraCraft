extends SceneTree
var main
var checks=0
var failures=[]
var report=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func frames(n=2):
	for _i in range(n):await process_frame
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	main.set_process(false)
	for race in range(3):
		main._begin_local({"map":race,"seed":925,"players":[{"race":race},{"race":(race+1)%3,"bot":true}]})
		check(main.page=="loading","loading shown before preparation race%d"%race)
		var count=0;var values=[];var prior=-1.0;var started=Time.get_ticks_msec()
		while main.loading_job!=null:
			var progress=float(main.loading_job.status().progress)
			check(progress>=prior,"actual preparation progress never reverses")
			prior=progress;values.append(progress);count+=1
			main._poll_loading();await frames(1)
			if count==12:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/player_colors_20261024/loading-r%d.png"%race)
			if Time.get_ticks_msec()-started>90000:check(false,"loader timeout");break
		main.paused=true
		check(main.page=="game","prepared game entered race%d"%race)
		check(count>3,"display continues throughout background work race%d"%race)
		check(not is_same(main.draw_map,main.core.map),"renderer map isolated from simulation thread")
		check(main.draw_map.source_info.get("origin","")=="source_chk_cv5_vf4","loading preserves original map routes")
		var cached=main.terrain_artist.cache_builds
		main._sync_world_canvas();await frames(3)
		check(main.terrain_artist.cache_builds==cached,"first playable frame reuses prepared terrain")
		report.append({"race":race,"display_frames":count,"milliseconds":Time.get_ticks_msec()-started,"progress_samples":values})
		main.state.surrender_requests=[{"bot":1,"recipient":0}];main._update_hud();await frames(3)
		var hud=main.battle_hud;hud._update_surrender_prompt();await frames()
		var area=hud.surrender_panel.get_rect()
		var clear=true
		for x in range(int(area.position.x),int(area.end.x)+1,2):clear=clear and area.end.y+20<=hud.body_top_at(x)
		check(clear,"surrender board clears complete HUD ornament race%d"%race)
		check(hud.surrender_panel.get_theme_stylebox("panel") is StyleBoxTexture,"race artwork on surrender board")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/player_colors_20261024/surrender-r%d.png"%race)
		var res={"id":999,"type":"tera","pos":[64.5,64.5],"amount":5000}
		var b={"id":998,"owner":0,"race":race,"kind":1,"progress":0.0,"pos":[63,64],"hp":10}
		main.state.resources=[res];main.state.buildings=[b]
		for progress in [0.0,.1,.5,.88]:
			b.progress=progress;check(is_equal_approx(main._catalyst_presence(res),1),"catalyst remains during construction")
		b.progress=.94;check(main._catalyst_presence(res)>0 and main._catalyst_presence(res)<1,"catalyst blends during final phase")
		b.progress=1.0;check(main._catalyst_presence(res)==0,"catalyst merges only at completion")
	# A remote client's local preparation alone must not leave the waiting screen.
	main.remote_game={"map":0};main._begin_remote_loading();main.state={"battle_ready":false}
	while main.loading_job!=null:main._poll_loading();await frames(1)
	main._poll_loading()
	check(main.page=="connecting" and not main.loading_authenticated,"connection/authentication waits for prepared map and actual network")
	check(not main.loading_result.is_empty(),"remote map uses real asynchronous preparation")
	var building_report=JSON.parse_string(FileAccess.get_file_as_string("res://docs/building-balance-20261024.json"))
	check(building_report.audit.size()==39,"all39 buildings included in durability comparison")
	for row in building_report.audit:
		var d=ACData.building(int(row.race),int(row.kind));check(d.hp>0 and d.shield>=0 and d.hp+d.shield==row.total_durability,"building durability published values match runtime")
	var output={"checks":checks,"failures":failures,"loading":report}
	FileAccess.open("res://build/player_colors_20261024/loading-ui.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("LOADING_UI checks=",checks," failures=",failures)
	main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
