extends SceneTree
var failures:=0
var checks:=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.audio.requested_music_name=="music_menu" and scene.audio.current_music_name.is_empty(),"actual main menu resolves its empty user slot without preview playback")
	scene._settings_menu()
	await process_frame
	check(scene.audio.current_music_name.is_empty() and not scene.audio._music_player.playing,"actual options preserve the silent default")
	scene._menus().close()
	var core:=ACCore.new()
	core.setup({"map":0,"spawn_slots":[0,2],"players":[{"race":2},{"race":0}]})
	scene.core=core
	scene.draw_map=core.map
	scene.local_slot=0
	scene.state=core.snapshot(0)
	scene._build_hud()
	check(scene.audio.requested_music_name=="music_r2" and scene.audio.current_music_name.is_empty(),"actual battle HUD chooses the local player's optional owl slot")
	scene._main_menu()
	check(scene.audio.requested_music_name=="music_menu" and scene.audio.current_music_name.is_empty(),"actual return to menu resolves the optional menu slot")
	core=ACCore.new()
	core.setup({"map":0,"spawn_slots":[1,3],"players":[{"race":0},{"race":1}]})
	scene.core=core
	scene.draw_map=core.map
	scene.local_slot=0
	scene.state=core.snapshot(0)
	scene._build_hud()
	await create_timer(.1).timeout
	check(scene.audio.current_music_name=="music_r0" and scene.audio._music_player.playing and scene.audio._music_player.stream is AudioStreamMP3,"actual hyrax battle starts the supplied MP3")
	var position: float=scene.audio._music_player.get_playback_position()
	scene._settings_menu()
	await create_timer(.1).timeout
	check(scene.audio.current_music_name=="music_r0" and scene.audio._music_player.playing and scene.audio._music_player.get_playback_position()>=position,"battle options preserve playback of the supplied song")
	scene._menus().close()
	scene._main_menu()
	check(scene.audio.current_music_name.is_empty() and not scene.audio._music_player.playing and not scene.audio._music_fade_player.playing,"returning from hyrax battle stops the song for the empty menu slot")
	scene.audio.stop_music()
	scene.queue_free()
	await process_frame
	await create_timer(.1).timeout
	print("Music actual-scene integration: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
