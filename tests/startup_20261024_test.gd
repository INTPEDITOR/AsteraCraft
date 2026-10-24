extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/startup-20261024/"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	var screen=load("res://startup.tscn").instantiate()
	screen.navigate_on_start=false;root.add_child(screen);await frames(3);screen.set_process(false)
	screen.clock=1;screen.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"publisher-logo.png")
	check(screen.publisher_alpha()>.99 and screen.title_alpha()==0,"publisher only on black at start")
	screen.clock=2.05
	check(screen.publisher_alpha()>0 and screen.publisher_alpha()<1,"publisher fades gradually")
	screen.clock=2.6
	check(screen.publisher_alpha()==0 and screen.title_alpha()==0,"brief clean black transition")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1280,960)]:
		root.size=resolution;root.content_scale_size=resolution;await frames(3)
		screen.clock=5;screen.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"title-%dx%d.png"%[resolution.x,resolution.y])
		check(Rect2(Vector2.ZERO,screen.size).encloses(screen.wordmark_rect()),"wordmark stays inside viewport %s"%resolution)
	for type in ["keyboard","mouse","joypad"]:
		if "--capture-only" in OS.get_cmdline_user_args():quit();return
		screen.leaving=false
		var event: InputEvent
		if type=="keyboard":event=InputEventKey.new();event.keycode=KEY_ENTER
		elif type=="mouse":event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		else:event=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A
		event.pressed=true;screen._input(event);await frames(2)
		check(screen.leaving,"%s starts existing main hub"%type)
	screen.queue_free();await frames(2)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://scripts/main.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	check(main.page=="main" and main.ui.get_node_or_null("MainHub")!=null,"destination is original main menu")
	print("STARTUP_20261024 ",checks," checks; failures=",failures.size())
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
