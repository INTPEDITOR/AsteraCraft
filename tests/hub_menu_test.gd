extends SceneTree

const MENU=preload("res://scripts/hub_menu.gd")

class Harness extends Control:
	var race_choice=1
	var map_choice=2
	var menu_backdrop: Texture2D
	var audio=null
	var actions: Array=[]
	var settings={"last_played_race":0}
	func _single_menu() -> void:actions.append("single")
	func _online_menu() -> void:actions.append("online")
	func _replay_menu() -> void:actions.append("replay")
	func _settings_menu() -> void:actions.append("settings")
	func _quit_game() -> void:actions.append("exit")

var failures: Array=[]
var checks=0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool,description: String) -> void:
	checks+=1
	if not condition:failures.append(description);printerr("FAIL: "+description)

func _run() -> void:
	root.size=Vector2i(1440,900)
	var harness=Harness.new()
	harness.size=Vector2(1440,900)
	var menu_theme=Theme.new()
	var font=ACUIFont.create()
	menu_theme.default_font=font
	harness.theme=menu_theme
	root.add_child(harness)
	var seen: Dictionary={}
	for entry in range(24):
		var remembered_race=int(entry/8)
		harness.settings.last_played_race=remembered_race
		var menu=MENU.new()
		harness.add_child(menu)
		menu.configure(harness)
		seen[menu.background_index]=true
		check(menu.background_index==remembered_race,"repeated entry preserves last played faction background")
		check(harness.race_choice==1 and harness.map_choice==2,"background selection preserves match settings")
		check(menu.nav_buttons.size()==5,"five menu actions")
		check(menu.button_plates.size()==9,"three faction and three button states loaded")
		check(menu.button_art_path=="res://assets/ui_native/main_","menu uses native generated art")
		check(menu.title_art!=null,"menu uses current generated title artwork")
		for index in range(5):
			var button: Button=menu.nav_buttons[index]
			check(button.position.x==58 and button.size==Vector2(320,76),"navigation keeps exact native dimensions in left column")
			var style=button.get_theme_stylebox("normal")
			check(style is StyleBoxTexture,"generated native normal style")
			if style is StyleBoxTexture:
				check(style.texture.get_size()==button.size,"button artwork matches control size")
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:check(style.get_texture_margin(side)==0,"main buttons do not use nine-slice stretching")
			if index>0:check(button.position.y>=menu.nav_buttons[index-1].get_rect().end.y,"menu actions do not overlap")
		if entry==0:
			for button in menu.nav_buttons:button.pressed.emit()
			check(harness.actions==["single","online","replay","settings","exit"],"all navigation buttons call their actions")
			if "--capture" in OS.get_cmdline_user_args():
				for faction in range(3):
					menu.choose_background(faction)
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://build/preview-main%d.png"%faction)
		harness.remove_child(menu)
		menu.free()
	check(seen.size()==3,"all three remembered faction backgrounds are available")
	harness.free()
	print("HUB_MENU_TEST checks=%d failures=%d remembered_backgrounds=%d"%[checks,failures.size(),seen.size()])
	quit(0 if failures.is_empty() else 1)
