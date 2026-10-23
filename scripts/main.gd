extends Control

const Core=preload("res://scripts/core.gd")
const REPLAYS_ENABLED=false
var simulation_worker: ACSimulationWorker
var loading_job: ACBattleLoader
var loading_screen: ACLoadingScreen
var loading_config: Dictionary={}
var loading_result: Dictionary={}
var loading_local=false
var loading_connected=false
var loading_authenticated=false
var _placement_requested=""
var _placement_result={}
const ConstructionVisual=preload("res://scripts/construction_visual.gd")
const DEFAULT_ZOOM=1.75
const MIN_ZOOM=1.0
const MAX_ZOOM=2.5
var assets:=ACAssets.new()
var battle_hud: ACRtsHUD
var audio: ACAudio
var terrain_artist:=ACTerrainRenderer.new()
var root_artist=preload("res://scripts/root_renderer.gd").new()
var construction_visual:=ConstructionVisual.new()
var building_damage_visual:=preload("res://scripts/building_damage_visual.gd").new()
var building_status_lights:=preload("res://scripts/building_status_lights.gd").new()
var death_visual:=preload("res://scripts/death_visual.gd").new()
var pointer_skill: String=""
var pointer_order=""
var render_rects: Dictionary={}
var world_clip: Control
var world_canvas: Control
var _world_effect_canvas: Control
var _entity_canvases: Dictionary={}
var _selection_bodies: Dictionary={}
var _fog_canvas: ACFogCanvas
var _root_canvas: Control
var _object_canvas_offset=Vector2.ZERO
var nuclear_clouds: Dictionary={}
var world_mask: Control
var camera_velocity=Vector2.ZERO
var pointer_position=Vector2.INF
var visual_previous: Dictionary={}
var visual_current: Dictionary={}
var visual_clock=0.0
var visual_step=.05
var visual_state_time=-1.0
var visual_motion: Dictionary={}
var _pointer_confined=false
var _cursor_key=""
var _cursor_frames: Dictionary={}
var effect_frames: Array=[]
var building_parts: Array=[]
var world_resources: Array=[]
var world_resource_images: Array=[]
var tera_theme_textures: Array=[]
var tera_theme_images: Array=[]
var double_select=false
var menu_backdrop: Texture2D
var menu_pages: ACMenuPages
var core: ACCore
var state: Dictionary={}
var draw_map:=ACMap.new()
var ui: Control
var page="main"
var selected: Array=[]
var selected_resource: int=-1
var groups: Dictionary={}
var camera=Vector2(18,18)
var zoom=DEFAULT_ZOOM
var _zoom_target=DEFAULT_ZOOM
var _zoom_anchor=Vector2.ZERO
var _zoom_animating=false
var color_choice=-1
var player_palette=ACPlayerPalette.new()
var _palette_entity: Dictionary={}
var drag_start=Vector2.ZERO
var dragging=false
var middle_drag=false
var minimap_drag=false
var attack_mode=false
var build_kind=-1
var last_group_key=-1
var last_group_time=-1000
var root_viewer_signature=0
var minimap_texture: ImageTexture
var minimap_signature: int=-1
var build_panel=false
var spectator=false
var paused=false
var status_text=""
var status_until=0.0
var elapsed=0.0
var tick_accum=0.0
var hud_clock=0.0
var hud_signature=""
var replay_clock=0.0
var replay_frames: Array=[]
var replay_mode=false
var replay_index=0
var replay_codec=FileAccess.COMPRESSION_FASTLZ
var replay_interval=.2
var replay_span=.2
var local_slot=0
var race_choice=0
var map_choice=0
var bot_count=1
var difficulty=1
var game_mode="ffa"
var session_token=""
var account: Dictionary={}
var backend_url="https://asteracraft-matchmaking.changjin93.chatgpt.site/api"
var remote_game: Dictionary={}
var room: Dictionary={}
var queue_data: Dictionary={}
var network_client=false
var poll_clock=0.0
var api_busy=false
var endpoint_label: Label
var resource_label: Label
var info_label: Label
var selection_label: Label
var action_grid: GridContainer
var message_label: Label
var race_select: OptionButton
var room_list: VBoxContainer
var auth_nick: LineEdit
var auth_pass: LineEdit
var online_status: Label
var room_detail: Label
var queue_label: Label
var accept_button: Button
var map_select: OptionButton
var mode_select: OptionButton
var settings: Dictionary=ACSettings.defaults()
var font: Font

# Dedicated server state. Only this authority owns gameplay and results.
var public_p2p: ACPublicP2P
var hosted_process=-1
var match_heartbeat=0.0
var public_reported=false
var dedicated=false
var server_config: Dictionary={}
var peer_slots: Dictionary={}
var observer_peers: Dictionary={}
var disconnect_deadlines: Dictionary={}
var command_windows: Dictionary={}
var server_ready=false
var server_created=0.0
var countdown=-1.0
var snapshot_clock=0.0
var result_sent=false
var test_network=false
var test_surrender_after=2.0
var test_client_surrender=false
var test_sent=false
var test_deadline=0.0

func _ready() -> void:
	Engine.max_fps=144
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	name="Main"
	get_viewport().mouse_exited.connect(func():pointer_position=Vector2(-1,-1))
	get_window().focus_exited.connect(_release_pointer)
	get_window().focus_entered.connect(_sync_pointer)
	tree_exiting.connect(_release_pointer)
	tree_exiting.connect(func():
		if hosted_process>0 and OS.is_process_running(hosted_process):OS.kill(hosted_process)
	)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	font=preload("res://scripts/ui_font.gd").create()
	var custom_theme=Theme.new()
	custom_theme.default_font=font
	custom_theme.default_font_size=16
	custom_theme.set_color("font_color","Label",Color("d9dfe5"))
	custom_theme.set_color("font_color","Button",Color("f5deb0"))
	custom_theme.set_stylebox("normal","Button",_style(Color("182029"),Color("605847"),4))
	custom_theme.set_stylebox("hover","Button",_style(Color("303b46"),Color("d7ad54"),4))
	custom_theme.set_stylebox("pressed","Button",_style(Color("51462a"),Color("ffd578"),4))
	custom_theme.set_stylebox("disabled","Button",_style(Color("10151c"),Color("303640"),4))
	theme=custom_theme
	_load_settings()
	var args=OS.get_cmdline_user_args()
	if "--battle-config" in args:
		var i=args.find("--battle-config")
		if i+1<args.size():
			_start_dedicated(args[i+1])
			return
	if "--test-client" in args:
		var i=args.find("--test-client")
		var config=JSON.parse_string(FileAccess.get_file_as_string(args[i+1]))
		test_network=true
		test_client_surrender=bool(config.get("surrender",false))
		backend_url=str(config.get("endpoint",backend_url))
		session_token=str(config.get("session_token",""))
		test_surrender_after=float(config.get("surrender_after",2.0))
		test_deadline=Time.get_ticks_msec()/1000.0+75
		ui=Control.new();ui.z_index=3300
		add_child(ui)
		_join_game(config)
		return
	assets.load_all()
	construction_visual.load_all()
	terrain_artist.load_art()
	effect_frames=_atlas("res://assets/effect_sprites.png",4,4)
	building_parts=_atlas("res://assets/building_parts.png",4,4)
	world_resources=_atlas("res://assets/resources_v2.png",2,1)
	if world_resources.size()==2 and ResourceLoader.exists("res://assets/tera_base_v05.png"):world_resources[1]=load("res://assets/tera_base_v05.png")
	for resource_texture in world_resources:world_resource_images.append(resource_texture.get_image())
	for biome in ["frontier","basin","highland"]:
		var source: Image=load("res://assets/tera_vent_%s_v058.png"%biome).get_image()
		var texture=assets._trim(source,Rect2i(Vector2i.ZERO,source.get_size()))
		tera_theme_textures.append(texture);tera_theme_images.append(texture.get_image())
	audio=ACAudio.new()
	add_child(audio)
	if audio.director!=null:
		audio.director.attack_visible=func(point: Vector2):return page=="game" and _world_visible_at(_ground_point(point))
	_apply_settings(false)
	ui=Control.new();ui.z_index=3300
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_main_menu()
	if "--smoke-game" in args:
		_start_local({"map":0,"mode":"ffa","players":[{"name":"테스트","race":0},{"name":"봇","race":1,"bot":true,"difficulty":1}]})
		if page=="game" and core!=null and not state.get("units",[]).is_empty():print("SMOKE_GAME_READY")
		var art_catalog_path="res://data/loading_art_20261024.json"
		if FileAccess.file_exists(art_catalog_path):
			var art_catalog=JSON.parse_string(FileAccess.get_file_as_string(art_catalog_path));var art_ready=0;var art_expected=0
			for item in art_catalog.get("images",[]):
				if not item.get("approved",false):continue
				art_expected+=1
				var texture: Texture2D=load(str(item.file))
				if texture!=null and texture.get_width()>=1200 and texture.get_height()>=675:art_ready+=1
			if art_ready==art_expected:print("SMOKE_LOADING_ART_READY images=",art_ready)
			else:push_error("Packaged loading artwork missing: %d/%d"%[art_ready,art_expected])
	if "--capture-menu" in args:
		_capture_later("user://menu.png")

func _style(bg: Color,border: Color,width: int=1) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=7
	s.content_margin_bottom=7
	return s

func _clear_ui() -> void:
	for child in ui.get_children():
		child.queue_free()
	selected=[]
	selected_resource=-1
	build_panel=false
	build_kind=-1
	hud_signature=""

func _panel(rect: Rect2,color: String="111821") -> Panel:
	var p=Panel.new()
	p.position=rect.position
	p.size=rect.size
	p.add_theme_stylebox_override("panel",_style(Color(color),Color("635b49"),1))
	ui.add_child(p)
	return p

func _label(parent: Node,text: String,pos: Vector2,width: float=400,font_size: int=18) -> Label:
	var l=Label.new()
	l.text=text
	l.position=pos
	l.size=Vector2(width,36)
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func _button(parent: Node,text: String,pos: Vector2,width: float,action: Callable,height: float=46) -> Button:
	var b=Button.new()
	b.text=text
	b.position=pos
	b.size=Vector2(width,height)
	b.pressed.connect(func():
		if audio!=null:audio.play_ui("ready" if b.text in ["준비","준비 취소","매치 수락"] else "confirm")
		action.call()
	)
	parent.add_child(b)
	return b

func _option(parent: Node,items: Array,pos: Vector2,width: float,index: int,changed: Callable) -> OptionButton:
	var o=OptionButton.new()
	o.position=pos
	o.size=Vector2(width,44)
	for item in items:
		o.add_item(str(item))
	o.select(index)
	o.item_selected.connect(func(selected):
		if audio!=null:audio.play_ui("select")
		changed.call(selected)
	)
	parent.add_child(o)
	return o

func _main_menu() -> void:
	page="main"
	if audio!=null:audio.set_music_context(-1)
	if menu_pages!=null:menu_pages.close()
	if ui.get_node_or_null("MainHub")!=null:
		queue_redraw()
		return
	_clear_ui()
	if audio!=null:
		audio.clear(true)
	var hub=ACHubMenu.new()
	hub.name="MainHub"
	ui.add_child(hub)
	hub.configure(self)
	queue_redraw()

func _menus() -> ACMenuPages:
	if menu_pages==null:menu_pages=ACMenuPages.new(self)
	return menu_pages

func _single_menu() -> void:
	_menus().single()

func _settings_menu() -> void:
	_menus().settings()

func _online_menu() -> void:
	_menus().online()

func _authenticate(register: bool) -> void:
	_menus().authenticate(register)

func _rooms_menu() -> void:
	_menus().rooms()

func _fetch_rooms() -> void:
	_menus().fetch_rooms()

func _room_menu() -> void:
	_menus().room_menu()

var room_update_pending=false
func _room_update(data: Dictionary) -> void:
	if room_update_pending or room.is_empty():return
	room_update_pending=true
	_update_room_text()
	data.id=room.id
	_api("/room/update",data,func(result):
		room_update_pending=false
		if page!="room":return
		if result.has("room"):room=result.room;_menus().room_notice_until=0;_update_room_text()
		else:_menus().show_room_notice(str(result.get("error","변경 실패")))
	)

func _update_room_text() -> void:
	_menus().update_room_text()

func _ladder_menu() -> void:
	_menus().ladder()

func _leaderboard_menu() -> void:
	_menus().leaderboard()

func _api(route: String,body: Dictionary,callback: Callable) -> void:
	var request=HTTPRequest.new()
	request.timeout=8
	add_child(request)
	api_busy=true
	var headers=PackedStringArray(["Content-Type: application/json","X-Astera-Protocol: 11"])
	if session_token!="":headers.append("Authorization: Bearer "+session_token)
	request.request_completed.connect(func(result,code,_headers,bytes):
		api_busy=false
		var data=JSON.parse_string(bytes.get_string_from_utf8()) if not bytes.is_empty() else null
		if not data is Dictionary:data={"error":"로비에 연결할 수 없습니다. 연결을 확인하고 다시 시도하세요."}
		if result!=HTTPRequest.RESULT_SUCCESS:data={"error":"로비 연결이 끊겼습니다. 다시 연결해 주세요."}
		if code==401:session_token="";account={}
		callback.call(data)
		request.queue_free()
	)
	var post=not body.is_empty() or route in ["/queue/leave","/room/leave"]
	var err=request.request(backend_url+route,headers,HTTPClient.METHOD_POST if post else HTTPClient.METHOD_GET,JSON.stringify(body) if post else "")
	if err!=OK:
		api_busy=false
		callback.call({"error":"요청을 시작할 수 없습니다."})
		request.queue_free()

func _show_loading(faction: int,map_id: int,page_name: String) -> void:
	_clear_ui();page=page_name
	loading_screen=ACLoadingScreen.new();ui.add_child(loading_screen);loading_screen.configure(faction,map_id)
	_sync_world_canvas();queue_redraw()

func _begin_local(config: Dictionary) -> void:
	_stop_simulation_worker()
	loading_config=config.duplicate(true);loading_result={};loading_local=true
	_show_loading(int(config.players[0].get("race",0)),int(config.get("map",0)),"loading")
	loading_job=ACBattleLoader.new()
	if loading_job.start(config,terrain_artist,true)!=OK:
		loading_job=null;_start_local(config)

func _begin_remote_loading() -> void:
	if test_network:return
	loading_local=false;loading_result={};loading_connected=false;loading_authenticated=false;state={}
	var faction=race_choice
	if remote_game.has("host_config") and local_slot<remote_game.host_config.players.size():faction=int(remote_game.host_config.players[local_slot].race)
	_show_loading(faction,int(remote_game.get("map",0)),"connecting")
	loading_screen.cancel_button.show()
	loading_screen.cancel_requested.connect(func():_leave_network();_rooms_menu())
	loading_screen.set_progress(0,"전투 연결 및 전장 준비 중")
	loading_job=ACBattleLoader.new()
	if loading_job.start(remote_game,terrain_artist,false)!=OK:
		loading_job=null;_notify("전장 준비를 시작하지 못했습니다");_leave_network();_main_menu()

func _poll_loading() -> void:
	if loading_job!=null:
		var status=loading_job.status()
		if is_instance_valid(loading_screen):loading_screen.set_progress(float(status.progress)*(.98 if not loading_local else 1.0),status.caption)
		if loading_job.finished():
			loading_result=loading_job.finish();loading_job=null
			if loading_local:
				var prepared=loading_result;loading_result={}
				_start_local(loading_config,prepared.core,prepared.map)
				return
	if not loading_local and page=="connecting" and not loading_result.is_empty():
		if loading_connected and not loading_authenticated:
			loading_authenticated=true
			# Authentication is the host's existing start barrier. Send it only
			# after this client has prepared its real map and terrain meshes.
			_authenticate_peer.rpc_id(1,str(remote_game.ticket))
		if is_instance_valid(loading_screen):loading_screen.set_progress(1.0 if loading_connected else .98,"다른 지휘관의 준비를 기다리는 중" if loading_connected else "전투 연결을 기다리는 중")
		if not state.is_empty() and bool(state.get("battle_ready",true)):_finish_remote_loading()

func _finish_remote_loading() -> void:
	draw_map=loading_result.map;loading_result={}
	if local_slot>=0 and local_slot<state.players.size():_remember_played_race(int(state.players[local_slot].race))
	_focus_home(true);replay_frames=[];replay_codec=FileAccess.COMPRESSION_FASTLZ;replay_clock=0.0
	paused=false;replay_mode=false;result_sent=false
	if audio!=null:audio.clear(true);audio.set_paused(false)
	_build_hud()

func _start_local(config: Dictionary,prepared_core: ACCore=null,prepared_map: ACMap=null) -> void:
	_stop_simulation_worker()
	for node in _entity_canvases.values():node.queue_free()
	_entity_canvases.clear();_entity_by_id.clear();_entity_list=[];_entity_source={}
	_placement_requested="";_placement_result={};_shot_origins.clear()
	network_client=false
	spectator=false
	result_sent=false
	groups={}
	render_rects={}
	_selection_bodies.clear()
	tick_accum=0
	core=prepared_core
	if core==null:
		core=Core.new();core.setup(config)
	draw_map=prepared_map if prepared_map!=null else core.map
	local_slot=0
	page="game"
	state=core.snapshot(local_slot)
	_remember_played_race(int(state.players[local_slot].race))
	_focus_home(true)
	paused=false
	replay_mode=false
	replay_frames=[]
	replay_codec=FileAccess.COMPRESSION_FASTLZ
	replay_clock=0.0
	_build_hud()

func _stop_simulation_worker() -> void:
	if simulation_worker!=null:simulation_worker.stop();simulation_worker=null

func _exit_tree() -> void:
	_stop_simulation_worker()
	if loading_job!=null:loading_job.finish();loading_job=null

func _start_simulation_worker() -> void:
	if simulation_worker!=null or core==null:return
	# The renderer gets a separate immutable map; navigation and source solids
	# remain exclusively on the simulation thread.
	if is_same(draw_map,core.map):draw_map=ACMap.new();draw_map.make(core.map.theme)
	simulation_worker=ACSimulationWorker.new();simulation_worker.start(core)

func _process_simulation_worker(dt: float) -> bool:
	var output=simulation_worker.poll()
	if not output.is_empty():
		state=output.state
		if output.has("placement"):_placement_result=output.placement
		_accept_visual_snapshot(state.units,float(state.time))
		for notice in output.notices:_notify(notice)
		for error in output.errors:_notify(error);_voice_error(error)
		if state.ended and not result_sent:result_sent=true;_show_result()
	tick_accum=minf(.2,tick_accum+minf(dt,.1))
	var steps=mini(2,floori(tick_accum/.05))
	if steps>0 and simulation_worker.submit(steps,-1 if spectator else local_slot):tick_accum-=steps*.05
	visual_clock=minf(visual_clock,.1)
	return not output.is_empty()

