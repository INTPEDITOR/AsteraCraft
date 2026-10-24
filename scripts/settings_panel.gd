class_name ACSettingsPanel
extends Control

var controller: Control
var pages
var controls: Dictionary = {}
var resolution_values: Array = []

func configure(main: Control, page_builder, back: Callable) -> void:
	controller = main
	pages = page_builder
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(810,610)
	pages.label(self,"화면 모드",0,300,18)
	pages.label(self,"창 해상도",0,220,18,340)
	var selected_mode := ACSettings.WINDOW_MODES.find(str(main.settings.window_mode))
	controls.window_mode = pages.option(self,["창 모드","전체 화면","테두리 없는 창"],0,38,300,maxi(0,selected_mode),func(index):
		controller._set_setting("window_mode",ACSettings.WINDOW_MODES[index])
		_update_resolution_availability()
	)
	resolution_values = ACSettings.RESOLUTIONS.duplicate(true)
	var current = main.settings.resolution
	if current not in resolution_values:
		resolution_values.append(current.duplicate())
	var labels: Array = []
	for resolution in resolution_values:
		labels.append("%d × %d" % [resolution[0],resolution[1]])
	controls.resolution = pages.option(self,labels,340,38,220,resolution_values.find(current),func(index):controller._set_setting("resolution",resolution_values[index].duplicate()))
	pages.label(self,"모든 화면 모드에서 게임 화면은 16:9를 유지합니다.",91,760,15)
	var edge := CheckButton.new()
	edge.name = "EdgeScroll"
	edge.text = "가장자리 화면 이동"
	edge.position = Vector2(0,143)
	edge.size = Vector2(245,42)
	edge.button_pressed = bool(main.settings.edge_scroll)
	edge.toggled.connect(func(value):controller._set_setting("edge_scroll",value);_sound("confirm"))
	add_child(edge)
	controls.edge_scroll = edge
	pages.label(self,"화면 이동 감도",193,200,18)
	_add_slider("edge_scroll_speed",Vector2(225,198),.25,2.5,.05,float(main.settings.edge_scroll_speed),true)
	pages.label(self,"음량",251,300,23)
	_add_volume("music_volume","음악",298)
	_add_volume("voice_volume","대사",356)
	_add_volume("sfx_volume","효과음",414)
	pages.button(self,"확인",0,530,220,back,48)
	_update_resolution_availability()

func _add_volume(key: String, title: String, y: float) -> void:
	pages.label(self,title,y-6,145,19)
	_add_slider(key,Vector2(165,y),0,1,.01,float(controller.settings[key]),false)

func _add_slider(key: String, position_value: Vector2, minimum: float, maximum: float, step_value: float, value: float, speed: bool) -> void:
	var slider := HSlider.new()
	slider.name = key
	slider.position = position_value
	slider.size = Vector2(455 if speed else 515,30)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value = value
	add_child(slider)
	var number = pages.label(self,"",position_value.y-6,95,18,position_value.x+slider.size.x+18)
	var update := func(amount):number.text="%.2f×" % amount if speed else "%d%%" % roundi(amount*100.0)
	update.call(value)
	slider.value_changed.connect(func(amount):controller._set_setting(key,amount);update.call(amount))
	slider.drag_ended.connect(func(_changed):_sound("confirm"))
	controls[key] = slider

func _update_resolution_availability() -> void:
	if controls.has("resolution"):
		controls.resolution.disabled = str(controller.settings.window_mode)!="windowed"

func _sound(cue: String) -> void:
	if controller.audio!=null:
		controller.audio.play_ui(cue)
