extends SceneTree
var checks=0
var failures: Array=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.5.3","exported project version")
	var game=JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	check(str(game.version)=="0.5.3","exported game version")
	check(game.units[1][1].as==50 and game.units[1][1].production_count==2,"exported shell claw pair cost")
	check(FileAccess.file_exists("res://data/original_maps.json"),"original terrain data bundled")
	check(load("res://assets/building_1_02_nutrient_v053.png") is Texture2D,"new nutrient sac bundled")
	check(ACData.unit_max_energy(1,8)==200,"parasite energy configured")
	for theme in range(3):
		var original=ACMap.new();original.make(theme)
		check(original.source_info.origin=="source_chk_cv5_vf4" and original.starts.size()==4,"original map runtime %d"%theme)
	var graphics=JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_v052.json"))
	for info in graphics.air.values():
		for file in info.frames:check(load(str(file)) is Texture2D,"bundled directional sprite "+str(file))
	for info in graphics.vehicle.frames:
		for part in ["chassis","turret"]:check(load(str(info[part])) is Texture2D,"bundled vehicle "+str(info[part]))
	for key in ["bodies","rotors"]:
		for file in graphics.drone[key]:check(load(str(file)) is Texture2D,"bundled unmanned drone "+str(file))
	var deaths=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/death_v052.json"))
	check(deaths.cues.size()==39,"39 death cues bundled")
	for clip in deaths.cues:
		var stream=load("res://assets/audio/"+str(clip.file))
		check(stream is AudioStream and stream.get_length()>.6,"bundled death "+str(clip.file))
	var voices=JSON.parse_string(FileAccess.get_file_as_string("res://data/voices_v05.json"))
	check(voices.clips.size()==442,"442 bundled voices")
	for clip in voices.clips:
		var stream=load(str(clip.file))
		check(stream is AudioStream and stream.get_length()>.25,"bundled audio "+str(clip.id))
	var repair=JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_repairs_v05.json"))
	for section in ["air","motions"]:
		for key in repair.get(section,{}):
			var info=repair[section][key]
			var file=str(info.get("file",info.get("texture","")))
			check(ResourceLoader.exists(file),"current repaired asset "+key)
	for path in ["res://assets/owl_buildings_repaired_v05.png","res://assets/terrain_faces_v05.png","res://assets/hyrax_fire_poses_v05.png"]:
		check(load(path) is Texture2D,"current graphic "+path)
	var main=load("res://scripts/main.gd").new()
	root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame;await process_frame
	check(main.audio.director!=null,"exported voice director starts")
	for race in range(3):
		main._start_local({"map":race,"seed":413,"players":[{"name":"Export QA","race":race},{"name":"Bot","race":(race+1)%3,"bot":true}]})
		main.paused=true;main.set_process(false);main.audio.set_paused(false)
		var low=main.core.add_unit(0,1,Vector2(62,62))
		var high=main.core.add_unit(0,12,Vector2(65,62))
		main.state=main.core.snapshot();main.selected=[low.id,high.id];main._update_hud()
		check(main._portrait_entity().id==high.id,"exported priority race %d"%race)
		main._selection_voice()
		check(main.audio.director.last_played=="r%d_u12_n0"%race,"exported selection voice")
		main.audio.director.reset();main._voice_error("테라가 부족합니다")
		check(main.audio.director.last_played=="r%d_ann_tera"%race,"exported narrator")
		for i in range(60):main.core.step(.05)
		check(main.core.time>=2.9,"exported match advances")
	main.audio.clear();main.queue_free();await process_frame;await process_frame
	print("RELEASE_V053 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