func _build_hud() -> void:
	_clear_ui()
	page="game"
	battle_hud=ACRtsHUD.new()
	ui.add_child(battle_hud)
	battle_hud.configure(self)
	pointer_order=""
	if audio!=null:
		audio.clear(true)
		var music_race=int(state.players[local_slot].race) if local_slot>=0 and local_slot<state.get("players",[]).size() else race_choice
		audio.set_music_context(music_race)
	_sync_world_canvas()
	queue_redraw()

func _view_rect() -> Rect2:
	return Rect2(0,42,size.x,size.y-298)

func _world_render_rect() -> Rect2:
	# Keep camera composition stable while terrain continues behind the
	# original HUD silhouette. Its transparent upper gaps reveal the world.
	return Rect2(Vector2.ZERO,size)

func _mini_rect() -> Rect2:
	if battle_hud!=null:return battle_hud.minimap_rect()
	return Rect2(18,size.y-213,192,192)

func _iso(p: Vector2) -> Vector2:
	return p*32

func _from_iso(p: Vector2) -> Vector2:
	return p/32

func world_to_screen(p: Vector2) -> Vector2:
	return (_iso(p)-_iso(camera))*zoom+_view_rect().get_center()

func screen_to_world(p: Vector2) -> Vector2:
	var flat=_from_iso((p-_view_rect().get_center())/zoom+_iso(camera))
	if flat.x<0 or flat.x>=ACMap.SIZE or flat.y< -4 or flat.y>ACMap.SIZE:return flat
	# Each 16px terrain square contains two affine triangles. Intersect its
	# vertical screen ray with both pieces, then select the frontmost surface
	# in the terrain renderer's increasing-y draw order. Fixed-point iteration
	# jumped between opposite sides of steep cliffs and misplaced commands.
	var fraction=fposmod(flat.x*2.0,1.0)
	var knots: Array[float]=[]
	var begin=floori((flat.y-.25)*2.0)
	var end=ceili((flat.y+4.0)*2.0)
	for row in range(begin,end+1):
		var y=float(row)*.5
		if y>=0 and y<ACMap.SIZE:knots.append(y)
		var diagonal=y+fraction*.5
		if fraction>.00001 and diagonal>=0 and diagonal<ACMap.SIZE:knots.append(diagonal)
	knots.sort()
	var result=flat
	var found=false
	for index in range(knots.size()-1):
		var a=knots[index]
		var b=knots[index+1]
		var fa=(a-flat.y)*32.0-draw_map.visual_elevation(Vector2(flat.x,a))
		var fb=(b-flat.y)*32.0-draw_map.visual_elevation(Vector2(flat.x,b))
		if fa*fb>0 or is_equal_approx(fa,fb):continue
		var y=lerpf(a,b,clampf(-fa/(fb-fa),0,1))
		if not found or y>result.y:result.y=y;found=true
	return result

func _elevation(p: Vector2) -> float:
	return draw_map.visual_elevation(p)*zoom

func _ground_point(p: Vector2) -> Vector2:
	return world_to_screen(p)-Vector2(0,_elevation(p))

func _ensure_world_canvas() -> void:
	if is_instance_valid(ui):ui.z_index=3300
	if is_instance_valid(world_clip):return
	world_clip=Control.new()
	world_clip.name="WorldViewportClip"
	world_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world_clip.clip_contents=true
	add_child(world_clip)
	move_child(world_clip,0)
	world_canvas=Control.new()
	world_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world_canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	world_clip.add_child(world_canvas)
	world_canvas.draw.connect(_draw_world)
	_fog_canvas=ACFogCanvas.new();world_canvas.add_child(_fog_canvas)
	_root_canvas=Control.new();_root_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root_canvas.z_index=1
	world_canvas.add_child(_root_canvas);_root_canvas.draw.connect(_draw_retained_roots)
	_world_effect_canvas=Control.new();_world_effect_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_world_effect_canvas.z_index=3100;world_canvas.add_child(_world_effect_canvas)
	_world_effect_canvas.draw.connect(_draw_world_overlay_canvas)
	world_mask=Control.new()
	world_mask.name="WorldOutsideMask"
	world_mask.z_index=3200
	world_mask.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(world_mask)
	move_child(world_mask,world_clip.get_index()+1)
	world_mask.draw.connect(_draw_world_mask)

func _sync_world_canvas() -> void:
	_ensure_world_canvas()
	world_clip.visible=page=="game" and not state.is_empty()
	world_mask.visible=world_clip.visible
	if not world_clip.visible:return
	var map_rect=Rect2(world_to_screen(Vector2.ZERO),world_to_screen(Vector2.ONE*ACMap.SIZE)-world_to_screen(Vector2.ZERO)).abs()
	var clip=map_rect.intersection(_world_render_rect())
	world_clip.position=clip.position
	world_clip.size=clip.size
	world_canvas.size=clip.size
	world_canvas.queue_redraw()
	_root_canvas.queue_redraw()
	if spectator:_fog_canvas.hide()
	else:
		var fog=state.get("fog",PackedByteArray());var seen=state.get("explored",PackedByteArray())
		if simulation_worker==null and not network_client and not replay_mode and core!=null:
			fog=core.visibility[local_slot];seen=core.explored[local_slot]
		_fog_canvas.update_masks(fog,seen,_fog_stamp(),Rect2(map_rect.position-world_clip.position,map_rect.size),Rect2(Vector2.ZERO,clip.size))
	world_mask.size=size
	world_mask.queue_redraw()
	_sync_nuclear_clouds()

func _sync_nuclear_clouds() -> void:
	var active={}
	for fx in state.get("effects",[]):
		var type=str(fx.get("type",""))
		var key=str(fx.get("skill","")).replace("_warning","") if type=="skill" else "warhead_ascent" if type=="nuclear_ascent" else "warhead_descent" if type=="nuclear_descent" else ""
		if key.is_empty():continue
		var info=assets.sprites.effect_info(key)
		var frames: Array=assets.v060_effects.get("nuclear_cloud",[]) if key=="nuclear" else []
		if info.is_empty() and frames.is_empty():continue
		var id=int(fx.id);active[id]=true
		if not nuclear_clouds.has(id):
			var node=ACNuclearCloud.new() if key=="nuclear" else preload("res://scripts/effect_sprite.gd").new()
			if info.is_empty():node.configure(frames[0].atlas,frames.size())
			else:node.configure(info.texture,int(info.count),Vector2i(int(info.columns),int(info.rows)),ACData.point(info.get("pivot",[.5,.65])))
			if key=="nuclear":node.phase_frames=info.get("phase_frames",[])
			node.z_index=3102;world_canvas.add_child(node);nuclear_clouds[id]=node
		var now=float(state.time)+(minf(visual_clock,visual_step) if not paused else 0)
		var point=_ground_point(ACData.point(fx.to))-world_clip.position
		var duration=maxf(.01,float(fx.until)-float(fx.started))
		var age=maxf(0,now-float(fx.started));var progress=clampf(age/duration,0,1)
		var width=(float(fx.get("radius",5))*64 if key=="nuclear" else float(fx.get("radius",4))*64 if key=="sap_bloom" else 180 if key=="verdict" else 120 if key in ["smoke","discipline"] else 96 if key.begins_with("warhead_") else 72)*zoom
		if not info.is_empty():width*=float(info.texture.get_width())/maxf(1,float(info.columns)*float(info.get("scale_hint",float(info.texture.get_width())/float(info.columns))))
		if key=="nuclear":nuclear_clouds[id].update_cloud(point,width,age,duration)
		else:
			var frame=progress*(int(info.count)-1);var opacity=1.0
			if str(fx.get("skill","")).ends_with("_warning"):frame*=.25;opacity=.55
			if key.begins_with("warhead_"):
				var travel=minf(600,size.y*.75)*zoom
				point.y-=travel*(progress*progress if key=="warhead_ascent" else 1-progress*progress)
				frame=fposmod(age*16,float(info.count))
			nuclear_clouds[id].update_frame(point,width,frame,opacity)
	for id in nuclear_clouds.keys():
		if not active.has(id):nuclear_clouds[id].queue_free();nuclear_clouds.erase(id)

func _draw_world_mask() -> void:
	if page!="game":return
	var bounds=Rect2(world_to_screen(Vector2.ZERO),world_to_screen(Vector2.ONE*ACMap.SIZE)-world_to_screen(Vector2.ZERO)).abs().intersection(Rect2(Vector2.ZERO,size))
	for rect in [Rect2(0,0,size.x,bounds.position.y),Rect2(0,bounds.end.y,size.x,maxf(0,size.y-bounds.end.y)),Rect2(0,bounds.position.y,bounds.position.x,bounds.size.y),Rect2(bounds.end.x,bounds.position.y,maxf(0,size.x-bounds.end.x),bounds.size.y)]:
		if rect.has_area():world_mask.draw_rect(rect,Color.BLACK)

func _world_transform(origin: Vector2=Vector2.ZERO,rotation: float=0.0,scale_value: Vector2=Vector2.ONE) -> void:
	world_canvas.draw_set_transform(origin-world_clip.position-_object_canvas_offset,rotation,scale_value)

func _accept_visual_snapshot(units: Array,stamp: float,reset: bool=false) -> void:
	if reset:_shot_origins.clear()
	var next: Dictionary={}
	for unit in units:
		var id=int(unit.id)
		next[id]={"pos":ACData.point(unit.pos),"facing":ACData.point(unit.facing),"body_direction":ACData.point(unit.get("body_direction",unit.facing)),"turret_direction":ACData.point(unit.get("turret_direction",unit.facing)),"container":int(unit.get("container",-1)),"race":int(unit.race),"kind":int(unit.kind)}
		if visual_current.has(id) and (int(visual_current[id].get("race",unit.race))!=int(unit.race) or int(visual_current[id].get("kind",unit.kind))!=int(unit.kind)):
			visual_motion.erase(id)
			visual_current.erase(id)
	if reset or visual_current.is_empty() or stamp<visual_state_time:
		visual_motion.clear()
		visual_previous=next
		visual_current=next
		visual_step=.05
	else:
		visual_previous=visual_current
		visual_current=next
		visual_step=clampf(stamp-visual_state_time,.025,10.0 if replay_mode else .3)
	visual_state_time=stamp
	visual_clock=0.0

func _visual_position(unit: Dictionary) -> Vector2:
	var current=ACData.point(unit.pos)
	var id=int(unit.id)
	if not visual_previous.has(id) or not visual_current.has(id):return current
	var previous=visual_previous[id]
	if int(previous.container)!=int(unit.get("container",-1)) or ACData.point(previous.pos).distance_squared_to(current)>(400 if replay_mode else 16):return current
	return ACData.point(previous.pos).lerp(current,clampf(visual_clock/visual_step,0,1))

func _visual_facing(unit: Dictionary,field: String="facing") -> Vector2:
	# A moving aircraft's hull and pilot follow displacement, even if weapon
	# targeting updated facing during the same simulation tick.
	if field=="facing" and ACData.unit(int(unit.race),int(unit.kind)).air and bool(unit.get("moving",false)):
		field="body_direction"
	var current=ACData.point(unit.get(field,unit.facing))
	var id=int(unit.id)
	if not visual_previous.has(id):return current
	var previous=ACData.point(visual_previous[id].get(field,visual_previous[id].facing))
	if current.length_squared()<.01 or previous.length_squared()<.01:return current
	return Vector2.from_angle(lerp_angle(previous.angle(),current.angle(),clampf(visual_clock/visual_step,0,1)))

func _update_visual_motion(dt: float) -> void:
	var alive: Dictionary={}
	for unit in state.get("units",[]):
		var id=int(unit.id)
		alive[id]=true
		var position=_visual_position(unit)
		var definition=ACData.unit(int(unit.race),int(unit.kind))
		var data: Dictionary=visual_motion.get(id,{"pos":position,"phase":1.0,"walking":false})
		var distance=position.distance_to(data.pos)
		data.pos=position
		if paused or distance>3:
			data.walking=false
		elif distance>.0005:
			# Advance feet/tracks by distance covered, not simulation time.
			# Authored walk cycles advance by distance, keeping planted feet
			# synchronized with movement at any simulation/display rate.
			var stride=maxf(1.25,float(definition.size)*1.5)
			var phases=int(assets.sprites.action_info(int(unit.race),int(unit.kind),"walk").get("rows",4))
			data.phase=fposmod(float(data.phase)+distance*phases/stride,float(phases))
			data.walking=true
		elif bool(data.walking):
			# Settle onto the next shared idle pose before stopping the cycle.
			var phase=float(data.phase)
			var phases=int(assets.sprites.action_info(int(unit.race),int(unit.kind),"walk").get("rows",4))
			var target=ceilf(phase/maxf(1,phases*.5))*maxf(1,phases*.5) if phases!=4 else 1.0 if phase<1 else (3.0 if phase<3 else 5.0)
			data.phase=move_toward(phase,target,dt*12.0)
			if is_equal_approx(float(data.phase),target):data.phase=fposmod(target,float(phases));data.walking=false
		visual_motion[id]=data
	for id in visual_motion.keys():
		if not alive.has(id):visual_motion.erase(id)

func _release_pointer() -> void:
	_pointer_confined=false
	if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if DisplayServer.get_name()!="headless":Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	_cursor_key=""
	camera_velocity=Vector2.ZERO
	middle_drag=false
	minimap_drag=false
	dragging=false

func _sync_pointer() -> void:
	if dedicated or DisplayServer.get_name()=="headless" or not is_inside_tree():return
	var active=get_window().has_focus() and get_window().mode!=Window.MODE_MINIMIZED
	# Native window movement must own the pointer. Only fullscreen gameplay
	# confines it; windowed play and menus never warp the operating-system mouse.
	var confine=active and page=="game" and not paused and get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]
	var desired=Input.MOUSE_MODE_CONFINED if confine else Input.MOUSE_MODE_VISIBLE
	if confine!=_pointer_confined or Input.mouse_mode!=desired:
		_pointer_confined=confine
		Input.mouse_mode=desired
	_update_game_cursor(active)

func _update_game_cursor(active: bool) -> void:
	var race=int(settings.get("last_played_race",0)) if active else -1
	if active and page=="game" and local_slot<state.get("players",[]).size():race=int(state.players[local_slot].race)
	var key="%d:default"%race
	if race>=0 and page=="game" and _can_point_world(pointer_position):
		if attack_mode:key="%d:attack"%race
		elif pointer_order!="" or build_kind>=0:key="%d:target"%race
	if key==_cursor_key:return
	_cursor_key=key
	var cursor=assets.cursor(race,key.get_slice(":",1)) if race>=0 else {}
	if cursor.is_empty():
		Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	else:
		Input.set_custom_mouse_cursor(cursor.texture,Input.CURSOR_ARROW,cursor.hotspot)

func _clamp_camera() -> void:
	# The gameplay viewport stays over the map, including at corner starts.
	var half=_view_rect().size/(64.0*zoom)
	half=half.min(Vector2.ONE*ACMap.SIZE*.5)
	camera=camera.clamp(half,Vector2.ONE*ACMap.SIZE-half)

func _notification(what: int) -> void:
	if what!=NOTIFICATION_RESIZED or page!="game" or state.is_empty():return
	# Enlarging a window at the eastern/southern boundary must not leave the
	# old camera limit exposing a strip outside the map.
	_clamp_camera()
	render_rects.clear();_selection_bodies.clear()
	if is_instance_valid(world_clip):call_deferred("_sync_world_canvas")
	queue_redraw()

func _focus_home(reset_zoom: bool=false) -> void:
	if reset_zoom:zoom=DEFAULT_ZOOM;_zoom_target=zoom;_zoom_animating=false
	camera_velocity=Vector2.ZERO
	if reset_zoom:_accept_visual_snapshot(state.get("units",[]),float(state.get("time",0)),true)
	var start_index=local_slot*2 if state.get("players",[]).size()==2 else local_slot
	if start_index<draw_map.starts.size():
		camera=ACData.point(draw_map.starts[start_index])
	for building in state.get("buildings",[]):
		if int(building.owner)==local_slot and int(building.kind)==0:
			camera=_center(building)
			break
	_clamp_camera()
	render_rects.clear();_selection_bodies.clear()

func _process(dt: float) -> void:
	if network_client and remote_game.get("transport","")=="webrtc":
		match_heartbeat-=dt
		if match_heartbeat<=0:
			match_heartbeat=20.0
			_api("/match/heartbeat",{"id":remote_game.id,"connected":page=="game"},func(_data):pass)
	elapsed+=dt
	visual_clock+=dt
	if dedicated:
		_server_process(dt)
		return
	if loading_job!=null or page=="connecting":_poll_loading()
	_sync_pointer()
	if test_network:
		if Time.get_ticks_msec()/1000.0>test_deadline:printerr("TEST CLIENT TIMEOUT");get_tree().quit(2)
		if not state.is_empty() and state.time>test_surrender_after and test_client_surrender and not test_sent:
			test_sent=true
			_remote_command.rpc_id(1,{"type":"surrender"})
		return
	if page!="game" and elapsed<status_until+1:queue_redraw()
	if page=="game":
		var simulated_this_frame=false
		if not paused and not replay_mode and not network_client and core!=null:
			_start_simulation_worker()
			simulated_this_frame=_process_simulation_worker(dt)
		if replay_mode:_tick_replay(dt)
		if REPLAYS_ENABLED and not replay_mode and not paused:
			replay_clock+=dt
			if replay_clock>=replay_interval and not state.is_empty() and (not simulated_this_frame or replay_clock>=replay_interval+.1):
				replay_clock=fmod(replay_clock,replay_interval)
				replay_frames.append(_encode_replay_frame(state))
				if replay_frames.size()>36000:replay_frames.pop_front()
		if audio!=null:
			audio.set_paused(paused)
			audio.process_state(state,local_slot,camera,zoom)
		_camera_input(dt)
		_update_zoom(dt)
		_update_visual_motion(dt)
		_sync_world_canvas()
		hud_clock-=dt
		if hud_clock<=0:
			hud_clock=.2
			_update_hud()
		queue_redraw()
	elif is_instance_valid(world_clip):
		world_clip.hide()
		if is_instance_valid(world_mask):world_mask.hide()
	if page in ["rooms","room","ladder"] and not api_busy:
		poll_clock-=dt
		if poll_clock<=0:
			poll_clock=2.0 if page=="rooms" else .5
			if page=="rooms":
				_fetch_rooms()
			elif page=="room":
				_api("/room/state",{},func(data):
					if page!="room":return
					if data.get("game")!=null:_join_game(data.game)
					elif data.get("room")!=null:room=data.room;_update_room_text()
				)
			else:
				_api("/queue/state",{},func(data):
					if page!="ladder":return
					queue_data=data
					if data.get("game")!=null:_join_game(data.game);return
					if data.get("offer")!=null:
						queue_label.text="상대를 찾았습니다. %d초 안에 수락하세요."%data.offer.seconds
						accept_button.visible=true
						accept_button.disabled=bool(data.offer.accepted)
					elif data.get("queued",false):
						queue_label.text="비슷한 점수의 상대 검색 중… %d초\n대기 시간이 길어지면 점수 범위를 조금씩 넓힙니다."%data.wait
						accept_button.visible=false
					else:accept_button.visible=false
				)

