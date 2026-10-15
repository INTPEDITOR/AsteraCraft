extends SceneTree

func _initialize() -> void:
	var assets=ACAssets.new()
	assets.load_all()
	# 39 playable definitions plus the physical citrus brood technical entity.
	var failed=assets.unit_frames.size()!=40 or not assets.unit_frames.has("1:13") or assets.motion_frames.size()!=39 or assets.building_frames.size()!=39 or assets.resource_frames.size()!=2 or assets.ground_textures.size()!=3 or assets.menu==null
	if assets.brood_frames.size()!=2 or assets.citrus_fx.size()!=6 or assets.tera_plumes.size()!=8:failed=true;printerr("Missing auxiliary v0.4 sprites")
	for race in range(3):
		for kind in range(13):
			if not assets.unit_frames.has("%d:%d"%[race,kind]):failed=true;printerr("Missing playable unit ",race,":",kind)
		for mode in ["default","move","attack"]:
			if not assets.cursor_frames.has("%d:%s"%[race,mode]):failed=true;printerr("Missing faction cursor ",race,":",mode)
	for name in ["ui_icons","command_buttons","menu_buttons","resources_v2","terrain_tiles","terrain_transitions","map_decor","effect_sprites","building_parts","buildings_1_v2"]:
		if not ResourceLoader.exists("res://assets/%s.png"%name):
			failed=true;printerr("Missing release art ",name)
	for race in range(3):
		var board="res://assets/modal_board_r%d_v3.png"%race
		if not ResourceLoader.exists(board):failed=true;printerr("Missing faction modal board ",race)
		for state_name in ["normal","hover","pressed"]:
			var button_path="res://assets/ui_native/main_r%d_%s.png"%[race,state_name]
			if not ResourceLoader.exists(button_path):failed=true;printerr("Missing native menu ",button_path)
			elif load(button_path).get_size()!=Vector2(320,76):failed=true;printerr("Wrong native menu size ",button_path)
			for extent in [Vector2i(220,48),Vector2i(300,48),Vector2i(220,44),Vector2i(300,44)]:
				var modal_path="res://assets/ui_native/modal_%dx%d_r%d_%s.png"%[extent.x,extent.y,race,state_name]
				if not ResourceLoader.exists(modal_path):failed=true;printerr("Missing native popup ",modal_path)
				elif load(modal_path).get_size()!=Vector2(extent):failed=true;printerr("Wrong native popup size ",modal_path)
		for pattern in ["menu_planet_%d","portraits_%d","ui_hud_%d"]:
			if not ResourceLoader.exists("res://assets/"+(pattern%race)+".png"):
				failed=true;printerr("Missing faction art ",pattern%race)
	var sounds: Array=[]
	for art in ["title_logo_correct","terrain_macro","buildings_1_tree_v3","buildings_1_tree_distinct_v3","ui_hud_1_native_v3","ui_hud_2_native_v3","hud_materials_v3"]:
		if not ResourceLoader.exists("res://assets/%s.png"%art):failed=true;printerr("Missing release art ",art)
	for face in ["NotoSansKR-VF.ttf","Orbitron-VF.ttf","Galmuri14.ttf"]:
		if not ResourceLoader.exists("res://assets/fonts/"+face):failed=true;printerr("Missing bundled UI font ",face)
	for license in ["OFL-NotoSansKR.txt","OFL-Orbitron.txt","OFL-Galmuri.txt"]:
		if not FileAccess.file_exists("res://assets/fonts/"+license):failed=true;printerr("Missing font license ",license)
	var interface_font=ACUIFont.create()
	if not interface_font.has_char(0xac00) or interface_font.get_string_size("승리 패배 ASTERA 200",HORIZONTAL_ALIGNMENT_LEFT,-1,20).x<=100:failed=true;printerr("Cannot render bundled UI font")
	for race in range(3):
		for kind in range(13):sounds.append("unit_%d_%d"%[race,kind])
		for prefix in ["mine","explosion"]:sounds.append("%s_%d"%[prefix,race])
	for action in ["build","confirm","error","ready","select"]:sounds.append("ui_"+action)
	sounds.append("heal_medic")
	var mixer=ACAudio.new()
	var sound_count=0
	for name in sounds:
		var stream=mixer._stream(name)
		if stream!=null and stream.get_length()>0:
			sound_count+=1
		else:failed=true;printerr("Cannot play release sound ",name)
	mixer.free()
	if sound_count!=51:failed=true;printerr("Missing release sound: ",sound_count,"/51")
	for key in assets.unit_frames:
		for frame in assets.unit_frames[key]:
			var texture: Texture2D=frame.texture
			if texture.get_width()<3 or texture.get_height()<3:failed=true;printerr("Invalid frame ",key)
	for key in assets.building_frames:
		var frame=assets.building_frames[key]
		if frame.get_width()<3 or frame.get_height()<3:failed=true;printerr("Invalid building ",key)
	var c=ACCore.new()
	c.setup({"map":2,"players":[{"race":2},{"race":1,"bot":true}]})
	for i in range(80):c.step(.05)
	if c.time<3.9 or c.snapshot(0).units.is_empty():failed=true
	print("PACK_TEST unit types=",assets.unit_frames.size()," motions=",assets.motion_frames.size()," buildings=",assets.building_frames.size()," sounds=",sound_count," failed=",failed)
	quit(1 if failed else 0)
