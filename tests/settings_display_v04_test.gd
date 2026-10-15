extends SceneTree
## Uses a separate test process and never writes a user's settings file.
const Settings = preload("res://scripts/settings.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + detail)

func settle() -> void:
	await create_timer(0.35).timeout
	await process_frame

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Use a GUI display for physical window-mode verification")
		quit(1)
		return
	var original_mode := DisplayServer.window_get_mode()
	var original_borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	var original_size := DisplayServer.window_get_size()
	var original_position := DisplayServer.window_get_position()
	var value := Settings.defaults()
	value.resolution = [1280,720]
	Settings.apply_display(value)
	await settle()
	check(DisplayServer.window_get_size()==Vector2i(1280,720),"windowed 1280 x 720 applies to the physical window")
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"windowed mode applies")
	check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),"window frame is restored")
	value.window_mode = "borderless"
	Settings.apply_display(value)
	await settle()
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),"borderless mode flag applies")
	var screen := DisplayServer.window_get_current_screen()
	check(DisplayServer.window_get_size()==DisplayServer.screen_get_size(screen),"borderless fills the native screen")
	value.window_mode = "fullscreen"
	Settings.apply_display(value)
	await settle()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"fullscreen mode applies")
	check(DisplayServer.window_get_size()==DisplayServer.screen_get_size(screen),"fullscreen uses the native screen resolution")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,original_borderless)
	DisplayServer.window_set_size(original_size)
	DisplayServer.window_set_position(original_position)
	DisplayServer.window_set_mode(original_mode)
	print("Physical display settings: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