func _camera_input(dt: float) -> void:
	if ui!=null and ui.get_node_or_null("MenuModal")!=null:
		camera_velocity=Vector2.ZERO
		return
	var delta=Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):delta.x-=1
	if Input.is_key_pressed(KEY_RIGHT):delta.x+=1
	if Input.is_key_pressed(KEY_UP):delta.y-=1
	if Input.is_key_pressed(KEY_DOWN):delta.y+=1
	var mouse=pointer_position if pointer_position.is_finite() else get_global_mouse_position()
	if settings.edge_scroll and Rect2(Vector2.ZERO,size).has_point(mouse) and not dragging and not middle_drag and not minimap_drag and not _mini_rect().has_point(mouse):
		var edge=10.0
		if mouse.x<edge:delta.x-=1.0-mouse.x/edge
		if mouse.x>size.x-edge:delta.x+=(mouse.x-(size.x-edge))/edge
		if mouse.y<edge:delta.y-=1.0-mouse.y/edge
		if mouse.y>size.y-edge:delta.y+=(mouse.y-(size.y-edge))/edge
	delta=delta.limit_length(1)
	var target=delta*650.0*clampf(float(settings.get("edge_scroll_speed",1.0)),.25,2.5)
	var response=9.0 if delta.length_squared()>.001 else 13.0
	camera_velocity=camera_velocity.lerp(target,1.0-exp(-response*dt))
	if camera_velocity.length_squared()<.02:camera_velocity=Vector2.ZERO
	var previous=camera
	camera+=_from_iso(camera_velocity*dt/zoom)
	_clamp_camera()
	if camera!=previous:render_rects.clear();_selection_bodies.clear()

func _view_snapshot() -> Dictionary:
	if simulation_worker==null and core!=null and not network_client and not replay_mode:
		return core.snapshot(local_slot)
	return state.duplicate(true)

func _visible(e: Dictionary) -> bool:
	if spectator or replay_mode:return true
	if int(e.owner)==local_slot:return true
	if simulation_worker==null and not network_client and core!=null:return core.can_see(local_slot,e)
	return true

var _entity_source: Dictionary={}
var _entity_list: Array=[]
var _entity_by_id: Dictionary={}
var _entity_count=-1

func _index_view_entities() -> void:
	var count=state.get("buildings",[]).size()+state.get("units",[]).size()
	if is_same(_entity_source,state) and count==_entity_count:return
	_entity_source=state;_entity_count=count
	_entity_list=state.get("buildings",[])+state.get("units",[]);_entity_by_id.clear()
	for e in _entity_list:_entity_by_id[int(e.id)]=e

func _entities() -> Array:
	_index_view_entities()
	return _entity_list

func _entity(id: int) -> Dictionary:
	_index_view_entities()
	return _entity_by_id.get(id,{})

func _selected_resource_data() -> Dictionary:
	if selected_resource<0:return {}
	for resource in state.get("resources",[]):
		if int(resource.id)==selected_resource:return resource
	return {}

func _select_resource(resource: Dictionary) -> void:
	selected=[]
	selected_resource=int(resource.id)
	attack_mode=false
	pointer_order=""
	build_kind=-1
	build_panel=false
	dragging=false
	hud_signature=""
	_update_hud()
	queue_redraw()

func _resource_dimensions(resource: Dictionary) -> Vector2:
	return ACData.point(resource.collision_size) if resource.has("collision_size") else (Vector2(4,2) if resource.type=="tera" else Vector2(2,1))

func _resource_texture(resource: Dictionary) -> Texture2D:
	if resource.type=="tera" and tera_theme_textures.size()==3:return tera_theme_textures[draw_map.theme]
	return world_resources[1 if resource.type=="tera" else 0]

func _resource_screen_rect(resource: Dictionary) -> Rect2:
	if world_resources.size()!=2:return Rect2()
	var texture: Texture2D=_resource_texture(resource)
	var dimensions=_resource_dimensions(resource)
	var width=dimensions.x*32*zoom
	var height=width*texture.get_height()/texture.get_width()
	var ground=_ground_point(ACData.point(resource.pos))
	return Rect2(ground+Vector2(-width*.5,dimensions.y*16*zoom-height),Vector2(width,height))

func _resource_refinery(resource: Dictionary) -> Dictionary:
	if resource.type!="tera":return {}
	for building in state.get("buildings",[]):
		if int(building.kind)!=1:continue
		var definition=ACData.building(int(building.race),1)
		var center=ACData.point(building.pos)+Vector2(float(definition.w)-1,float(definition.h)-1)*.5
		if center.distance_squared_to(ACData.point(resource.pos))<.000001:return building
	return {}

func _resource_at(mouse: Vector2,as_only: bool=false) -> Dictionary:
	var chosen: Dictionary={}
	var best=INF
	for resource in state.get("resources",[]):
		if as_only and resource.type!="as":continue
		if resource.type=="as" and float(resource.amount)<=0:continue
		var pos=ACData.point(resource.pos)
		if not draw_map.inside(Vector2i(pos)) or _fog_value(int(pos.y)*ACMap.SIZE+int(pos.x))==0:continue
		var dimensions=_resource_dimensions(resource)
		var ground=_ground_point(pos)
		var physical=Rect2(ground-dimensions*16*zoom,dimensions*32*zoom)
		var image_rect=_resource_screen_rect(resource)
		var hit=physical.has_point(mouse)
		if not hit and _resource_refinery(resource).is_empty() and image_rect.has_point(mouse) and world_resource_images.size()==2:
			var image: Image=tera_theme_images[draw_map.theme] if resource.type=="tera" and tera_theme_images.size()==3 else world_resource_images[1 if resource.type=="tera" else 0]
			var sample=Vector2i((mouse-image_rect.position)/image_rect.size*Vector2(image.get_size()))
			hit=image.get_pixelv(sample.clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)).a>.15
		if not hit:continue
		var distance=mouse.distance_squared_to(image_rect.get_center())/maxf(1,image_rect.size.length_squared())
		if distance<best:chosen=resource;best=distance
	return chosen

func _command_point(mouse: Vector2) -> Vector2:
	var resource=_resource_at(mouse)
	return ACData.point(resource.pos) if not resource.is_empty() else screen_to_world(mouse)

func _build_position(mouse: Vector2) -> Vector2:
	var point=screen_to_world(mouse)
	var definition=ACData.building(int(state.players[local_slot].race),build_kind)
	# Commands and ghosts share the footprint centre, not its top-left corner.
	if build_kind!=1:return (point-Vector2(definition.w,definition.h)*.5).round()
	var resource=_resource_at(mouse)
	if resource.is_empty() or resource.type!="tera":
		for node in state.get("resources",[]):
			if node.type=="tera" and Rect2(ACData.point(node.pos)-_resource_dimensions(node)*.5,_resource_dimensions(node)).grow(.4).has_point(point):resource=node;break
	if not resource.is_empty() and resource.type=="tera":
		return ACData.point(resource.pos)-Vector2(float(definition.w)-1,float(definition.h)-1)*.5
	return (point-Vector2(float(definition.w)-1,float(definition.h)-1)*.5).round()

func _focus_selection(portrait_only: bool=false) -> void:
	var target=Vector2.ZERO;var count=0
	if selected_resource>=0:
		for resource in state.get("resources",[]):
			if int(resource.id)==selected_resource:target=ACData.point(resource.pos);count=1;break
	elif portrait_only:
		var entity=_portrait_entity()
		if not entity.is_empty():target=_center(entity);count=1
	else:
		for id in selected:
			var entity=_entity(int(id))
			if not entity.is_empty():target+=_center(entity);count+=1
	if count==0:return
	camera=target/float(count);camera_velocity=Vector2.ZERO
	_clamp_camera();render_rects.clear();_selection_bodies.clear();queue_redraw()

func _center(e: Dictionary) -> Vector2:
	var p=ACData.point(e.pos)
	if e.has("progress"):
		var d=ACData.building(int(e.race),int(e.kind))
		p+=Vector2(d.w,d.h)*.5
	return p

func _selection_center(unit: Dictionary) -> Vector2:
	if _selection_bodies.has(int(unit.id)):return Rect2(_selection_bodies[int(unit.id)]).get_center()
	if render_rects.has(int(unit.id)):return Rect2(render_rects[int(unit.id)]).get_center()
	var d=ACData.unit(int(unit.race),int(unit.kind))
	return _ground_point(_visual_position(unit))-Vector2(0,(22.0 if d.air else float(d.get("visual_extent",32))*.38)*zoom)

func _drag_hits_unit(rect: Rect2,unit: Dictionary) -> bool:
	var middle=_selection_center(unit)
	if rect.has_point(middle):return true
	# Accept overlap with the central body, excluding a long barrel or empty
	# atlas padding. A drag across most of a chassis should select that unit.
	var bounds: Rect2=_selection_bodies.get(int(unit.id),render_rects.get(int(unit.id),Rect2(middle-Vector2.ONE*10*zoom,Vector2.ONE*20*zoom)))
	return rect.intersects(Rect2(middle-bounds.size*.3,bounds.size*.6))

func _hit_test(mouse: Vector2, own_only: bool=false) -> int:
	var best=INF
	var chosen=-1
	for e in state.get("units",[]):
		if e.get("container",-1)>=0 or not _visible(e) or (own_only and int(e.owner)!=local_slot):continue
		var p=_selection_center(e)
		var d=ACData.unit(int(e.race),int(e.kind))
		var radius=maxf(12,float(d.size)*13*zoom)
		var rect: Rect2=render_rects.get(int(e.id),Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2))
		if rect.grow(3).has_point(mouse) or mouse.distance_to(p)<radius:
			var distance=mouse.distance_to(p)/maxf(12,rect.size.y)
			if distance<best:best=distance;chosen=int(e.id)
	if chosen>=0:return chosen
	for e in state.get("buildings",[]):
		if not _visible(e) or (own_only and int(e.owner)!=local_slot):continue
		var d=ACData.building(int(e.race),int(e.kind))
		var wp=screen_to_world(mouse)
		var origin=ACData.point(e.pos)-Vector2(.5,.5) if int(e.kind)==1 else ACData.point(e.pos)
		if Rect2(origin,Vector2(d.w,d.h)).has_point(wp):return int(e.id)
	return -1

func _select_army() -> void:
	var army=state.get("units",[]).filter(func(u):return int(u.owner)==local_slot and int(u.kind)!=0 and ACData.unit(int(u.race),int(u.kind)).get("role","")!="brood" and u.get("container",-1)<0 and float(u.get("hp",0))>0)
	army.sort_custom(func(a,b):
		var ad=ACData.point(a.pos).distance_squared_to(camera)
		var bd=ACData.point(b.pos).distance_squared_to(camera)
		return ad<bd if not is_equal_approx(ad,bd) else int(a.id)<int(b.id)
	)
	selected=[]
	selected_resource=-1
	for unit in army.slice(0,12):selected.append(int(unit.id))
	_selection_voice()
	hud_signature=""
	_update_hud()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if page=="game" and (ui==null or ui.get_node_or_null("MenuModal")==null) and _handle_minimap_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		pointer_position=event.position
		if _pointer_confined and not Rect2(Vector2.ZERO,size).has_point(pointer_position):
			pointer_position=pointer_position.clamp(Vector2.ONE,size-Vector2.ONE)
			get_viewport().warp_mouse(pointer_position)
	if page!="game" or (ui!=null and ui.get_node_or_null("MenuModal")!=null):return
	# Target confirmation precedes GUI dispatch. A focused command button must
	# not consume the single battlefield click that completes A or R.
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and (attack_mode or pointer_order!=""):
		var mini=_mini_rect()
		if mini.has_point(event.position):
			if _confirm_pointer_target((event.position-mini.position)/mini.size*ACMap.SIZE,event.position,true):get_viewport().set_input_as_handled();return
		elif _can_point_world(event.position):
			if _confirm_pointer_target(_command_point(event.position),event.position):get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.physical_keycode not in [0,KEY_UNKNOWN]:
		event=event.duplicate()
		event.keycode=event.physical_keycode
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_A,KEY_R]:
		if is_instance_valid(battle_hud) and battle_hud.handle_hotkey(event):
			dragging=false
			get_viewport().set_input_as_handled()
			return
	# Army selection is a global battle shortcut, including while a HUD
	# button has keyboard focus. GUI event consumption must not swallow it.
	if page=="game" and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
		_select_army()
		get_viewport().set_input_as_handled()

func _minimap_camera(point: Vector2) -> void:
	var rect=_mini_rect()
	camera=((point-rect.position)/rect.size).clamp(Vector2.ZERO,Vector2.ONE)*ACMap.SIZE
	camera_velocity=Vector2.ZERO
	_clamp_camera();render_rects.clear();_selection_bodies.clear();queue_redraw()

func _handle_minimap_input(event: InputEvent) -> bool:
	if event is InputEventMouse:pointer_position=event.position
	if event is InputEventMouseMotion and minimap_drag:
		_minimap_camera(event.position);return true
	if not event is InputEventMouseButton:return false
	if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and minimap_drag:
		minimap_drag=false;return true
	if not event.pressed or not _mini_rect().has_point(event.position):return false
	var point=(event.position-_mini_rect().position)/_mini_rect().size*ACMap.SIZE
	if event.button_index==MOUSE_BUTTON_LEFT:
		dragging=false
		if not _confirm_pointer_target(point,event.position,true):
			minimap_drag=true;_minimap_camera(event.position)
		return true
	if event.button_index==MOUSE_BUTTON_RIGHT:
		attack_mode=false;pointer_order="";build_kind=-1
		_issue_order("move",point,-1)
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if page!="game" or (ui!=null and ui.get_node_or_null("MenuModal")!=null):return
	if event is InputEventKey and event.physical_keycode not in [0,KEY_UNKNOWN]:
		event=event.duplicate()
		event.keycode=event.physical_keycode
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(battle_hud) and battle_hud.handle_hotkey(event):return
		if event.keycode==KEY_ESCAPE:
			if build_kind>=0 or attack_mode or build_panel or pointer_order!="":
				build_kind=-1;attack_mode=false;build_panel=false;pointer_order="";hud_signature=""
			else:_pause_menu()
		elif event.keycode==KEY_SPACE:_focus_home()
		elif event.keycode>=KEY_1 and event.keycode<=KEY_9:
			var key=int(event.keycode-KEY_0)
			if event.ctrl_pressed:
				if selected_resource<0:groups[key]=selected.slice(0,12)
				last_group_key=-1
			else:
				selected_resource=-1
				selected=groups.get(key,[]).filter(func(id):return not _entity(int(id)).is_empty()).slice(0,12)
				var now=Time.get_ticks_msec()
				if last_group_key==key and now-last_group_time<=350:_focus_selection()
				last_group_key=key;last_group_time=now
				_selection_voice()
		_update_hud()
		queue_redraw()
	if event is InputEventMouseMotion:
		if middle_drag:
			camera-=_from_iso(event.relative/zoom)
			camera_velocity=Vector2.ZERO
			_clamp_camera()
			render_rects.clear();_selection_bodies.clear()
		queue_redraw()
	if event is InputEventMouseButton:
		var mouse=event.position
		if event.button_index==MOUSE_BUTTON_MIDDLE:middle_drag=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and _can_point_world(mouse):
			_zoom_anchor=mouse
			if not _zoom_animating:_zoom_target=zoom
			_zoom_target=clampf(_zoom_target*(1.10 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.10),_minimum_zoom(),MAX_ZOOM)
			_zoom_animating=true
			camera_velocity=Vector2.ZERO
			_clamp_camera()
			render_rects.clear();_selection_bodies.clear()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and _mini_rect().has_point(mouse):
				if _confirm_pointer_target((mouse-_mini_rect().position)/_mini_rect().size*ACMap.SIZE,mouse,true):return
				camera=(mouse-_mini_rect().position)/_mini_rect().size*ACMap.SIZE
				_clamp_camera()
				render_rects.clear();_selection_bodies.clear()
				return
			if event.pressed and _can_point_world(mouse):
				var pos=_command_point(mouse)
				if build_kind>=0:
					_send_command({"type":"build","kind":build_kind,"pos":ACData.packed(_build_position(mouse)),"ids":selected,"queued":event.shift_pressed})
					if not event.shift_pressed:build_kind=-1;build_panel=false;hud_signature=""
					return
				if _confirm_pointer_target(pos,mouse):return
				drag_start=mouse;dragging=true;double_select=event.double_click
			elif not event.pressed and dragging:
				dragging=false
				selected_resource=-1
				if not event.shift_pressed:selected=[]
				if mouse.distance_to(drag_start)>8:
					var rect=Rect2(drag_start,mouse-drag_start).abs()
					for e in state.units:
						if selected.size()>=12:break
						var point=_selection_center(e)
						if int(e.owner)==local_slot and e.hp>0 and e.container<0 and _visible(e) and _drag_hits_unit(rect,e) and _world_visible_at(point) and int(e.id) not in selected:selected.append(int(e.id))
					if selected.is_empty():
						for e in state.buildings:
							if selected.size()>=12:break
							var point=_ground_point(_center(e))
							if int(e.owner)==local_slot and rect.has_point(point) and _world_visible_at(point):selected.append(int(e.id))
				elif _can_point_world(mouse):
					var id=_hit_test(mouse)
					if id>=0:
						var e=_entity(id)
						if double_select and not e.has("progress") and int(e.owner)==local_slot:
							for u in state.units:
								if selected.size()>=12:break
								if int(u.owner)==local_slot and int(u.kind)==int(e.kind) and int(u.id) not in selected and _world_visible_at(_ground_point(_visual_position(u))):selected.append(int(u.id))
						elif id not in selected and selected.size()<12:selected.append(id)
					else:
						var resource=_resource_at(mouse)
						if not resource.is_empty():_select_resource(resource)
				selected=selected.slice(0,12)
				_selection_voice()
				hud_signature="";_update_hud()
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and _mini_rect().has_point(mouse):
			attack_mode=false;pointer_order="";build_kind=-1
			_issue_order("move",(mouse-_mini_rect().position)/_mini_rect().size*ACMap.SIZE,-1)
			return
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and _can_point_world(mouse):
			if build_kind>=0 or attack_mode or pointer_order!="":build_kind=-1;attack_mode=false;pointer_order="";return
			var pos=_command_point(mouse)
			_issue_order("context",pos,_context_target(mouse,pos))

