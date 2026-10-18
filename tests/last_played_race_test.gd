extends SceneTree

var checks=0
var failures: Array=[]
var previous_settings=""
var had_settings=false

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)

func run() -> void:
	root.size=Vector2i(1440,900)
	had_settings=FileAccess.file_exists("user://settings.json")
	if had_settings:previous_settings=FileAccess.get_file_as_string("user://settings.json")
	var script=load("res://scripts/main.gd")
	var main=script.new()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	main.settings.last_played_race=0
	main._save_settings()
	main.ui.get_node("MainHub").choose_background()
	await capture("preview-main-real0.png")
	main.race_choice=2
	main._single_menu()
	await process_frame
	check(main.settings.last_played_race==0,"choosing a future race does not change last played race")
	main._start_local({"map":0,"mode":"ffa","players":[{"name":"Test","race":1},{"name":"AI","race":0,"bot":true}]})
	await process_frame
	check(main.settings.last_played_race==1,"local game saves actual player race")
	var stored=JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	check(stored.last_played_race==1,"actual played race persists to settings")
	main._settings_menu()
	await process_frame
	var popup=main.ui.get_node("MenuModal")
	check(popup.button_race==1,"settings button palette follows last played race")
	await capture("preview-settings-r1-v03.png")
	var expected_board="res://assets/modal_board_r1_v3.png"
	if ResourceLoader.exists(expected_board):check(popup.board_art_path==expected_board,"settings board uses faction-specific generated art")
	var independent=script.new()
	independent._load_settings()
	check(independent.settings.last_played_race==1&&independent.race_choice==1,"new instance restores played race and next-match default")
	independent.free()
	main._main_menu()
	await process_frame
	var hub=main.ui.get_node("MainHub")
	check(hub.background_index==1,"returning to main uses last played faction background")
	await capture("preview-main-real1.png")
	main._start_local({"map":0,"mode":"ffa","players":[{"name":"Test","race":2},{"name":"AI","race":0,"bot":true}]})
	await process_frame
	var authoritative=main.core.snapshot()
	main.settings.last_played_race=1
	main._save_settings()
	main.page="connecting"
	main.network_client=true
	main.local_slot=0
	main._receive_state(var_to_bytes(authoritative).compress(FileAccess.COMPRESSION_DEFLATE))
	await process_frame
	check(main.settings.last_played_race==2,"first authoritative online snapshot saves confirmed local race")
	main.network_client=false
	main._settings_menu()
	await process_frame
	check(main.ui.get_node("MenuModal").button_race==2,"later faction changes do not reuse first faction's popup palette")
	await capture("preview-settings-r2-v03.png")
	main._main_menu()
	await capture("preview-main-real2.png")
	main.queue_free()
	await process_frame
	if had_settings:
		var file=FileAccess.open("user://settings.json",FileAccess.WRITE)
		if file!=null:file.store_string(previous_settings)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	print("LAST_PLAYED_RACE_TEST checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
