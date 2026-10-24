extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/font-layout-20261024/"
var measured=0
func validate_buttons(node: Node) -> void:
	if node is Button and node.is_visible_in_tree() and node.size.x>0 and node.text!="":
		var face=node.get_theme_font("font");var font_size=node.get_theme_font_size("font_size")
		measured+=1
		check(face.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=node.size.x-8,"button text stays inside: "+node.text)
		check(face.get_height(font_size)<=node.size.y-4,"button text height stays inside: "+node.text)
	for child in node.get_children():validate_buttons(child)
func shot(label: String) -> void:
	await frames(3);validate_buttons(main.ui);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	check("LevelUp-Regular" in main.font.base_font.resource_path,"user-supplied LevelUp is global primary face")
	for character in "아무 버튼이나 입력해서 시작 공격력 체력 실드 중장갑 싱글플레이 0123456789":
		if character!=" ":check(main.font.base_font.has_char(character.unicode_at(0)),"LevelUp contains "+character)
	await shot("main-menu-levelup")
	main._single_menu();await shot("single-menu-levelup")
	main._main_menu();await frames(2);main._settings_menu();await shot("settings-levelup")
	for race in range(3):
		main._clear_ui();await frames(2)
		var loading=ACLoadingScreen.new();main.ui.add_child(loading);loading.configure(race,0);loading.set_progress(.83,"지형 표면 준비 중")
		await shot("loading-r%d-levelup"%race)
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"buttons_measured":measured,"font":"LevelUp Regular, user ZIP, SIL OFL1.1"},"\t"))
	print("LEVELUP_LAYOUT checks=",checks," buttons=",measured," failures=",failures.size());quit(0 if failures.is_empty() else 1)
