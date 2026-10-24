extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/egyul-ui-applied-20261024/"
func geometry(node: Node) -> Array:
	var rows=[]
	if node is BaseButton:rows.append({"type":node.get_class(),"position":str(node.global_position),"size":str(node.size)})
	for child in node.get_children():rows.append_array(geometry(child))
	return rows
func run() -> void:
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size;main.set_process(false);await frames(3)
	main.account={"id":"qa-user","nickname":"테스트 지휘관","nickname_confirmed":true,"rating":1200};main.session_token="test"
	main.room={"id":"native-ui","name":"종족 공통 대기실","owner":"qa-user","map":0,"mode":"teams","members":[{"user":"qa-user","nickname":"테스트 지휘관","race":1,"team":0,"ready":false,"slot":0,"color_id":2},{"user":"bot-1","nickname":"컴퓨터 1","race":0,"team":1,"ready":true,"slot":1,"color_id":3,"bot":true}],"closed_slots":[]}
	var baseline={};var report=[]
	for race in range(3):
		main.settings.last_played_race=race
		for page in ["single","settings","account_menu","rooms","room_menu","leaderboard","replays"]:
			main._menus().call(page);await frames(5)
			var rows=geometry(main._menus().modal)
			if race==0:baseline[page]=rows
			else:check(rows==baseline[page],"same button sizes and global positions: "+page+" race "+str(race))
			report.append({"race":race,"page":page,"buttons":rows})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"menus":7,"factions":3,"matrix":report}
	FileAccess.open(OUT+"menu-matrix.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("FACTION_MENU_GEOMETRY ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures,"menus":7,"factions":3}));quit(0 if failures.is_empty() else 1)
