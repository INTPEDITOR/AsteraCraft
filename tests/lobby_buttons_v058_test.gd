extends SceneTree
var checks=0
var failures=[]
func _initialize():call_deferred("run")
func check(value,message):
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func run():
	var main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);await process_frame
	main.account={"id":"host","nickname":"방장","nickname_confirmed":true};main.session_token="fixture"
	var member={"user":"host","nickname":"방장","race":1,"team":0,"ready":false,"observer":false,"bot":false}
	main.room={"id":"room","owner":"host","name":"버튼 검사","map":0,"mode":"ffa","members":[member],"locked":false}
	main._room_menu();var pages=main.menu_pages
	check(pages.team_button.disabled,"FFA team disabled")
	check(pages.remove_bot_button.disabled,"no bots to remove")
	check(not pages.observer_button.disabled,"host may observe")
	var observed=main.room.duplicate(true);observed.members[0].observer=true
	main.api_responses["/room/update"]={"room":observed}
	pages.observer_button.pressed.emit()
	check(main.api_requests.back().body.observer==true,"observer action wired")
	check(not main.race_select.visible and pages.room_rows[4].race.visible,"observer appears in the separate observer section")
	check(not pages.ready_button.disabled and pages.ready_button.text=="호스팅 준비","observer host can ready")
	pages.ready_button.pressed.emit();check(main.api_requests.back().body.ready==true,"host ready wired")
	pages.add_bot_button.pressed.emit();check(main.api_requests.back().body.add_bot==true,"add bot wired")
	main.api_responses["/room/update"]={"error":"플레이어 자리가 가득 찼습니다."}
	pages.add_bot_button.pressed.emit();check(main.room_detail.text.contains("가득"),"error visible inside modal")
	main.room.members[0].observer=false;main.room.mode="teams";pages.update_room_text()
	check(not pages.team_button.disabled,"teams enabled for player")
	pages.team_button.pressed.emit();check(main.api_requests.back().body.team==1,"team action wired")
	main.map_select.item_selected.emit(2);check(main.api_requests.back().body.map==2,"map action wired")
	main.mode_select.item_selected.emit(0);check(main.api_requests.back().body.mode=="ffa","mode action wired")
	main.race_select.item_selected.emit(2);check(main.api_requests.back().body.race==2,"race action wired")
	main.api_responses["/room/update"]={"error":"QA no room mutation"}
	pages.room_rows[2].slot_button.pressed.emit()
	check(main.api_requests.back().body.slot==2 and main.api_requests.back().body.closed==true,"host can close an individual empty player slot")
	main.room.closed_slots=[2,3];pages.update_room_text()
	check(pages.room_rows[2].nickname.text.contains("닫힌") and pages.room_rows[2].slot_button.text=="슬롯 열기","closed seat is visibly distinct and can reopen")
	pages.room_rows[2].slot_button.pressed.emit()
	check(main.api_requests.back().body.slot==2 and not main.api_requests.back().body.closed,"reopening targets the same seat")
	main.room.closed_slots=[]
	for i in range(3):
		var bot=member.duplicate();bot.user="bot%d"%i;bot.bot=true;main.room.members.append(bot)
	pages.update_room_text()
	check(pages.add_bot_button.disabled,"full player slots disable add")
	check(not pages.remove_bot_button.disabled,"bot removal available")
	var bot_select=pages.room_rows[1].bot_select
	bot_select.item_selected.emit(2)
	check(main.api_requests.back().body.bot_id=="bot0" and main.api_requests.back().body.bot_race==2,"host bot faction selector targets the exact computer")
	pages.remove_bot_button.pressed.emit();check(main.api_requests.back().body.remove_bot==true,"remove action wired")
	main.room.locked=true;pages.update_room_text()
	check(pages.ready_button.disabled and pages.observer_button.disabled and pages.team_button.disabled,"countdown locks changes")
	check(pages.room_rows[1].bot_select.disabled,"countdown also locks bot faction")
	main.api_responses["/room/leave"]={"error":"연결 실패"};pages.leave_room()
	check(main.page=="room" and not main.room.is_empty(),"failed leave retains room")
	main.api_responses["/room/leave"]={"ok":true};pages.leave_room()
	check(main.room.is_empty() and main.page=="rooms","leave returns to list")
	main.queue_free();await process_frame;await process_frame
	print("LOBBY_BUTTONS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
