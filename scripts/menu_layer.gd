class_name ACMenuLayer
extends Control

signal closed

var content: Control
var board: NinePatchRect
var heading: Label
var close_button: Button
var controller: Control
var wanted_size=Vector2(1050,720)
var _last_size=Vector2.ZERO
static var _board_art: Dictionary={}
static var _native_plates: Dictionary={}
var button_race=0
var board_art_path=""

func configure(main: Control,title: String,extent: Vector2) -> void:
	controller=main
	wanted_size=extent
	button_race=clampi(int(main.settings.get("last_played_race",0)),0,2)
	name="MenuModal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil=ColorRect.new()
	veil.color=Color(0,0,0,.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(veil)
	board=NinePatchRect.new()
	board.mouse_filter=Control.MOUSE_FILTER_STOP
	var art="res://assets/modal_board_r%d_v3.png"%button_race
	if not ResourceLoader.exists(art):art="res://assets/modal_board_v3.png"
	board_art_path=art
	if ResourceLoader.exists(art):
		if not _board_art.has(art):
			var source=load(art).get_image()
			if art!="res://assets/modal_board_v3.png" and source.get_size()==Vector2i(1536,1024):
				var regions=[Rect2i(16,70,1504,860),Rect2i(8,18,1520,974),Rect2i(24,28,1488,952)]
				source=source.get_region(regions[button_race])
				# Board artwork can scale uniformly; its corners then stay under 110px.
				source.resize(int(source.get_width()*.5),int(source.get_height()*.5),Image.INTERPOLATE_LANCZOS)
			var left=source.get_width()
			var top=source.get_height()
			var right=0
			var bottom=0
			for y in range(0,source.get_height(),2):
				for x in range(0,source.get_width(),2):
					if source.get_pixel(x,y).a>.75:
						left=mini(left,x);top=mini(top,y);right=maxi(right,x);bottom=maxi(bottom,y)
			var bounds=Rect2i(Vector2i(maxi(0,left-3),maxi(0,top-3)),Vector2i(mini(source.get_width()-left,right-left+7),mini(source.get_height()-top,bottom-top+7)))
			_board_art[art]=ImageTexture.create_from_image(source.get_region(bounds))
		board.texture=_board_art[art]
		board.patch_margin_left=110
		board.patch_margin_right=110
		board.patch_margin_top=110
		board.patch_margin_bottom=110
	else:
		var fallback=Panel.new()
		var plate=StyleBoxFlat.new()
		plate.bg_color=Color("101b21")
		plate.border_color=Color("a38a4c")
		plate.set_border_width_all(5)
		plate.set_corner_radius_all(12)
		plate.shadow_color=Color(0,0,0,.75)
		plate.shadow_size=20
		fallback.add_theme_stylebox_override("panel",plate)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		board.add_child(fallback)
	add_child(board)
	heading=Label.new()
	heading.text=title
	heading.position=Vector2(130,80)
	heading.add_theme_font_size_override("font_size",29)
	heading.add_theme_color_override("font_color",Color("dfc583"))
	board.add_child(heading)
	close_button=Button.new()
	close_button.text="×"
	close_button.size=Vector2(44,42)
	close_button.add_theme_font_size_override("font_size",28)
	for state in ["normal","hover","pressed","focus"]:close_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close_button.pressed.connect(func():closed.emit())
	board.add_child(close_button)
	content=Control.new()
	content.position=Vector2(75,140)
	content.mouse_filter=Control.MOUSE_FILTER_PASS
	board.add_child(content)
	var matching=main.theme.duplicate()
	for state in ["normal","hover","pressed","disabled","focus"]:
		matching.set_stylebox(state,"CheckButton",StyleBoxEmpty.new())
	theme=matching
	_layout()
	set_process(true)

func style_control(control: BaseButton,extent: Vector2) -> void:
	control.size=extent
	for state_name in ["normal","hover","pressed"]:
		var path="res://assets/ui_native/modal_%dx%d_r%d_%s.png"%[int(extent.x),int(extent.y),button_race,state_name]
		var style: StyleBox
		if ResourceLoader.exists(path):
			if not _native_plates.has(path):_native_plates[path]=load(path)
			var texture_style=StyleBoxTexture.new()
			texture_style.texture=_native_plates[path]
			# Artwork is produced at this exact control size; no slicing or stretching.
			texture_style.set_texture_margin(SIDE_LEFT,0)
			texture_style.set_texture_margin(SIDE_RIGHT,0)
			texture_style.set_texture_margin(SIDE_TOP,0)
			texture_style.set_texture_margin(SIDE_BOTTOM,0)
			style=texture_style
		else:
			var fallback=StyleBoxFlat.new()
			fallback.bg_color=Color("182129")
			fallback.border_color=Color("a38a4c")
			fallback.set_border_width_all(2)
			style=fallback
		style.content_margin_left=32
		style.content_margin_right=32
		style.content_margin_top=7
		style.content_margin_bottom=7
		control.add_theme_stylebox_override(state_name,style)
	var disabled=control.get_theme_stylebox("normal").duplicate()
	if disabled is StyleBoxTexture:disabled.modulate_color=Color(.45,.45,.45,.8)
	control.add_theme_stylebox_override("disabled",disabled)
	control.add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func _layout() -> void:
	board.size=wanted_size.min(size-Vector2(50,50))
	board.position=(size-board.size)*.5
	content.size=board.size-Vector2(150,215)
	heading.size=Vector2(board.size.x-320,48)
	close_button.position=Vector2(board.size.x-170,80)
	_last_size=size

func _process(_dt: float) -> void:
	if size!=_last_size:_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
