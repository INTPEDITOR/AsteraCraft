extends SceneTree
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	assert(not args.is_empty() and ProjectSettings.load_resource_pack(args[0],true))
	var channel=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"))
	assert(channel.tag=="feedback4-20261024" and channel.built_at_unix>0)
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	assert(data.race_names==["노바너","이귤","아라아울"])
	var labs={"frontline_vitality":7,"missile_autoloader":9,"flamer_range":9,"transport_thrusters":10,"guardian_march":6,"golem_range":6}
	for research in data.research:
		if labs.has(research.id):assert(int(research.building)==labs[research.id])
	var files=["assets/ui/egyul_hud_living_common_20261024.png","assets/bomber_propulsion_20261024/hulls.png","assets/bomber_propulsion_20261024/exhaust.png","assets/ui/icon_fragment_fixes_20261024/commands_r0_16.png","assets/startup/title_three_factions_approved_20261024.png","assets/startup/zipza_games_original_20261024.png","assets/fonts/LevelUp-Regular.ttf","scripts/startup_screen.gd","scripts/game_updater.gd"]
	for file in files:assert(ResourceLoader.exists("res://"+file),file)
	var effects=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_effects_isolated_20261024.json"))
	assert(effects.frames.size()==128)
	for frame in effects.frames:assert(ResourceLoader.exists(frame.file),frame.file)
	var art=JSON.parse_string(FileAccess.get_file_as_string("res://data/loading_art_20261024.json"))
	assert(art.images.size()==30)
	assert(FileAccess.file_exists("res://data/windows_updater.txt"))
	assert(FileAccess.file_exists("res://assets/fonts/OFL-LevelUp.txt"))
	assert(not FileAccess.file_exists("res://work/egyul-hud-common-20261024/raw.png"))
	assert(not FileAccess.file_exists("res://build/terrain-metadata/jungle.vr4"))
	print("FEEDBACK4_PACK verified update metadata/Korean race names/research labs/approved living HUD/bomber layers/isolated icon/128 effects/title/LevelUp/updater; work/source data excluded")
	quit()
