class_name ACMenuPages
extends RefCounted

var main: Control
var discovery: ACLobbyDiscovery
var modal: ACMenuLayer
var ready_button: Button
var room_controls: Array[Control]=[]
var auth_nick: LineEdit
var auth_pass: LineEdit
var online_attempt=0
var returning_to_game=false
var room_owner_id=""
var room_member_ids: Array=[]
var room_rows: Array=[]
var room_preview: ACLobbyMapPreview
var room_map_name: Label
var replay_file=""
var observer_button: Button
var team_button: Button
var add_bot_button: Button
var remove_bot_button: Button
var room_notice=""
var room_notice_until=0

func _init(controller: Control) -> void:
	main=controller

func open(page_name: String,title: String,extent=Vector2(1040,720)) -> Control:
	if main.ui.get_node_or_null("MainHub")==null and main.page!="game":main._main_menu()
	close()
	main.page=page_name
	modal=ACMenuLayer.new()
	main.ui.add_child(modal)
	modal.configure(main,title,extent)
	modal.closed.connect(func():main._main_menu())
	return modal.content

func close() -> void:
	var previous=main.ui.get_node_or_null("MenuModal")
	if previous!=null:
		main.ui.remove_child(previous)
		previous.queue_free()
	modal=null

func label(parent: Node,text: String,y: float,width=850,font_size=19,x=0.0) -> Label:
	return main._label(parent,text,Vector2(x,y),width,font_size)

func button(parent: Node,text: String,x: float,y: float,width: float,action: Callable,height=48) -> Button:
	var button=main._button(parent,text,Vector2(x,y),width,action,height)
	button.add_theme_font_size_override("font_size",20)
	button.clip_text=true
	if is_instance_valid(modal):modal.style_control(button,Vector2(width,height))
	return button

func option(parent: Node,items: Array,x: float,y: float,width: float,index: int,action: Callable) -> OptionButton:
	var option=main._option(parent,items,Vector2(x,y),width,index,action)
	option.add_theme_font_size_override("font_size",20)
	option.clip_text=true
	if is_instance_valid(modal):modal.style_control(option,Vector2(width,44))
	return option

func single() -> void:
	var p=open("single","싱글플레이",Vector2(1140,840))
	label(p,"선택한 전장",0,350,23,545)
	var preview=ACLobbyMapPreview.new()
	preview.name="SingleMapPreview"
	preview.position=Vector2(545,45)
	preview.size=Vector2(320,320)
	p.add_child(preview)
	preview.set_map(main.map_choice)
	label(p,"128 × 128 · 최대 4명",385,350,18,545)
	label(p,"내 종족",0)
	option(p,ACData.get_data().race_names,0,40,300,main.race_choice,func(i):main.race_choice=i)
	label(p,"전장",105)
	option(p,ACLobbyMapPreview.map_names(),0,145,300,main.map_choice,func(i):main.map_choice=i;preview.set_map(i))
	label(p,"컴퓨터 수",210)
	option(p,["1명 · 1 대 1","2명 · 3인 자유전","3명 · 4인 자유전"],0,250,300,main.bot_count-1,func(i):main.bot_count=i+1)
	label(p,"컴퓨터 난이도",315)
	option(p,["쉬움","보통","어려움"],0,355,300,main.difficulty,func(i):main.difficulty=i)
	option(p,["자유전","2 대 2 팀전"],0,420,300,1 if main.game_mode=="teams" else 0,func(i):main.game_mode="teams" if i==1 else "ffa")
	button(p,"전투 시작",0,510,300,func():
		var count=3 if main.game_mode=="teams" else main.bot_count
		var players:Array=[{"name":main.account.get("nickname","지휘관"),"race":main.race_choice,"team":0}]
		for i in range(count):players.append({"name":"컴퓨터 %d"%(i+1),"race":(main.race_choice+i+1)%3,"team":(i+1)%2,"bot":true,"difficulty":main.difficulty})
		main._start_local({"map":main.map_choice,"mode":main.game_mode,"players":players})
	,48)

func settings() -> void:
	returning_to_game=main.page=="game"
	var was_game=returning_to_game
	var p=open("game" if was_game else "settings","환경 설정",Vector2(960,820))
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(func():_settings_back(was_game))
	if was_game and not main.network_client:main.paused=true
	var panel=ACSettingsPanel.new()
	p.add_child(panel)
	panel.configure(main,self,Callable(self,"_settings_back").bind(was_game))

func _settings_back(was_game: bool) -> void:
	if was_game:close();main._pause_menu()
	else:main._main_menu()

