class_name ACLoadingScreen
extends Control
signal cancel_requested

var background: Texture2D
var board: Panel
var title: Label
var subtitle: Label
var phase: Label
var percent: Label
var bar: ProgressBar
var cancel_button: Button
var race=0
var _last_size=Vector2.ZERO
static var _last_art: Dictionary={}
var background_path=""

func configure(faction: int,map_id: int) -> void:
	race=clampi(faction,0,2)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var path="res://assets/menu_planet_%d_wide_v05.png"%race
	if race==1:path="res://assets/menu_planet_1_roots_v058.png"
	var catalog_path="res://data/loading_art_20261024.json"
	if FileAccess.file_exists(catalog_path):
		var catalog=JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		var choices=[]
		for item in catalog.get("images",[]):
			if int(item.race)==race and bool(item.get("approved",false)) and ResourceLoader.exists(str(item.file)):choices.append(str(item.file))
		if not choices.is_empty():
			var previous=str(_last_art.get(race,""));var candidates=choices.filter(func(value):return value!=previous)
			path=choices[0] if candidates.is_empty() else candidates.pick_random()
			_last_art[race]=path
	background_path=path
	background=load(path)
	if race==1:board=ACEgyulNativeUI.frame(ACEgyulNativeUI.LOADING)
	else:board=Panel.new();board.add_theme_stylebox_override("panel",ACRaceUI.board_style(race))
	add_child(board)
	title=_label(ACData.get_data().race_names[race],25,ACRaceUI.ACCENTS[race])
	subtitle=_label(ACLobbyMapPreview.map_names()[clampi(map_id,0,2)]+" · 전장 진입",17,Color("c5c8c6"))
	phase=_label("전장 준비 중",17,Color("deded7"))
	percent=_label("0%",20,ACRaceUI.ACCENTS[race]);percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	bar=ProgressBar.new();bar.show_percentage=false;bar.max_value=100
	var empty=StyleBoxFlat.new();empty.bg_color=Color("0b1319");empty.border_color=ACRaceUI.ACCENTS[race].darkened(.55);empty.set_border_width_all(1);empty.set_corner_radius_all(5)
	var fill=StyleBoxFlat.new();fill.bg_color=ACRaceUI.ACCENTS[race];fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background",empty);bar.add_theme_stylebox_override("fill",fill);board.add_child(bar)
	cancel_button=Button.new();cancel_button.text="연결 취소";cancel_button.hide();ACRaceUI.style_button(cancel_button,race);cancel_button.pressed.connect(func():cancel_requested.emit());add_child(cancel_button)
	_layout()

func _label(text: String,font_size: int,color: Color) -> Label:
	var label=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);board.add_child(label);return label

func set_progress(value: float,text: String) -> void:
	bar.value=clampf(value,0,1)*100;percent.text="%d%%"%floori(bar.value);phase.text=text

func _layout() -> void:
	if board==null:return
	board.size=Vector2(760 if race==1 else minf(760,size.x-60),300)
	board.position=Vector2((size.x-board.size.x)*.5,maxf(30,size.y*.70-board.size.y*.5))
	# Keep all text and the bar inside the artwork's thick inner frame.
	title.position=Vector2(84,64);title.size=Vector2(board.size.x-168,34)
	subtitle.position=Vector2(84,107);subtitle.size=Vector2(board.size.x-168,28)
	phase.position=Vector2(84,160);phase.size=Vector2(board.size.x-284,28)
	percent.position=Vector2(board.size.x-184,151);percent.size=Vector2(100,38)
	bar.position=Vector2(84,204);bar.size=Vector2(board.size.x-168,18)
	var cancel_width=220 if race==1 else 180
	cancel_button.size=Vector2(cancel_width,44);cancel_button.position=Vector2((size.x-cancel_width)*.5,minf(size.y-56,board.position.y+board.size.y+18))
	_last_size=size;queue_redraw()

func _process(_dt: float) -> void:
	if size!=_last_size:_layout()

func _draw() -> void:
	if background!=null:
		var scale=maxf(size.x/background.get_width(),size.y/background.get_height())
		var extent=background.get_size()*scale
		draw_texture_rect(background,Rect2((size-extent)*.5,extent),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(.005,.01,.016,.35))
