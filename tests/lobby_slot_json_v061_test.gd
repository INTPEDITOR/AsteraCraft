extends SceneTree
var failures=[]
var checks=0
func check(value,label):
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func wire(value):return JSON.parse_string(JSON.stringify(value))
func _initialize():call_deferred("run")
func run():
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);await process_frame
	main.account={"id":"host","nickname":"방장","nickname_confirmed":true};main.session_token="fixture"
	var member={"user":"host","nickname":"방장","race":1,"team":0,"ready":false,"observer":false,"bot":false,"slot":0}
	main.room=wire({"id":"room","owner":"host","name":"JSON 슬롯 검사","map":0,"mode":"ffa","members":[member],"closed_slots":[],"locked":false})
	main._room_menu();var pages=main.menu_pages
	for slot in [2,3,1]:
		var closed=main.room.duplicate(true);closed.closed_slots.append(slot)
		main.api_responses["/room/update"]=wire({"room":closed})
		pages.room_rows[slot].slot_button.pressed.emit()
		check(main.api_requests.back().body.slot==slot and main.api_requests.back().body.closed,"close targets exact seat")
		check(pages.room_rows[slot].nickname.text.contains("닫힌"),"closed seat marked after real JSON parse")
		check(pages.room_rows[slot].slot_button.text=="슬롯 열기","closed seat offers reopen after real JSON parse")
	for slot in [3,1,2]:
		var opened=main.room.duplicate(true);opened.closed_slots=opened.closed_slots.filter(func(value):return int(value)!=slot)
		main.api_responses["/room/update"]=wire({"room":opened})
		pages.room_rows[slot].slot_button.pressed.emit()
		check(main.api_requests.back().body.slot==slot and not main.api_requests.back().body.closed,"reopen sends false using JSON-parsed slot IDs")
		check(pages.room_rows[slot].nickname.text.contains("빈 플레이어") and pages.room_rows[slot].slot_button.text=="슬롯 닫기","reopened seat visibly open")
	main.queue_free();await process_frame;await process_frame
	print("LOBBY_SLOT_JSON_V061 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