func _confirm_pointer_target(point: Vector2,mouse: Vector2,minimap: bool=false) -> bool:
	if not attack_mode and pointer_order=="":return false
	var attacking=attack_mode
	var order=pointer_order
	attack_mode=false
	pointer_order=""
	dragging=false
	if selected_resource>=0 or selected.is_empty():return true
	if attacking:
		var target=-1 if minimap else _hit_test(mouse)
		_issue_order("attack" if target>=0 else "attack_move",point,target)
	elif order=="rally":_set_rally(point)
	elif order=="skill":_send_command({"type":"skill","skill":pointer_skill,"ids":selected,"pos":ACData.packed(point),"target":-1 if minimap else _hit_test(mouse)})
	elif order=="ability":_send_command({"type":order,"ids":selected,"pos":ACData.packed(point),"target":-1 if minimap else _hit_test(mouse)})
	else:
		_issue_order("context" if order in ["gather","repair"] else order,point,-1 if minimap else _context_target(mouse,point))
	hud_signature=""
	_update_hud()
	queue_redraw()
	return true

func _world_visible_at(point: Vector2) -> bool:
	if not _world_render_rect().has_point(point):return false
	if is_instance_valid(battle_hud) and battle_hud.blocks_world_input(point):return false
	var map_rect=Rect2(world_to_screen(Vector2.ZERO),world_to_screen(Vector2.ONE*ACMap.SIZE)-world_to_screen(Vector2.ZERO)).abs()
	return map_rect.has_point(point)

func _can_point_world(mouse: Vector2) -> bool:
	if not _world_visible_at(mouse):return false
	var hovered=get_viewport().gui_get_hovered_control()
	return hovered==null or hovered==self or hovered==ui or hovered==battle_hud or hovered==world_clip or hovered==world_canvas

func _issue_order(type: String,pos: Vector2,target: int) -> void:
	if selected_resource>=0 or selected.is_empty():return
	var troops:Array=[]
	var producers:Array=[]
	for id in selected:
		var e=_entity(int(id))
		if e.is_empty() or int(e.owner)!=local_slot:continue
		if e.has("progress"):
			if _building_accepts_rally(e):producers.append(id)
		elif ACData.unit(int(e.race),int(e.kind)).get("role","")!="brood":troops.append(id)
	if not producers.is_empty():_set_rally(pos)
	if troops.is_empty():return
	if target>=0 or troops.size()<2:
		_send_command({"type":type,"ids":troops,"target":target,"pos":ACData.packed(pos)})
	else:
		_send_command({"type":type,"ids":troops,"target":-1,"pos":ACData.packed(pos),"formation":true})
	_notify("공격 이동" if type=="attack_move" else "명령 확인")

func _building_accepts_rally(entity: Dictionary) -> bool:
	if not entity.has("progress") or int(entity.owner)!=local_slot or float(entity.progress)<1:return false
	var race=int(entity.race)
	if race==1:return int(entity.kind) in [0,3]
	for kind in range(ACData.unit_count(race)):
		if int(ACData.unit(race,kind).producer)==int(entity.kind):return true
	return false

func _select_brood(building_id: int) -> void:
	var source=_entity(building_id)
	if source.is_empty():return
	var mother=int(source.id) if int(source.kind)==0 else int(source.get("brood_mother",-1))
	selected=[];selected_resource=-1
	for unit in state.get("units",[]):
		if int(unit.owner)==local_slot and int(unit.race)==1 and int(unit.kind)==13 and int(unit.get("brood_mother",-1))==mother and unit.get("brood_state","idle")=="idle":selected.append(int(unit.id))
	hud_signature="";_update_hud()
	_notify("연결된 배양체 %d기 선택"%selected.size())

func _set_rally(point: Vector2) -> bool:
	var producers: Array=[]
	for id in selected:
		var entity=_entity(int(id))
		if not entity.is_empty() and _building_accepts_rally(entity):producers.append(int(id))
	if producers.is_empty():return false
	_send_command({"type":"rally","ids":producers,"pos":ACData.packed(point)})
	_notify("집결 지점을 지정했습니다.")
	return true

func _send_command(cmd: Dictionary) -> void:
	if spectator or replay_mode or state.get("ended",false):return
	if selected_resource>=0 and str(cmd.get("type","")) not in ["surrender","surrender_response"]:return
	if network_client:
		if multiplayer.multiplayer_peer!=null and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
			_remote_command.rpc_id(1,cmd)
			if audio!=null:audio.play_ui("confirm")
	elif core!=null:
		if simulation_worker!=null:
			simulation_worker.command(local_slot,cmd)
			if audio!=null:audio.play_ui("confirm")
			return
		var error=core.command(local_slot,cmd)
		if error!="":
			_notify(error)
			_voice_error(error)
			if audio!=null:audio.play_ui("error")
		elif audio!=null:audio.play_ui("confirm")

func _update_hud() -> void:
	if is_instance_valid(battle_hud):battle_hud.update_hud()

func _portrait_entity() -> Dictionary:
	var list: Array=[]
	for id in selected:
		var entity=_entity(int(id))
		if not entity.is_empty():list.append(entity)
	return ACData.portrait_leader(list)

func _selection_voice() -> void:
	if audio==null or audio.director==null or replay_mode:return
	var leader=_portrait_entity()
	if not leader.is_empty() and int(leader.get("owner",-1))==local_slot:audio.director.select_unit(leader)

func _voice_error(message: String) -> void:
	if audio==null or audio.director==null or local_slot<0 or local_slot>=state.get("players",[]).size():return
	audio.director.error_notice(message,int(state.players[local_slot].race))

func _make_actions() -> void:
	for child in action_grid.get_children():child.queue_free()
	if selected.is_empty():return
	var e=_entity(int(selected[0]))
	if e.is_empty() or int(e.owner)!=local_slot:return
	var race=int(e.race)
	if not e.has("progress"):
		if int(e.kind)==0:
			if not build_panel:
				_action("건설 [B]",func():build_panel=true;hud_signature="")
			else:
				for kind in range(ACData.get_data().buildings[race].size()):
					var d=ACData.building(race,kind)
					_action("%s\n%d / %d"%[d.name,d.as,d.tera],func():build_kind=kind,assets.building(race,kind),d.description+" · %d×%d칸"%[d.w,d.h])
		else:
			_action("공격 이동 [A]",func():attack_mode=true)
			_action("정지 [S]",func():_send_command({"type":"stop","ids":selected}))
			_action("위치 사수 [H]",func():_send_command({"type":"hold","ids":selected}))
			_action("특수 기능 [Q]",func():_send_command({"type":"ability","ids":selected,"pos":ACData.packed(screen_to_world(get_global_mouse_position()))}))
	else:
		if e.progress<1:
			_action("건설 취소\n75% 환급",func():_send_command({"type":"cancel","id":e.id}))
			return
		for kind in range(ACData.unit_count(race)):
			var d=ACData.unit(race,kind)
			if (race==1 and int(e.kind) in [0,3]) or (race!=1 and int(d.producer)==int(e.kind)):
				var icon=assets.unit(race,kind,Vector2(1,1)).get("texture")
				_action("%s\n%d / %d"%[d.name,d.as,d.tera],func():_send_command({"type":"train","id":e.id,"kind":kind}),icon,d.description)
		if (race in [0,2] and int(e.kind)==6) or (race==1 and int(e.kind) in [4,5,6]):
			_action("공격 연구",func():_send_command({"type":"research","id":e.id,"stat":"attack"}))
			_action("장갑 연구",func():_send_command({"type":"research","id":e.id,"stat":"armor"}))
			if race==2:_action("실드 연구",func():_send_command({"type":"research","id":e.id,"stat":"shield"}))
		_action("생산 취소",func():_send_command({"type":"cancel","id":e.id}))

func _action(text: String,action: Callable,icon: Texture2D=null,tip: String="") -> void:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(165,46)
	b.add_theme_font_size_override("font_size",13)
	if icon!=null:
		b.icon=icon
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",32)
	b.pressed.connect(action)
	action_grid.add_child(b)

func _notify(text: String) -> void:
	status_text=text
	status_until=elapsed+4
	queue_redraw()

func _pause_menu() -> void:
	_menus().pause()

func _show_result() -> void:
	var won=local_slot in state.get("winners",[])
	if audio!=null and audio.director!=null and not replay_mode and not spectator:
		audio.director.announce("victory" if won else "defeat",int(state.players[local_slot].race),1.0,4)
	var p=_menus().result(won)
	if network_client and not remote_game.is_empty() and not spectator:
		_fetch_rating(p,won,10)

func _fetch_rating(panel: Control, won: bool, attempts: int) -> void:
	if not is_instance_valid(panel) or remote_game.is_empty():return
	_api("/game?id="+str(remote_game.id),{},func(data):
		if not is_instance_valid(panel):return
		if data.has("user"):account=data.user
		if data.has("game") and data.game.get("result")!=null:
			var result=data.game.result
			var rating=panel.get_node_or_null("ResultRating")
			if remote_game.get("ranked",false) and rating!=null:
				if data.game.get("status")=="void":rating.text="결과 무효 · 래더 점수 변동 없음"
				else:rating.text="래더 %s%d · 현재 %d점"%["+" if won else "-",int(result.get("delta",0)),int(account.get("rating",1000))]
		elif attempts>0:
			await get_tree().create_timer(1).timeout
			_fetch_rating(panel,won,attempts-1)
		else:
			var rating=panel.get_node_or_null("ResultRating")
			if rating!=null and remote_game.get("ranked",false):rating.text="래더 결과를 아직 확인하지 못했습니다. 순위표에서 다시 확인하세요."
	)

func _save_replay() -> void:
	if replay_frames.is_empty() or replay_mode:return
	var dir=DirAccess.open("user://")
	if not dir.dir_exists("replays"):dir.make_dir("replays")
	var stamp=int(Time.get_unix_time_from_system())
	var file="user://replays/%d-%d.acr"%[stamp,Time.get_ticks_usec()]
	var suffix=0
	while FileAccess.file_exists(file):
		suffix+=1;file="user://replays/%d-%d-%d.acr"%[stamp,Time.get_ticks_usec(),suffix]
	var f=FileAccess.open_compressed(file,FileAccess.WRITE,FileAccess.COMPRESSION_DEFLATE)
	if f!=null:
		f.store_var({"version":ACData.get_data().version,"map":draw_map.theme,"map_layout":draw_map.source_info.get("origin","reference_inspired_original"),"slot":local_slot,"codec":replay_codec,"interval":replay_interval,"frames":replay_frames},false)
		f.flush()
		var write_error=f.get_error();f.close()
		_notify("리플레이를 저장했습니다." if write_error==OK else "리플레이를 저장하지 못했습니다.")
	else:_notify("리플레이를 저장하지 못했습니다.")

func _replay_state(frame) -> Dictionary:
	if frame is Dictionary:
		if frame.has("compressed"):
			var length=int(frame.get("size",0))
			if length<=0 or length>16777216:return {}
			var decoded=bytes_to_var(frame.compressed.decompress(length,replay_codec))
			return decoded if decoded is Dictionary else {}
		return frame
	if frame is PackedByteArray:
		var decoded=bytes_to_var(frame.decompress_dynamic(16777216,replay_codec))
		return decoded if decoded is Dictionary else {}
	return {}

func _encode_replay_frame(snapshot: Dictionary):
	# The local renderer uses a cheap read-only view. Internal paths/caches
	# are stripped only for a recorded frame, never written into the replay.
	if snapshot.get("_live_view",false) and core!=null:snapshot=core.snapshot(local_slot)
	var raw=var_to_bytes(snapshot)
	return {"size":raw.size(),"compressed":raw.compress(replay_codec)}

func _update_zoom(dt: float) -> void:
	if not _zoom_animating:return
	var focus=screen_to_world(_zoom_anchor)
	var target=clampf(_zoom_target,_minimum_zoom(),MAX_ZOOM)
	zoom=lerpf(zoom,target,1.0-exp(-14.0*maxf(0,dt)))
	if absf(zoom-target)<.0005:zoom=target;_zoom_animating=false
	camera+=focus-screen_to_world(_zoom_anchor)
	_clamp_camera()
	render_rects.clear();_selection_bodies.clear()

func _minimum_zoom() -> float:
	return MIN_ZOOM if spectator or replay_mode else DEFAULT_ZOOM

func _begin_replay() -> void:
	replay_index=0;replay_clock=0.0
	state=_replay_state(replay_frames[0])
	_accept_visual_snapshot(state.get("units",[]),float(state.get("time",0)),true)
	_next_replay_frame()

func _next_replay_frame() -> bool:
	if replay_index+1>=replay_frames.size():return false
	var next=_replay_state(replay_frames[replay_index+1])
	if next.is_empty():paused=true;return false
	replay_span=clampf(float(next.get("time",0))-float(state.get("time",0)),.025,10.0)
	replay_index+=1
	state=next
	_accept_visual_snapshot(state.get("units",[]),float(state.get("time",0)))
	visual_step=replay_span
	return true

func _tick_replay(dt: float) -> void:
	if replay_frames.is_empty():return
	if not paused:
		replay_clock+=dt
		var steps=0
		while replay_clock>=replay_span and steps<8:
			replay_clock-=replay_span;steps+=1
			if not _next_replay_frame():replay_clock=replay_span;paused=true;break
	visual_clock=minf(replay_clock,replay_span)

func _replay_menu() -> void:
	_menus().replays()

func _load_settings() -> void:
	settings=ACSettings.load_file()
	race_choice=int(settings.last_played_race)
	_apply_settings(true)

func _set_setting(key: String,value,persist: bool=true) -> void:
	settings[key]=value
	if key=="volume":settings.sfx_volume=value
	_apply_settings(key in ["window_mode","resolution"])
	if persist:_save_settings()

func _apply_settings(apply_display: bool=true) -> void:
	settings=ACSettings.normalize(settings)
	if audio!=null:audio.set_channel_volumes(float(settings.music_volume),float(settings.voice_volume),float(settings.sfx_volume))
	if apply_display:ACSettings.apply_display(settings)
	if apply_display and has_method("_sync_pointer"):call("_sync_pointer")
	queue_redraw()

func _remember_played_race(race: int) -> void:
	settings.last_played_race=clampi(race,0,2)
	_save_settings()

func _save_settings() -> void:
	settings=ACSettings.normalize(settings)
	ACSettings.save_file(settings)

func _capture_later(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)

# Network callbacks are declared in the same scene on client and authority.
func _join_game(game: Dictionary) -> void:
	if network_client and remote_game.get("id")==game.id:return
	_leave_network()
	remote_game=game
	public_reported=false;match_heartbeat=0.0
	network_client=true
	spectator=bool(game.get("spectator",false))
	local_slot=maxi(0,int(game.slot))
	if game.get("transport","")=="webrtc":
		if game.get("is_host",false):
			var config: Dictionary=game.host_config.duplicate(true);config.signal_url=backend_url
			var file="user://hosted-"+str(game.id)+".json"
			var output=FileAccess.open(file,FileAccess.WRITE)
			if output==null:_notify("전투 설정을 저장하지 못했습니다");_report_public_void();network_client=false;return
			output.store_string(JSON.stringify(config));output.close()
			# The elected player's PC runs the authoritative child process.
			var arguments=PackedStringArray(["--headless"])
			if OS.has_feature("editor"):arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
			arguments.append_array(["--","--battle-config",ProjectSettings.globalize_path(file)])
			hosted_process=OS.create_process(OS.get_executable_path(),arguments,false)
			if hosted_process<=0:_notify("방장 전투 호스팅을 시작하지 못했습니다");_report_public_void();return
		public_p2p=ACPublicP2P.new();add_child(public_p2p)
		public_p2p.failed.connect(func(message):_notify(message);_report_public_void())
		multiplayer.multiplayer_peer=public_p2p.setup(backend_url,{"id":game.id,"peer_id":game.peer_id,"signal_ticket":game.signal_ticket})
		multiplayer.connected_to_server.connect(_connected,CONNECT_ONE_SHOT)
		if not multiplayer.server_disconnected.is_connected(_server_disconnected):multiplayer.server_disconnected.connect(_server_disconnected)
		_menus().connecting()
		return
	var peer=ENetMultiplayerPeer.new()
	var host=str(game.host)
	if host in ["127.0.0.1","localhost"]:
		host=backend_url.trim_prefix("http://").trim_prefix("https://").split(":")[0]
	var err=peer.create_client(host,int(game.port))
	if err!=OK:_notify("전투 서버 연결을 시작하지 못했습니다");network_client=false;return
	multiplayer.multiplayer_peer=peer
	multiplayer.connected_to_server.connect(_connected,CONNECT_ONE_SHOT)
	if not multiplayer.server_disconnected.is_connected(_server_disconnected):multiplayer.server_disconnected.connect(_server_disconnected)
	_menus().connecting()

func _connected() -> void:
	if test_network:_authenticate_peer.rpc_id(1,str(remote_game.ticket))
	else:loading_connected=true

func _leave_network() -> void:
	_stop_simulation_worker()
	if loading_job!=null:loading_job.finish();loading_job=null
	loading_result={};loading_connected=false;loading_authenticated=false
	if network_client and not result_sent:_report_public_void()
	if is_instance_valid(public_p2p):public_p2p.close();public_p2p.queue_free();public_p2p=null
	if multiplayer.multiplayer_peer!=null:multiplayer.multiplayer_peer.close();multiplayer.multiplayer_peer=null
	if hosted_process>0 and OS.is_process_running(hosted_process):OS.kill(hosted_process)
	hosted_process=-1
	network_client=false

func _server_disconnected() -> void:
	if remote_game.get("transport","")=="webrtc":_report_public_void()
	if network_client and not result_sent and not test_network:
		var p=_panel(Rect2(size.x*.5-260,190,520,300),"101820")
		_label(p,"연결이 끊겼습니다",Vector2(30,25),450,30)
		if remote_game.get("transport","")=="webrtc":
			_label(p,"직접 연결이 종료되어 점수가 반영되지 않습니다.",Vector2(30,95),460,18)
			_button(p,"메인 화면",Vector2(30,160),220,func():_leave_network();_main_menu())
			return
		_label(p,"60초 안에 재접속하면 전투를 계속합니다.",Vector2(30,95),460,18)
		_button(p,"재접속",Vector2(30,160),220,_reconnect_game)
		_button(p,"메인 화면",Vector2(270,160),220,func():_leave_network();_main_menu())

func _reconnect_game() -> void:
	_api("/active",{},func(data):
		if data.get("game")!=null:
			_leave_network()
			_join_game(data.game)
		else:_notify(data.get("error","진행 중인 경기가 없습니다"))
	)

@rpc("authority","call_remote","reliable")
func _match_finished(winning_slots: Array, duration: float) -> void:
	state.ended=true
	state.winners=winning_slots
	state.time=duration
	_report_public_result(winning_slots,duration)
	if not result_sent and not test_network:
		result_sent=true
		_show_result()