func online() -> void:
	online_attempt+=1
	var attempt=online_attempt
	var p=open("online","멀티플레이",Vector2(890,590))
	main.online_status=label(p,"전장을 찾고 있습니다…",80,740,24)
	main.online_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	main.online_status.size.y=140
	label(p,"인터넷에서 지휘관을 찾아 래더와 커스텀 경기에 참가합니다.",20,740,17)
	button(p,"뒤로",0,270,220,func():online_attempt+=1;main._main_menu())
	button(p,"다시 연결",250,270,220,func():
		if discovery!=null:discovery.forget_service()
		online()
	)
	if discovery==null:
		discovery=ACLobbyDiscovery.new()
		main.add_child(discovery)
	# Render the modal before discovery or local service startup can run.
	await main.get_tree().process_frame
	if attempt!=online_attempt or main.page!="online":return
	discovery.ensure_service(func(endpoint,_scope):
		if attempt!=online_attempt or main.page!="online":return
		if endpoint=="":main.online_status.text="멀티플레이를 준비하지 못했습니다. 게임 압축을 모두 푼 뒤 다시 실행해 주세요.";return
		main.backend_url=endpoint
		main._api("/health",{},func(data):
			if attempt!=online_attempt or main.page!="online":return
			if data.has("error"):
				discovery.forget_service()
				main.online_status.text="로비에 연결하지 못했습니다. 다시 연결을 눌러 재탐색해 주세요."
				return
			if int(data.get("protocol",0))!=10:main.online_status.text="연결할 지휘관들이 모두 같은 버전의 게임을 실행해야 합니다.";return
			_open_online_account(attempt)
		)
	)

func _open_online_account(attempt: int) -> void:
	if _account_ready():
		main._api("/me",{},func(data):
			if attempt!=online_attempt or main.page!="online":return
			if data.has("user") and data.user.get("nickname_confirmed",false):main.account=data.user;main._rooms_menu()
			else:main.account={};main.session_token="";account_menu()
		)
		return
	main.account={}
	main.session_token=""
	account_menu()
	_migrate_legacy_identity()

func _account_ready() -> bool:
	return main.session_token!="" and bool(main.account.get("nickname_confirmed",false))

func _migrate_legacy_identity() -> void:
	# Only prove the old generated credential pair; never log in or create an account.
	if not FileAccess.file_exists("user://commander.json"):return
	var identity=JSON.parse_string(FileAccess.get_file_as_string("user://commander.json"))
	if not identity is Dictionary:return
	var password=str(identity.get("password",""))
	var pattern=RegEx.create_from_string("^[0-9a-f]{40}$")
	if pattern.search(password)==null or str(identity.get("nickname",""))!="지휘관"+password.substr(0,12):return
	main._api("/account/legacy",identity,func(_data):pass)

func _complete_auth(data: Dictionary) -> void:
	if not data.get("user",{}).get("nickname_confirmed",false):
		main.account={}
		main.session_token=""
		if is_instance_valid(main.online_status):main.online_status.text="직접 정한 닉네임으로 가입하거나 로그인해 주세요."
		return
	main.session_token=data.token
	main.account=data.user
	main._rooms_menu()

func account_menu() -> void:
	var p=open("account","멀티플레이 로그인",Vector2(820,650))
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(_account_back)
	label(p,"직접 정한 닉네임으로 전장에 참여하세요.",0,650,19)
	auth_nick=LineEdit.new()
	auth_nick.name="Nickname"
	auth_nick.placeholder_text="닉네임 · 2~16자"
	auth_nick.max_length=16
	auth_nick.position=Vector2(0,60)
	auth_nick.size=Vector2(650,48)
	auth_nick.add_theme_font_size_override("font_size",20)
	if FileAccess.file_exists("user://profile.json"):
		var parser=JSON.new()
		if parser.parse(FileAccess.get_file_as_string("user://profile.json"))==OK and parser.data is Dictionary:auth_nick.text=str(parser.data.get("nickname",""))
	p.add_child(auth_nick)
	auth_pass=LineEdit.new()
	auth_pass.name="Password"
	auth_pass.placeholder_text="비밀번호 · 6자 이상"
	auth_pass.max_length=100
	auth_pass.secret=true
	auth_pass.position=Vector2(0,125)
	auth_pass.size=Vector2(650,48)
	auth_pass.add_theme_font_size_override("font_size",20)
	auth_pass.text_submitted.connect(func(_text):authenticate(false))
	p.add_child(auth_pass)
	main.online_status=label(p,"",255,650,17)
	main.online_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	main.online_status.size.y=70
	button(p,"로그인",0,195,300,func():authenticate(false))
	button(p,"회원 가입",335,195,300,func():authenticate(true))
	button(p,"돌아가기",0,345,220,_account_back)
	auth_nick.grab_focus()

