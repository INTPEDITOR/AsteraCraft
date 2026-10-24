extends Control
## Lightweight boot scene: publisher mark -> approved title -> existing hub.
signal start_requested

const LOGO_IN := .25
const LOGO_HOLD := 1.35
const LOGO_OUT := .9
const BLACK_GAP := .15
const TITLE_IN := .8
const TITLE_AT := LOGO_IN+LOGO_HOLD+LOGO_OUT+BLACK_GAP
const PROMPT := "아무 버튼이나 입력해서 시작"

var clock := 0.0
var leaving := false
var navigate_on_start := true
var publisher: Texture2D
var backdrop: Texture2D
var wordmark: Texture2D
var prompt_font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var args=OS.get_cmdline_user_args()
	if "--battle-config" in args or "--test-client" in args or "--smoke-game" in args or "--capture-menu" in args or "--skip-intro" in args:
		_enter_main.call_deferred();return
	publisher=load("res://assets/startup/zipza_games_original_20261024.png")
	backdrop=load("res://assets/startup/title_three_factions_approved_20261024.png")
	var image=load("res://assets/title_logo_correct.png").get_image()
	wordmark=ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
	prompt_font=preload("res://scripts/ui_font.gd").create()
	load("res://scripts/game_updater.gd").confirm_booted()
	queue_redraw()

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

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
	var baseline=Vector2((size.x-prompt_font.get_string_size(PROMPT,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)*.5,size.y*.945)
	var pulse=.86+.14*sin(maxf(0,clock-TITLE_AT)*2.0)
	draw_rect(Rect2(size*Vector2(.24,.901),size*Vector2(.52,.068)),Color(0,0,0,alpha*.38))
	draw_string(prompt_font,baseline,PROMPT,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1,1,1,alpha*pulse))

func _input(event: InputEvent) -> void:
	if leaving:return
	var pressed=(event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		if title_alpha()>=.99:_enter_main.call_deferred()

func _enter_main() -> void:
	if leaving:return
	leaving=true
	start_requested.emit()
	if navigate_on_start:
		get_tree().change_scene_to_file("res://main.tscn")
