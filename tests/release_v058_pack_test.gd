extends SceneTree
var checks=0
var failures: Array=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var network=JSON.parse_string(FileAccess.get_file_as_string("res://data/public_network.json"))
	check(str(network.lobby_url).begins_with("https://"),"public HTTPS matchmaking endpoint bundled")
	# The extension is initialized and exercised by the exported-EXE P2P test.
	# A standalone editor loading a PCK does not auto-load its extension list.
	var terrain=ACTerrainRenderer.new();terrain.load_art()
	check(terrain.quiet_materials.size()==12 and terrain.scenery_textures.size()==90 and terrain.world_materials.size()==9,"new ground relief and scenery bundled")
	check(terrain.bank_materials.size()==15,"all modular cliff corner shoreline and ramp materials bundled")
	for theme in range(3):
		check(terrain.quiet_materials[theme*4].get_width()>=1024,"HD base floor bundled %d"%theme)
		check(terrain.world_materials[theme*3].texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"bank detail uses anisotropic filtering %d"%theme)
	check(terrain.DIAMOND_SIZE==Vector2(192,96),"larger diamond geometry bundled")
	for theme in range(3):
		var source_map=ACMap.new();source_map.make(theme)
		check(source_map.source_detail_active,"8px original walk geometry bundled %d"%theme)
		check(source_map.visual_ramps.size()==[12,6,4][theme],"all authored ramp regions bundled %d"%theme)
		var water_cells=0
		for i in range(128*128):
			if source_map.visual_role(i)==3 and source_map.is_water(i):water_cells+=1
		check(water_cells==[943,169,456][theme],"impassable obstacle interiors displayed as water %d"%theme)
		check(load("res://assets/tera_vent_%s_v058.png"%["frontier","basin","highland"][theme]) is Texture2D,"themed Tera art bundled")
		var terrain_renderer=ACTerrainRenderer.new()
		var rear=terrain_renderer._bank_section(source_map,Vector2(2048,2048),Vector2.UP,"height_bank")
		var front=terrain_renderer._bank_section(source_map,Vector2(2048,2048),Vector2.DOWN,"height_bank")
		check(rear.top.is_equal_approx(rear.bottom) and front.bottom.y>front.top.y,"exported cliff faces obey camera direction")
	check(ACMap.HQ_MINERAL_GAP==3.0,"headquarters mineral setback bundled")
	check(load("res://assets/citrus_root_ground_v058.png") is Texture2D,"citrus woody root ground art bundled")
	check(load("res://assets/menu_planet_1_roots_v058.png") is Texture2D,"new citrus planet menu art bundled")
	check(ACCore.TERA_INTERVAL==3.0,"faster Tera cycle bundled")
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.5.9","exported project version")
	var game=JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	check(str(game.version)=="0.5.9","exported game version")
	for file in ["citrus_bat_leaf_v059.png","portraits_0_faces_v059.png","portraits_1_faces_v059.png","portraits_2_faces_v059.png","game_icon.png"]:
		check(load("res://assets/"+file) is Texture2D,"new v059 asset bundled: "+file)
	check(game.units[1][1].as==50 and game.units[1][1].production_count==2,"exported shell claw pair cost")
	check(FileAccess.file_exists("res://data/original_maps.json"),"original terrain data bundled")
	check(load("res://assets/building_1_02_nutrient_v053.png") is Texture2D,"new nutrient sac bundled")
	check(ACData.unit_max_energy(1,8)==200,"parasite energy configured")
	for theme in range(3):
		var original=ACMap.new();original.make(theme)
		check(original.source_info.origin=="source_chk_cv5_vf4" and original.starts.size()==4,"original map runtime %d"%theme)
		check(original.visual_roles.size()==16384,"separate terrain visual roles bundled %d"%theme)
		if theme==0:check(original.visual_role(44*128+57)==3,"reported flat doodad remains an obstacle in the release")
	var source_maps=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	for map_data in source_maps.maps:
		for node in map_data.resources:
			check(ACData.point(node.pos).is_equal_approx(ACData.point(node.source_pos)-Vector2.ONE*.5),"source resource center conversion")
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
	if FileAccess.file_exists("res://data/voice_effects_v058.json"):
		var voice_fx=JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_effects_v058.json"))
		check(voice_fx.revision=="faction-radio-hive-telepathy-v1" and voice_fx.clips.size()==442,"faction voice effects manifest bundled")
		for info in voice_fx.clips:
			var voice_stream=load("res://assets/voices/%s.wav"%str(info.id))
			check(voice_stream is AudioStream and absf(voice_stream.get_length()-float(info.seconds))<.02,"processed voice duration bundled "+str(info.id))
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
	var hub=main.ui.get_node("MainHub")
	hub.choose_background(1)
	check(hub.art==load("res://assets/menu_planet_1_roots_v058.png"),"exported citrus menu selects new art")
	check(main.audio.director!=null,"exported voice director starts")
	check(main.audio.current_music_name=="music_menu" and main.audio._music_player.playing,"exported menu plays Echoes of Astera")
	for race in range(3):
		main._start_local({"map":race,"seed":413,"players":[{"name":"Export QA","race":race},{"name":"Bot","race":(race+1)%3,"bot":true}]})
		check(main.audio.current_music_name=="music_r%d"%race and main.audio._music_player.playing,"exported battle selects local faction music")
		var starters=main.core.units.filter(func(u):return u.owner==0 and u.kind==0)
		check(starters.size()==4 and starters.all(func(u):return u.order=="gather" and u.get("auto_mine_hq",-1)>=0 and u.target>=0),"exported starting automatic mining")
		main.paused=true;main.set_process(false);main.audio.set_paused(false)
		var low=main.core.add_unit(0,1,Vector2(62,62))
		var high=main.core.add_unit(0,12,Vector2(65,62))
		main.state=main.core.snapshot();main.selected=[low.id,high.id];main._update_hud()
		check(main.state.has("roots") and main.state.has("building_memory"),"exported root and last-seen building state bundled")
		var restored=bytes_to_var(var_to_bytes(main.state).compress(FileAccess.COMPRESSION_DEFLATE).decompress_dynamic(-1,FileAccess.COMPRESSION_DEFLATE))
		check(restored.roots==main.state.roots and restored.building_memory==main.state.building_memory,"root and fog memory survive network state encoding")
		check(main._portrait_entity().id==high.id,"exported priority race %d"%race)
		main._selection_voice()
		check(main.audio.director.last_played=="r%d_u12_n0"%race,"exported selection voice")
		main.audio.director.reset();main._voice_error("테라가 부족합니다")
		check(main.audio.director.last_played=="r%d_ann_tera"%race,"exported narrator")
		for i in range(60):main.core.step(.05)
		check(main.core.time>=2.9,"exported match advances")
	main.audio.clear();main.queue_free();await process_frame;await process_frame
	print("RELEASE_V058 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