func _account_back() -> void:
	if _account_ready():main._rooms_menu()
	else:main._main_menu()

func authenticate(register: bool) -> void:
	if main.api_busy:return
	var identity={"nickname":auth_nick.text.strip_edges(),"password":auth_pass.text}
	if identity.nickname.length()<2 or identity.password.length()<6:
		main.online_status.text="닉네임 2~16자와 비밀번호 6자 이상을 입력하세요."
		if main.audio!=null:main.audio.play_ui("error")
		return
	main._api("/register" if register else "/login",identity,func(data):
		if main.page!="account":return
		if data.has("token"):
			var file=FileAccess.open("user://profile.json",FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify({"nickname":identity.nickname}))
			_complete_auth(data)
		elif is_instance_valid(main.online_status):
			main.online_status.text=data.get("error","로그인 실패")
			if main.audio!=null:main.audio.play_ui("error")
	)

func rooms() -> void:
	if not _account_ready():account_menu();return
	var scope="온라인"
	var p=open("rooms","멀티플레이 · "+scope,Vector2(1260,840))
	label(p,"%s   ·   %d점"%[main.account.get("nickname","지휘관"),int(main.account.get("rating",1000))],0,650,21)
	main.race_select=option(p,ACData.get_data().race_names,0,55,300,main.race_choice,func(i):main.race_choice=i)
	button(p,"방 만들기",390,55,220,func():main._api("/room/create",{"race":main.race_choice,"map":main.map_choice,"mode":"ffa"},func(data):
		if data.has("room"):main.room=data.room;main._room_menu()
		else:main._notify(data.get("error","방을 만들지 못했습니다."))
	))
	button(p,"새로고침",630,55,220,main._fetch_rooms)
	button(p,"계정",870,55,220,account_menu)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(0,130)
	scroll.size=Vector2(1095,365)
	p.add_child(scroll)
	main.room_list=VBoxContainer.new()
	main.room_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main.room_list.add_theme_constant_override("separation",12)
	scroll.add_child(main.room_list)
	button(p,"래더 매치",0,530,220,main._ladder_menu)
	button(p,"순위표",280,530,220,main._leaderboard_menu)
	button(p,"뒤로",840,530,220,main._main_menu)
	main._fetch_rooms()

func fetch_rooms() -> void:
	main._api("/rooms",{},func(data):
		if main.page!="rooms" or not is_instance_valid(main.room_list):return
		for child in main.room_list.get_children():main.room_list.remove_child(child);child.queue_free()
		if data.has("error"):
			if main.account.is_empty():main._online_menu();return
			label(main.room_list,data.error,0,1000,18)
			var retry=Button.new()
			retry.text="다시 연결"
			retry.custom_minimum_size=Vector2(220,48)
			retry.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
			if is_instance_valid(modal):modal.style_control(retry,Vector2(220,48))
			retry.pressed.connect(func():
				if discovery!=null:discovery.forget_service()
				main.account={};main.session_token="";main._online_menu()
			)
			main.room_list.add_child(retry)
			return
		if data.rooms.is_empty():label(main.room_list,"열린 방이 없습니다. 새 방을 만들어 보세요.",0,1000,19)
		for item in data.rooms:main.room_list.add_child(make_room_row(item))
	)

func make_room_row(item: Dictionary) -> Panel:
	var row=Panel.new()
	row.custom_minimum_size=Vector2(1060,64)
	row.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var background=StyleBoxFlat.new()
	background.bg_color=Color(.025,.035,.045,.78)
	background.border_color=Color(.56,.47,.27,.45)
	background.set_border_width_all(1)
	row.add_theme_stylebox_override("panel",background)
	var description=label(row,"%s\n참가 %d / %d · 관전 %d / 4 · %s"%[item.name,item.members.filter(func(m):return not m.get("observer",false)).size(),4-item.get("closed_slots",[]).size(),item.members.filter(func(m):return m.get("observer",false)).size(),ACLobbyMapPreview.map_names()[int(item.map)]],4,800,18,16)
	description.size.y=56
	description.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button(row,"입장",832,8,220,func():main._api("/room/join",{"id":item.id,"race":main.race_choice},func(result):
		if result.has("room"):main.room=result.room;main._room_menu()
		else:main._notify(result.get("error","입장하지 못했습니다."))
	))
	return row

func _room_seats(room: Dictionary) -> Array:
	var seats=[{},{},{},{},{},{},{},{}]
	for member in room.members:
		if member.get("observer",false):
			for index in range(4,8):
				if seats[index].is_empty():seats[index]=member;break
		else:
			var slot=int(member.get("slot",-1)) if member.get("slot")!=null else -1
			if slot>=0 and slot<4 and seats[slot].is_empty():seats[slot]=member
			else:
				for index in range(4):
					if seats[index].is_empty():seats[index]=member;break
	return seats

