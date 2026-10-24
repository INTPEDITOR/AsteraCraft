extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/menu-caption-20261024/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(5)
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect();main.set_process(false);await frames(3)
	var report=[]
	for race in range(3):
		main.settings.last_played_race=race;main._single_menu();await frames(6)
		var buttons=[]
		for control in main._menus().modal.content.get_children():
			if control is Button:buttons.append(control)
		for button in buttons:button.get_node("CentredCaption").hide()
		await frames(3);await RenderingServer.frame_post_draw
		var before=root.get_texture().get_image()
		for button in buttons:button.get_node("CentredCaption").show()
		await frames(3);await RenderingServer.frame_post_draw
		var after=root.get_texture().get_image();after.save_png(OUT+"single-r%d.png"%race)
		for button in buttons:
			var region=Rect2i(button.global_position.round(),button.size.round())
			var low=Vector2i(10000,10000);var high=Vector2i(-1,-1)
			for y in range(8,region.size.y-6):
				for x in range(22,region.size.x-30):
					var p=region.position+Vector2i(x,y);var a=before.get_pixelv(p);var b=after.get_pixelv(p)
					if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.15:
						low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
			check(high.x>=0,"visible caption "+str(race)+" "+button.text)
			var centre=(Vector2(low)+Vector2(high)+Vector2.ONE)*.5
			check(absf(centre.x-button.size.x*.5)<=1.5 and absf(centre.y-button.size.y*.5)<=1.5,"rendered pixels centred "+str(race)+" "+button.text+" "+str(centre))
			report.append({"race":race,"text":button.text,"button":str(button.size),"actual_text_pixels":[low.x,low.y,high.x,high.y],"centre":str(centre)})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"captions":report}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("MENU_CAPTIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
