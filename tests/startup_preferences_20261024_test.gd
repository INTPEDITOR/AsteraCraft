extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/feedback4-20261024/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var filename=ACSettings.FILE;var existed=FileAccess.file_exists(filename);var saved=FileAccess.get_file_as_string(filename) if existed else ""
	var preferences=ACSettings.defaults();preferences.resolution=[1280,720];preferences.window_mode="windowed";preferences.music_volume=.35
	ACSettings.save_file(preferences)
	var screen=load("res://startup.tscn").instantiate();root.add_child(screen);current_scene=screen
	await frames(3)
	check(DisplayServer.window_get_size()==Vector2i(1280,720),"saved resolution already applied at publisher-logo stage")
	check(screen.clock<screen.TITLE_AT,"resolution and music test occurs before title transition")
	check(screen.audio.current_music_name=="music_menu" and screen.audio._music_player.playing,"music starts with the publisher logo")
	check(is_equal_approx(screen.audio.music_volume,.35),"startup music respects saved user volume")
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"publisher-saved-resolution-1280x720.png")
	var mixer=screen.audio;var identity=mixer.get_instance_id();var position=mixer._music_player.get_playback_position()
	screen.clock=5;screen.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"title-saved-resolution-1280x720.png")
	screen._enter_main();await frames(6)
	main=root.get_node("Main")
	check(main.audio.get_instance_id()==identity,"same music player survives title-to-main scene change")
	check(main.audio._music_player.playing and main.audio._music_player.get_playback_position()>position,"menu music continues without restarting at title exit")
	check(DisplayServer.window_get_size()==Vector2i(1280,720),"main menu retains the same saved resolution")
	if existed:FileAccess.open(filename,FileAccess.WRITE).store_string(saved)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"first_screen_resolution":[1280,720],"continuous_music":true}
	FileAccess.open(OUT+"startup-preferences-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STARTUP_PREFERENCES ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
