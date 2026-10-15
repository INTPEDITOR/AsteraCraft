extends SceneTree

# Execute from an empty project directory so source imports cannot hide a bad pack.
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr(message)

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty() or not ProjectSettings.load_resource_pack(args[0]):
		printerr("Pass the exported PCK after --")
		quit(1)
		return
	var maps = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	check(maps is Dictionary, "Export contains the map manifest")
	if maps is Dictionary:
		check(maps.get("maps", []).size() == 3, "Export contains three original maps")
	for name in ["hud_materials_v3", "ui_hud_0", "ui_hud_1_native_v3", "ui_hud_2_native_v3", "title_logo_correct", "resource_icons_v3", "terrain_macro", "buildings_1_tree_v3", "buildings_1_tree_distinct_v3"]:
		var texture = ResourceLoader.load("res://assets/" + name + ".png")
		check(texture is Texture2D and texture.get_width() > 0, "Exported art: " + name)
	for race in range(3):
		var board=ResourceLoader.load("res://assets/modal_board_r%d_v3.png"%race)
		check(board is Texture2D,"Exported faction popup board")
		for state_name in ["normal", "hover", "pressed"]:
			var button = ResourceLoader.load("res://assets/ui_native/main_r%d_%s.png" % [race,state_name])
			check(button is Texture2D and button.get_size() == Vector2(320,76), "Exported native menu button")
			for extent in [Vector2i(220,48),Vector2i(300,48),Vector2i(220,44),Vector2i(300,44)]:
				var plate=ResourceLoader.load("res://assets/ui_native/modal_%dx%d_r%d_%s.png"%[extent.x,extent.y,race,state_name])
				check(plate is Texture2D and plate.get_size()==Vector2(extent),"Exported exact-native popup button")
		for kind in range(13):
			var motion = ResourceLoader.load("res://assets/motion/r%d_u%02d.png" % [race,kind])
			check(motion is Texture2D, "Exported motion: %d / %d" % [race,kind])
	var cache=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_cache_v04.json"))
	check(cache is Dictionary and cache.get("units",{}).size()==39,"Exported smooth-motion cache manifest")
	if cache is Dictionary:
		for key in cache.get("units",{}):
			var motion=ResourceLoader.load(String(cache.units[key].file))
			check(motion is Texture2D,"Exported smooth-motion atlas: "+key)
	var auxiliary=JSON.parse_string(FileAccess.get_file_as_string("res://data/aux_sprites_v04.json"))
	check(auxiliary is Dictionary,"Exported brood/projectile/plume manifest")
	if auxiliary is Dictionary:
		for key in ["brood","citrus_projectiles","tera_plume"]:
			var atlas=ResourceLoader.load(String(auxiliary.get(key,{}).get("file","")))
			check(atlas is Texture2D,"Exported auxiliary sprite: "+key)
	var cursor=ResourceLoader.load("res://assets/faction_cursors_v4.png")
	check(cursor is Texture2D,"Exported faction cursors")
	for name in ["NotoSansKR-VF.ttf","Orbitron-VF.ttf","Galmuri14.ttf"]:
		var font = ResourceLoader.load("res://assets/fonts/"+name)
		check(font is Font,"Exported bundled font: "+name)
	for name in ["OFL-NotoSansKR.txt","OFL-Orbitron.txt","OFL-Galmuri.txt"]:
		check(FileAccess.file_exists("res://assets/fonts/"+name),"Exported font license: "+name)
	var font_factory=ResourceLoader.load("res://scripts/ui_font.gd")
	check(font_factory!=null,"Exported shared UI font loader")
	if font_factory!=null:
		var font=font_factory.create()
		check(font is Font and font.has_char(0xac00) and font.get_string_size("승리 ASTERA 200",HORIZONTAL_ALIGNMENT_LEFT,-1,20).x>100,"Exported composite font renders Hangul and Latin")
	check(not FileAccess.file_exists("res://assets/fonts/Galmuri14.woff2"),"Unused unsupported WOFF2 is excluded from release pack")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for race in range(3):
		check(data.buildings[race][1].w == 4 and data.buildings[race][1].h == 2, "Exported 4x2 refinery")
	print("EXPORT_CONTENT_V04 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