func room_menu() -> void:
	if not _account_ready():account_menu();return
	var p=open("room","커스텀 대기실",Vector2(1260,840))
	room_controls=[]
	room_rows=[]
	room_member_ids=[]
	var seats=_room_seats(main.room)
	for member in seats:room_member_ids.append(str(member.get("user","")))
	var owner=main.room.owner==main.account.id
	room_owner_id=str(main.room.owner)
	room_map_name=label(p,"",0,300,22)
	room_preview=ACLobbyMapPreview.new()
	room_preview.name="RoomMapPreview"
	room_preview.position=Vector2(0,42)
	room_preview.size=Vector2(300,300)
	p.add_child(room_preview)
	main.map_select=option(p,ACLobbyMapPreview.map_names(),0,365,300,int(main.room.map),func(i):main._room_update({"map":i}))
	main.map_select.set_meta("owner_only",true)
	room_controls.append(main.map_select)
	main.mode_select=option(p,["자유전","팀전"],0,425,300,1 if main.room.mode=="teams" else 0,func(i):main._room_update({"mode":"teams" if i==1 else "ffa"}))
	main.mode_select.set_meta("owner_only",true)
	room_controls.append(main.mode_select)
	label(p,"128 × 128 · 최대 4명\n스타팅 무작위",490,300,18)
	var room_title=label(p,str(main.room.name),0,740,22,350)
	room_title.clip_text=true
	room_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label(p,"참가자",40,220,17,368)
	label(p,"종족",40,220,17,600)
	label(p,"팀",40,85,17,850)
	label(p,"상태",40,120,17,950)
	main.race_select=null
	for index in range(8):
		var row=Panel.new()
		row.name="PlayerSlot%d"%index
		row.position=Vector2(350,72+index*39)
		row.size=Vector2(740,37)
		var style=StyleBoxFlat.new()
		style.bg_color=Color(.035,.045,.05,.85)
		style.border_color=Color(.53,.45,.28,.5)
		style.set_border_width_all(1)
		row.add_theme_stylebox_override("panel",style)
		p.add_child(row)
		var nick=label(row,"빈 슬롯",4,210,17,18)
		nick.clip_text=true
		nick.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		var race=label(row,"",4,220,17,250)
		var team=label(row,"",4,85,17,500)
		var status=label(row,"",4,125,17,600)
		for item in [nick,race,team,status]:item.size.y=29
		room_rows.append({"nickname":nick,"race":race,"team":team,"status":status})
		var seated: Dictionary=seats[index]
		if index<4 and owner:
			var slot_index=index
			var slot_button=button(row,"슬롯 닫기",600,0,125,func():main._room_update({"slot":slot_index,"closed":not slot_index in main.room.get("closed_slots",[])}),36)
			slot_button.add_theme_font_size_override("font_size",14)
			slot_button.set_meta("owner_only",true)
			room_rows.back()["slot_button"]=slot_button;room_controls.append(slot_button)
		if seated.get("bot",false) and owner:
			race.visible=false
			var bot_id=str(seated.user)
			var bot_select=option(row,["바위너구리","귤 변이 군체","고대 부엉이"],250,0,220,int(seated.race),func(i):main._room_update({"bot_id":bot_id,"bot_race":i}))
			bot_select.size.y=36;bot_select.custom_minimum_size.y=36
			bot_select.add_theme_font_size_override("font_size",17)
			bot_select.set_meta("owner_only",true)
			room_rows.back()["bot_select"]=bot_select
			room_controls.append(bot_select)
		if seated.get("user","")==main.account.id:
			race.visible=false
			main.race_select=option(row,["바위너구리","귤 변이 군체","고대 부엉이"],250,0,220,int(seated.race),func(i):main.race_choice=i;main._room_update({"race":i}))
			main.race_select.size.y=36
			main.race_select.custom_minimum_size.y=36
			main.race_select.add_theme_font_size_override("font_size",17)
			room_controls.append(main.race_select)
	main.room_detail=label(p,"",385,740,18,350)
	main.room_detail.size.y=48
	main.room_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	team_button=button(p,"팀 변경",350,445,160,func():
		for member in main.room.members:
			if member.user==main.account.id:main._room_update({"team":1-int(member.team)})
	)
	room_controls.append(team_button)
	observer_button=button(p,"관전자로 전환",520,445,175,func():
		for member in main.room.members:
			if member.user==main.account.id:main._room_update({"observer":not member.get("observer",false)})
	)
	room_controls.append(observer_button)
	if owner:
		add_bot_button=button(p,"컴퓨터 추가",705,445,180,func():main._room_update({"add_bot":true}))
		remove_bot_button=button(p,"컴퓨터 제거",895,445,180,func():main._room_update({"remove_bot":true}))
		room_controls.append(add_bot_button);room_controls.append(remove_bot_button)
	for control in [team_button,observer_button,add_bot_button,remove_bot_button]:
		if is_instance_valid(control):control.add_theme_font_size_override("font_size",16)
	ready_button=button(p,"준비",350,520,300,func():
		for member in main.room.members:
			if member.user==main.account.id:main._room_update({"ready":not member.ready})
	,48)
	button(p,"방 나가기",830,520,220,leave_room)
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(leave_room)
	update_room_text()
	main.poll_clock=.15

