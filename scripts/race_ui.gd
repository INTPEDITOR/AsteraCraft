class_name ACRaceUI
extends RefCounted

const ACCENTS=[Color("e7bf65"),Color("dda35c"),Color("a9d9ee")]
static var boards: Dictionary={}

static func board_style(race: int) -> StyleBoxTexture:
	if race==1:
		var native=ACEgyulNativeUI.plate(ACEgyulNativeUI.SURRENDER)
		native.content_margin_left=84;native.content_margin_right=84;native.content_margin_top=64;native.content_margin_bottom=72
		return native
	if not boards.has(race):
		var image=load("res://assets/modal_board_r%d_v3.png"%race).get_image()
		var regions=[Rect2i(16,70,1504,860),Rect2i(8,18,1520,974),Rect2i(24,28,1488,952)]
		image=image.get_region(regions[race]);image.resize(image.get_width()/2,image.get_height()/2,Image.INTERPOLATE_LANCZOS)
		boards[race]=ImageTexture.create_from_image(image)
	var style=StyleBoxTexture.new();style.texture=boards[race]
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,76)
	style.content_margin_left=84;style.content_margin_right=84
	style.content_margin_top=84;style.content_margin_bottom=78
	return style

static func style_button(button: Button,race: int) -> void:
	if race==1:ACEgyulNativeUI.button(button);return
	for state in ["normal","hover","pressed"]:
		var style=StyleBoxTexture.new()
		style.texture=load("res://assets/ui_native/modal_220x48_r%d_%s.png"%[race,state])
		style.set_texture_margin(SIDE_LEFT,35);style.set_texture_margin(SIDE_RIGHT,35)
		style.set_texture_margin(SIDE_TOP,12);style.set_texture_margin(SIDE_BOTTOM,12)
		style.content_margin_left=0;style.content_margin_right=0
		style.content_margin_top=0;style.content_margin_bottom=0
		button.add_theme_stylebox_override(state,style)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",ACCENTS[race].lightened(.2))
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	button.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	button.add_theme_constant_override("shadow_offset_y",1)
	button.add_theme_font_size_override("font_size",15)