@rpc("any_peer","call_remote","reliable")
func _authenticate_peer(ticket: String) -> void:
	if not dedicated:return
	var peer=multiplayer.get_remote_sender_id()
	for slot in range(server_config.players.size()):
		if not server_config.players[slot].get("bot",false) and ticket==str(server_config.players[slot].ticket):
			for old in peer_slots.keys():
				if peer_slots[old]==slot and old!=peer:
					peer_slots.erase(old)
					command_windows.erase(old)
					multiplayer.multiplayer_peer.disconnect_peer(old)
			peer_slots[peer]=slot
			disconnect_deadlines.erase(slot)
			_server_notice.rpc_id(peer,"인증 완료. 상대를 기다립니다.")
			return
	for observer in server_config.get("observers",[]):
		if ticket==str(observer.ticket):
			if observer_peers.has(ticket):
				var old=int(observer_peers[ticket])
				peer_slots.erase(old)
				command_windows.erase(old)
				if old!=peer:multiplayer.multiplayer_peer.disconnect_peer(old)
			observer_peers[ticket]=peer
			peer_slots[peer]=-1
			return
	multiplayer.multiplayer_peer.disconnect_peer(peer)

@rpc("authority","call_remote","reliable")
func _server_notice(message: String) -> void:
	_notify(message)
	_voice_error(message)

@rpc("any_peer","call_remote","reliable")
func _remote_command(cmd: Dictionary) -> void:
	if not dedicated or not server_ready:return
	var peer=multiplayer.get_remote_sender_id()
	if not peer_slots.has(peer) or int(peer_slots[peer])<0:return
	var window=command_windows.get(peer,{"at":Time.get_ticks_msec(),"count":0})
	if Time.get_ticks_msec()-window.at>1000:window={"at":Time.get_ticks_msec(),"count":0}
	window.count+=1
	command_windows[peer]=window
	if window.count>100:return
	if not cmd.get("type","") is String:return
	if cmd.type not in ["surrender","surrender_response","produce_drone","cancel_drone","build","train","cancel","research","rally","ability","stop","hold","context","move","attack","attack_move","morph","cancel_morph"]:return
	if not cmd.get("ids",[]) is Array:return
	if cmd.get("ids",[]).size()>12:return
	for id in cmd.get("ids",[]):
		if not id is int:return
	for key in ["id","kind","target","queue_index","bot"]:
		if cmd.has(key) and not cmd[key] is int:return
	if cmd.has("formation") and not cmd.formation is bool:return
	if cmd.has("queued") and not cmd.queued is bool:return
	if cmd.has("stat") and not cmd.stat is String:return
	if cmd.has("pos"):
		if not cmd.pos is Array or cmd.pos.size()!=2:return
		for value in cmd.pos:
			if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>=ACMap.SIZE:return
	var error=core.command(int(peer_slots[peer]),cmd)
	if error!="":_server_notice.rpc_id(peer,error)

@rpc("authority","call_remote","unreliable_ordered",1)
func _receive_state(bytes: PackedByteArray) -> void:
	if dedicated:return
	var raw=bytes.decompress_dynamic(16777216,FileAccess.COMPRESSION_DEFLATE)
	var data=bytes_to_var(raw)
	if not data is Dictionary:return
	_accept_visual_snapshot(data.get("units",[]),float(data.get("time",0)))
	state=data
	if test_network:
		if state.get("ended",false):
			if result_sent:return
			result_sent=true
			_report_public_result(state.winners,float(state.time))
			print("ASTERA_CLIENT_RESULT "+JSON.stringify({"winners":state.winners,"time":state.time,"slot":local_slot,"units":state.units.size()}))
			await get_tree().create_timer(3).timeout
			_leave_network()
			get_tree().quit()
		return
	if page=="connecting" and not loading_result.is_empty() and bool(state.get("battle_ready",true)):_finish_remote_loading()
	if state.get("ended",false) and not result_sent:
		_report_public_result(state.winners,float(state.time))
		result_sent=true
		_show_result()
	queue_redraw()

func _start_dedicated(config_file: String) -> void:
	dedicated=true
	server_config=JSON.parse_string(FileAccess.get_file_as_string(config_file))
	core=Core.new()
	core.setup(server_config)
	var peer: MultiplayerPeer
	if server_config.get("transport","")=="webrtc":
		public_p2p=ACPublicP2P.new();add_child(public_p2p)
		public_p2p.failed.connect(func(message):_emit_result({"void":true,"reason":message}))
		peer=public_p2p.setup(str(server_config.signal_url),server_config,true)
	else:
		peer=ENetMultiplayerPeer.new()
	if server_config.get("transport","")!="webrtc" and peer.create_server(int(server_config.port),8)!=OK:
		print("ASTERA_RESULT "+JSON.stringify({"void":true,"reason":"전투 포트 사용 실패"}))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer=peer
	multiplayer.peer_disconnected.connect(func(id):
		command_windows.erase(id)
		for ticket in observer_peers.keys():
			if int(observer_peers[ticket])==id:observer_peers.erase(ticket)
		if peer_slots.has(id):
			if server_ready and int(peer_slots[id])>=0:disconnect_deadlines[peer_slots[id]]=Time.get_ticks_msec()/1000.0+60
			peer_slots.erase(id)
	)
	server_created=Time.get_ticks_msec()/1000.0

func _server_process(dt: float) -> void:
	if result_sent:return
	var now=Time.get_ticks_msec()/1000.0
	if not server_ready:
		var needed=0
		for p in server_config.players:
			if not p.get("bot",false):needed+=1
		if peer_slots.values().filter(func(slot):return int(slot)>=0).size()==needed:
			if countdown<0:countdown=0 if server_config.get("lobby_countdown_done",false) else 3
			countdown-=dt
			if countdown<=0:server_ready=true
		elif now-server_created>120:
			_emit_result({"void":true,"reason":"경기 시작 전 접속 시간 초과"})
			return
	else:
		for slot in disconnect_deadlines.keys():
			if now>disconnect_deadlines[slot]:core.command(int(slot),{"type":"surrender"});disconnect_deadlines.erase(slot)
		tick_accum+=minf(dt,.2)
		while tick_accum>=.05:
			core.step(.05)
			core.resolve_spells()
			tick_accum-=.05
		if core.time>7200:
			_emit_result({"void":true,"reason":"서버 제한 시간 초과"})
			return
		if core.ended:
			for peer in peer_slots:
				var snapshot=_network_snapshot(int(peer_slots[peer]))
				_receive_state.rpc_id(int(peer),var_to_bytes(snapshot).compress(FileAccess.COMPRESSION_DEFLATE))
				_match_finished.rpc_id(int(peer),core.winners,core.time)
			_emit_result({"winners":core.winners,"duration":core.time})
			return
	snapshot_clock-=dt
	if snapshot_clock<=0:
		snapshot_clock=.18
		var encoded_views={}
		for peer in peer_slots:
			var viewer=int(peer_slots[peer])
			if not encoded_views.has(viewer):encoded_views[viewer]=var_to_bytes(_network_snapshot(viewer)).compress(FileAccess.COMPRESSION_DEFLATE)
			_receive_state.rpc_id(int(peer),encoded_views[viewer])

func _network_snapshot(viewer: int) -> Dictionary:
	var snapshot=core.snapshot(viewer)
	snapshot.battle_ready=server_ready
	return snapshot

func _emit_result(result: Dictionary) -> void:
	if result_sent:return
	result_sent=true
	print("ASTERA_RESULT "+JSON.stringify(result))
	await get_tree().create_timer(2).timeout
	get_tree().quit()

func _draw() -> void:
	if dedicated:return
	if page=="main":return
	if page!="game":
		draw_rect(Rect2(Vector2.ZERO,size),Color("070b10"))
		if menu_backdrop!=null:draw_texture_rect(menu_backdrop,Rect2(Vector2.ZERO,size),false,Color(1,1,1,.47))
		draw_rect(Rect2(0,0,650,size.y),Color(0.025,.035,.05,.86))
		if elapsed<status_until:draw_string(font,Vector2(70,size.y-18),status_text,HORIZONTAL_ALIGNMENT_LEFT,size.x-140,18,Color("ffd17a"))
		return
	if state.is_empty():return
	draw_rect(_world_render_rect(),Color("090e13"))

func _draw_retained_roots() -> void:
	var previous=world_canvas;world_canvas=_root_canvas
	_world_transform()
	_draw_root_ground(_world_render_rect())
	_draw_ground_remains()
	world_canvas=previous

func _draw_root_ground(_view: Rect2) -> void:
	var viewer=hash([local_slot,spectator,network_client,replay_mode])
	if viewer!=root_viewer_signature:
		root_viewer_signature=viewer;root_artist.chunks.clear();root_artist.pending.clear();root_artist.chunk_input=0
	var packed=state.get("roots",PackedInt32Array())
	if simulation_worker==null and spectator and not network_client and not replay_mode and core!=null:packed=core.roots.snapshot(core,-1)
	var fog_signature=_fog_stamp()
	root_artist.draw(world_canvas,draw_map,packed,_fog_value,zoom,world_to_screen,fog_signature)

func _draw_world() -> void:
	var view=_world_render_rect()
	_world_transform()
	world_canvas.draw_rect(view,Color("0a1119"))
	terrain_artist.draw(world_canvas,draw_map,view,zoom,world_to_screen,screen_to_world,_fog_value,float(state.get("time",0)),_fog_stamp(),false)
	var objects: Array=[]
	var points={}
	for res in state.get("resources",[]):
		var p=ACData.point(res.pos)
		if not draw_map.inside(Vector2i(p)):continue
		if not _resource_screen_rect(res).intersects(view) or _fog_value(int(p.y)*128+int(p.x))==0:continue
		objects.append(res)
	for remembered in state.get("building_memory",[]):
		var point=_center(remembered)
		if _fog_value(int(point.y)*128+int(point.x))==1 and _building_screen_rect(remembered).intersects(view.grow(128)):objects.append(remembered)
	for e in _entities():
		if e.get("container",-1)>=0 or not _visible(e):continue
		var point=_ground_point(_center(e) if e.has("progress") else _visual_position(e))
		var in_view=_building_screen_rect(e).intersects(view.grow(128)) if e.has("progress") else view.grow(200).has_point(point)
		if in_view:objects.append(e);points[int(e.id)]=point
	_sync_entity_canvases(objects,points)
	_world_effect_canvas.queue_redraw()

func _draw_ground_remains() -> void:
	# Ground remains belong above living root tiles and below standing units.
	for debris in state.get("rubble",[]):
		var texture=assets.rubble_texture(int(debris.race),int(debris.kind))
		if texture==null:continue
		var point=_ground_point(ACData.point(debris.pos));var width=float(debris.width)*32*zoom
		var dimensions=Vector2(width,width*texture.get_height()/float(texture.get_width()))
		var opacity=1-smoothstep(.22,1.0,(float(state.time)-float(debris.started))/45.0)
		var light=.38 if debris.get("fogged",false) else 1.0
		world_canvas.draw_texture_rect(texture,Rect2(point-dimensions*Vector2(.5,.65),dimensions),false,Color(light,light,light,opacity))
	for fx in state.get("effects",[]):
		if fx.get("type","")=="death":
			if not fx.get("airborne",false):_draw_death_body(fx)
			if _death_is_ground(fx):_draw_effect(fx)

func _sync_entity_canvases(objects: Array,points: Dictionary={}) -> void:
	var active={};var now=Time.get_ticks_msec()*.001
	for e in objects:
		var id=int(e.id);active[id]=true
		if not _entity_canvases.has(id):
			var node=ACEntityCanvas.new();node.main=self;world_canvas.add_child(node);_entity_canvases[id]=node
		var node: ACEntityCanvas=_entity_canvases[id]
		node.entity=e
		if e.has("owner"):
			var owner=int(e.owner)
			var palette_id=int(state.players[owner].get("color_id",owner%8))
			node.material=player_palette.material(int(e.race),palette_id,e.has("progress"))
		var point: Vector2=points.get(id,Vector2.INF)
		if not point.is_finite():point=_ground_point(_center(e) if e.has("progress") else ACData.point(e.pos) if e.has("amount") else _visual_position(e))
		var next_position=point-world_clip.position
		if not node.position.is_equal_approx(next_position):node.position=next_position
		var depth=_render_depth(e) if e.has("progress") or e.has("amount") else point.y+(10000 if ACData.unit(int(e.race),int(e.kind)).air else 0)
		var layer=clampi(roundi(depth),2,3000)
		if node.z_index!=layer:node.z_index=layer
		if node.bounds.has_area():render_rects[id]=Rect2(node.bounds.position+point,node.bounds.size)
		if node.body_bounds.has_area():_selection_bodies[id]=Rect2(node.body_bounds.position+point,node.body_bounds.size)
		if now>=node.next_pose or not is_equal_approx(node.drawn_zoom,zoom):
			# Authored attack clips keep all their poses. Movement transforms
			# still interpolate at display rate without repainting every frame.
			var fps=12.0
			if not e.has("progress") and not e.has("amount"):
				var action=str(e.get("action","idle"))
				if action=="idle" and _uses_wingbeat(e):action="walk"
				var attack_duration=assets.sprites.action_length(int(e.race),int(e.kind),"attack")
				var attack_window=minf(attack_duration,maxf(.15,float(ACData.unit(int(e.race),int(e.kind)).period)*.9))
				if (not e.get("moving",false) or _moving_fire_pose(e)) and float(state.time)-float(e.get("fired",-99))<attack_window and assets.sprites.has_action(int(e.race),int(e.kind),"attack"):
					action="attack"
				fps=clampf(float(assets.unit_action_info(int(e.race),int(e.kind),action).get("fps",12)),4,30)
			var stagger=float(posmod(id,12))/12.0
			node.next_pose=(floorf(now*fps-stagger)+1+stagger)/fps
			node.queue_redraw()
	for id in _entity_canvases.keys():
		if not active.has(id):_entity_canvases[id].queue_free();_entity_canvases.erase(id);render_rects.erase(id);_selection_bodies.erase(id)

func _draw_world_overlay_canvas() -> void:
	var previous=world_canvas;world_canvas=_world_effect_canvas
	_world_transform();_draw_world_overlay();world_canvas=previous

func _draw_world_overlay() -> void:
	var view=_world_render_rect()
	for unit in state.get("units",[]):
		if not unit.get("beam_active",false) or unit.hp<=0:continue
		var target=_entity(int(unit.get("beam_target",-1)))
		if target.is_empty() or target.hp<=0 or not _visible(unit) or not _visible(target):continue
		var end=_ground_point(_center(target))-Vector2(0,12*zoom)
		var start=_weapon_tip(unit,_visual_position(unit),_center(target))
		var focus=1.0+minf(2,maxf(0,float(state.time)-float(unit.get("focus_started",state.time)))*.35)
		var width=(1.3+focus*.4)*zoom
		world_canvas.draw_line(start,end,Color(1,.16,.28,.18),width*3,true)
		world_canvas.draw_line(start,end,Color(1,.34,.44,.9),width,true)
		world_canvas.draw_line(start,end,Color(1,.91,.86,.9),width*.38,true)
		world_canvas.draw_circle(end,(2+focus*.5)*zoom,Color(1,.28,.38,.75),true,-1,true)
	for contact in state.get("shimmers",[]):_draw_cloak_shimmer(contact)
	for id in selected:
		var producer=_entity(int(id))
		if not producer.is_empty() and _building_accepts_rally(producer):_draw_rally_beacon(producer)
	var flame_latest={}
	for fx in state.get("effects",[]):
		if fx.get("projectile","")=="flame":flame_latest[int(fx.get("unit",-1))]=int(fx.id)
	for fx in state.get("effects",[]):
		if fx.get("type","")=="death" and fx.get("airborne",false):_draw_death_body(fx)
		if fx.get("type","")=="death" and _death_is_ground(fx):continue
		if fx.get("projectile","")=="flame" and flame_latest.get(int(fx.get("unit",-1)),-1)!=int(fx.id):continue
		_draw_effect(fx)
	var mouse=pointer_position if pointer_position.is_finite() else get_global_mouse_position()
	if build_kind>=0 and _can_point_world(mouse):
		var pos=_build_position(mouse)
		var d=ACData.building(int(state.players[local_slot].race),build_kind)
		var valid=true
		if simulation_worker==null and core!=null and not network_client:valid=core.placement(local_slot,build_kind,pos)==""
		elif simulation_worker!=null:
			var key="%d:%d:%s"%[local_slot,build_kind,str(pos)]
			if key!=_placement_requested:simulation_worker.placement(local_slot,build_kind,pos,key);_placement_requested=key
			valid=_placement_result.get("key","")==key and _placement_result.get("valid",false)
		_draw_building_ghost(int(state.players[local_slot].race),build_kind,pos,valid)
	if dragging:
		var rect=Rect2(drag_start,get_global_mouse_position()-drag_start).abs()
		world_canvas.draw_rect(rect,Color(.2,1,.5,.07))
		world_canvas.draw_rect(rect,Color(.3,1,.5),false,1.5)
	terrain_artist.draw_boundary_mask(world_canvas,draw_map,view,zoom,world_to_screen)

func _fog_stamp() -> int:
	if spectator:return hash(["all_visible",draw_map.get_instance_id()])&0x7fffffff
	var revision=int(core.vision_revisions.get(local_slot,0)) if simulation_worker==null and not network_client and not replay_mode and core!=null else int(state.get("fog_revision",floorf(float(state.get("time",0))*5)))
	return hash([revision,local_slot,spectator,network_client,replay_mode,draw_map.get_instance_id()])&0x7fffffff

func _fog_value(index: int) -> int:
	if spectator:return 2
	if index<0 or index>=128*128:return 0
	if simulation_worker==null and not network_client and not replay_mode and core!=null:
		return 2 if core.visibility[local_slot][index] else (1 if core.explored[local_slot][index] else 0)
	var fog=state.get("fog",[])
	var seen=state.get("explored",[])
	if fog.is_empty():return 2
	return 2 if fog[index] else (1 if seen[index] else 0)

func _team_color(owner: int) -> Color:
	return ACPlayerColors.color(int(state.players[owner].get("color_id",owner%8))) if owner>=0 and owner<state.get("players",[]).size() else Color.WHITE

func _draw_footprint(pos: Vector2,dimensions: Vector2,color: Color,fill: bool=false) -> void:
	var points=PackedVector2Array([_ground_point(pos),_ground_point(pos+Vector2(dimensions.x,0)),_ground_point(pos+dimensions),_ground_point(pos+Vector2(0,dimensions.y))])
	if fill:world_canvas.draw_colored_polygon(points,color)
	points.append(points[0])
	world_canvas.draw_polyline(points,color.lightened(.3),1.5,true)

