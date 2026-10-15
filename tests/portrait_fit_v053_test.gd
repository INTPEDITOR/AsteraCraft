extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int=2) -> void:
	for i in range(n):await process_frame
func run() -> void:
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);await frames(4)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);main.set_process(false)
	var sheet=Image.create(14*150,3*210,false,Image.FORMAT_RGBA8);sheet.fill(Color("171717"))
	for race in range(3):
		main._start_local({"map":0,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false)
		for kind in range(14):
			var entity=main.core.add_unit(0,kind,Vector2(50,50)) if kind<13 else main.core.buildings[0]
			main.state=main.core.snapshot(0);main.selected=[entity.id];main._update_hud();await frames();await RenderingServer.frame_post_draw
			var screen=root.get_texture().get_image();var scale=Vector2(screen.get_size())/main.size
			var rect=main.battle_hud._portrait_rect().grow(7)
			var crop=screen.get_region(Rect2i(rect.position*scale,rect.size*scale));crop.resize(150,210,Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(kind*150,race*210))
	sheet.save_png("res://build/portrait-fit-review-v053.png")
	print("PORTRAIT_FIT 39 unit portraits + 3 building portraits rendered")
	main.queue_free();await frames();quit()
