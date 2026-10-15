extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._settings_menu()
	await process_frame
	await process_frame
	var modal=main.ui.get_node_or_null("MenuModal")
	if modal==null:
		printerr("Settings capture: no settings modal")
		quit(1)
		return
	var panel: ACSettingsPanel
	for child in modal.content.get_children():
		if child is ACSettingsPanel:panel=child
	if panel==null or panel.controls.size()!=7:
		printerr("Settings capture: missing requested controls")
		quit(1)
		return
	for key in panel.controls:
		if not modal.content.get_global_rect().encloses(panel.controls[key].get_global_rect()):
			printerr("Settings capture: control outside board: "+str(key))
			quit(1)
			return
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/preview-settings-v04.png"))
	print("Actual settings scene: 7 controls present and inside generated board")
	main.queue_free()
	await process_frame
	quit()
