extends SceneTree
## Exercises the real user-supplied MP3 through the production mixer.
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func run() -> void:
	var audio:=ACAudio.new()
	root.add_child(audio)
	await process_frame
	# Restrict lookup to embedded assets so a developer's external music folder
	# cannot hide a missing/remapped release track.
	audio.music_directories=["res://assets/music"]
	check(audio._music_tracks.has("music_r0") and not audio._music_tracks.has("music_r0.mp3"),"MP3 manifest uses the extension-independent runtime key")
	var source:=audio.music_source("music_r0")
	check(source.get("path","")=="res://assets/music/music_r0.mp3" and bool(source.get("embedded",false)),"approved embedded MP3 resolves through the production source lookup")
	var stream:=audio._music_stream("music_r0")
	check(stream is AudioStreamMP3 and absf(stream.get_length()-221.88)<.15,"real MP3 decodes to its complete 3m42s duration")
	if not stream is AudioStreamMP3:
		audio.queue_free()
		quit(1)
		return
	check(stream.loop and is_zero_approx(stream.loop_offset),"real MP3 loops from the beginning")
	check(not audio.set_music_context(-1),"empty menu slot stays silent")
	audio.set_channel_volumes(.35,.5,0.0)
	check(audio.set_music_context(0,.03) and audio.current_music_name=="music_r0","hyrax faction selects Ironbound Frontier")
	await create_timer(.12).timeout
	check(audio._music_player.playing and audio._music_player.bus==&"MUSIC" and audio._music_player.get_playback_position()>0.0,"real decoder advances on the independent MUSIC bus with SFX muted")
	audio._music_player.seek(stream.get_length()-.04)
	var deadline:=Time.get_ticks_msec()+2000
	await create_timer(.1).timeout
	while audio._music_player.playing and audio._music_player.get_playback_position()>=1.0 and Time.get_ticks_msec()<deadline:
		await create_timer(.05).timeout
	check(audio._music_player.playing and audio._music_player.get_playback_position()<1.0,"real MP3 wraps at the end without stopping (position %.3f, playing %s, driver %s)"%[audio._music_player.get_playback_position(),audio._music_player.playing,AudioServer.get_driver_name()])
	audio.set_channel_volumes(0,.5,.6)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"music mute is independent of effect volume")
	audio.set_channel_volumes(.42,.5,.6)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MUSIC"))-linear_to_db(.42))<.001,"music volume restores to the selected level")
	check(not audio.set_music_context(1) and not audio._music_player.playing and not audio._music_fade_player.playing,"unfilled citrus slot does not borrow hyrax music")
	check(not audio.set_music_context(2) and audio.current_music_name.is_empty(),"unfilled owl slot stays silent")
	audio.queue_free()
	await process_frame
	print("Supplied MP3 playback: %d checks, %d failures; duration %.3f s; driver %s"%[checks,failures.size(),stream.get_length(),AudioServer.get_driver_name()])
	stream=null
	await create_timer(.1).timeout
	quit(0 if failures.is_empty() else 1)
