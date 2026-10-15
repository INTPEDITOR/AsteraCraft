extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func run() -> void:
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/manifest.json"))
	check(manifest is Dictionary and manifest.tracks.size()==1 and manifest.tracks[0].file=="music_r0.mp3" and bool(manifest.tracks[0].user_supplied) and manifest.slots.size()==4 and bool(manifest.included_music),"release contains the approved hyrax MP3 and four replaceable user music slots")
	var audio:=ACAudio.new()
	root.add_child(audio)
	await process_frame
	check(audio.music_source("music_menu").is_empty(),"stale import caches cannot enable excluded preview music")
	var folder:="user://music-fixture-%d"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	audio.music_directories=[folder]
	check(not audio.set_music_context(-1) and audio.current_music_name.is_empty(),"an empty user slot stays silent")
	# A short existing SFX is a loader fixture, never release background music.
	var fixture:=FileAccess.get_file_as_bytes("res://assets/audio/heal_medic.wav")
	var names:=["music_menu","music_r0","music_r1","music_r2"]
	for name in names:
		var file:=FileAccess.open(folder.path_join(name+".wav"),FileAccess.WRITE)
		file.store_buffer(fixture)
		file.close()
		var stream:=audio._music_stream(name)
		check(stream is AudioStreamWAV and stream.get_length()>.6 and stream.mix_rate==44100,"external user WAV loads without a fixed production duration/rate: "+name)
		check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_begin==0 and stream.loop_end==roundi(stream.get_length()*stream.mix_rate),"external slot loops its own complete file: "+name)
	audio.set_channel_volumes(.37,.5,0.0)
	check(audio.set_music_context(-1,.04) and audio.current_music_name=="music_menu","custom main menu music plays independently of muted SFX")
	await create_timer(.08).timeout
	check(audio._music_player.bus==&"MUSIC" and audio._music_player.playing and not audio._music_fade_player.playing,"crossfade finishes with one MUSIC-bus player")
	var position:=audio._music_player.get_playback_position()
	check(audio.set_music_context(-1) and audio._music_player.get_playback_position()>=position-.01,"opening options does not restart the user's score")
	audio.set_paused(true)
	await create_timer(.05).timeout
	check(audio._music_player.playing and not audio._music_player.stream_paused,"options and replay pause preserve music")
	audio.set_paused(false)
	check(audio.set_music_context(1,.05) and audio.current_music_name=="music_r1" and audio._music_fade_player.playing,"race change crossfades to its own user file")
	await create_timer(.09).timeout
	audio.clear(true)
	audio.process_state({"time":9.0,"units":[],"buildings":[]},0,Vector2.ZERO,1)
	audio.process_state({"time":1.0,"units":[],"buildings":[]},0,Vector2.ZERO,1)
	check(audio._music_player.playing and audio.current_music_name=="music_r1","UI cleanup and replay seek preserve the active custom score")
	audio.set_channel_volumes(0,.5,.6)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"music slider controls the actual playback bus independently")
	audio._music_streams.erase("music_r2")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join("music_r2.wav")))
	check(not audio.set_music_context(2) and not audio._music_player.playing and not audio._music_fade_player.playing,"a missing race slot stops music instead of substituting another score")
	audio.clear()
	audio.queue_free()
	await process_frame
	await create_timer(.1).timeout
	for name in names:
		var file:=folder.path_join(name+".wav")
		if FileAccess.file_exists(file):DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("Optional user music: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
