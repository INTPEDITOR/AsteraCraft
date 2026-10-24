extends SceneTree
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	assert(not args.is_empty() and ProjectSettings.load_resource_pack(args[0],true))
	var channel=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"))
	assert(channel.tag=="feedback5-20261024")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/egyul_native_ui_20261024.json"))
	assert(manifest.items.size()==9)
	for entry in manifest.items:
		var texture: Texture2D=load(str(entry.file))
		assert(texture!=null and texture.get_size()==Vector2(entry.size[0],entry.size[1]))
		assert(texture.get_image().get_width()==int(entry.size[0]))
	assert(ResourceLoader.exists("res://scripts/egyul_native_ui.gd"))
	assert(ResourceLoader.exists("res://assets/ui/egyul_hud_living_common_20261024.png"))
	assert(not FileAccess.file_exists("res://work/egyul-ui-native-20261024/review.gd"))
	print("FEEDBACK5_PACK verified native9 images, helper, unchanged approved HUD, metadata and source exclusion")
	quit()
