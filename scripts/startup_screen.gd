extends Control
## Publisher -> title with real preparation progress -> an already-ready hub.
signal start_requested

const LOGO_IN := .25
const LOGO_HOLD := 1.35
const LOGO_OUT := .9
const BLACK_GAP := .15
const TITLE_IN := .8
const TITLE_AT := LOGO_IN+LOGO_HOLD+LOGO_OUT+BLACK_GAP
const PROMPT := "아무 버튼이나 입력해서 시작"
const MAIN_PATH := "res://main.tscn"

var clock := 0.0
var leaving := false
var navigate_on_start := true
var publisher: Texture2D
var backdrop: Texture2D
var wordmark: Texture2D
var prompt_font: Font
var audio: ACAudio
var ready_to_start=false
var preparation_progress=0.0
var preparation_caption="메인 화면 불러오는 중"
var prepared_main: Control
var _main_scene: PackedScene
var _finishing_preparation=false
var _preparation_error=false
var _skip_intro=false

func _ready() -> void:
	var preferences=ACSettings.load_file()
	ACSettings.apply_display(preferences)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var args=OS.get_cmdline_user_args()
	if "--battle-config" in args or "--test-client" in args or "--smoke-game" in args or "--capture-menu" in args or "--skip-intro" in args:
		_skip_intro=true
		_enter_main.call_deferred();return
	publisher=load("res://assets/startup/zipza_games_original_20261024.png")
	backdrop=load("res://assets/startup/title_three_factions_approved_20261024.png")
	var image=load("res://assets/title_logo_correct.png").get_image()
	wordmark=ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
	prompt_font=preload("res://scripts/ui_font.gd").create()
	audio=ACAudio.acquire(self)
	audio.set_channel_volumes(float(preferences.music_volume),float(preferences.voice_volume),float(preferences.sfx_volume))
	audio.set_music_context(-1,.15)
	load("res://scripts/game_updater.gd").confirm_booted()
	if ResourceLoader.load_threaded_request(MAIN_PATH)!=OK:
		_preparation_error=true;preparation_caption="메인 화면을 불러오지 못했습니다"
	queue_redraw()

func _process(delta: float) -> void:
	clock+=delta
	_poll_preparation()
	queue_redraw()

func _poll_preparation() -> void:
	if ready_to_start or _preparation_error or _skip_intro:return
	if is_instance_valid(prepared_main):
		preparation_progress=maxf(preparation_progress,.15+float(prepared_main.startup_progress)*.83)
		preparation_caption=prepared_main.startup_caption
		if prepared_main.startup_ready and not _finishing_preparation:
			_finishing_preparation=true;_finish_preparation()
		return
	if _main_scene==null:
		var progress=[]
		var status=ResourceLoader.load_threaded_get_status(MAIN_PATH,progress)
		if not progress.is_empty():preparation_progress=maxf(preparation_progress,float(progress[0])*.15)
		if status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_preparation_error=true;preparation_caption="메인 화면을 불러오지 못했습니다";return
		if status!=ResourceLoader.THREAD_LOAD_LOADED:return
		_main_scene=ResourceLoader.load_threaded_get(MAIN_PATH)
	# Keep the logo/fade responsive. Heavy image preparation begins only once
	# the title and its loading indicator have actually been presented.
	if title_alpha()<.99:return
	prepared_main=_main_scene.instantiate()
	prepared_main.startup_preparation=true
	prepared_main.process_mode=Node.PROCESS_MODE_DISABLED
	prepared_main.hide()
	add_child(prepared_main)
	prepared_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _finish_preparation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(prepared_main) or not prepared_main.startup_ready:return
	preparation_progress=1.0;preparation_caption="준비 완료";ready_to_start=true
	queue_redraw()

func prompt_visible() -> bool:
	return ready_to_start and title_alpha()>=.99

func loading_bar_rect() -> Rect2:
	return Rect2(size*Vector2(.32,.944),size*Vector2(.36,.008))

func title_alpha() -> float:
	return smoothstep(TITLE_AT,TITLE_AT+TITLE_IN,clock)

func publisher_alpha() -> float:
	return minf(smoothstep(0,LOGO_IN,clock),1-smoothstep(LOGO_IN+LOGO_HOLD,LOGO_IN+LOGO_HOLD+LOGO_OUT,clock))

func _fit(texture: Texture2D,area: Rect2) -> Rect2:
	var extent=texture.get_size()*minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	return Rect2(area.get_center()-extent*.5,extent)

func wordmark_rect() -> Rect2:
	return _fit(wordmark,Rect2(size*Vector2(.29,.025),size*Vector2(.42,.29)))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
	if publisher==null:return
	var mark_alpha=publisher_alpha()
	if mark_alpha>0:
		draw_texture_rect(publisher,_fit(publisher,Rect2(size*Vector2(.20,.16),size*Vector2(.60,.68))),false,Color(1,1,1,mark_alpha))
	var alpha=title_alpha()
	if alpha<=0:return
	# Contain preserves all three factions at unusual aspect ratios.
	draw_texture_rect(backdrop,_fit(backdrop,Rect2(Vector2.ZERO,size)),false,Color(1,1,1,alpha))
	draw_texture_rect(wordmark,wordmark_rect(),false,Color(1,1,1,alpha))
	var font_size=clampi(roundi(size.y*.027),16,30)
	var text=PROMPT if ready_to_start else preparation_caption+" · %d%%"%mini(99,floori(preparation_progress*100))
	var baseline=Vector2((size.x-prompt_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)*.5,size.y*(.945 if ready_to_start else .927))
	var pulse=.86+.14*sin(maxf(0,clock-TITLE_AT)*2.0)
	# The approved backdrop remains untouched: no dark plate behind the text.
	draw_string_outline(prompt_font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(0,0,0,alpha*.65))
	draw_string(prompt_font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1,1,1,alpha*(pulse if ready_to_start else 1.0)))
	if not ready_to_start:
		var bar=loading_bar_rect()
		draw_rect(bar,Color(1,.9,.68,alpha*.55),false,1)
		var fill=bar.grow(-2);fill.size.x*=preparation_progress
		if fill.size.x>0:draw_rect(fill,Color(1,.78,.36,alpha))

func _input(event: InputEvent) -> void:
	if leaving:return
	var pressed=(event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		if prompt_visible():_enter_main.call_deferred()

func _enter_main() -> void:
	if leaving:return
	if not _skip_intro and not ready_to_start:return
	leaving=true
	start_requested.emit()
	if navigate_on_start:
		if is_instance_valid(audio) and audio.get_parent()==self:audio.reparent(get_tree().root)
		if is_instance_valid(prepared_main) and prepared_main.startup_ready:
			# No file load, instantiation, asset preparation or menu construction
			# occurs on the accepted input. Activate the retained ready instance.
			prepared_main.reparent(get_tree().root)
			prepared_main.process_mode=Node.PROCESS_MODE_INHERIT
			prepared_main.show()
			get_tree().current_scene=prepared_main
			queue_free()
		else:get_tree().change_scene_to_file(MAIN_PATH)
