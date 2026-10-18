extends SceneTree
var checks=0
func check(ok):
	checks+=1
	if not ok:printerr("LADDER_MENU FAILED ",checks);quit(1);assert(ok)
func _initialize():call_deferred("run")
func run():
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(4):await process_frame
	main.account={"id":"qa","nickname":"test","nickname_confirmed":true,"rating":1000,"wins":0,"losses":0};main.session_token="qa"
	main._rooms_menu();await process_frame
	check(main.ui.find_children("*","Button",true,false).all(func(b):return b.text!="연결 도움말"))
	main.api_responses["/leaderboard"]={"users":[{"nickname":"new","rating":1000,"wins":0,"losses":0},{"nickname":"loser","rating":980,"wins":0,"losses":1,"win_rate":0}]}
	main._leaderboard_menu();await process_frame
	var table=main.ui.find_child("LadderStandings",true,false)
	var row=table.get_root().get_first_child()
	check(row!=null and row.get_text(0)=="1" and row.get_text(1)=="loser" and row.get_next()==null)
	main.api_responses["/leaderboard"]={"users":[{"nickname":"new","rating":1000,"wins":0,"losses":0}]}
	main._leaderboard_menu();await process_frame
	table=main.ui.find_child("LadderStandings",true,false)
	check(table.get_root().get_first_child()==null)
	print("LADDER_MENU PASS ",checks);main.queue_free();await process_frame;quit()
