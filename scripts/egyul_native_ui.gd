class_name ACEgyulNativeUI
extends RefCounted

## Each approved PNG has one native logical size. No nine-slicing or alternate
## dimensions are used; controls reflow or scroll instead of stretching art.
const ROOT="res://assets/ui/egyul_native_20261024/"
const MAIN="button-320x76"
const ACTION="button-220x48"
const SELECT="button-220x48"
const SMALL="button-105x36"
const DIALOG="button-145x44"
const LARGE="board-1260x840"
const MEDIUM="board-1060x840"
const COMPACT="board-820x650"
const LOADING="board-760x300"
const SURRENDER="board-520x300"
static var textures: Dictionary={}

class Frame:
	extends Panel
	var art: Texture2D
	var art_id=""
	func configure(id: String) -> void:
		art_id=id;art=ACEgyulNativeUI.texture(id)
		name="NativeEgyulFrame";set_meta("native_art",id)
		custom_minimum_size=art.get_size();size=art.get_size()
		add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		mouse_filter=Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		if art==null:return
		if art_id in [ACEgyulNativeUI.LARGE,ACEgyulNativeUI.MEDIUM]:
			var backing=StyleBoxFlat.new();backing.bg_color=Color("101516");backing.set_corner_radius_all(60)
			draw_style_box(backing,Rect2(Vector2(90,100),art.get_size()-Vector2(180,200)))
		draw_texture(art,Vector2.ZERO)

static func texture(id: String) -> Texture2D:
	if not textures.has(id):textures[id]=load(ROOT+id+".png")
	return textures[id]

static func frame(id: String) -> Panel:
	var panel=Frame.new();panel.configure(id);return panel

static func board_id(extent: Vector2) -> String:
	if extent.x>1060:return LARGE
	if extent.y>710:return MEDIUM
	return COMPACT

static func plate(id: String,state="normal") -> StyleBoxTexture:
	var style=StyleBoxTexture.new();style.texture=texture(id)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,0);style.set_content_margin(side,0)
	style.modulate_color=Color(1.16,1.10,1.03) if state=="hover" else Color(.77,.68,.54) if state=="pressed" else Color(.52,.48,.40,.8) if state=="disabled" else Color.WHITE
	return style

static func button(control: BaseButton,id=ACTION) -> void:
	var extent=texture(id).get_size()
	control.set_meta("native_art",id);control.custom_minimum_size=extent;control.size=extent
	control.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;control.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	for state in ["normal","hover","pressed","disabled"]:control.add_theme_stylebox_override(state,plate(id,state))
	control.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	control.add_theme_font_size_override("font_size",20 if id==MAIN else 13 if id==SMALL else 16)
	control.add_theme_color_override("font_color",Color("ebd2a0"));control.add_theme_color_override("font_hover_color",Color("fff1c8"))
	control.add_theme_color_override("font_pressed_color",Color("e0bf82"));control.add_theme_color_override("font_disabled_color",Color("9a8f79"))
	control.add_theme_color_override("font_shadow_color",Color(0,0,0,.9));control.add_theme_constant_override("shadow_offset_y",1)
	if control is Button:control.clip_text=true
	if control is OptionButton:
		control.fit_to_longest_item=false
		control.alignment=HORIZONTAL_ALIGNMENT_CENTER
		for state in ["normal","hover","pressed","disabled","hover_pressed"]:
			var inset=plate(id,"pressed" if state=="hover_pressed" else state)
			inset.content_margin_left=12 if id==SMALL else 24;inset.content_margin_right=20 if id==SMALL else 32
			control.add_theme_stylebox_override(state,inset)
		control.add_theme_constant_override("arrow_margin",14)
		control.get_popup().theme=matching_theme(control.theme if control.theme!=null else Theme.new())
	# Re-apply after replacing the old theme/font, whose cached minimum can
	# otherwise leave an initially larger control at its previous dimensions.
	control.size=extent
	control.set_deferred("size",extent)

static func matching_theme(original: Theme) -> Theme:
	var theme=original.duplicate()
	var panel=StyleBoxFlat.new();panel.bg_color=Color("101817");panel.border_color=Color("91672f");panel.set_border_width_all(1);panel.set_corner_radius_all(5)
	panel.content_margin_left=12;panel.content_margin_right=12;panel.content_margin_top=8;panel.content_margin_bottom=8
	for type in ["LineEdit","TextEdit","ItemList","Tree","PopupMenu"]:
		for state in ["normal","panel"]:theme.set_stylebox(state,type,panel)
		theme.set_color("font_color",type,Color("e6d6b4"))
	var hover=panel.duplicate();hover.bg_color=Color("49402b");theme.set_stylebox("hover","PopupMenu",hover)
	for type in ["Label","CheckButton","CheckBox"]:theme.set_color("font_color",type,Color("e6d6b4"))
	return theme
