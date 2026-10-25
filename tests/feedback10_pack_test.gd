extends SceneTree
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();assert(not args.is_empty() and ProjectSettings.load_resource_pack(args[0],true))
	var channel=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"));assert(channel.tag=="feedback10-20261025")
	assert(ACData.get_data().version=="0.6.4" and ACData.attack_range(ACData.unit(0,5),true)==12.0)
	assert(preload("res://scripts/bot_ai.gd").NAMES.size()==6)
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/egyul_native_ui_20261024.json"));assert(manifest.items.size()==12)
	for entry in manifest.items:
		var texture: Texture2D=load(str(entry.file));assert(texture!=null and texture.get_size()==Vector2(entry.size[0],entry.size[1]))
		assert(texture.get_image().get_width()==int(entry.size[0]))
	var hud: Texture2D=load("res://assets/ui/egyul_hud_flush_20261024.png");assert(hud.get_size()==Vector2(1600,269))
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/egyul_hud_flush_20261024.json"));assert(layout.body_profile.size()==1600)
	assert(ResourceLoader.exists("res://scripts/centered_button_caption.gd"))
	assert(not FileAccess.file_exists("res://work/button_gallery_20261024.gd"))
	var script=load("res://scripts/main.gd");var game=script.new();assert(not game.has_method("_save_replay") and not game.has_method("_replay_menu"))
	game.state={"time":1.0,"players":[]}
	var count=0
	for race in range(3):
		for kind in range(ACData.get_data().units[race].size()):
			if not ACData.unit(race,kind).air:continue
			var unit={"race":race,"kind":kind,"id":count+1,"owner":0};var first=game._air_hover_offset(unit)
			game.state.time=2.0;assert(first.distance_to(game._air_hover_offset(unit))>.01);game.state.time=1.0;count+=1
	assert(count==12 and game.CAMERA_EDGE_GUARD==2.0);game.free()
	var hud_script=load("res://scripts/rts_hud.gd");var hud_node=hud_script.new();assert(hud_node.has_method("world_view_bottom"));hud_node.free()
	print("FEEDBACK10_PACK verified native12 images, approved HUD, metadata, caption, replay removal, camera and aircraft12 hover without source fallback")
	quit()