func show_room_notice(message: String) -> void:
	room_notice=message;room_notice_until=Time.get_ticks_msec()+6000
	update_room_text()

func leave_room() -> void:
	main._api("/room/leave",{},func(data):
		if data.has("error"):show_room_notice(str(data.error));return
		main.room={};main._rooms_menu()
	)

func update_room_text() -> void:
	if not is_instance_valid(main.room_detail):return
	var r=main.room
	var seats=_room_seats(r)
	var member_ids: Array=[]
	for member in seats:member_ids.append(str(member.get("user","")))
	if room_owner_id!=str(r.owner) or room_member_ids!=member_ids:room_menu();return
	room_preview.set_map(int(r.map))
	room_map_name.text=ACLobbyMapPreview.map_names()[int(r.map)]
	var self_observer=false
	var player_count=0
	var observer_count=0
	var bot_count=0
	for member in r.members:
		if member.get("observer",false):observer_count+=1
		else:player_count+=1
		if member.get("bot",false):bot_count+=1
	for index in range(8):
		var row=room_rows[index]
		var member: Dictionary=seats[index]
		if row.has("slot_button"):
			row.slot_button.visible=member.is_empty()
			row.slot_button.text="슬롯 열기" if index in r.get("closed_slots",[]) else "슬롯 닫기"
			row.status.visible=not member.is_empty()
		if member.is_empty():
			var closed=index<4 and index in r.get("closed_slots",[])
			row.nickname.text=("닫힌 플레이어 슬롯 %d"%[index+1] if closed else "빈 플레이어 슬롯 %d"%[index+1]) if index<4 else "빈 관전자 슬롯"
			row.race.text="";row.team.text="";row.status.text="닫힘" if closed else "참가 대기" if index<4 else "관전 대기"
			row.status.modulate=Color("777e82")
			continue
		row.nickname.text=member.nickname+(" · 방장" if member.user==r.owner else "")
		var observing=bool(member.get("observer",false))
		row.race.text="관전자" if observing else ["바위너구리","귤 변이 군체","고대 부엉이"][int(member.race)]
		row.team.text=str(int(member.team)+1) if r.mode=="teams" and not observing else "—"
		row.status.text="관전" if observing else ("준비 완료" if member.ready else "준비 대기")
		row.status.modulate=Color("a5d88f") if member.ready else Color("b8b6ac")
		if row.has("bot_select"):row.bot_select.select(int(member.race))
		if member.user==main.account.id:
			self_observer=observing
			observer_button.text="플레이어로 전환" if observing else "관전자로 전환"
			if is_instance_valid(ready_button):ready_button.text="준비 취소" if member.ready else ("호스팅 준비" if observing and r.owner==main.account.id else "준비")
			row.race.visible=observing
			if is_instance_valid(main.race_select):
				main.race_select.visible=not observing
				main.race_select.select(int(member.race))
	main.room_detail.text="모두 준비하면 5초 뒤 시작 · 남은 3초부터 준비 확정"
	if self_observer and r.owner==main.account.id:main.room_detail.text="방장 관전 · 내 PC로 호스팅 · 참가자와 방장 모두 준비하면 시작"
	if player_count<2:main.room_detail.text="전투할 플레이어가 2명 이상 필요합니다. 컴퓨터도 참가할 수 있습니다."
	if r.get("countdown")!=null:main.room_detail.text="%d초 뒤 전투 시작%s"%[int(r.countdown)," · 준비 확정" if r.get("locked",false) else ""]
	elif r.get("start_error")!=null:main.room_detail.text=str(r.start_error)
	if Time.get_ticks_msec()<room_notice_until:main.room_detail.text=room_notice
	if is_instance_valid(main.map_select):main.map_select.select(int(r.map))
	if is_instance_valid(main.mode_select):main.mode_select.select(1 if r.mode=="teams" else 0)
	var locked=bool(r.get("locked",false)) or main.room_update_pending
	if is_instance_valid(ready_button):ready_button.disabled=locked or (self_observer and r.owner!=main.account.id)
	for control in room_controls:
		if is_instance_valid(control):control.set("disabled",locked or (control.get_meta("owner_only",false) and r.owner!=main.account.id))
	if is_instance_valid(main.race_select):main.race_select.disabled=locked or self_observer
	team_button.disabled=locked or self_observer or r.mode!="teams"
	team_button.tooltip_text="팀전에서 플레이어의 팀을 변경합니다." if r.mode!="teams" else "1팀과 2팀을 전환합니다."
	var capacity=4-r.get("closed_slots",[]).size()
	observer_button.disabled=locked or (player_count>=capacity if self_observer else observer_count>=4)
	observer_button.tooltip_text="방장도 관전할 수 있으며 내 PC가 호스팅을 계속합니다." if r.owner==main.account.id else "플레이어와 관전자를 전환합니다. 각 정원은 4명입니다."
	if is_instance_valid(add_bot_button):
		add_bot_button.disabled=locked or player_count>=capacity or r.members.size()>=8 or r.owner!=main.account.id
		add_bot_button.tooltip_text="열린 플레이어 슬롯은 컴퓨터를 포함해 %d명입니다."%capacity
	if is_instance_valid(remove_bot_button):
		remove_bot_button.disabled=locked or bot_count==0 or r.owner!=main.account.id
		remove_bot_button.tooltip_text="마지막으로 추가한 컴퓨터를 제거합니다."

