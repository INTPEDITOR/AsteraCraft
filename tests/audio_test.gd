extends SceneTree

var failures: Array = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var audio := ACAudio.new()
	root.add_child(audio)
	await process_frame
	check(audio.get_child_count() == 25, "20 pooled effects, listener, music, voice and dialogue director")
	for race in range(3):
		for kind in range(13):
			var stream := audio._stream("unit_%d_%d" % [race,kind])
			check(stream != null and stream.get_length() >= 0.65, "unit %d/%d audio load" % [race,kind])
			# Godot 4.6 imports PCM16 WAV as compressed QOA by default. Both are
			# valid AudioStreamWAV playback resources; raw source format is checked
			# separately by the asset generator/PCM header validation.
			check(stream != null and stream.mix_rate == 44100 and not stream.data.is_empty(), "unit %d/%d playback format" % [race,kind])
		check(audio._stream("mine_%d" % race) != null, "mining sound race %d" % race)
		check(audio._stream("explosion_%d" % race) != null, "destruction sound race %d" % race)
	for name in ["confirm", "select", "error", "ready", "build"]:
		check(audio._stream("ui_" + name) != null, "UI sound " + name)
	check(audio._stream("does_not_exist") == null, "missing sound is safe")
	check(audio.play_ui("confirm"), "UI confirmation starts")
	check(not audio.play_ui("confirm"), "rapid UI duplication is throttled")
	audio.clear()
	var unit := {"id": 15,"race": 0,"kind": 1,"owner": 0,"pos": [18,18],"fired": 1.0,"container": -1}
	var shot := {"id": 1,"type": "shot","race": 0,"kind": 1,"unit": 15,"from": [18,18],"to": [20,20],"until": 1.3}
	var state := {"time": 1.0,"units": [unit],"effects": [shot]}
	var before := int(audio.debug_stats.played)
	audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played) == before+1, "timestamp and projectile share one muzzle report")
	audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played) == before+1, "repeated state does not duplicate the shot")
	unit.fired = 2.0
	state.time = 2.0
	state.effects = []
	audio.process_state(state,0,Vector2(118,118),.82)
	check(int(audio.debug_stats.played) == before+1, "distant offscreen shot is culled")
	var worker := {"id": 16,"race": 1,"kind": 0,"owner": 0,"pos": [18,18],"fired": -99.0,"container": -1,"order": "gather","action": "gather","moving": false,"gather_clock": .5,"carried": 0}
	state.units = [worker]
	state.time = 3.0
	audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played) == before+2, "worker mining starts")
	audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played) == before+2, "mining playback is rate limited")
	state.time = 3.9
	audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played) == before+3, "continued work repeats mining sound")
	var explicit := {"id": 2,"type": "harvest","race": 1,"kind": 0,"unit": 16,"from": [18,18],"to": [18,18],"until": 4.2}
	audio.consume_effects([explicit],3.9)
	check(int(audio.debug_stats.played) == before+3, "worker and harvest event share mining cooldown")
	for i in range(50):
		audio.play_unit(i%3,i%13,Vector2(18,18))
	var playing := 0
	var combat := 0
	for voice in audio._voices:
		if voice.player.playing:
			playing += 1
			if voice.group == "combat":
				combat += 1
	check(playing <= 20 and combat <= 12, "battle mixer stays inside 20 voices and 12 combat voices")
	audio.set_paused(true)
	before = int(audio.debug_stats.played)
	check(not audio.play_unit(0,1,Vector2(18,18)) and int(audio.debug_stats.played)==before,"paused battle starts no new sound")
	audio.set_paused(false)
	audio.set_volume(0.0)
	check(not audio.play_ui("ready"), "master volume mute prevents playback")
	audio.clear()
	playing = 0
	for voice in audio._voices:
		if voice.player.playing:
			playing += 1
	check(playing == 0 and audio._seen_effects.is_empty(), "cleanup stops voices and forgets old event IDs")
	print("Audio checks: %d; failures: %d" % [checks, failures.size()])
	audio.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
