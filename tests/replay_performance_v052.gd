extends SceneTree
func _initialize() -> void:
	var main=load("res://scripts/main.gd").new()
	var c=ACCore.new();c.setup({"map":0,"seed":17,"players":[{"race":0},{"race":2}]})
	for owner in range(2):
		for i in range(100):
			var u=c.add_unit(owner,9,Vector2(25+owner*55+i%10,25+i/10))
			u.order="move";u.goal=[60,60]
	main.replay_frames=[];main.replay_mode=true
	var encoding: Array=[];var decoding: Array=[];var total=0
	for frame in range(60):
		for i in range(4):c.step(.05)
		var state=c.snapshot(-1);var start=Time.get_ticks_usec()
		var packed=main._encode_replay_frame(state)
		encoding.append((Time.get_ticks_usec()-start)/1000.0);total+=packed.compressed.size();main.replay_frames.append(packed)
	for packed in main.replay_frames:
		var start=Time.get_ticks_usec();main._replay_state(packed);decoding.append((Time.get_ticks_usec()-start)/1000.0)
	main._begin_replay();main._tick_replay(.1)
	var unit=main.state.units[-1];var position=main._visual_position(unit)
	var smooth=position.is_finite() and main.replay_index==1
	encoding.sort();decoding.sort()
	var report={"units":c.units.size(),"frames":60,"interval":.2,"compressed_bytes":total,"encode_p95_ms":encoding[56],"decode_p95_ms":decoding[56],"interpolation":smooth}
	FileAccess.open("res://build/replay-performance-v052.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("REPLAY_PERFORMANCE_V052 "+JSON.stringify(report));main.free();quit(0 if smooth else 1)
