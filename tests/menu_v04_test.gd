extends SceneTree

var checks=0
var failures: Array=[]
var profile_before=""
var profile_existed=false
var settings_before=""
var settings_existed=false

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+filename)

func run() -> void:
	root.size=Vector2i(1440,900)
	profile_existed=FileAccess.file_exists("user://profile.json")
	if profile_existed:profile_before=FileAccess.get_file_as_string("user://profile.json")
	settings_existed=FileAccess.file_exists("user://settings.json")
	if settings_existed:settings_before=FileAccess.get_file_as_string("user://settings.json")
	var main=load("res://tests/menu_v04_harness.gd").new()
	root.add_child(main)
	main.size=Vector2(1440,900)
	await process_frame
	main.settings.last_played_race=0
	var hub=main.ui.get_node("MainHub")
	main._single_menu()
	await process_frame
	var pages=main.menu_pages
	var text=""
	for item in pages.modal.find_children("*","Label",true,false):text+=item.text+"\n"
	check(not text.contains("전투 조작") and not text.contains("드래그"),"single popup removes battle-control instructions")
	var single_preview=pages.modal.find_child("SingleMapPreview",true,false)
	check(single_preview is ACLobbyMapPreview and single_preview.battlefield.resources.size()==108,"single popup shows the actual map thumbnail")
	check(ACLobbyMapPreview.map_names()==["황철 분지","과숙의 심장","적월의 성역"],"menu names come from current map catalog")
	await capture("preview-single-v04.png")
	main.account={}
	main.session_token=""
	main._rooms_menu()
	await process_frame
	check(main.page=="account" and main.ui.get_node("MainHub")==hub,"unauthenticated room entry opens login on same background")
	check(pages.auth_nick.max_length==16 and pages.auth_pass.secret,"explicit nickname and secret password fields exist")
	check(main.api_requests.is_empty(),"opening login never automatically registers or logs in")
	pages.auth_nick.text=""
	pages.auth_pass.text="123"
	pages.authenticate(true)
	check(main.api_requests.is_empty() and main.page=="account","empty nickname cannot register or enter multiplayer")
	pages._complete_auth({"token":"legacy-token","user":{"id":"legacy","nickname":"지휘관123","nickname_confirmed":false}})
	check(main.account.is_empty() and main.session_token=="" and main.page=="account","unconfirmed generated account cannot pass client entry gate")
	var commander_existed=FileAccess.file_exists("user://commander.json")
	var commander_before=FileAccess.get_file_as_string("user://commander.json") if commander_existed else ""
	var old_password="1".repeat(40)
	var old_file=FileAccess.open("user://commander.json",FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"nickname":"지휘관"+old_password.substr(0,12),"password":old_password}))
	old_file.close()
	pages._migrate_legacy_identity()
	check(main.api_requests.size()==1 and main.api_requests[0].route=="/account/legacy" and main.account.is_empty(),"old generated identity is submitted only as exclusion proof, never login or registration")
	if commander_existed:
		old_file=FileAccess.open("user://commander.json",FileAccess.WRITE);old_file.store_string(commander_before);old_file.close()
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://commander.json"))
	await capture("preview-login-v04.png")
	var user={"id":"qa-user","nickname":"은하의 지휘관","nickname_confirmed":true,"rating":1245,"wins":12,"losses":6,"win_rate":66.7}
	main.api_responses["/login"]={"token":"qa-token","user":user}
	pages.auth_nick.text=user.nickname
	pages.auth_pass.text="explicit-password"
	pages.authenticate(false)
	await process_frame
	check(main.page=="rooms" and main.account.nickname==user.nickname and main.session_token=="qa-token","explicit successful login opens rooms")
	var profile=JSON.parse_string(FileAccess.get_file_as_string("user://profile.json"))
	check(profile.nickname==user.nickname and not profile.has("password"),"new local profile remembers nickname without writing password")
	main._leaderboard_menu()
	await process_frame
	var table=pages.modal.find_child("LadderStandings",true,false)
	check(table is Tree and table.columns==6 and table.column_titles_visible,"standings use six real columns")
	var expected=["순위","닉네임","점수","승","패","승률"]
	for column in range(6):check(table.get_column_title(column)==expected[column],"standings column heading %d"%column)
	var row=table.get_root().get_first_child()
	check(row.get_text(1)==user.nickname and row.get_text(2)=="1245" and row.get_text(3)=="12" and row.get_text(4)=="6" and row.get_text(5)=="66.7%","standings display server record in separate columns")
	await capture("preview-leaderboard-v04.png")
	main.room={"id":"qa-room","name":"은하의 첫 전투","owner":"qa-user","map":0,"mode":"teams","countdown":null,"locked":false,"members":[{"user":"qa-user","nickname":user.nickname,"race":0,"team":0,"ready":false,"bot":false},{"user":"qa-other","nickname":"별빛 탐험가","race":1,"team":1,"ready":true,"bot":false},{"user":"qa-bot","nickname":"컴퓨터 3","race":2,"team":0,"ready":true,"bot":true}]}
	main._room_menu()
	main.poll_clock=1000
	await process_frame
	check(pages.room_rows.size()==4,"custom lobby always presents four player slots")
	check(pages.room_preview.position.x<pages.room_rows[0].nickname.get_parent().position.x,"actual minimap is left of player slot table")
	check(pages.room_rows[3].nickname.text=="빈 슬롯" and pages.room_rows[3].status.text=="참가 대기","empty player slot is visibly represented")
	check(pages.room_preview.battlefield.resources.size()==108,"custom minimap uses actual resource nodes")
	for player_row in pages.room_rows:
		var panel=player_row.nickname.get_parent()
		check(Rect2(Vector2.ZERO,pages.modal.content.size).encloses(panel.get_rect()),"player row fits content safe area")
	check(not pages.ready_button.disabled and not main.map_select.disabled,"owner waiting-room controls are enabled before lock")
	for race in range(3):
		main.settings.last_played_race=race
		main._room_menu()
		main.poll_clock=1000
		await capture("preview-room-r%d-v04.png"%race)
	main.room.countdown=5
	main.room.members[0].ready=true
	main._update_room_text()
	check(not pages.ready_button.disabled and main.room_detail.text.contains("5초"),"five-second countdown remains cancellable")
	main.room.countdown=3
	main.room.locked=true
	main._update_room_text()
	check(pages.ready_button.disabled and main.map_select.disabled and main.race_select.disabled,"three-second lock disables ready and room configuration")
	check(main.room_detail.text.contains("준비 확정"),"locked countdown has explicit ready confirmation status")
	main.room.map=2
	main._update_room_text()
	var reference=ACMap.new()
	reference.make(2)
	check(pages.room_preview.map_id==2 and pages.room_preview.battlefield.terrain==reference.terrain,"server map updates refresh exact thumbnail terrain")
	main.room.owner="qa-other"
	main.room.locked=false
	main.room.countdown=null
	main._update_room_text()
	check(main.map_select.disabled and main.mode_select.disabled,"owner transfer disables map/mode controls for former owner")
	main._main_menu()
	check(main.ui.get_node("MainHub")==hub,"closing redesigned screens preserves original hub instance")
	main.set_process(false)
	for race in range(3):
		main._start_local({"map":race,"seed":404+race,"players":[{"name":"QA Player","race":race},{"name":"QA Bot","race":(race+1)%3,"bot":true}]})
		var initial=main.core.snapshot(main.local_slot)
		main.core.time=83
		main.core.ended=true
		main.core.winners=[1] if race==1 else [0]
		main.core.players[0].gathered=456
		main.core.players[0].kills=7
		main.state=main.core.snapshot(main.local_slot)
		main._update_hud()
		main.replay_frames=[var_to_bytes(initial).compress(FileAccess.COMPRESSION_DEFLATE)]
		main.result_sent=true
		var battle=main.battle_hud
		var battlefield=main.draw_map
		main._show_result()
		check(main.page=="game" and main.battle_hud==battle and main.draw_map==battlefield,"result popup preserves actual battlefield and HUD")
		check(pages.modal.button_race==race and pages.modal.heading.text==("패배" if race==1 else "승리"),"result uses played faction board and actual winner state")
		check(main.ui.get_node_or_null("ResultPanel")==null,"legacy flat result panel is absent")
		var result_text=""
		for item in pages.modal.find_children("*","Label",true,false):result_text+=item.text+"\n"
		check(result_text.contains("01:23") and result_text.contains("456") and result_text.contains("7"),"result summary displays recorded battle statistics")
		var actions=pages.modal.content.find_children("*","Button",true,false)
		check(actions.size()==2 and actions[0].size==Vector2(300,48) and actions[1].size==Vector2(300,48),"result has only two exact-native action buttons")
		await capture("preview-result-r%d-v04.png"%race)
	main.network_client=true
	main.remote_game={"id":"qa-ranked","ranked":true}
	main.api_responses["/game?id=qa-ranked"]={"game":{"status":"finished","result":{"winners":[0],"delta":30}},"user":{"id":"qa-user","nickname":user.nickname,"nickname_confirmed":true,"rating":1275,"wins":13,"losses":6}}
	main._show_result()
	check(pages.modal.content.get_node("ResultRating").text.contains("+30") and main.account.rating==1275,"ranked result preserves authoritative rating refresh")
	pages._watch_result_replay()
	check(main.replay_mode and main.core==null and not main.network_client and main.ui.get_node_or_null("MenuModal")==null,"result replay action enters saved frames and closes result popup")
	check(main.saved_replays==4,"result presentation still requests automatic replay saving")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://replays"))
	var replay_data={"version":"0.4.0","map":2,"slot":0,"frames":[main.state.duplicate(true)]}
	for filename in ["qa-selected-v04.acr","qa-neighbor-v04.acr"]:
		var replay_stream=FileAccess.open_compressed("user://replays/"+filename,FileAccess.WRITE,FileAccess.COMPRESSION_DEFLATE)
		replay_stream.store_var(replay_data,false)
		replay_stream.close()
	var outside=FileAccess.open("user://qa-outside-v04.acr",FileAccess.WRITE)
	outside.store_string("outside replay directory")
	outside.close()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://replays/qa-directory-v04.acr"))
	check(pages._delete_replay("../qa-outside-v04.acr")==ERR_INVALID_PARAMETER and FileAccess.file_exists("user://qa-outside-v04.acr"),"replay delete rejects traversal and preserves outside file")
	check(pages._delete_replay(ProjectSettings.globalize_path("user://qa-outside-v04.acr"))==ERR_INVALID_PARAMETER,"replay delete rejects absolute paths")
	check(pages._delete_replay("qa-directory-v04.acr")==ERR_INVALID_PARAMETER and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://replays/qa-directory-v04.acr")),"replay delete never deletes directories")
	main._main_menu()
	pages.replays()
	var replay_list=pages.modal.find_child("ReplayList",true,false)
	check(replay_list.get_child_count()==2,"replay list includes only replay files")
	var selected_row: Control
	for item in replay_list.get_children():
		if item.get_meta("replay_file")=="qa-selected-v04.acr":selected_row=item
	for action in selected_row.find_children("*","Button",true,false):
		if action.text=="삭제":action.pressed.emit();break
	check(main.page=="replay_delete" and pages.modal.heading.text=="리플레이 삭제" and FileAccess.file_exists("user://replays/qa-selected-v04.acr"),"per-row delete opens faction confirmation before removing selected file")
	await capture("preview-replay-delete-v04.png")
	for action in pages.modal.content.find_children("*","Button",true,false):
		if action.text=="취소":action.pressed.emit();break
	check(main.page=="replays" and FileAccess.file_exists("user://replays/qa-selected-v04.acr") and FileAccess.file_exists("user://replays/qa-neighbor-v04.acr"),"delete cancellation preserves selected and neighboring replays")
	await capture("preview-replays-v04.png")
	pages.confirm_replay_delete("qa-selected-v04.acr")
	for action in pages.modal.content.find_children("*","Button",true,false):
		if action.text=="삭제":action.pressed.emit();break
	replay_list=pages.modal.find_child("ReplayList",true,false)
	check(main.page=="replays" and not FileAccess.file_exists("user://replays/qa-selected-v04.acr") and FileAccess.file_exists("user://replays/qa-neighbor-v04.acr") and replay_list.get_child_count()==1,"confirmed deletion removes only selected replay and refreshes list")
	check(pages._load_replay("qa-neighbor-v04.acr") and main.replay_mode,"remaining replay still loads and plays")
	main._main_menu()
	pages.replays()
	pages.confirm_replay_delete("qa-neighbor-v04.acr")
	for action in pages.modal.content.find_children("*","Button",true,false):
		if action.text=="삭제":action.pressed.emit();break
	check(not main.replay_mode and main.replay_frames.is_empty() and pages.replay_file=="","deleting current replay safely stops retained playback state")
	var empty_visible=false
	for item in pages.modal.find_children("*","Label",true,false):
		if item.text=="저장된 리플레이가 없습니다.":empty_visible=true
	check(empty_visible and pages.modal.find_child("ReplayList",true,false).get_child_count()==0,"deleting last replay refreshes empty state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://replays/qa-directory-v04.acr"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa-outside-v04.acr"))
	main.queue_free()
	await process_frame
	if profile_existed:
		var file=FileAccess.open("user://profile.json",FileAccess.WRITE);file.store_string(profile_before)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
	if settings_existed:
		var file=FileAccess.open("user://settings.json",FileAccess.WRITE);file.store_string(settings_before)
	print("MENU_V04_TEST checks=%d failures=%d (mock API; no network claim)"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
