extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/feedback4-20261024/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	var sizes=[]
	for race in range(3):
		main._start_local({"map":1,"players":[{"race":race},{"race":0}]});main.paused=true;main.set_process(false);main.spectator=true
		main.selected=[main.state.buildings.filter(func(b):return int(b.owner)==0 and int(b.kind)==0)[0].id]
		main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
		var hud=main.battle_hud;var area=hud.shell_draw_rect();var mini=hud.minimap_rect();var portrait=hud._portrait_rect();var command=hud.command_slot_rect(0)
		if race==1:
			check(hud._frame_art[1].resource_path=="res://assets/ui/egyul_hud_living_common_20261024.png","approved living artwork is the actual runtime skin")
			check(hud._frame_slices[1].size()==3,"approved decorative margins fit the common content layout")
			check(hud._frame_body_profiles[1].size()==1963,"organic silhouette mask follows the fitted artwork")
		sizes.append({"race":race,"height":area.size.y,"minimap":mini.size,"portrait":portrait.size,"command":command.size})
		var image=root.get_texture().get_image();image.save_png(OUT+"common-hud-r%d-preview.png"%race)
		var factor=Vector2(image.get_size())/main.size;var crop=Rect2i(area.position*factor,area.size*factor).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		image.get_region(crop).save_png(OUT+"common-hud-r%d-strip.png"%race)
	for index in range(1,3):
		for field in ["height","minimap","portrait","command"]:
			check(str(sizes[index][field])==str(sizes[0][field]),"common HUD geometry matches across races: "+field)
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"sizes":sizes,"candidate_only":false,"user_approved_runtime_skin":true}
	FileAccess.open(OUT+"egyul-hud-preview-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("EGYUL_HUD_COMMON ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
