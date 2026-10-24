extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/egyul-ui-aspect16x9-20261024/"
var native_controls=0
var screenshots=[]
func shot(name: String) -> void:
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png");screenshots.append(name)
func audit(node: Node) -> void:
	if node is Control and node.has_meta("native_art"):
		var id=str(node.get_meta("native_art"));var expected=ACEgyulNativeUI.texture(id).get_size()
		check(node.size.is_equal_approx(expected),id+" drawn at native size, got "+str(node.size)+" "+(node.text if node is Button else ""))
		if node is BaseButton:
			for state in ["normal","hover","pressed","disabled"]:
				var style=node.get_theme_stylebox(state)
				check(style is StyleBoxTexture and style.texture.get_size()==expected,"matching native state "+id+":"+state)
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:check(style.get_texture_margin(side)==0,"no nine slice "+id)
			var text_size=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size"))
			check(text_size.x<=expected.x-20,"label fits native plate: "+node.text)
		native_controls+=1
	for child in node.get_children():audit(child)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for id in [ACEgyulNativeUI.LARGE,ACEgyulNativeUI.MEDIUM]:
		var image=ACEgyulNativeUI.texture(id).get_image();var low=255;var high=0;var darkest=255;var lightest=0
		for y in range(image.get_height()/4,image.get_height()*3/4,5):
			for x in range(image.get_width()/4,image.get_width()*3/4,5):
				var colour=image.get_pixel(x,y)
				low=mini(low,roundi(colour.a*255));high=maxi(high,roundi(colour.a*255))
				darkest=mini(darkest,roundi(colour.r*255));lightest=maxi(lightest,roundi(colour.r*255))
		check(low>=248 and high-low<=7,"opaque even centre without patchy holes: "+id)
		check(lightest-darkest<=12,"subtle centre texture without large black stains: "+id)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size;await frames(3)
	main.set_process(false);main.settings.last_played_race=1
	var hub=main.ui.get_node("MainHub");hub.choose_background(1)
	var updater=main._game_updater();updater.checked=true;updater.install_enabled=true;hub._build_update_panel()
	for state in ["current","available","downloading","failed"]:
		updater.state=state;updater.progress=.63;updater.changed.emit();await frames(3);audit(hub)
	await shot("main-menu")
	main._single_menu();await frames(5);audit(main._menus().modal)
	check(main._menus().modal.board.size==Vector2(1260,840),"large menu fixed art")
	var choice: OptionButton
	for child in main._menus().modal.content.get_children():
		if child is OptionButton and child.get_item_text(0)=="1명":choice=child
	await click(choice.global_position+choice.size*.5)
	check(choice.get_popup().visible,"native dropdown opens on click")
	choice.get_popup().hide();choice.select(1);choice.item_selected.emit(1);await frames(3)
	check(main.bot_count==2,"native dropdown selection callback changes actual match setting")
	await shot("single-menu")
	main._settings_menu();await frames(5);audit(main._menus().modal);await shot("settings")
	main._menus().account_menu();await frames(5);audit(main._menus().modal);await shot("account")
	main.account={"id":"qa-user","nickname":"테스트 지휘관","nickname_confirmed":true,"rating":1200};main.session_token="test"
	main._rooms_menu();await frames(5);audit(main._menus().modal);await shot("rooms")
	main.room={"id":"native-ui","name":"이귤 대기실","owner":"qa-user","map":0,"mode":"teams","members":[{"user":"qa-user","nickname":"테스트 지휘관","race":1,"team":0,"ready":false,"slot":0,"color_id":2},{"user":"bot-1","nickname":"컴퓨터 1","race":0,"team":1,"ready":true,"slot":1,"color_id":3,"bot":true}],"closed_slots":[]}
	main._room_menu();await frames(5);audit(main._menus().modal);await shot("room")
	main._menus().leaderboard();await frames(5);audit(main._menus().modal);await shot("ranking")
	main._main_menu();await frames(4)
	var loading=ACLoadingScreen.new();main.ui.add_child(loading);loading.configure(1,0);loading.set_progress(.63,"지형 표면 준비 중");loading.cancel_button.show();await frames(5);audit(loading);await shot("loading");loading.queue_free();await frames(3)
	var geometry=[]
	var resolutions=[]
	var menu_geometry=[]
	for race in range(3):
		main._main_menu();await frames(3);main.settings.last_played_race=race
		var faction_hub=main.ui.get_node("MainHub");faction_hub.choose_background(race);await frames(3)
		check(faction_hub.nav_buttons[0].size==Vector2(320,76),"same main button size for faction "+str(race))
		await shot("menu-r%d"%race)
		main._single_menu();await frames(4)
		var controls=[]
		for control in main._menus().modal.content.get_children():
			if control is Button:
				check(control.size==Vector2(220,48),"same standard menu control size for faction "+str(race)+" "+control.text)
				controls.append({"position":str(control.global_position),"size":str(control.size)})
		menu_geometry.append(controls)
		main._start_local({"map":0,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false)
		main.selected=[main.state.buildings.filter(func(b):return b.owner==0 and b.kind==0)[0].id]
		main._sync_world_canvas();main.battle_hud.update_hud(true);await shot("hud-r%d"%race)
		var hud=main.battle_hud
		geometry.append({"race":race,"shell":str(hud.shell_draw_rect().size),"mini":str(hud.minimap_rect().size),"portrait":str(hud._portrait_rect().size),"command":str(hud.command_slot_rect(0).size)})
		var producer=main._entity(int(main.selected[0]));var saved_queue=producer.get("queue",[]).duplicate(true)
		producer.queue=[{"kind":0,"left":10.0,"total":20.0}];hud.update_hud(true);await frames(3)
		check(hud.queue_buttons.size()==5,"five visible production queue slots race "+str(race))
		for queue_button in hud.queue_buttons:
			check(queue_button.size.is_equal_approx(Vector2(90,32)),"same queue button size race "+str(race))
			check(hud._detail_content_rect().encloses(Rect2(queue_button.global_position,queue_button.size)),"queue remains inside safe info area race "+str(race))
		if race==1:await shot("queue-r1")
		producer.queue=saved_queue;hud.update_hud(true);await frames(3)
		if race==1:
			for button in hud.action_buttons:
				for child in button.get_children():
					if child is TextureRect and child.has_meta("command_image"):check((child.get_rect().get_center()-button.size*.5).length()<.01,"command glyph centred inside measured art opening")
			main.state.surrender_requests=[{"bot":1,"recipient":0}];hud.update_hud(true);await frames(5);audit(hud.surrender_panel);check(hud.surrender_panel.size==Vector2(520,300),"surrender uses native520x300");await shot("surrender")
			var column=hud.surrender_panel.get_child(0);var first=column.get_child(0);var last=column.get_child(column.get_child_count()-1)
			var content_centre=(first.global_position.y+last.global_position.y+last.size.y)*.5
			check(absf(content_centre-hud.surrender_panel.get_global_rect().get_center().y)<=.5,"surrender title/body/buttons centred vertically in actual frame")
			main._pause_menu();await frames(4);audit(main._menus().modal);await shot("pause")
			main._menus().close()
		for extent in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(1920,1200),Vector2i(1920,800),Vector2i(2560,1440)]:
			root.size=extent;root.content_scale_size=Vector2i(1600,900);await frames(5)
			var projected=root.get_final_transform()*Rect2(Vector2.ZERO,main.size)
			check(main.size==Vector2(1600,900) and absf(projected.size.x/projected.size.y-16.0/9.0)<.001,"fixed16:9 game area with external letterbox at "+str(extent)+" race "+str(race))
			var shell=hud.shell_draw_rect()
			check(shell.position.x==0 and shell.end.is_equal_approx(main.size),"HUD reaches left right and bottom race "+str(race))
			for button in hud.action_buttons:
				var expected=hud.command_slot_rect(int(button.get_meta("slot")))
				check(button.get_rect().is_equal_approx(expected),"command art and click area reflow together at "+str(extent)+" race "+str(race))
			resolutions.append({"race":race,"window":str(root.size),"logical_view":str(main.size),"projected_view":str(projected)})
			if race==1 and extent in [Vector2i(1440,900),Vector2i(1920,800)]:await shot("edge-%dx%d"%[extent.x,extent.y])
		root.size=Vector2i(1600,900);root.content_scale_size=root.size;await frames(3)
	for field in ["shell","mini","portrait","command"]:check(geometry[0][field]==geometry[1][field] and geometry[1][field]==geometry[2][field],"all three race HUD sizes match: "+field)
	check(menu_geometry[0]==menu_geometry[1] and menu_geometry[1]==menu_geometry[2],"same button positions and sizes across all three factions")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_controls":native_controls,"screenshots":screenshots,"hud_sizes":geometry,"menu_geometry":menu_geometry,"resolutions":resolutions,"actual_runtime_ui":true}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("EGYUL_NATIVE_UI ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
