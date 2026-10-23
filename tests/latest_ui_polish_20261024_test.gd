extends SceneTree
var main
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func frames(n=2):
	for _i in range(n):await process_frame
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames();main.set_process(false)
	for race in range(3):
		main._show_loading(race,race,"loading");main.loading_screen.set_progress(.63,"지형 표면 준비 중");await frames(3)
		var s=main.loading_screen
		for item in [s.title,s.subtitle,s.phase,s.percent,s.bar]:
			check(item.position.x>=80 and item.get_rect().end.x<=s.board.size.x-80 and item.position.y>=60 and item.get_rect().end.y<=s.board.size.y-60,"loading contents inside thick frame race%d"%race)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://build/player_colors_20261024/loading-final-r%d.png"%race)
		main._start_local({"map":2,"seed":925,"players":[{"race":race},{"race":(race+1)%3,"bot":true}]});main.paused=true
		main.state.surrender_requests=[{"bot":1,"recipient":0}];main._update_hud();await frames(3);main.battle_hud._update_surrender_prompt();await frames()
		var hud=main.battle_hud;var style=hud.surrender_panel.get_theme_stylebox("panel");var area=hud.surrender_panel.get_rect()
		check(hud.race==race and style.texture==ACRaceUI.boards[race],"surrender artwork matches local race")
		check(hud.surrender_panel.get_child(0).position.x>=80 and hud.surrender_panel.get_child(0).position.y>=80,"surrender text avoids ornate border")
		var clear=true
		for x in range(int(area.position.x),int(area.end.x)+1,2):clear=clear and area.end.y+20<=hud.body_top_at(x)
		check(clear,"surrender board above entire HUD profile")
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://build/player_colors_20261024/surrender-final-r%d.png"%race)
	# Real mixer playback for each race: start, ongoing construction, completion.
	var audio=main.audio;audio.set_paused(false)
	for race in range(3):
		audio.clear(true);audio._camera=Vector2(64,64);audio._zoom=1
		var building={"id":900+race,"owner":0,"race":race,"kind":0,"pos":[62,62],"hp":200,"progress":.01}
		audio._construction_sounds([building],10)
		check(audio.last_cue=="construct_%d"%race,"race construction start audible cue")
		var start_voice=audio._voices.filter(func(v):return v.group=="construction_start" and v.player.playing)
		check(not start_voice.is_empty() and int(start_voice[0].priority)==3,"construction start wins over ordinary low-priority sounds")
		building.progress=.5;audio._construction_sounds([building],13)
		check(audio._voices.any(func(v):return v.group=="construction" and v.player.playing),"ongoing building cue repeats")
		building.progress=1;audio._construction_sounds([building],14)
		check(audio.last_cue=="construct_complete_%d"%race,"completion has distinct race cue")
		check(audio._voices.any(func(v):return v.group=="construction_finish" and v.priority==4 and v.player.playing),"completion cue survives combat pool priority")
	var result={"checks":checks,"failures":failures}
	FileAccess.open("res://build/player_colors_20261024/latest-ui-polish.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LATEST_UI_POLISH ",JSON.stringify(result));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
