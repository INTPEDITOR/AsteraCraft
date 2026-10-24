extends SceneTree
func _initialize() -> void:
	var args=OS.get_cmdline_user_args();assert(not args.is_empty() and ProjectSettings.load_resource_pack(args[0],true))
	var channel=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"));assert(channel.tag=="feedback6-20261024")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/egyul_native_ui_20261024.json"));assert(manifest.items.size()==12)
	for entry in manifest.items:
		var texture: Texture2D=load(str(entry.file));assert(texture!=null and texture.get_size()==Vector2(entry.size[0],entry.size[1]))
		assert(texture.get_image().get_width()==int(entry.size[0]))
	var hud: Texture2D=load("res://assets/ui/egyul_hud_flush_20261024.png");assert(hud.get_size()==Vector2(1600,269))
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/egyul_hud_flush_20261024.json"));assert(layout.body_profile.size()==1600)
	assert(ResourceLoader.exists("res://scripts/centered_button_caption.gd"))
	assert(not FileAccess.file_exists("res://work/button_gallery_20261024.gd"))
	var script=load("res://scripts/main.gd");var game=script.new();assert(not game.has_method("_save_replay") and not game.has_method("_replay_menu"));game.free()
	print("FEEDBACK6_PACK verified native12 images, approved HUD, metadata, caption and replay removal without source fallback")
	quit()
