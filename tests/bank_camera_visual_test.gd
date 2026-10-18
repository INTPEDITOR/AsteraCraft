extends "res://tests/map_photo_tour.gd"
func run():
	root.size=Vector2i(1600,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	main._start_local({"map":2,"seed":413,"players":[{"race":2},{"race":0}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.state=main.core.snapshot();main._update_hud()
	await photograph(2,"rear-edge",Vector2(44,74),1.5)
	print("BANK_CAMERA_VISUAL captured rear/side/front of real highland plateau");quit()
