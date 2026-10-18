class_name ACHubMenu
extends Control

## Backgrounds are cosmetic: menu entry never changes the next match's race/map.
const NAV_NAMES := ["싱글플레이","멀티플레이","리플레이","환경 설정","게임 종료"]
const NAV_TIPS := ["컴퓨터와 전투합니다.","커스텀 방 또는 래더에 입장합니다.","저장한 전투를 다시 봅니다.","화면·음향·조작을 설정합니다.","아스테라크래프트를 종료합니다."]
const BUTTON_WIDTH := 320.0
const BUTTON_HEIGHT := 76.0
static var _plate_cache: Dictionary = {}
static var _background_cache: Dictionary = {}

var main: Control
var art: Texture2D
var font: Font
var background_index := 0
var nav_buttons: Array[Button] = []
var button_plates: Array[Texture2D] = []
var button_art_path := ""
var _last_size := Vector2.ZERO
var title_art: Texture2D
var _shade: GradientTexture2D

func configure(controller: Control) -> void:
	main=controller
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	font=get_theme_default_font()
	var gradient=Gradient.new()
	gradient.colors=PackedColorArray([Color(.008,.013,.018,.86),Color(.008,.013,.018,0)])
	_shade=GradientTexture2D.new()
	_shade.gradient=gradient
	_shade.width=256
	_shade.height=1
	_shade.fill_from=Vector2.ZERO
	_shade.fill_to=Vector2.RIGHT
	if ResourceLoader.exists("res://assets/title_logo_correct.png"):
		var logo=load("res://assets/title_logo_correct.png").get_image()
		title_art=ImageTexture.create_from_image(logo.get_region(logo.get_used_rect()))
	choose_background()
	_load_button_art()
	_build_navigation()
	_layout()
	set_process(true)
	queue_redraw()

func choose_background(index: int=-1) -> void:
	var preferences=main.get("settings") if main!=null else {}
	var remembered=int(preferences.get("last_played_race",0)) if preferences is Dictionary else 0
	background_index=clampi(remembered if index<0 else index,0,2)
	var path="res://assets/menu_planet_%d_wide_v05.png"%background_index
	if background_index==1:path="res://assets/menu_planet_1_roots_v058.png"
	art=null
	if ResourceLoader.exists(path):
		if not _background_cache.has(path):_background_cache[path]=load(path)
		art=_background_cache[path]
	elif ResourceLoader.exists("res://assets/menu_hub.png"):art=load("res://assets/menu_hub.png")
	main.menu_backdrop=art
	if not nav_buttons.is_empty():_refresh_button_styles()
	queue_redraw()

func _load_button_art() -> void:
	button_art_path="res://assets/ui_native/main_"
	button_plates.clear()
	if _plate_cache.has(button_art_path):
		button_plates.assign(_plate_cache[button_art_path])
		return
	for faction in range(3):
		for state_name in ["normal","hover","pressed"]:
			var path="res://assets/ui_native/main_r%d_%s.png"%[faction,state_name]
			if not ResourceLoader.exists(path):
				button_plates.clear()
				return
			var texture: Texture2D=load(path)
			if texture.get_size()!=Vector2(BUTTON_WIDTH,BUTTON_HEIGHT):
				push_error("Native main button size mismatch: "+path)
				button_plates.clear()
				return
			button_plates.append(texture)
	_plate_cache[button_art_path]=button_plates.duplicate()

func _build_navigation() -> void:
	for index in range(NAV_NAMES.size()):
		var button=Button.new()
		button.name="Navigation%d"%index
		button.text=NAV_NAMES[index]
		button.tooltip_text=""
		button.add_theme_font_size_override("font_size",22)
		button.add_theme_color_override("font_color",Color("d9c99b"))
		button.add_theme_color_override("font_hover_color",Color("fff0bd"))
		button.add_theme_color_override("font_pressed_color",Color("b7a775"))
		button.add_theme_color_override("font_focus_color",Color("fff0bd"))
		button.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
		button.add_theme_constant_override("shadow_offset_x",1)
		button.add_theme_constant_override("shadow_offset_y",2)
		var action_index=index
		button.pressed.connect(func():activate(action_index))
		button.mouse_entered.connect(func():_play_ui("select"))
		add_child(button)
		nav_buttons.append(button)
	_refresh_button_styles()

func _refresh_button_styles() -> void:
	for button in nav_buttons:
		button.add_theme_stylebox_override("normal",_button_style(0))
		button.add_theme_stylebox_override("hover",_button_style(1))
		button.add_theme_stylebox_override("pressed",_button_style(2))
		button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func _button_style(state_index: int) -> StyleBox:
	if button_plates.size()==9:
		var style=StyleBoxTexture.new()
		style.texture=button_plates[background_index*3+state_index]
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,0)
		style.content_margin_left=0
		style.content_margin_right=0
		style.content_margin_top=0
		style.content_margin_bottom=0
		return style
	var style=StyleBoxFlat.new()
	style.bg_color=[Color("17201e"),Color("2d3426"),Color("0c120f")][state_index]
	style.border_color=Color("a58e4d").lightened(.25 if state_index==1 else 0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.shadow_color=Color(0,0,0,.65)
	style.shadow_size=5
	style.shadow_offset=Vector2(0,4)
	return style

func activate(index: int) -> void:
	if index<0 or index>=NAV_NAMES.size():return
	_play_ui("confirm")
	match index:
		0:main._single_menu()
		1:main._online_menu()
		2:main._replay_menu()
		3:main._settings_menu()
		4:
			if main.has_method("_quit_game"):main.call("_quit_game")
			else:get_tree().quit()

func _play_ui(cue: String) -> void:
	var audio=main.get("audio")
	if audio!=null:audio.play_ui(cue)

func _layout() -> void:
	var top=clampf(size.y*.30,238,290)
	var spacing=86.0
	if top+4*spacing+BUTTON_HEIGHT>size.y-60:
		spacing=maxf(60,(size.y-60-top-BUTTON_HEIGHT)/4)
	for index in range(nav_buttons.size()):
		nav_buttons[index].position=Vector2(58,top+index*spacing)
		nav_buttons[index].size=Vector2(BUTTON_WIDTH,BUTTON_HEIGHT)
	_last_size=size
	queue_redraw()

func _process(_dt: float) -> void:
	if size!=_last_size:_layout()

func _draw() -> void:
	if art!=null:
		var factor=maxf(size.x/art.get_width(),size.y/art.get_height())
		var sample=size/factor
		draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),Rect2((art.get_size()-sample)*.5,sample))
	else:draw_rect(Rect2(Vector2.ZERO,size),Color("0b1018"))
	# A local shade leaves the architecture and planet on the right unobscured.
	var shade_width=minf(650,size.x*.48)
	if _shade!=null:draw_texture_rect(_shade,Rect2(0,0,shade_width,size.y),false)
	if title_art!=null:
		var factor=minf(348.0/title_art.get_width(),175.0/title_art.get_height())
		var title_size=title_art.get_size()*factor
		draw_texture_rect(title_art,Rect2(Vector2(48+(348-title_size.x)*.5,46+(175-title_size.y)*.5),title_size),false)
	else:
		draw_string(font,Vector2(62,130),"ASTERA CRAFT",HORIZONTAL_ALIGNMENT_LEFT,-1,36,Color("e1d9c5"))
	draw_line(Vector2(63,229),Vector2(359,229),Color(.62,.65,.64,.45),1)
	draw_string(font,Vector2(63,size.y-39),"v%s  ·  ASTERA CRAFT"%str(ACData.get_data().version),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a6a695"))