func _draw_building_ghost(race: int,kind: int,pos: Vector2,valid: bool) -> void:
	if race==2 and kind not in [0,2]:
		for tower in state.get("buildings",[]):
			if int(tower.owner)!=local_slot or int(tower.kind)!=(0 if kind==1 else 2) or tower.hp<=0 or tower.progress<1:continue
			var boundary=PackedVector2Array()
			for i in range(65):boundary.append(_ground_point(_center(tower)+Vector2.from_angle(float(i)*TAU/64.0)*(14.0 if kind==1 else 12.0)))
			world_canvas.draw_polyline(boundary,Color(.45,.8,1,.65),2,true)
	var definition=ACData.building(race,kind)
	var texture=assets.building(race,kind)
	if texture==null:return
	var anchor=pos+Vector2(definition.w,definition.h)*.5
	if kind==1:anchor=pos+Vector2(float(definition.w)-1,float(definition.h)-1)*.5
	var point=_ground_point(anchor)
	var width=float(definition.w)*32*zoom
	var height=width*texture.get_height()/texture.get_width()
	var front=float(definition.h)*16*zoom
	var tint=Color(.48,1,.66,.55) if valid else Color(1,.3,.24,.55)
	var authored=assets.sprites.building(race,kind,1,false,Vector2.DOWN,0)
	if not authored.is_empty():
		var foundation=point+Vector2(0,front)
		_draw_unit_frame(authored,foundation,width,tint)
		var turret=assets.sprites.building_turret(race,kind,Vector2.DOWN,0)
		if not turret.is_empty():_draw_unit_frame(turret,foundation+authored.get("mount",Vector2.ZERO)*width/maxf(1,float(authored.scale_hint)),width,tint)
		return
	world_canvas.draw_texture_rect(texture,Rect2(point+Vector2(-width*.5,front-height),Vector2(width,height)),false,tint)

func _render_depth(e: Dictionary) -> float:
	if e.has("amount"):
		return _ground_point(ACData.point(e.pos)+Vector2(0,maxf(0,_resource_dimensions(e).y*.5-.5))).y
	if e.has("progress"):
		var definition=ACData.building(int(e.race),int(e.kind))
		return _ground_point(ACData.point(e.pos)+Vector2(float(definition.w)*.5,float(definition.h)-.5)).y
	var point=_ground_point(_visual_position(e))
	return point.y+(10000 if ACData.unit(int(e.race),int(e.kind)).air else 0)

func _building_screen_rect(e: Dictionary) -> Rect2:
	var race=int(e.race);var kind=int(e.kind)
	var d=ACData.building(race,kind)
	var point=_ground_point(_center(e))
	var width=float(d.w)*32*zoom;var front=float(d.h)*16*zoom
	var frame=assets.sprites.building(race,kind,1,false,Vector2.DOWN,0)
	if not frame.is_empty():
		var factor=width/maxf(1,float(frame.scale_hint))
		return Rect2(point+Vector2(0,front)-Vector2(frame.anchor)*factor,frame.texture.get_size()*factor)
	var texture=assets.building(race,kind)
	var height=width*texture.get_height()/texture.get_width() if texture!=null else width*1.5
	return Rect2(point+Vector2(-width*.5,front-height),Vector2(width,height))

func _draw_building(e: Dictionary) -> void:
	var d=ACData.building(int(e.race),int(e.kind))
	var pos=ACData.point(e.pos)
	var anchor=_center(e)
	if int(e.kind)==1:
		anchor=pos+Vector2(float(d.w)-1,float(d.h)-1)*.5
		for resource in state.get("resources",[]):
			if resource.type=="tera" and Rect2(pos,Vector2(d.w,d.h)).has_point(ACData.point(resource.pos)):
				anchor=ACData.point(resource.pos)
				break
	var sp=_ground_point(anchor)
	if e.get("remembered",false):
		# A frozen last-seen silhouette is terrain intelligence, not a live
		# entity: no idle motion, smoke, health bars, selection or target entry.
		var remembered_frame=assets.sprites.building(int(e.race),int(e.kind),float(e.progress),false,Vector2.DOWN,0)
		if not remembered_frame.is_empty():
			render_rects[int(e.id)]=_draw_unit_frame(remembered_frame,sp+Vector2(0,float(d.h)*16*zoom),float(d.w)*32*zoom,Color(.40,.40,.43))
			return
		var remembered_texture=assets.building(int(e.race),int(e.kind))
		if remembered_texture==null:return
		var width=float(d.w)*32.0*zoom
		var height=width*remembered_texture.get_height()/remembered_texture.get_width()
		var rect=Rect2(sp+Vector2(-width*.5,float(d.h)*16.0*zoom-height),Vector2(width,height))
		for layer in construction_visual.shadow_layers(int(e.race),int(e.kind),remembered_texture,rect,float(e.progress)):
			world_canvas.draw_texture_rect(layer.texture,layer.rect,false,Color(.40,.40,.43,float(layer.opacity)))
		render_rects[int(e.id)]=rect
		return
	var idle_clock=float(state.time)+(minf(visual_clock,visual_step) if not paused else 0.0)+int(e.id)*.173
	var active=not e.get("queue",[]).is_empty() or not str(e.get("research","")).is_empty() or bool(e.get("tera_active",false))
	var attack_clock=maxf(0,float(state.time)-float(e.get("fired",-99)))+(minf(visual_clock,visual_step) if not paused else 0.0)
	if attack_clock>=.75:attack_clock=-1
	var facing=_iso(ACData.point(e.get("facing",[0,1]))).normalized()
	var authored=assets.sprites.building(int(e.race),int(e.kind),float(e.progress),active and e.get("powered",true),facing,idle_clock,attack_clock)
	var tex=assets.building_idle(int(e.race),int(e.kind),idle_clock) if float(e.progress)>=1.0 else assets.building(int(e.race),int(e.kind))
	if int(e.id) in selected:_draw_footprint(pos-Vector2(.5,.5) if int(e.kind)==1 else pos,Vector2(d.w,d.h),_team_color(int(e.owner)))
	var width=float(d.w)*32.0*zoom
	var front=float(d.h)*16.0*zoom
	_world_shadow(sp+Vector2(0,front*.12),Vector2(width*.94,width*.58),.13)
	var damage_texture: Texture2D=null
	var damage_rect=Rect2()
	if not authored.is_empty():
		var factor=width/maxf(1,float(authored.scale_hint))
		var foundation=sp+Vector2(0,front)
		var color=Color(.96,.97,.98)
		if not e.get("powered",true):color*=Color(.48,.52,.58)
		var rect=_draw_unit_frame(authored,foundation,width,color)
		damage_texture=authored.texture;damage_rect=building_damage_visual.frame_rect(authored,foundation,width)
		if e.progress>=1:
			var turret=assets.sprites.building_turret(int(e.race),int(e.kind),facing,idle_clock,attack_clock)
			if not turret.is_empty():rect=rect.merge(_draw_unit_frame(turret,foundation+authored.get("mount",Vector2.ZERO)*factor,width,color))
		render_rects[int(e.id)]=rect
	elif tex!=null:
		var height=width*tex.get_height()/tex.get_width()
		var color=Color(.96,.97,.98)
		var rect=Rect2(sp+Vector2(-width*.5,front-height),Vector2(width,height))
		damage_texture=tex;damage_rect=rect
		render_rects[int(e.id)]=rect
		if float(e.progress)<1:
			construction_visual.draw(world_canvas,int(e.race),int(e.kind),tex,rect,float(e.progress),idle_clock)
			if construction_visual.available(int(e.race),int(e.kind)):
				var phase: Dictionary=construction_visual.frames["%d:%d"%[int(e.race),int(e.kind)]][ConstructionVisual.stage(float(e.progress))]
				damage_texture=phase.texture
				damage_rect=rect if phase.get("composite",false) else construction_visual.scaffold_rect(phase,rect)
		else:
			if not e.get("powered",true):color*=Color(.48,.52,.58)
			world_canvas.draw_texture_rect(tex,rect,false,color)
			if int(e.kind)==1:_draw_refinery_plume(e,rect)
	if damage_texture!=null:
		if float(e.progress)>=1 and e.get("powered",true):
			building_status_lights.draw(world_canvas,damage_texture,damage_rect,int(e.race),idle_clock,active)
		var capacity=building_damage_visual.health_capacity(float(d.hp),float(e.progress))
		if building_damage_visual.received_damage(e):
			building_damage_visual.draw(world_canvas,int(e.race),float(e.hp),capacity,damage_texture,damage_rect,idle_clock,int(e.id))
	if int(e.id) in selected:_draw_bars(sp+Vector2(0,front+6),e,d,mini(110,int(width*.65)))
	if int(e.id) in selected and not e.queue.is_empty():
		var q=e.queue[0]
		var bar_width=mini(110,int(width*.65))
		var fraction=clampf(1-float(q.left)/maxf(.01,float(q.total)),0,1)
		_draw_segmented_bar(Rect2(sp+Vector2(-bar_width*.5,front+16),Vector2(bar_width,5)),fraction*float(d.hp),float(d.hp),Color("69bfd1"))

func _deployment_progress(e: Dictionary) -> float:
	if not e.has("deploy_until"):return 1.0 if e.get("anchored",false) else 0.0
	var start=float(e.get("deploy_started",0));var now=float(state.get("time",0))+minf(visual_clock,visual_step)
	var progress=clampf((now-start)/maxf(.01,float(e.deploy_until)-start),0,1)
	return progress if e.get("deploy_to",false) else 1-progress

func _moving_fire_pose(e: Dictionary) -> bool:
	# Carrier drones already fire while circling. Their authored muzzle pulse
	# must remain visible during that existing movement, without stopping them.
	return int(e.race)==0 and int(e.kind)==15 and assets.sprites.units.get("0:15",{}).get("staged16",false)

func _uses_wingbeat(e: Dictionary) -> bool:
	return (int(e.race)==1 and int(e.kind)==10) or (int(e.race)==2 and int(e.kind)==9)

func _uses_fixed_hull(e: Dictionary) -> bool:
	var d=ACData.unit(int(e.race),int(e.kind))
	# The scout's separately authored rotor cycle is retained; jet hulls stay still.
	return (bool(d.air) and str(d.get("material",""))=="mechanical" and not (int(e.race)==0 and int(e.kind)==8)) or (int(e.race)==1 and int(e.kind)==11) or (int(e.race)==2 and int(e.kind)==8)

func _draw_unit(e: Dictionary) -> void:
	var d=ACData.unit(int(e.race),int(e.kind))
	var foot=_ground_point(_visual_position(e))
	var animation_clock=float(e.get("action_clock",state.time))+(minf(visual_clock,visual_step) if not paused else 0.0)
	var action=str(e.get("action","idle"))
	if d.get("role","")=="brood":
		action="morph" if e.get("brood_state","idle")=="morph" else "idle"
		if action=="morph":animation_clock=clampf(1-float(e.get("morph_left",0))/maxf(.01,float(e.get("morph_total",1))),0,.999)*.8
	if bool(e.get("healing",false)):
		action="heal"
		animation_clock=maxf(0,float(state.time)-float(e.get("heal_started",state.time)))+(minf(visual_clock,visual_step) if not paused else 0.0)
	elif d.get("role","")!="brood" and action in ["idle","walk","move"] and visual_motion.has(int(e.id)):
		var motion: Dictionary=visual_motion[int(e.id)]
		action="walk" if bool(motion.walking) else "idle"
		if action=="idle" and assets.sprites.has_unit(int(e.race),int(e.kind)):
			animation_clock=float(state.time)+(minf(visual_clock,visual_step) if not paused else 0.0)+float(e.id)*.173
		else:animation_clock=float(motion.phase)/maxf(1,float(assets.sprites.action_info(int(e.race),int(e.kind),"walk").get("fps",9)))
	if d.air and action in ["idle","walk","move"]:
		animation_clock=float(state.get("time",0))+(minf(visual_clock,visual_step) if not paused else 0.0)+float(e.id)*.173
		if action=="idle" and _uses_wingbeat(e):action="walk"
	if (not e.get("moving",false) or _moving_fire_pose(e)) and assets.sprites.has_action(int(e.race),int(e.kind),"attack"):
		var age=float(state.time)-float(e.get("fired",-99))+(minf(visual_clock,visual_step) if not paused else 0.0)
		var duration=assets.sprites.action_length(int(e.race),int(e.kind),"attack")
		var window=minf(duration,maxf(.15,float(d.period)*.9))
		if age>=0 and age<window:
			action="attack";animation_clock=age*duration/maxf(.01,window)
	var vehicle=assets.vehicle(int(e.race),int(e.kind),_visual_facing(e,"body_direction"),_visual_facing(e,"turret_direction"),_deployment_progress(e),action,animation_clock)
	var frame=vehicle.chassis if not vehicle.is_empty() else assets.unit(int(e.race),int(e.kind),_visual_facing(e),"idle" if _uses_fixed_hull(e) else action,0.0 if _uses_fixed_hull(e) else animation_clock)
	if frame.is_empty():return
	if not vehicle.is_empty() and action in ["walk","move"] and not frame.get("v062",false):
		frame=frame.duplicate()
		frame.gait=animation_clock*9.0
		frame.walker=int(e.kind)==12
	var tex: Texture2D=frame.texture
	var radius=float(d.size)*12*zoom
	# A single faint round contact shadow stays directly below every unit.
	_world_shadow(foot,Vector2(radius*1.6,radius*1.1),.13)
	_world_transform(foot,0,Vector2(1,.46))
	if int(e.id) in selected:world_canvas.draw_arc(Vector2.ZERO,radius+4,0,TAU,36,_team_color(int(e.owner)),1.6,true)
	_world_transform(Vector2.ZERO)
	var sp=foot-Vector2(0,22*zoom if d.air else 0)
	if d.air and not _uses_fixed_hull(e):
		sp.y-=sin(animation_clock*1.7)*1.8*zoom
		sp.x+=sin(animation_clock*.85)*.45*zoom
	var extent=float(d.get("visual_extent",float(d.size)*(62 if d.air else 47)))*zoom
	var color=Color(.96,.97,.98)
	if e.get("cloaked",false):color.a=.42
	if bool(d.air) and bool(e.get("moving",false)) and assets.propulsion_frames.size()==3:
		# Separate exhaust frames preserve the approved hull pixels and view angle.
		var facing=_visual_facing(e).normalized()
		var exhaust: Texture2D=assets.propulsion_frames[int(e.race)][posmod(int(elapsed*16)+int(e.id),8)]
		_world_transform(sp-facing*extent*.27,Vector2.DOWN.angle_to(-facing))
		world_canvas.draw_texture_rect(exhaust,Rect2(-extent*.14,-extent*.025,extent*.28,extent*.40),false,Color(1,1,1,color.a*.85))
		_world_transform()
	var support_rect=Rect2()
	if int(e.race)==0 and int(e.kind)==5 and frame.get("staged16",false):
		var supports=assets.siege_supports(_visual_facing(e,"body_direction"),_deployment_progress(e),frame)
		if not supports.is_empty():support_rect=_draw_unit_frame(supports,sp,extent,color)
	var rect=_draw_drone(e,sp,extent,color,animation_clock) if int(e.race)==0 and int(e.kind)==8 and not assets.drone_parts.is_empty() and (frame.get("separate_rotors",false) or not frame.get("v062",false)) else _draw_unit_frame(frame,sp,extent,color)
	if support_rect.has_area():rect=rect.merge(support_rect)
	if not vehicle.is_empty():
		_selection_bodies[int(e.id)]=rect
		var factor=extent/maxf(1,float(frame.scale_hint))
		var mount=sp+vehicle.mount*factor
		if not frame.get("staged16",false):
			if action in ["walk","move"]:mount.y-=sin(animation_clock*18.0)*.5*zoom
			var recoil=0.0
			if action=="attack":recoil=sin(clampf(animation_clock/.20,0,1)*PI)*2.0*zoom
			mount-=_visual_facing(e,"turret_direction")*recoil
		rect=rect.merge(_draw_unit_frame(vehicle.turret,mount,extent*vehicle.turret_scale,color))
		if not vehicle.embedded_pilot:
			var pilot=assets.pilot(_visual_facing(e,"turret_direction"))
			if not pilot.is_empty():rect=rect.merge(_draw_unit_frame(pilot,mount+vehicle.pilot_mount*factor*vehicle.turret_scale,clampf(extent*.14,8*zoom,12*zoom),color))
	elif int(e.race)==0 and bool(d.air) and not bool(frame.get("embedded_pilot",false)):
		var pilot_mount=assets.air_pilot_mount(0,int(e.kind),_visual_facing(e))
		var pilot=assets.pilot(_visual_facing(e),true)
		if not pilot_mount.is_empty() and not pilot.is_empty():
			var factor=extent/maxf(1,float(frame.scale_hint))
			rect=rect.merge(_draw_unit_frame(pilot,sp+pilot_mount.offset*factor,pilot_mount.width*factor,color))
	render_rects[int(e.id)]=rect
	if int(e.id) in selected or float(state.time)-float(e.get("damaged",-99))<2.5:_draw_bars(Vector2(foot.x,rect.position.y-8),e,d,clampi(int(extent),26,80))
	if e.get("carried",0)>0:world_canvas.draw_circle(foot+Vector2(7,-10)*zoom,3*zoom,Color("ffd354"))

func _draw_cloak_shimmer(contact: Dictionary) -> void:
	var pos=ACData.point(contact.pos)
	if _fog_value(int(pos.y)*128+int(pos.x))<2:return
	var point=_ground_point(pos)
	if not _world_render_rect().grow(60).has_point(point):return
	var frame=assets.unit(int(contact.race),int(contact.kind),ACData.point(contact.facing),"idle",0)
	if frame.is_empty():return
	var texture: Texture2D=frame.texture
	var d=ACData.unit(int(contact.race),int(contact.kind))
	var factor=float(d.get("visual_extent",30))*zoom/float(frame.scale_hint)
	var flip=bool(frame.get("flip",false))
	_world_transform(point,0,Vector2(-factor if flip else factor,factor))
	for strip in range(10):
		var y=float(strip)*texture.get_height()/10.0
		var h=float(texture.get_height())/10.0
		var wobble=sin(elapsed*3.0+strip*.8+pos.x)*2.4/factor
		var alpha=.06+.035*(sin(elapsed*2.0+strip*.7)+1)*.5
		var destination=Rect2(Vector2(-frame.anchor.x+wobble,y-frame.anchor.y),Vector2(texture.get_width(),h))
		world_canvas.draw_texture_rect_region(texture,destination,Rect2(0,y,texture.get_width(),h),Color(.65,.8,.9,alpha))
	_world_transform()

