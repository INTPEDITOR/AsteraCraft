extends SceneTree
var main: Control
var soldier: Dictionary
var hq: Dictionary
var goal: Vector2
var stage=-1
var checks=0
var failures: Array=[]
var started=0
var changed=0

func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("NATIVE FAIL "+message)
func run() -> void:
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_title("AsteraCraftNativeInputV04")
	main=load("res://main.tscn").instantiate();root.add_child(main)
	await process_frame
	main._start_local({"map":0,"seed":223,"players":[{"race":0},{"race":1}]})
	main.paused=true;main.settings.edge_scroll=false;main.spectator=true
	hq=main.core.buildings[0]
	var home=main.core.center(hq)
	soldier=main.core.add_unit(0,1,home+Vector2(3,2));goal=home+Vector2(5,3)
	main.state=main.core.snapshot();main.selected=[soldier.id];main._update_hud()
	await process_frame
	DisplayServer.window_set_title("AsteraCraftNativeInputV04")
	root.window_input.connect(func(event):
		if event is InputEventKey or event is InputEventMouseButton:print("OS_EVENT ",event.as_text()," pressed=",event.is_pressed()," raw=",event," main_input=",main.is_processing_input()," focused=",root.has_focus()," selected=",main.selected," pointer=",main.pointer_position," attack=",main.attack_mode," order=",soldier.get("order","pending"))
	)
	started=Time.get_ticks_msec();next(0)

func next(index: int) -> void:
	stage=index;changed=Time.get_ticks_msec()
	if stage==1:main.selected=[hq.id];main._update_hud()
	if stage==2:main.selected=[soldier.id];main._update_hud()
	if stage==4:main.page="main";main._release_pointer()
	var point=main._mini_rect().position+main._mini_rect().size*Vector2(.7,.6) if stage==2 else main._ground_point(goal)
	var file=FileAccess.open("res://build/native-input-v04-state.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage,"point":[point.x,point.y],"size":[main.size.x,main.size.y]}))
	print("NATIVE_STAGE ",stage)

func _process(_dt: float) -> bool:
	if stage<0:return false
	if Time.get_ticks_msec()-started>40000:
		check(false,"native helper timeout at stage %d"%stage);finish();return false
	if Time.get_ticks_msec()-changed<600:return false
	if stage==0 and soldier.order=="attack_move":
		check(ACData.point(soldier.goal).distance_to(goal)<.03 and not main.attack_mode,"hardware A + ground click exact attack move")
		check(main.selected==[soldier.id] and not main.dragging,"hardware target click consumed once")
		next(1)
	elif stage==1 and ACData.point(hq.rally).distance_to(goal)<.03:
		check(main.pointer_order=="" and main.selected==[hq.id],"hardware R + ground click exact rally")
		next(2)
	elif stage==2 and ACData.point(soldier.goal).distance_to(Vector2(.7,.6)*128)<.03:
		check(soldier.order=="attack_move" and not main.attack_mode,"hardware A + minimap click exact attack move")
		next(3)
	elif stage==3 and FileAccess.file_exists("res://build/native-input-v04-focus.json"):
		var record=JSON.parse_string(FileAccess.get_file_as_string("res://build/native-input-v04-focus.json"))
		check(record.confined,"native desktop clip confines to the real game client")
		check(record.unfocused_released,"minimizing releases native mouse confinement")
		check(record.refocused_confined,"restoring the game restores confinement")
		next(4)
	elif stage==4 and FileAccess.file_exists("res://build/native-input-v04-menu.json"):
		var record=JSON.parse_string(FileAccess.get_file_as_string("res://build/native-input-v04-menu.json"))
		check(record.released,"menu releases native mouse confinement")
		finish()
	return false

func finish() -> void:
	stage=-1;main._release_pointer()
	print("NATIVE_INPUT_V04 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