func ladder() -> void:
	if not _account_ready():account_menu();return
	var scope="온라인"
	var p=open("ladder","래더 매치 · 1 대 1 · "+scope,Vector2(1010,790))
	label(p,"%s   ·   %d점   ·   %d승 %d패"%[main.account.nickname,int(main.account.rating),int(main.account.wins),int(main.account.losses)],0,850,22)
	option(p,ACData.get_data().race_names,0,70,300,main.race_choice,func(i):main.race_choice=i)
	main.queue_label=label(p,"세 전장 중 하나에서 비슷한 실력의 상대를 찾습니다.\n전장과 스타팅은 매칭 시 무작위로 정합니다.\n\n동일한 점수의 상대: 승리 +20 / 패배 -20\n상대가 200점 높으면: 승리 약 +30 / 패배 약 -10",155,850,21)
	main.queue_label.size.y=230
	button(p,"상대 찾기",0,385,300,func():main._api("/queue/join",{"race":main.race_choice},func(data):
		if data.has("error"):main._notify(data.error)
		else:main.queue_data={"queued":true};main.queue_label.text="상대를 찾고 있습니다…"
	))
	main.accept_button=button(p,"매치 수락",330,385,300,func():
		if main.queue_data.get("offer")!=null:main._api("/queue/accept",{"id":main.queue_data.offer.id},func(data):
			if data.has("error"):main._notify(data.error)
		)
	)
	main.accept_button.visible=false
	var cancel=func():main._api("/queue/leave",{},func(_data):main.queue_data={};main._rooms_menu())
	button(p,"검색 취소",0,470,220,cancel)
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(cancel)
	main.poll_clock=.3

func leaderboard() -> void:
	if not _account_ready():account_menu();return
	var p=open("ranking","래더 순위",Vector2(1010,840))
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(func():main._rooms_menu())
	var status=label(p,"불러오는 중…",0,850,18)
	var table=Tree.new()
	table.name="LadderStandings"
	table.position=Vector2(0,40)
	table.size=Vector2(860,460)
	table.columns=6
	table.column_titles_visible=true
	table.hide_root=true
	table.select_mode=Tree.SELECT_ROW
	table.add_theme_font_size_override("font_size",20)
	table.add_theme_font_size_override("title_button_font_size",19)
	var titles=["순위","닉네임","점수","승","패","승률"]
	var widths=[65,285,120,100,100,135]
	for column in range(6):
		table.set_column_title(column,titles[column])
		table.set_column_expand(column,column==1)
		table.set_column_custom_minimum_width(column,widths[column])
	var root_item=table.create_item()
	p.add_child(table)
	main._api("/leaderboard",{},func(data):
		if not is_instance_valid(table):return
		if data.has("error"):status.text=data.error;return
		var ranked_users=data.users.filter(func(user):return int(user.get("wins",0))+int(user.get("losses",0))>0)
		status.text="%d명의 지휘관"%ranked_users.size() if not ranked_users.is_empty() else "아직 래더 전적이 있는 지휘관이 없습니다."
		for index in range(ranked_users.size()):
			var user=ranked_users[index]
			var row=table.create_item(root_item)
			var values=[str(index+1),str(user.nickname),str(int(user.rating)),str(int(user.wins)),str(int(user.losses)),"%.1f%%"%float(user.get("win_rate",0)) if int(user.wins)+int(user.losses)>0 else "—"]
			for column in range(6):
				row.set_text(column,values[column])
				row.set_text_alignment(column,HORIZONTAL_ALIGNMENT_LEFT if column==1 else HORIZONTAL_ALIGNMENT_CENTER)
			row.set_custom_minimum_height(42)
	)
	button(p,"돌아가기",0,525,220,main._rooms_menu)

