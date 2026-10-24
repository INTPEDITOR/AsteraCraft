class_name ACCenteredButtonCaption
extends Control

## Centre the visible glyphs on the painted plate, independently of the
## OptionButton's arrow reservation and the font's asymmetric line metrics.
var button: Button
var line: TextLine
var ink:=Rect2()
var baseline:=Vector2.ZERO
var font: Font
var arrow: Texture2D
var icon: Texture2D
var icon_position:=Vector2.ZERO
var colours: Dictionary={}
var _key=""

static func apply(control: Button) -> void:
	var existing=control.get_node_or_null("CentredCaption")
	var caption=existing as ACCenteredButtonCaption if existing!=null else ACCenteredButtonCaption.new()
	caption.button=control
	caption.name="CentredCaption";caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color","font_focus_color"]:
		var colour=control.get_theme_color(state)
		if colour.a>0:caption.colours[state]=colour
		control.add_theme_color_override(state,Color.TRANSPARENT)
	control.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	control.add_theme_color_override("font_outline_color",Color.TRANSPARENT)
	for colour_name in ["icon_normal_color","icon_focus_color","icon_hover_color","icon_pressed_color","icon_hover_pressed_color","icon_disabled_color"]:
		control.add_theme_color_override(colour_name,Color.TRANSPARENT)
	if control is OptionButton:
		if caption.arrow==null:caption.arrow=control.get_theme_icon("arrow")
		var clear=Image.create(1,1,false,Image.FORMAT_RGBA8)
		control.add_theme_icon_override("arrow",ImageTexture.create_from_image(clear))
	if existing==null:control.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption._rebuild()

func _process(_dt: float) -> void:
	_rebuild();queue_redraw()

func _rebuild() -> void:
	var text=button.text;var font_size=button.get_theme_font_size("font_size")
	var current_font=button.get_theme_font("font")
	var selected_icon=button.get_item_icon(button.selected) if button is OptionButton and button.selected>=0 else button.icon
	var key=text+str(font_size)+str(button.size)+str(current_font.get_instance_id())+str(selected_icon.get_instance_id() if selected_icon!=null else 0)
	if key==_key:return
	_key=key;font=current_font;icon=selected_icon;line=TextLine.new()
	line.add_string(text,font,font_size)
	var ts=TextServerManager.get_primary_interface();var pen=Vector2.ZERO
	var found=false;ink=Rect2()
	for glyph in ts.shaped_text_get_glyphs(line.get_rid()):
		for repeat_index in range(glyph.repeat):
			if glyph.font_rid.is_valid():
				var pixels=Vector2i(glyph.font_size,0)
				ts.font_render_glyph(glyph.font_rid,pixels,glyph.index)
				var extent=ts.font_get_glyph_size(glyph.font_rid,pixels,glyph.index)
				if extent.x>0 and extent.y>0:
					var bounds=Rect2(pen+glyph.offset+ts.font_get_glyph_offset(glyph.font_rid,pixels,glyph.index),extent)
					ink=ink.merge(bounds) if found else bounds;found=true
			pen.x+=glyph.advance
	var centre=size*.5
	if icon!=null:
		var icon_size=icon.get_size();var start=(size.x-icon_size.x-6-ink.size.x)*.5
		icon_position=Vector2(start,(size.y-icon_size.y)*.5).round()
		centre.x=start+icon_size.x+6+ink.size.x*.5
	baseline=(centre-ink.get_center()).round()
	set_meta("visible_text_rect",Rect2(baseline+ink.position,ink.size))

func _draw() -> void:
	if line==null:return
	var state="font_color"
	if button.disabled:state="font_disabled_color"
	elif button.is_pressed():state="font_pressed_color"
	elif button.is_hovered():state="font_hover_color"
	var colour: Color=colours.get(state,Color("e8d2a0"))
	# TextLine.draw expects the line top; glyph bounds above use its baseline.
	line.draw(get_canvas_item(),baseline-Vector2(0,line.get_line_ascent()),colour)
	if icon!=null:draw_texture(icon,icon_position,Color(1,1,1,.5) if button.disabled else Color.WHITE)
	if arrow!=null:
		var margin=button.get_theme_constant("arrow_margin")
		draw_texture(arrow,Vector2(size.x-margin-arrow.get_width(),(size.y-arrow.get_height())*.5).round(),colour)
