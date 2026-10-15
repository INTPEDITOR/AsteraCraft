extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var main=load("res://scripts/main.gd").new()
	root.add_child(main)
	await process_frame
	var endpoint=OS.get_environment("ASTERA_TEST_LOBBY")
	if endpoint!="":
		var discovery=load("res://scripts/lobby_discovery.gd").new()
		main.add_child(discovery);discovery.endpoint=endpoint
		main._menus().discovery=discovery
	main._online_menu()
	for i in range(60):
		await create_timer(.2).timeout
		if main.page=="account" or main.page=="rooms":
			print("ONLINE_OPEN_OK "+str(main.page));cleanup(main);quit();return
	print("ONLINE_OPEN_FAIL page="+str(main.page)+" status="+(main.online_status.text if is_instance_valid(main.online_status) else "missing"))
	cleanup(main);quit(1)
func cleanup(main) -> void:
	var discovery=main._menus().discovery
	if discovery!=null and discovery.local_process>0:OS.kill(discovery.local_process)