func result(won: bool) -> Control:
	var observing=main.spectator or main.replay_mode
	var p=open("game","관전 종료" if observing else ("승리" if won else "패배"),Vector2(940,760))
	modal.heading.modulate=Color("ddd6c0") if observing else (Color("f0d17b") if won else Color("e99183"))
	var leave=func():
		main._leave_network()
		main.core=null
		main.result_sent=false
		main.paused=false
		main._main_menu()
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(leave)
	label(p,"전투 기록",0,750,24)
	var player=main.state.get("players",[])[main.local_slot] if main.local_slot<main.state.get("players",[]).size() else {}
	var seconds=int(main.state.get("time",0))
	var rows=[
		["전투 시간","%02d:%02d"%[seconds/60,seconds%60]],
		["종족",["바위너구리","귤 변이 군체","고대 부엉이"][int(player.get("race",main.settings.last_played_race))]],
		["수집한 자원",str(int(player.get("gathered",0)))],
		["처치한 유닛",str(int(player.get("kills",0)))]
	]
	if observing:
		var winners: Array=[]
		for slot in main.state.get("winners",[]):
			if int(slot)>=0 and int(slot)<main.state.players.size():winners.append(str(main.state.players[int(slot)].get("name","플레이어 %d"%(int(slot)+1))))
		rows=[["전투 시간","%02d:%02d"%[seconds/60,seconds%60]],["승리 진영",", ".join(winners) if not winners.is_empty() else "없음"],["참여 방식","관전자"],["기록","관전 리플레이 저장"]]
	for index in range(rows.size()):
		label(p,rows[index][0],64+index*55,320,21)
		label(p,rows[index][1],64+index*55,400,21,340)
	var rating=label(p,"래더 결과를 확인하고 있습니다…" if main.network_client and main.remote_game.get("ranked",false) else "커스텀 · 래더 점수 변동 없음" if main.network_client else "싱글플레이",310,750,20)
	rating.name="ResultRating"
	if observing:rating.text="관전 · 승패 및 래더 점수 변동 없음"
	rating.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rating.size.y=64
	button(p,"메인 화면",0,425,300,leave)
	var replay=button(p,"리플레이 보기",340,425,300,_watch_result_replay)
	replay.disabled=main.replay_frames.is_empty()
	var save=button(p,"리플레이 저장",680,425,300,func():main._save_replay())
	save.disabled=main.replay_frames.is_empty()
	return p

func _watch_result_replay() -> void:
	if main.replay_frames.is_empty():return
	main._leave_network()
	main.core=null
	main.replay_mode=true
	main.replay_index=0
	main.replay_clock=0
	replay_file=""
	main.state=main._replay_state(main.replay_frames[0])
	main.selected=[]
	main.selected_resource=-1
	main.paused=false
	main._focus_home(true)
	main._begin_replay()
	close()
	main._build_hud()

func connecting() -> void:
	var p=open("connecting","전투 연결",Vector2(820,560))
	label(p,"전장에 진입하고 있습니다…",55,650,25)
	label(p,"다른 지휘관의 연결이 완료되면 전투를 시작합니다.",115,650,18)
	var cancel=func():main._leave_network();main._rooms_menu()
	button(p,"취소",0,235,220,cancel)
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(cancel)

func replays() -> void:
	var p=open("replays","리플레이",Vector2(1090,840))
	var dir=DirAccess.open("user://replays")
	var files=PackedStringArray()
	if dir!=null:
		for file in dir.get_files():
			if file.get_extension().to_lower()=="acr":files.append(file)
		files.sort()
		files.reverse()
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(0,0)
	scroll.size=Vector2(940,480)
	p.add_child(scroll)
	var list=VBoxContainer.new()
	list.name="ReplayList"
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for file in files:
		var row=Panel.new()
		row.set_meta("replay_file",file)
		row.custom_minimum_size=Vector2(920,64)
		var style=StyleBoxFlat.new()
		style.bg_color=Color(.035,.045,.05,.85)
		style.border_color=Color(.53,.45,.28,.5)
		style.set_border_width_all(1)
		row.add_theme_stylebox_override("panel",style)
		list.add_child(row)
		var filename=label(row,file+(" · 재생 중" if main.replay_mode and replay_file==_replay_path(file) else ""),18,410,19,14)
		filename.clip_text=true
		filename.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		button(row,"재생",450,8,220,func():_load_replay(file))
		button(row,"삭제",690,8,220,func():confirm_replay_delete(file))
	if files.is_empty():label(p,"저장된 리플레이가 없습니다.",40,900,22)
	button(p,"돌아가기",0,520,220,main._main_menu)

