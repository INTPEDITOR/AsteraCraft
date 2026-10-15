extends SceneTree
## Run from an empty --path, using this script's absolute path and -- PACK.pck.
## This prevents source-tree imported resources from hiding a broken export.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not ProjectSettings.load_resource_pack(args[0]):
		printerr("Audio export check: pass a readable PCK after --")
		quit(1)
		return
	var names: Array[String] = []
	for race in range(3):
		for kind in range(13):
			names.append("unit_%d_%d" % [race,kind])
		names.append("mine_%d" % race)
		names.append("explosion_%d" % race)
	for name in ["confirm","select","error","ready","build"]:
		names.append("ui_" + name)
	names.append("heal_medic")
	var paths: Array[String]=[]
	for name in names:paths.append("res://assets/audio/%s.wav"%name)
	var music_count:=0
	if FileAccess.file_exists("res://assets/music/manifest.json"):
		var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/manifest.json"))
		if manifest is Dictionary:
			for track in manifest.get("tracks",[]):
				paths.append("res://assets/music/"+str(track.file))
				music_count+=1
	var failures := 0
	var raw_present := 0
	var formats: Dictionary = {}
	for path in paths:
		if FileAccess.file_exists(path):
			raw_present += 1
		if not ResourceLoader.exists(path):
			printerr("Missing imported audio: " + path)
			failures += 1
			continue
		var stream = ResourceLoader.load(path)
		if path.begins_with("res://assets/music/"):
			if not stream is AudioStream or stream.get_length()<=0:failures+=1;printerr("Invalid user music: "+path)
			continue
		if not stream is AudioStreamWAV or stream.get_length() <= 0.0 or stream.data.is_empty():
			printerr("Invalid imported audio: " + path)
			failures += 1
		else:
			formats[int(stream.format)] = int(formats.get(int(stream.format),0)) + 1
	print("Exported audio: %d resources (51 SFX + %d optional user scores), %d failures, %d raw originals, formats %s" % [paths.size(),music_count,failures,raw_present,formats])
	quit(0 if failures == 0 else 1)
