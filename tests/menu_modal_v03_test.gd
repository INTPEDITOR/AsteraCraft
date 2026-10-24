extends SceneTree

var failures: Array=[]
var checks=0

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func modal_count(main: Control) -> int:
	var count=0
	for child in main.ui.get_children():
		if child is ACMenuLayer:count+=1
	return count

func press_key(code: Key) -> void:
	var event=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func capture(file: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+file)

func run() -> void:
	root.size=Vector2i(1440,900)
	var main=load("res://scripts/main.gd").new()
	root.add_child(main)
	main.size=Vector2(1440,900)
	await process_frame
	var hub=main.ui.get_node_or_null("MainHub")
	check(hub!=null,"main hub exists")
	var original_art=hub.art
	var discovery=ACLobbyDiscovery.new()
	main.add_child(discovery)
	check(discovery.scope=="LAN"&&discovery._configured_endpoint()=="","blank configuration defaults to LAN")
	check(discovery._node_runtime().ends_with("runtime/node.exe"),"bundled Node runtime is preferred over global install")
	check(FileAccess.file_exists(discovery._root_dir().path_join("server/server.js")),"service script resolves beside project/runtime")
	discovery.scope="ONLINE"
	discovery.endpoint="https://previous.invalid"
	discovery.forget_service()
	check(discovery.scope=="LAN"&&discovery.endpoint=="","forgetting endpoint also resets public scope")
	discovery.queue_free()
	main._single_menu()
	await process_frame
	check(main.ui.get_node_or_null("MainHub")==hub,"single modal preserves same main scene")
	check(modal_count(main)==1,"one single modal")
	await capture("preview-single-v03.png")
	main._settings_menu()
	await process_frame
	check(modal_count(main)==1,"settings replaces prior modal")
	check(hub.art==original_art,"background never rerolls during popup navigation")
	check(main.ui.get_node("MenuModal").board.texture!=null,"settings uses generated board")
	var edits=main.ui.find_children("*","LineEdit",true,false)
	check(edits.is_empty(),"settings contains no server address field")
	await capture("preview-settings-v03.png")
	main.ui.get_node("MenuModal").close_button.pressed.emit()
	await process_frame
	check(modal_count(main)==0&&main.ui.get_node("MainHub")==hub,"close button restores same main scene")
	main._settings_menu()
	await process_frame
	await press_key(KEY_ESCAPE)
	check(main.page=="main"&&modal_count(main)==0&&main.ui.get_node("MainHub")==hub,"ESC closes settings and preserves exact background")
	check(not main.has_method("_replay_menu"),"replay menu removed")
	main._main_menu()
	await process_frame
	check(modal_count(main)==0&&main.ui.get_node("MainHub")==hub,"closing returns to exact same main hub")
	main.account={"id":"test-user","nickname":"Test","nickname_confirmed":true,"rating":1000,"wins":0,"losses":0}
	main.session_token="test-token"
	main.room={"id":"test-room","name":"Test room","owner":"test-user","map":0,"mode":"ffa","countdown":5,"locked":false,"members":[{"user":"test-user","nickname":"Test","race":0,"team":0,"ready":true,"bot":false},{"user":"test-other","nickname":"Other","race":1,"team":1,"ready":true,"bot":false}]}
	main._room_menu()
	await process_frame
	check(modal_count(main)==1,"room uses modal")
	check(not main.menu_pages.ready_button.disabled,"ready can cancel with 5 seconds left")
	main.room.countdown=3
	main.room.locked=true
	main._update_room_text()
	check(main.menu_pages.ready_button.disabled,"ready button locks at 3 seconds")
	check(main.map_select.disabled&&main.race_select.disabled,"room configuration also locks")
	await capture("preview-room-v03.png")
	main._main_menu()
	main._start_local({"map":0,"mode":"ffa","players":[{"name":"Test","race":0},{"name":"AI","race":1,"bot":true}]})
	await process_frame
	var hud=main.battle_hud
	main._pause_menu()
	await process_frame
	check(main.page=="game"&&main.paused,"local match pauses under modal")
	check(main.battle_hud==hud&&is_instance_valid(hud),"pause preserves live HUD")
	main._settings_menu()
	await process_frame
	check(main.page=="game"&&main.battle_hud==hud&&modal_count(main)==1,"settings remain above same game/HUD")
	await capture("preview-game-settings-v03.png")
	var previous_camera=main.camera
	main._camera_input(.2)
	check(main.camera==previous_camera,"camera remains fixed beneath popup")
	main.pointer_order=""
	await press_key(KEY_A)
	check(main.pointer_order==""&&not main.attack_mode,"battle command hotkeys are blocked beneath popup")
	await press_key(KEY_ESCAPE)
	check(modal_count(main)==1&&main.ui.get_node("MenuModal").heading.text=="게임 메뉴","ESC returns from game settings to the game menu")
	await press_key(KEY_ESCAPE)
	check(modal_count(main)==0&&main.page=="game"&&not main.paused,"ESC closes game menu and resumes same game")
	main.queue_free()
	await process_frame
	print("MENU_MODAL_V03_TEST checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