func _replay_path(file: String) -> String:
	if file=="" or file.get_file()!=file or file.get_extension().to_lower()!="acr" or file.contains(":") or file.contains("/") or file.contains("\\"):return ""
	var user_directory=DirAccess.open("user://")
	var replays_directory=DirAccess.open("user://replays")
	if user_directory==null or replays_directory==null or user_directory.is_link("replays") or replays_directory.is_link(file):return ""
	var directory=ProjectSettings.globalize_path("user://replays").simplify_path()
	var target=directory.path_join(file).simplify_path()
	if target.get_base_dir()!=directory or DirAccess.dir_exists_absolute(target):return ""
	return target

func _load_replay(file: String) -> bool:
	var path=_replay_path(file)
	if path=="" or not FileAccess.file_exists(path):main._notify("리플레이 파일을 찾지 못했습니다.");return false
	var stream=FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_DEFLATE)
	if stream==null:main._notify("리플레이를 열지 못했습니다.");return false
	var replay=stream.get_var(false)
	stream.close()
	if not replay is Dictionary or not replay.get("frames") is Array or replay.frames.is_empty():main._notify("리플레이 기록이 올바르지 않습니다.");return false
	main.replay_codec=int(replay.get("codec",FileAccess.COMPRESSION_DEFLATE))
	var first=main._replay_state(replay.frames[0])
	var slot=int(replay.get("slot",-1))
	var map=int(replay.get("map",-1))
	if not first.get("players") is Array or slot<0 or slot>=first.players.size() or map<0 or map>2:main._notify("리플레이 기록이 올바르지 않습니다.");return false
	main._leave_network()
	main.replay_frames=replay.frames
	main.replay_mode=true
	main.replay_index=0
	main.replay_clock=0
	main.local_slot=slot
	main.state=first
	main.draw_map.make(map,str(replay.get("map_layout",first.get("map_layout","reference_inspired_original"))))
	main._focus_home(true)
	main._begin_replay()
	main.paused=false
	main.core=null
	replay_file=path
	close()
	main._build_hud()
	return true

func confirm_replay_delete(file: String) -> void:
	if _replay_path(file)=="":main._notify("삭제할 리플레이 경로가 올바르지 않습니다.");return
	var p=open("replay_delete","리플레이 삭제",Vector2(820,560))
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(replays)
	label(p,"이 리플레이를 삭제할까요?",25,650,24)
	var filename=label(p,file,90,650,20)
	filename.clip_text=true
	filename.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var status=label(p,"",145,650,17)
	button(p,"삭제",0,235,220,func():
		if _delete_replay(file)==OK:replays()
		else:status.text="리플레이를 삭제하지 못했습니다. 다시 시도해 주세요."
	)
	button(p,"취소",260,235,220,replays)

func _delete_replay(file: String) -> int:
	var path=_replay_path(file)
	if path=="" or not FileAccess.file_exists(path):return ERR_INVALID_PARAMETER
	var result=DirAccess.remove_absolute(path)
	if result==OK and main.replay_mode and replay_file==path:
		main.replay_mode=false
		main.replay_frames=[]
		main.replay_index=0
		main.replay_clock=0
		main.core=null
		main.paused=false
		replay_file=""
	return result

func pause() -> void:
	if main.page!="game":return
	if main.ui.get_node_or_null("MenuModal")!=null:return
	if not main.network_client:main.paused=true
	var p=open("game","게임 메뉴",Vector2(730,710))
	var resume=func():close();main.paused=false
	modal.closed.disconnect(modal.closed.get_connections()[0].callable)
	modal.closed.connect(resume)
	button(p,"계속하기",45,0,300,resume)
	button(p,"환경 설정",45,75,300,settings)
	button(p,"리플레이 저장",45,150,300,func():main._save_replay())
	button(p,"항복",45,225,300,func():resume.call();main._send_command({"type":"surrender"}))
	button(p,"메인 화면",45,300,300,func():
		if not main.replay_mode and not main.state.get("ended",false):main._send_command({"type":"surrender"})
		main._leave_network()
		main.core=null
		main.paused=false
		main._main_menu()
	)
	label(p,"온라인 경기는 메뉴를 열어도 계속 진행됩니다.",390,570,16)
