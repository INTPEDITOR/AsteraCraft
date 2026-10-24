extends "res://tests/view_input_v03_test.gd"
func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	for method in ["_save_replay","_replay_state","_encode_replay_frame","_begin_replay","_next_replay_frame","_tick_replay","_replay_menu"]:
		check(not main.has_method(method),"removed recording/playback method "+method)
	var pages=main._menus()
	for method in ["replays","_watch_result_replay","_load_replay","_replay_path","confirm_replay_delete","_delete_replay"]:
		check(not pages.has_method(method),"removed replay menu/file method "+method)
	for file in ["main","menu_pages","rts_hud"]:
		var source=FileAccess.get_file_as_string("res://scripts/"+file+".gd")
		check(not source.contains("replay") and not source.contains("리플레이"),"no replay storage/state/UI path in "+file)
	main._start_local({"map":0,"players":[{"race":0},{"race":1}]});await create_timer(1).timeout;await frames(3)
	check(main.page=="game" and not main.state.is_empty() and float(main.state.time)>0,"local match advances after replay removal")
	main.paused=true;main.set_process(false);main.spectator=true
	check(main._minimum_zoom()==main.MIN_ZOOM,"real spectator camera preserved")
	main.spectator=false;main._pause_menu();await frames(3)
	var texts=[]
	for button in pages.modal.find_children("*","Button",true,false):texts.append(button.text)
	check(not texts.has("리플레이"),"pause has no replay action")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"recording_saving_playback_menus_removed":true,"existing_user_files_deleted":false}
	DirAccess.make_dir_recursive_absolute("res://build/replay-removed-20261024")
	FileAccess.open("res://build/replay-removed-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("REPLAY_REMOVED ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