func _draw_drone(e: Dictionary,sp: Vector2,extent: float,color: Color,clock: float) -> Rect2:
	var direction=_visual_facing(e).normalized()
	var parts=assets.drone(direction,clock)
	# Mounts belong to the selected authored hull, so fans cannot drift while
	# the live heading moves between two stored body directions.
	var modules=assets.drone_mounts(parts.hull,direction,extent)
	_world_transform()
	for offset in modules:
		world_canvas.draw_line(sp,sp+offset,Color("252c30"),maxf(2,extent*.055),true)
		world_canvas.draw_line(sp,sp+offset,Color("a89038"),maxf(1,extent*.018),true)
	var rect=Rect2(sp,Vector2.ZERO)
	for offset in modules:
		if offset.y<0:rect=rect.merge(_draw_unit_frame(parts.rotor,sp+offset,extent*.42,color))
	rect=rect.merge(_draw_unit_frame(parts.hull,sp,extent*.6,color))
	for offset in modules:
		if offset.y>=0:rect=rect.merge(_draw_unit_frame(parts.rotor,sp+offset,extent*.42,color))
	return rect

func _draw_unit_frame(frame: Dictionary,point: Vector2,extent: float,color: Color=Color.WHITE) -> Rect2:
	var seal_bounds=Rect2()
	if frame.has("summon_stage"):
		var stage=clampi(int(frame.summon_stage),0,4)
		var seal=assets.sprites.owl_summon_seal()
		seal=seal.duplicate();seal.palette=false
		if not seal.is_empty():seal_bounds=_draw_unit_frame(seal,point,extent*.92,Color(color,float(color.a)*[.55,.48,.32,.18,.07][stage]))
		color*= [Color(1,.18,.12,0),Color(1,.2,.15,.20),Color(1,.52,.46,.45),Color(1,.82,.78,.74),Color(1,1,1,.96)][stage]
	var texture: Texture2D=frame.texture
	if not _palette_entity.is_empty() and frame.get("palette",true):texture=player_palette.marked(texture)
	var factor=extent/maxf(1,float(frame.get("scale_hint",maxf(texture.get_width(),texture.get_height()))))
	var anchor: Vector2=frame.get("anchor",texture.get_size()*.5)
	var flip=bool(frame.get("flip",false))
	var rotation=float(frame.get("rotation",0))
	var source_bounds: Rect2=frame.get("sprite_bounds",Rect2(Vector2.ZERO,texture.get_size()))
	_world_transform(point,rotation,Vector2(-factor if flip else factor,factor))
	if frame.has("gait"):
		var marked_frame=frame.duplicate();marked_frame.texture=texture;_draw_vehicle_gait(marked_frame,color)
	else:world_canvas.draw_texture(texture,-anchor,color)
	_world_transform()
	var transform=Transform2D(rotation,Vector2(-factor if flip else factor,factor),0,point)
	var bounds=Rect2(transform*(source_bounds.position-anchor),Vector2.ZERO)
	for corner in [Vector2(source_bounds.end.x,source_bounds.position.y),source_bounds.end,Vector2(source_bounds.position.x,source_bounds.end.y)]:
		bounds=bounds.expand(transform*(corner-anchor))
	return bounds.merge(seal_bounds) if seal_bounds.has_area() else bounds

var _vehicle_gait_meshes: Dictionary={}

