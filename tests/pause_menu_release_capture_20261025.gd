extends SceneTree
var main: Control
var checks=0
var failures: Array=[]
var OUT=""
func _initialize() -> void:
	OUT=OS.get_cmdline_user_args()[0].trim_suffix("/")+"/"
	call_deferred("run")
func frames(count: int=3) -> void:
	for index in range(count):await process_frame
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
var records=[]

func inspect_menu(race: int,online: bool) -> void:
	var modal=main._menus().modal
	var buttons=[]
	for child in modal.content.get_children():
		if child is Button:buttons.append(child)
		if child is Label:check(not child.text.contains("온라인 경기는"),"removed notice absent")
	check(buttons.map(func(b):return b.text)==["계속하기","환경 설정","항복","메인 화면"],"only four game menu actions")
	check(not modal.native_scroll.get_v_scroll_bar().is_visible_in_tree(),"no vertical scrollbar")
	check(not modal.native_scroll.get_h_scroll_bar().is_visible_in_tree(),"no horizontal scrollbar")
	var viewport=Rect2(modal.native_scroll.global_position,modal.native_scroll.size)
	var positions=[]
	for button in buttons:
		check(viewport.encloses(button.get_global_rect()),"entire button visible: "+button.text)
		check(button.size==Vector2(220,48),"approved native button size: "+button.text)
		positions.append(button.position)
	for index in range(1,buttons.size()):
		check(is_equal_approx(buttons[index].position.y-buttons[index-1].position.y,buttons[1].position.y-buttons[0].position.y),"equal spacing without empty row")
	check(main.paused!=online,"local pauses; online continues")
	if not records.is_empty():check(positions==records[0].positions,"identical three-faction layout")
	records.append({"race":race,"online":online,"positions":positions,"board":str(modal.board.size),"content":str(viewport),"scrollbar_visible":modal.native_scroll.get_v_scroll_bar().is_visible_in_tree()})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://scripts/main.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4);main.set_process(false)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(4)
	main._start_local({"map":1,"players":[{"race":0},{"race":1},{"race":2}]})
	main.set_process(false);main.settings.edge_scroll=false
	for race in range(3):
		main.local_slot=race;main.state=main.core.snapshot(race);main.settings.last_played_race=race
		main._focus_home(true);main._build_hud();main.network_client=false;main.paused=false
		main._pause_menu();await frames(6);inspect_menu(race,false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"pause-r%d.png"%race)
		var buttons=main._menus().modal.content.get_children().filter(func(n):return n is Button)
		buttons[1].pressed.emit();await frames(4)
		check(main._menus().modal.heading.text=="환경 설정" and main.paused,"settings retain local pause")
		main._menus().modal.closed.emit();await frames(5)
		check(main._menus().modal.heading.text=="게임 메뉴" and main.paused,"settings return to same game menu")
		main._menus().modal.closed.emit();await frames(3)
		check(main._menus().modal==null and not main.paused,"close resumes game")
		main.network_client=true;main._pause_menu();await frames(5);inspect_menu(race,true)
		main._menus().modal.content.get_children().filter(func(n):return n is Button)[0].pressed.emit();await frames(3)
		check(main._menus().modal==null and not main.paused,"continue closes online menu")
		main.network_client=false
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"factions":3,"local_online_cases":records,"screenshots":["pause-r0.png","pause-r1.png","pause-r2.png"]}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PAUSE_MENU_CAPTURE ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures}));main._release_pointer();quit(0 if failures.is_empty() else 1)
