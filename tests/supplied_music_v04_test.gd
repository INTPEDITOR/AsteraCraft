extends SceneTree
## Real MP3 decoding, looping and transitions; also run against the release PCK.
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
	audio.music_directories=["res://assets/music"]
	var titles={"music_menu":"Echoes of Astera","music_r0":"Ironbound Frontier","music_r1":"Seeds of Dominion","music_r2":"Crimson Covenant"}
	check(audio._music_tracks.size()==4,"all four supplied tracks registered")
	audio.set_channel_volumes(.35,.5,0.0)
	for race in [-1,0,1,2]:
		var name="music_menu" if race<0 else "music_r%d"%race
		var info=audio._music_tracks.get(name,{})
		check(info.get("title","")==titles[name],"correct music assignment: "+name)
		var source=audio.music_source(name)
		check(source.get("path","")=="res://assets/music/"+name+".mp3" and source.get("embedded",false),"embedded source: "+name)
		var stream=audio._music_stream(name)
		check(stream is AudioStreamMP3,"real MP3 loads: "+name)
		if not stream is AudioStreamMP3:continue
		check(absf(stream.get_length()-float(info.get("seconds",0)))<.15 and stream.get_length()>200,"complete duration: "+name)
		check(stream.loop and is_zero_approx(stream.loop_offset),"full-track loop: "+name)
		check(audio.set_music_context(race,.03) and audio.current_music_name==name,"context starts supplied music: "+name)
		await create_timer(.15).timeout
		check(audio._music_player.playing and audio._music_player.get_playback_position()>0.0 and audio._music_player.bus==&"MUSIC","decoder advances with SFX muted: "+name)
		check(not audio._music_fade_player.playing,"previous track stops after crossfade: "+name)
		var position=audio._music_player.get_playback_position()
		audio.set_music_context(race)
		check(audio._music_player.get_playback_position()>=position-.01,"same context does not restart: "+name)
		audio._music_player.seek(stream.get_length()-.04)
		await create_timer(.2).timeout
		var deadline=Time.get_ticks_msec()+2000
		while audio._music_player.playing and audio._music_player.get_playback_position()>=1.0 and Time.get_ticks_msec()<deadline:
			await create_timer(.05).timeout
		check(audio._music_player.playing and audio._music_player.get_playback_position()<1.0,"decoder wraps without stopping: "+name)
	audio.set_channel_volumes(0,.5,.6)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"independent music mute")
	audio.set_channel_volumes(.42,.5,.6)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"MUSIC"))-linear_to_db(.42))<.001,"music volume restores")
	audio.set_music_context(-1,.03)
	await create_timer(.1).timeout
	check(audio.current_music_name=="music_menu" and audio._music_player.playing and not audio._music_fade_player.playing,"return to menu finishes transition")
	audio.stop_music();audio.queue_free()
	await process_frame
	await create_timer(.1).timeout
	print("Supplied MP3 playback: %d checks, %d failures; driver %s"%[checks,failures.size(),AudioServer.get_driver_name()])
	quit(0 if failures.is_empty() else 1)