func _draw_vehicle_gait(frame: Dictionary,color: Color) -> void:
	# A small articulated mesh animates the generated chassis layer while
	# leaving its centre, collision point and independent turret registered.
	var texture: Texture2D=frame.texture
	var source: Texture2D=texture.atlas if texture is AtlasTexture else texture
	var tick=posmod(int(float(frame.gait)*4),16)
	var key=Vector3i(texture.get_instance_id(),tick,1 if bool(frame.walker) else 0)
	if _vehicle_gait_meshes.has(key):
		world_canvas.draw_mesh(_vehicle_gait_meshes[key],source,Transform2D.IDENTITY,color)
		return
	var region: Rect2=texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	var vertices=PackedVector2Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
	var phase=TAU*tick/16.0
	var size_value=texture.get_size()
	for y in range(5):
		for x in range(5):
			var fraction=Vector2(x,y)/4.0
			var point=fraction*size_value-frame.anchor
			if bool(frame.walker):
				var leg=smoothstep(.50,.95,fraction.y)*smoothstep(.10,.35,absf(fraction.x-.5))
				var stride=sin(phase+(PI if x<2 else 0))
				point.x+=stride*3.0*leg
				point.y-=maxf(0,stride)*4.0*leg
			else:
				# Suspension travels above the tread contact, not the whole sprite.
				point.y-=sin(phase*2)*(1-smoothstep(.35,.90,fraction.y))*1.3
			vertices.append(point);uv.append((region.position+fraction*region.size)/source.get_size())
	for y in range(4):
		for x in range(4):
			var start=y*5+x
			indices.append_array(PackedInt32Array([start,start+1,start+6,start,start+6,start+5]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	_vehicle_gait_meshes[key]=mesh
	world_canvas.draw_mesh(mesh,source,Transform2D.IDENTITY,color)

func _draw_rally_beacon(building: Dictionary) -> void:
	var point=ACData.point(building.get("rally",building.pos))
	var screen=_ground_point(point)
	if not _world_render_rect().grow(80).has_point(screen):return
	var texture=assets.rally(int(building.race))
	if texture==null:return
	var width=28*zoom
	var dimensions=Vector2(width,width*texture.get_height()/float(texture.get_width()))
	_world_shadow(screen,Vector2(width,width*.35),.17)
	world_canvas.draw_texture_rect(texture,Rect2(screen-Vector2(dimensions.x*.5,dimensions.y),dimensions),false,Color(1,1,1,.85))

func _energy_capacity(e: Dictionary,d: Dictionary) -> float:
	return maxf(0,float(e.get("max_energy",d.get("max_energy",200 if d.get("role","") in ["medic","mage","priest"] else 0))))

func _draw_bars(sp: Vector2,e: Dictionary,d: Dictionary,width: int) -> void:
	var hp_color=Color("65c976") if float(e.hp)>float(d.hp)*.35 else Color("f16b58")
	_draw_segmented_bar(Rect2(sp-Vector2(width*.5,0),Vector2(width,5)),float(e.hp),float(d.hp),hp_color)
	if float(d.get("shield",0))>0:
		_draw_segmented_bar(Rect2(sp-Vector2(width*.5,6),Vector2(width,4)),float(e.shield),float(d.shield),Color("e884a3"))
	var maximum_energy=_energy_capacity(e,d)
	if maximum_energy>0:
		_draw_segmented_bar(Rect2(sp+Vector2(-width*.5,6),Vector2(width,4)),float(e.get("energy",0)),maximum_energy,Color("73b6ec"))

var _bar_patterns: Dictionary={}

func _draw_segmented_bar(rect: Rect2,value: float,maximum: float,color: Color) -> void:
	var count=clampi(int(ceil(maximum/20.0)),1,mini(24,maxi(1,int(rect.size.x/3))))
	var key=Vector3i(maxi(1,ceili(rect.size.x)),maxi(1,ceili(rect.size.y)),count)
	if not _bar_patterns.has(key):
		var image=Image.create(key.x,key.y,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
		for index in range(count):
			var left=roundi(float(index)*key.x/count);var right=roundi(float(index+1)*key.x/count)-1
			image.fill_rect(Rect2i(left,0,maxi(1,right-left),key.y),Color.WHITE)
		_bar_patterns[key]=ImageTexture.create_from_image(image)
	var pattern: Texture2D=_bar_patterns[key]
	world_canvas.draw_rect(rect.grow(1),Color(.015,.024,.024,.94))
	world_canvas.draw_texture_rect(pattern,rect,false,Color("1c3026"))
	var fraction=clampf(value/maxf(1,maximum),0,1)
	if fraction>0:world_canvas.draw_texture_rect_region(pattern,Rect2(rect.position,rect.size*Vector2(fraction,1)),Rect2(0,0,key.x*fraction,key.y),color)

func _cast_shadow(texture: Texture2D,anchor: Vector2,foot: Vector2,factor: float,flip: bool=false,altitude: float=0.0,opacity: float=1.0,rotation: float=0.0) -> void:
	# Project the object's actual alpha onto the ground with one shared light
	# direction. Ground contact is crisp; elevated aircraft get a wider penumbra.
	var softness=1.0+altitude*.065
	# Retained entity canvases already carry their world position. Shadow
	# vertices must use the same local origin as the body's drawing commands.
	var origin=foot+Vector2(.62,.32)*altitude-world_clip.position-_object_canvas_offset
	var x_axis=Vector2(-factor if flip else factor,0)
	var y_axis=Vector2(-factor*.28,-factor*.16)
	if altitude>0:
		x_axis=Vector2(-factor if flip else factor,0).rotated(rotation)*Vector2(1,.78)
		y_axis=Vector2(0,factor).rotated(rotation)*Vector2(1,.78)
	for offset in [Vector2(-softness,0),Vector2(softness,softness)]:
		world_canvas.draw_set_transform_matrix(Transform2D(x_axis,y_axis,origin+offset))
		world_canvas.draw_texture(texture,-anchor,Color(.025,.035,.045,(.10 if altitude>0 else .17)*opacity))
	_world_transform()

var _soft_shadow: GradientTexture2D

func _world_shadow(point: Vector2,dimensions: Vector2,opacity: float=.3) -> void:
	if _soft_shadow==null:
		var gradient=Gradient.new()
		gradient.colors=PackedColorArray([Color(0,0,0,.9),Color(0,0,0,.65),Color.TRANSPARENT])
		gradient.offsets=PackedFloat32Array([0,.4,1])
		_soft_shadow=GradientTexture2D.new();_soft_shadow.gradient=gradient
		_soft_shadow.width=64;_soft_shadow.height=64;_soft_shadow.fill=GradientTexture2D.FILL_RADIAL
		_soft_shadow.fill_from=Vector2(.5,.5);_soft_shadow.fill_to=Vector2(1,.5)
	_world_transform()
	world_canvas.draw_texture_rect(_soft_shadow,Rect2(point-dimensions*.5,dimensions),false,Color(1,1,1,opacity))

func _draw_ore(sp: Vector2,res: Dictionary) -> void:
	if world_resources.size()!=2:return
	var tex: Texture2D=world_resources[0]
	var rect=_resource_screen_rect(res)
	var dimensions=_resource_dimensions(res)*32*zoom
	_world_shadow(sp,dimensions*Vector2(.9,.7),.28)
	if int(res.id)==selected_resource:_draw_resource_selection(sp,res)
	world_canvas.draw_texture_rect(tex,rect,false,Color(.96,.97,.98))

func _draw_vent(sp: Vector2,res: Dictionary) -> void:
	if world_resources.size()!=2:return
	var presence=_catalyst_presence(res)
	if presence<=0:return
	var tex: Texture2D=_resource_texture(res)
	var rect=_resource_screen_rect(res)
	# Keep the original deposit until the refinery's final construction phase.
	# Its last 12% blends gently into the completed installation.
	var fusion=1.0-presence
	var fusion_scale=lerpf(1.0,.90,fusion)
	rect=Rect2(rect.get_center()-rect.size*fusion_scale*.5-Vector2(0,5*zoom*fusion),rect.size*fusion_scale)
	var dimensions=_resource_dimensions(res)*32*zoom
	_world_shadow(sp,dimensions*Vector2(.9,.7),.28*presence)
	if int(res.id)==selected_resource:_draw_resource_selection(sp,res)
	var tint=Color(.85,.84,.80,presence) if float(res.amount)>0 else Color(.42,.45,.47,presence)
	world_canvas.draw_texture_rect(tex,rect,false,tint)
	if float(res.amount)>0:
		var plume=assets.tera_plume(float(state.time)+(minf(visual_clock,visual_step) if not paused else 0.0)+float(res.id)*.137)
		if not plume.is_empty():
			var factor=dimensions.x*.22/float(plume.scale_hint)
			_world_transform(rect.position+rect.size*Vector2(.52,.46),0,Vector2.ONE*factor)
			world_canvas.draw_texture(plume.texture,-plume.anchor,Color(.7,.85,.9,.30*presence))
			_world_transform()

func _catalyst_presence(resource: Dictionary) -> float:
	var refinery=_resource_refinery(resource)
	if refinery.is_empty():return 1.0
	return 1.0-smoothstep(.88,1.0,float(refinery.progress))

func _draw_refinery_plume(building: Dictionary,rect: Rect2) -> void:
	if not building.get("tera_active",false):return
	var resource: Dictionary={}
	for node in state.get("resources",[]):
		if node.type=="tera" and int(node.id)==int(building.get("tera_resource",-1)):resource=node;break
	if resource.is_empty():
		for node in state.get("resources",[]):
			if node.type=="tera" and _resource_refinery(node).get("id",-1)==building.id:resource=node;break
	if resource.is_empty() or float(resource.amount)<=0:return
	var plume=assets.tera_plume(float(state.time)*.65+float(building.id)*.137)
	if plume.is_empty():return
	# Source-measured exhaust mouths: industrial chimney, grafted sap outlet,
	# and the owl catalyst aperture. Ground vent artwork is hidden below it.
	var outlets=[Vector2(.55,.035),Vector2(.53,.34),Vector2(.5,.19)]
	var mouth=rect.position+rect.size*outlets[int(building.race)]
	var factor=rect.size.x*.18/float(plume.scale_hint)
	_world_transform(mouth,0,Vector2.ONE*factor)
	world_canvas.draw_texture(plume.texture,-plume.anchor,Color(1,1,1,.3))
	_world_transform()

func _draw_resource_selection(sp: Vector2,res: Dictionary) -> void:
	var dimensions=_resource_dimensions(res)*32*zoom
	_world_transform(sp,0,Vector2(1,dimensions.y/maxf(1,dimensions.x)))
	world_canvas.draw_arc(Vector2.ZERO,dimensions.x*.5+2,0,TAU,48,Color("6bea9a"),1.7,true)
	_world_transform()

func _draw_minimap() -> void:
	_render_minimap(self)

var _minimap_ground: PackedByteArray
var _minimap_ground_key=-1

func _render_minimap(canvas: CanvasItem) -> void:
	var rect=_mini_rect()
	if rect.size.x<=2 or rect.size.y<=2:return
	var map_scale=rect.size/float(ACMap.SIZE)
	canvas.draw_rect(rect,Color("151a1d"))
	var signature=_fog_stamp()
	var ground_key=draw_map.render_signature
	if ground_key!=_minimap_ground_key:
		_minimap_ground_key=ground_key;_minimap_ground.resize(64*64*4)
		for y in range(64):
			for x in range(64):
				var index=y*256+x*2;var color=terrain_artist.terrain_color(draw_map,index)
				if draw_map.terrain[index]!=0:color=color.darkened(.35)
				var offset=(y*64+x)*4
				_minimap_ground[offset]=color.r8;_minimap_ground[offset+1]=color.g8;_minimap_ground[offset+2]=color.b8;_minimap_ground[offset+3]=255
	if minimap_texture==null or signature!=minimap_signature:
		var bytes=_minimap_ground.duplicate()
		for y in range(64):
			for x in range(64):
				var index=y*256+x*2;var f=_fog_value(index)
				var offset=(y*64+x)*4
				if f==0:bytes[offset]=21;bytes[offset+1]=26;bytes[offset+2]=29
				elif f==1:
					for channel in range(3):bytes[offset+channel]=int(bytes[offset+channel]*.45)
		var image=Image.create_from_data(64,64,false,Image.FORMAT_RGBA8,bytes)
		if minimap_texture==null:minimap_texture=ImageTexture.create_from_image(image)
		else:minimap_texture.update(image)
		minimap_signature=signature
	canvas.draw_texture_rect(minimap_texture,rect,false)
	for r in state.resources:
		var p=ACData.point(r.pos)
		if _fog_value(int(p.y)*128+int(p.x))>0 and r.amount>0:canvas.draw_rect(Rect2(rect.position+p*map_scale,Vector2(2,2)).intersection(rect),Color("f5cc50") if r.type=="as" else Color("6ac8ff"))
	for e in _entities():
		if not _visible(e) or e.get("container",-1)>=0:continue
		var p=_center(e)
		canvas.draw_rect(Rect2(rect.position+p*map_scale-Vector2.ONE,Vector2(4,4) if e.has("progress") else Vector2(2,2)).intersection(rect),_team_color(int(e.owner)))
	for remembered in state.get("building_memory",[]):
		var p=_center(remembered)
		if _fog_value(int(p.y)*128+int(p.x))==1:canvas.draw_rect(Rect2(rect.position+p*map_scale-Vector2.ONE,Vector2(4,4)).intersection(rect),_team_color(int(remembered.owner)).darkened(.65))
	var view_size=_view_rect().size/(32*zoom)*map_scale
	var viewport_rect=Rect2(rect.position+camera*map_scale-view_size*.5,view_size).intersection(rect.grow(-1))
	canvas.draw_rect(viewport_rect,Color.WHITE,false,1)
	if audio!=null and audio.director!=null:audio.director.draw_pings(canvas,rect,float(state.get("time",0)))

func _context_target(mouse: Vector2,_pos: Vector2) -> int:
	var target=_hit_test(mouse)
	var resource=_resource_at(mouse,true)
	if not resource.is_empty():
		var entity=_entity(target)
		# The crystal surface remains a reliable gathering target even when
		# another friendly miner stands at the deposit's lower edge.
		if entity.is_empty() or int(entity.owner)==local_slot:return int(resource.id)
	return target

func _atlas(file: String,columns: int,rows: int) -> Array:
	var list: Array=[]
	if not ResourceLoader.exists(file):return list
	var image=load(file).get_image()
	for y in range(rows):
		for x in range(columns):
			var rect=Rect2i(int(x*image.get_width()/columns),int(y*image.get_height()/rows),int(image.get_width()/columns),int(image.get_height()/rows))
			var piece=image.get_region(rect)
			var used=piece.get_used_rect()
			if used.size.x>1 and used.size.y>1:piece=piece.get_region(used)
			list.append(ImageTexture.create_from_image(piece))
	return list

func _draw_building_motion(_e: Dictionary,_sp: Vector2,_width: float) -> void:
	# A generic floating fan cannot follow every building silhouette.
	pass

func _effect_sprite(index: int,point: Vector2,extent: float,angle: float=0.0,tint: Color=Color.WHITE) -> void:
	if effect_frames.size()!=16:return
	var tex: Texture2D=effect_frames[clampi(index,0,15)]
	var factor=extent/maxf(tex.get_width(),tex.get_height())
	_world_transform(point,angle,Vector2.ONE*factor)
	world_canvas.draw_texture(tex,-tex.get_size()*.5,tint)
	_world_transform(Vector2.ZERO)

var _shot_origins: Dictionary={}

func _weapon_tip(source: Dictionary,origin: Vector2,target: Vector2,shot_index: int=-1) -> Vector2:
	var ground=_ground_point(origin)
	if source.is_empty():return ground-Vector2(0,15*zoom)
	if source.has("progress"):
		var definition=ACData.building(int(source.race),int(source.kind))
		var heading=_iso(ACData.point(source.get("facing",ACData.packed(target-origin)))).normalized()
		var body=assets.sprites.building(int(source.race),int(source.kind),1,false,heading,0,0)
		var turret=assets.sprites.building_turret(int(source.race),int(source.kind),heading,0,0)
		var pose=turret if not turret.is_empty() else body
		if not pose.is_empty() and pose.has("muzzle"):
			var width=float(definition.w)*32*zoom
			var factor=width/maxf(1,float(body.scale_hint))
			var muzzle=Vector2(pose.muzzle)
			if pose.get("flip",false):muzzle.x=-muzzle.x
			return ground+Vector2(0,float(definition.h)*16*zoom)+body.get("mount",Vector2.ZERO)*factor+muzzle*width/maxf(1,float(pose.scale_hint))
		return ground-Vector2(0,float(definition.h)*12*zoom)+(target-origin).normalized()*16*zoom
	var definition=ACData.unit(int(source.race),int(source.kind))
	var direction=(target-origin).normalized()
	var heading=_visual_facing(source) if source.has("id") else direction
	var turret=_visual_facing(source,"turret_direction") if source.has("id") else direction
	var vehicle_action="idle";var vehicle_clock=0.0
	var layered=assets.sprites.units.get("%d:%d"%[source.race,source.kind],{})
	if layered.get("staged16",false) and (not source.get("moving",false) or _moving_fire_pose(source)):
		var age=float(state.time)-float(source.get("fired",-99))+(minf(visual_clock,visual_step) if not paused else 0.0)
		var duration=assets.sprites.action_length(int(source.race),int(source.kind),"attack")
		var window=minf(duration,maxf(.15,float(definition.period)*.9))
		if age>=0 and age<window:vehicle_action="attack";vehicle_clock=age*duration/maxf(.01,window)
	var vehicle=assets.vehicle(int(source.race),int(source.kind),_visual_facing(source,"body_direction") if source.has("id") else heading,turret,_deployment_progress(source),vehicle_action,vehicle_clock)
	var extent=float(definition.get("visual_extent",float(definition.size)*(62 if definition.air else 47)))*zoom
	if not vehicle.is_empty():
		var factor=extent/maxf(1,float(vehicle.chassis.scale_hint))
		var socket: Vector2=vehicle.muzzle
		if not vehicle.get("muzzles",[]).is_empty():socket=Vector2(vehicle.muzzles[posmod(maxi(0,shot_index),vehicle.muzzles.size())])
		return ground+vehicle.mount*factor+socket*factor*float(vehicle.turret_scale)
	var elevated=ground-Vector2(0,(22 if definition.air else 0)*zoom)
	var clock=float(source.get("action_clock",0))
	if definition.air and source.has("id"):
		clock=float(state.get("time",0))+minf(visual_clock,visual_step)+float(source.id)*.173
	# The painted firing pose restarts on each shot, including render
	# interpolation. Its source-bound mouth must sample that same pose.
	if layered.get("staged16",false) and vehicle_action=="attack":clock=vehicle_clock
	if definition.air and source.has("id") and not _uses_fixed_hull(source):
		elevated.y-=sin(clock*1.7)*1.8*zoom
		elevated.x+=sin(clock*.85)*.45*zoom
	# A moving aircraft may aim at a target while its hull still faces its
	# displacement. Register the socket against the body actually being drawn.
	var pose=assets.unit(int(source.race),int(source.kind),heading,"idle" if _uses_fixed_hull(source) else "attack",0.0 if _uses_fixed_hull(source) else clock)
	if not pose.is_empty() and pose.get("staged16",false) and not pose.get("muzzles",[]).is_empty():
		var sockets: Array=pose.muzzles
		var muzzle=Vector2(sockets[posmod(maxi(0,shot_index),sockets.size())])
		if pose.get("flip",false):muzzle.x=-muzzle.x
		return elevated+muzzle*extent/maxf(1,float(pose.scale_hint))
	if not pose.is_empty() and pose.get("staged16",false) and pose.has("muzzle"):
		var muzzle=Vector2(pose.muzzle)
		if pose.get("flip",false):muzzle.x=-muzzle.x
		return elevated+muzzle*extent/maxf(1,float(pose.scale_hint))
	var fire=assets.fire_pose(int(source.race),int(source.kind),heading,clock)
	if not fire.is_empty():return ground+fire.muzzle*extent/maxf(1,float(fire.scale_hint))
	if pose.is_empty():return elevated
	if pose.get("v062",false) and pose.has("muzzle"):
		var muzzle=Vector2(pose.muzzle)
		if pose.get("flip",false):muzzle.x=-muzzle.x
		return elevated+muzzle*extent/maxf(1,float(pose.scale_hint))
	var offset=ACWeaponSockets.local_offset(pose,int(source.race),int(source.kind),heading,shot_index)
	return elevated+offset*extent/maxf(1,float(pose.scale_hint))

func _death_is_ground(fx: Dictionary) -> bool:
	var profile=ACDeathVisual.profile(int(fx.get("race",0)),int(fx.get("kind",0)),bool(fx.get("source_building",false)))
	return str(fx.get("death_effect",profile.key)) in ["blood_ground","juice_ground"]

func _draw_death_body(fx: Dictionary) -> void:
	if fx.get("source_building",false):return
	var race=int(fx.get("race",0));var kind=int(fx.get("kind",0))
	var clip=assets.death_info(race,kind)
	var detonation=fx.get("body_action","")=="attack" and assets.sprites.units.get("%d:%d"%[race,kind],{}).get("staged16",false)
	if detonation:
		var attack_clip=assets.unit_action_info(race,kind,"attack")
		if attack_clip.is_empty():detonation=false
		else:clip=attack_clip
	if clip.is_empty():return
	var now=float(state.time)+(minf(visual_clock,visual_step) if not paused else 0.0)
	var age=maxf(0,now-float(fx.get("started",now)))
	var direction=_iso(ACData.point(fx.get("facing",[0,1]))).normalized()
	var pose=assets.unit(race,kind,direction,"attack",age) if detonation else assets.death_body(race,kind,direction,age)
	if pose.is_empty():return
	var definition=ACData.unit(race,kind)
	var length=float(clip.get("rows",clip.get("count",1)))/maxf(1,float(clip.get("fps",12)))
	# The consumed bomb shows its attack once; only the ground stain persists.
	var end=length+.15 if detonation else maxf(length+.15,float(fx.get("until",now))-float(fx.get("started",now)))
	var opacity=1-smoothstep(length,end,age)
	var point=_ground_point(ACData.point(fx.get("to",fx.get("pos",[0,0]))))-Vector2(0,22*zoom if definition.air else 0)
	_draw_unit_frame(pose,point,float(definition.get("visual_extent",float(definition.size)*(62 if definition.air else 47)))*zoom,Color(1,1,1,opacity))

func _draw_effect(fx: Dictionary) -> void:
	var now=float(state.time)+(minf(visual_clock,visual_step) if not paused else 0.0)
	var start=float(fx.get("started",now-.05))
	var duration=maxf(.05,float(fx.get("until",now+.1))-start)
	var progress=clampf((now-start)/duration,0,1)
	var a=_ground_point(ACData.point(fx.get("from",fx.get("pos",[0,0]))))
	var b=_ground_point(ACData.point(fx.get("to",fx.get("pos",[0,0]))))
	if not _world_render_rect().grow(80).has_point(a) and not _world_render_rect().grow(80).has_point(b):return
	var race=int(fx.get("race",0))
	var kind=str(fx.get("type","shot"))
	var frame=mini(3,int(progress*4))
	if kind=="skill" and not assets.sprites.effect_info(str(fx.get("skill","")).replace("_warning","")).is_empty():return
	if kind in ["nuclear_ascent","nuclear_descent"] and not assets.sprites.effect_info("warhead_ascent" if kind=="nuclear_ascent" else "warhead_descent").is_empty():return
	if kind=="death":
		var profile=ACDeathVisual.profile(race,int(fx.get("kind",0)),bool(fx.get("source_building",false)))
		var effect=death_visual.sample(str(fx.get("death_effect",profile.key)),now-start,duration)
		if not effect.is_empty():
			var point=b-Vector2(0,22*zoom if bool(fx.get("airborne",profile.airborne)) else 0)
			_draw_unit_frame(effect,point,float(fx.get("extent",90))*zoom,Color(1,1,1,float(effect.opacity)))
			return
	if kind=="nuclear_marker":
		world_canvas.draw_circle(b,maxf(1.5,2.5*zoom),Color(1,.08,.04,.8+.2*sin(now*8)),true,-1,true)
		return
	if kind in ["nuclear_ascent","nuclear_descent"]:
		var descending=kind=="nuclear_descent";var texture=assets.warhead_texture(descending,progress)
		if texture!=null:
			var position=b-Vector2((1-progress)*40 if descending else progress*20,(1-progress)*300 if descending else progress*300)*zoom
			var dimensions=Vector2(30*zoom,30*zoom*texture.get_height()/float(texture.get_width()))
			world_canvas.draw_texture_rect(texture,Rect2(position-dimensions*.5,dimensions),false)
		return
	if kind in ["skill","death"]:
		var key=str(fx.get("death_style","")) if kind=="death" else str(fx.get("skill","")).replace("_warning","")
		if key=="nuclear":return # A dedicated shader blends the long cloud animation.
		var texture=assets.skill_texture("nuclear_cloud" if key=="nuclear" else key,progress)
		if texture!=null:
			var width=(float(fx.get("radius",5))*2*32 if key in ["nuclear","sap_bloom"] else float(fx.get("extent",90)) if kind=="death" else 180 if key=="verdict" else 120 if key in ["smoke","discipline"] else 72)*zoom
			var dimensions=Vector2(width,width*texture.get_height()/float(texture.get_width()))
			var color=Color(1,1,1,1-smoothstep(.6,1.0,progress)) if kind=="death" and key in ["juice","blood"] else Color.WHITE
			world_canvas.draw_texture_rect(texture,Rect2(b-dimensions*Vector2(.5,.86 if key=="nuclear" else .5),dimensions),false,color)
		return
	if kind=="heal" or str(fx.get("projectile","")).begins_with("heal_"):
		_draw_heal_effect(fx,a,b,progress)
		return
	if kind=="shot":
		var source=_entity(int(fx.get("unit",-1)))
		if not source.is_empty() and not source.has("progress") and ACData.unit(int(source.race),int(source.kind)).role in ["medic","healer_detector"]:return
		var shot_id=int(fx.id)
		var origin=ACData.point(fx.get("from",[0,0]))
		if not _shot_origins.has(shot_id):
			if source.is_empty():
				source={"race":race,"kind":int(fx.get("kind",0)),"facing":ACData.packed((ACData.point(fx.to)-origin).normalized())}
				if fx.get("source_building",false):source.progress=1
			_shot_origins[shot_id]=(_weapon_tip(source,origin,ACData.point(fx.to),int(fx.get("barrel",-1)))-_ground_point(origin))/maxf(.01,zoom)
			if _shot_origins.size()>512:_shot_origins.erase(_shot_origins.keys()[0])
		a=_ground_point(origin)+_shot_origins[shot_id]*zoom
		var victim=_entity(int(fx.get("target",-1)))
		if not victim.is_empty() and not victim.has("progress"):b=_selection_center(victim)
		else:b.y-=12*zoom
		var p=a.lerp(b,progress)
		var style=str(fx.get("projectile","bullet"))
		if style=="flame" and not source.is_empty():
			origin=_visual_position(source);a=_weapon_tip(source,origin,ACData.point(fx.to))
			var axis=(b-a).normalized()
			b=a+axis*float(ACData.unit(int(source.race),int(source.kind)).range)*32*zoom
		var color=[Color("ffe19b"),Color("6bdbf4"),Color("ff697c")][race]
		if _draw_weapon_effect(style,a,b,progress,color,float(fx.get("damage",0))):return
		if race==1 and style not in ["bash","claw","slam","slash","blade","drill","vine"]:
			var citrus: Texture2D=assets.citrus_projectile(style,progress>.86)
			if citrus!=null:
				var width=(40 if progress>.86 else 26)*zoom
				var dimensions=Vector2(width,width*citrus.get_height()/float(citrus.get_width()))
				_world_transform(b if progress>.86 else p,0 if progress>.86 else (b-a).angle())
				world_canvas.draw_texture_rect(citrus,Rect2(-dimensions*.5,dimensions),false)
				_world_transform()
				return
		if style in ["bash","claw","slam","slash","blade","drill"]:
			_effect_sprite(8+frame if race==2 else frame,b,34*zoom,(b-a).angle())
		else:
			if progress<.4:_effect_sprite(frame,a,24*zoom,0,Color(color,.8))
			if style in ["laser","beam"]:
				world_canvas.draw_line(a,b,Color(color,(1-progress)*.7),2.5*zoom,true)
				_effect_sprite(8+frame if race==2 else 4+frame,b,27*zoom)
			else:
				world_canvas.draw_line(p-(b-a).normalized()*12*zoom,p,Color(color,.65),1.8*zoom,true)
				_effect_sprite(4+frame if race==1 else (8+frame if race==2 else frame),p,(18 if race==0 else 28)*zoom,(b-a).angle())
	elif kind=="harvest":
		_effect_sprite(12+frame,b-Vector2(0,7*zoom),23*zoom,0,[Color("ffe7ac"),Color("99f1ff"),Color("f7b8be")][race])
	elif kind=="explosion":_effect_sprite(frame if race!=2 else 8+frame,b,58*zoom*(.65+progress))
	elif kind=="warning":world_canvas.draw_arc(b,60*zoom,0,TAU,40,Color("ff6178"),2,true)
	elif kind=="deposit":
		_effect_sprite(12+frame,b-Vector2(0,18*zoom),21*zoom)
	elif kind in ["repair","construct"]:_effect_sprite(12+frame,b,17*zoom)

func _draw_weapon_effect(style: String,from: Vector2,to: Vector2,progress: float,tint: Color,damage: float) -> bool:
	var key={"shotgun":"bullet","cannon":"shell","bomb":"shell","laser":"beam","blade":"slash","drill":"spark","tool":"spark","slam":"bash","spore":"acid","spell":"bolt"}.get(style,style)
	var texture=assets.skill_texture("weapon_"+key,progress)
	if texture==null:return false
	var axis=(to-from).normalized();var angle=axis.angle()
	if key=="beam":
		var width=clampf(damage/8.0,1.5,4)*zoom
		world_canvas.draw_line(from,to,Color(tint,(1-progress)*.7),width*2,true)
		world_canvas.draw_line(from,to,Color(1,1,1,(1-progress)*.85),width*.65,true)
		_world_transform(to,angle);world_canvas.draw_texture_rect(texture,Rect2(Vector2(-20,-20)*zoom,Vector2(40,40)*zoom),false);_world_transform()
	elif key=="flame":
		texture=assets.skill_texture("weapon_flame",fposmod(elapsed*1.7,1.0))
		var length=maxf(24,from.distance_to(to))
		var height=length*texture.get_height()/float(texture.get_width())
		for side in [-1,1]:
			_world_transform(from+axis.orthogonal()*side*1.6*zoom,angle+side*.12)
			world_canvas.draw_texture_rect(texture,Rect2(0,-height*.5,length,height),false,Color(1,1,1,.86))
		_world_transform()
	elif key in ["claw","slash","bash","spark","vine"]:
		var width=(50 if key in ["bash","vine"] else 36)*zoom
		_world_transform(to,angle);world_canvas.draw_texture_rect(texture,Rect2(Vector2.ONE*-width*.5,Vector2.ONE*width),false);_world_transform()
	else:
		var impact=progress>=.86
		var phase=lerpf(.75,.999,inverse_lerp(.86,1,progress)) if impact else lerpf(.25,.749,fposmod(progress*4,1))
		texture=assets.skill_texture("weapon_"+key,phase)
		var width=(44 if impact and key in ["shell","missile","plasma"] else 30 if impact else 24)*zoom
		_world_transform(to if impact else from.lerp(to,progress),0 if impact else angle)
		world_canvas.draw_texture_rect(texture,Rect2(Vector2.ONE*-width*.5,Vector2.ONE*width),false);_world_transform()
		if progress<.2:
			var muzzle=assets.skill_texture("weapon_"+key,progress)
			_world_transform(from,angle);world_canvas.draw_texture_rect(muzzle,Rect2(Vector2(-14,-14)*zoom,Vector2(28,28)*zoom),false);_world_transform()
	return true

func _draw_heal_effect(fx: Dictionary,from: Vector2,to: Vector2,progress: float) -> void:
	var source=_entity(int(fx.get("unit",-1)))
	var patient=_entity(int(fx.get("target",-1)))
	if not source.is_empty() and not source.has("progress"):from=_ground_point(_visual_position(source))
	if not patient.is_empty() and not patient.has("progress"):to=_ground_point(_visual_position(patient))
	from-=Vector2(0,18*zoom)
	to-=Vector2(0,14*zoom)
	if not source.is_empty() and not source.has("progress") and assets.sprites.has_action(int(source.race),int(source.kind),"heal"):
		var pose=assets.unit(int(source.race),int(source.kind),_visual_facing(source),"heal",0)
		if pose.get("staged16",false) and pose.has("muzzle"):
			var origin=_visual_position(source)
			from=_weapon_tip(source,origin,origin+ACData.point(source.facing))
	var sap=str(fx.get("projectile",""))=="heal_sap"
	var shield=str(fx.get("projectile",""))=="shield"
	var tint=Color("bfe990") if sap else (Color("b2d5ff") if shield else Color("7dffd3"))
	var strength=sin(PI*clampf(progress,0,1))*.8
	if sap and not source.is_empty() and int(source.get("race",-1))==1 and int(source.get("kind",-1))==9:
		var texture=assets.skill_texture("sap_heal",progress)
		if texture!=null:world_canvas.draw_texture_rect(texture,Rect2(to-Vector2(24,30)*zoom,Vector2(48,48)*zoom),false)
	if not shield:
		world_canvas.draw_line(from,to,Color(tint,strength*.2),6*zoom,true)
		world_canvas.draw_line(from,to,Color(tint,strength),1.5*zoom,true)
		world_canvas.draw_circle(from.lerp(to,fposmod(progress*2,1)),2.2*zoom,Color(tint,strength))
	_world_transform(to,0,Vector2(1,.5))
	world_canvas.draw_arc(Vector2.ZERO,(8+progress*10)*zoom,0,TAU,24,Color(tint,strength*.7),1.4*zoom,true)
	_world_transform()

func _report_public_void() -> void:
	if remote_game.get("transport","")!="webrtc" or public_reported or (spectator and not remote_game.get("is_host",false)):return
	public_reported=true
	_api("/match/report",{"id":remote_game.id,"void":true},func(_data):pass)

func _report_public_result(winners: Array, duration: float) -> void:
	if remote_game.get("transport","")!="webrtc" or public_reported or (spectator and not remote_game.get("is_host",false)):return
	public_reported=true
	_api("/match/heartbeat",{"id":remote_game.id,"connected":true},func(_data):
		_api("/match/report",{"id":remote_game.id,"winners":winners,"duration":duration},func(_result):pass)
	)


