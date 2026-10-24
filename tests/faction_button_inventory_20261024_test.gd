extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/faction-button-inventory-20261024/"
var matrix=[]
var texture_cache={}
func collect(node: Node,origin: Vector2) -> Array:
	var rows=[]
	if node is BaseButton and node.is_visible_in_tree():
		var row={"type":node.get_class(),"text":node.text,"position":str(node.global_position-origin),"size":str(node.size)}
		var style=node.get_theme_stylebox("normal")
		if style is StyleBoxTexture:
			var texture=style.texture;var key=str(texture.get_rid())
			if not texture_cache.has(key):
				var image=texture.get_image();var low=Vector2i(image.get_width(),image.get_height());var high=Vector2i(-1,-1)
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						if image.get_pixel(x,y).a>=.5:low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
				texture_cache[key]={"path":texture.resource_path,"canvas":str(texture.get_size()),"painted_bounds":str(Rect2i(low,high-low+Vector2i.ONE)),"painted_size":str(high-low+Vector2i.ONE)}
			row.art=texture_cache[key]
		else:row.art={"type":style.get_class(),"painted_size":str(node.size)}
		rows.append(row)
	for child in node.get_children():rows.append_array(collect(child,origin))
	return rows
func record(race: int,page: String,node: Control) -> void:
	matrix.append({"race":race,"page":page,"buttons":collect(node,node.global_position)})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	root.size=Vector2i(1600,900);ACSettings.keep_game_aspect();main.set_process(false);await frames(3)
	main.account={"id":"qa-user","nickname":"테스트 지휘관","nickname_confirmed":true,"rating":1200};main.session_token="test"
	main.room={"id":"native-ui","name":"종족 공통 대기실","owner":"qa-user","map":0,"mode":"teams","members":[{"user":"qa-user","nickname":"테스트 지휘관","race":1,"team":0,"ready":false,"slot":0,"color_id":2},{"user":"bot-1","nickname":"컴퓨터 1","race":0,"team":1,"ready":true,"slot":1,"color_id":3,"bot":true}],"closed_slots":[]}
	for race in range(3):
		main.settings.last_played_race=race;main._main_menu();await frames(4)
		var hub=main.ui.get_node("MainHub");hub.choose_background(race)
		var updater=main._game_updater();updater.checked=true;updater.install_enabled=true
		if hub.update_panel==null:hub._build_update_panel()
		await frames(3);record(race,"main",hub)
		for state in ["current","available","downloading","failed"]:
			updater.state=state;updater.progress=.5;updater.changed.emit();await frames(3);record(race,"update_"+state,hub.update_panel)
		for page in ["single","settings","account_menu","rooms","room_menu","leaderboard"]:
			main._menus().call(page);await frames(5);record(race,page,main._menus().modal)
		main._menus().close()
		var loading=ACLoadingScreen.new();main.ui.add_child(loading);loading.configure(race,0);loading.cancel_button.show();await frames(4);record(race,"loading",loading);loading.queue_free();await frames(2)
		main._start_local({"map":0,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false)
		main.selected=[main.state.buildings.filter(func(b):return b.owner==0 and b.kind==0)[0].id];main.battle_hud.update_hud(true);await frames(4)
		record(race,"battle",main.battle_hud)
		matrix[-1]["queue_slot_size"]=str(main.battle_hud.queue_slot_rect(0).size)
		main.state.surrender_requests=[{"bot":1,"recipient":0}];main.battle_hud.update_hud(true);await frames(5);record(race,"surrender",main.battle_hud.surrender_panel)
		main._pause_menu();await frames(4);record(race,"pause",main._menus().modal);main._menus().close()
		main._menus().result(true);await frames(4);record(race,"result",main._menus().modal)
	var mismatches=[]
	for reference in matrix:
		if reference.race!=0:continue
		for actual in matrix:
			if actual.page!=reference.page or actual.race==0:continue
			var rows=reference.buttons;var other=actual.buttons
			if rows.size()!=other.size():mismatches.append({"page":reference.page,"race":actual.race,"reason":"button count","baseline":rows.size(),"actual":other.size()});continue
			for index in range(rows.size()):
				if rows[index].size!=other[index].size:mismatches.append({"page":reference.page,"race":actual.race,"index":index,"text":other[index].text,"baseline":rows[index].size,"actual":other[index].size})
	var result={"factions":3,"contexts":matrix.size()/3,"control_size_mismatches":mismatches,"matrix":matrix,"visual_consistency_not_implied_by_equal_control_size":true}
	FileAccess.open(OUT+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("FACTION_BUTTON_INVENTORY ",JSON.stringify({"contexts":result.contexts,"size_mismatches":mismatches}));quit()
