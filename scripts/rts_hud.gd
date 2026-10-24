class_name ACRtsHUD
extends Control

## The battle HUD deliberately owns no simulation state. It reads snapshots and
## submits exactly the same authoritative commands as the world input code.
const HEIGHT := 256.0
const MAX_SELECTION := 12
const ICON_MOVE := 0
const ICON_ATTACK := 1
const ICON_STOP := 2
const ICON_HOLD := 3
const ICON_BUILD := 4
const ICON_GATHER := 5
const ICON_REPAIR := 6
const ICON_ABILITY := 7
const ICON_UNLOAD := 8
const ICON_CANCEL := 9
const ICON_RESEARCH := 10
const ICON_TRAIN := 11
const ICON_AS := 12
const ICON_TERA := 13
const ICON_POP := 14
const ICON_RALLY := 15
const PAGE_KEYS := [KEY_Q,KEY_W,KEY_E,KEY_R,KEY_A,KEY_S,KEY_D,KEY_F,KEY_Z]
const PAGE_KEY_NAMES := ["Q","W","E","R","A","S","D","F","Z"]
const PRODUCTION_KEYS := [KEY_Q,KEY_W,KEY_E,KEY_T,KEY_A,KEY_S,KEY_D,KEY_F,KEY_Z]
const PRODUCTION_KEY_NAMES := ["Q","W","E","T","A","S","D","F","Z"]
const SYMBOL_COLOR := Color("b6a252")
const SELECTION_SIZE := Vector2(125,28)
const BUILD_ORDERS := [
	[0,1,2,3,4,5,6,7,8,9,10,11,12],
	[0,1,2,4,6,7,5,8,9,3,12,10,11],
	[0,1,2,3,4,5,6,10,7,8,9,11,12]
]
const BUILD_ROLES := ["본부","테라 채취","보급","기초 보병","중형 지상","공중","전투 연구","지원","고급 해금","종족 특화","종족 특화","지상 방어","대공 · 탐지"]

class SegmentedMeter extends Control:
	var value := 0.0
	var max_value := 1.0
	var fill_color := Color("8bbf64")
	var fixed_segments := 0
	func set_values(current: float,total: float,color: Color) -> void:
		value=maxf(0,current)
		max_value=maxf(1,total)
		fill_color=color
		queue_redraw()
	func segment_count() -> int:
		var requested=fixed_segments if fixed_segments>0 else ceili(max_value/20.0)
		return clampi(requested,1,maxi(1,mini(24,int(size.x/3))))
	func _draw() -> void:
		var count=segment_count()
		var cell_width=(size.x-count+1)/count
		var filled=clampf(value/max_value,0,1)*count
		for index in range(count):
			var cell=Rect2(index*(cell_width+1),0,cell_width,size.y)
			draw_rect(cell,Color("26312b"))
			var amount=clampf(filled-index,0,1)
			if amount>0:draw_rect(Rect2(cell.position,Vector2(cell.size.x*amount,cell.size.y)),fill_color)

class ShellMenuCaption extends Control:
	func _draw() -> void:
		var font=get_theme_default_font()
		var font_size=clampi(roundi(size.y*.40),10,12)
		draw_string(font,Vector2(0,(size.y+font.get_ascent(font_size)-font.get_descent(font_size))*.5),"메뉴",HORIZONTAL_ALIGNMENT_CENTER,size.x,font_size,Color("dddcd3"))

class ShellHotkey extends Control:
	var caption=""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.045,.04,.8))
		draw_string(get_theme_default_font(),Vector2(0,10),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x,9,Color("c7b776"))

class PortraitCanvas extends Control:
	var texture: Texture2D
	func _draw() -> void:
		if texture==null:return
		draw_rect(Rect2(Vector2.ZERO,size),Color("080909"))
		var area=Rect2(Vector2.ONE,size-Vector2.ONE*2)
		var source_size=texture.get_size()
		var scale=maxf(area.size.x/source_size.x,area.size.y/source_size.y)
		var crop=area.size/scale
		draw_texture_rect_region(texture,area,Rect2((source_size-crop)*.5,crop))

var main: Control
var race := 0
var accent := Color("dfb64d")
var portraits: Dictionary = {}
var building_portraits: Array[Texture2D] = []
var armor_upgrade_icon: Texture2D
var icons: Array[Texture2D] = []
var command_art=ACCommandIcons.new()
var resource_icons: Array[Texture2D] = []
var action_buttons: Array[Button] = []
var action_specs: Array[Dictionary] = []
var selection_buttons: Array[Button] = []
var queue_buttons: Array[Button] = []
var icon_cache: Dictionary = {}
var selection_layer: Control
var action_layer: Control
var detail_layer: Control
var queue_layer: Control
var production_meter: SegmentedMeter
var energy_label: Label
var menu_button: Button
var surrender_panel: PanelContainer
var surrender_caption: Label
var surrender_bot=-1
var menu_art: Array[Texture2D]=[]
var title_label: Label
var subtitle_label: Label
var name_label: Label
var detail_label: Label
var description_label: Label
var status_label: Label
var timer_label: Label
var resources: Array[Label] = []
var resource_symbols: Array[TextureRect] = []
var signature := ""
var command_page := 0
var hover_hotkeys: Dictionary = {}
var _unit: Dictionary = {}
var _resource: Dictionary = {}
var _definition: Dictionary = {}
var _portrait: Texture2D
var _portrait_canvas: PortraitCanvas
var _unit_icon: Texture2D
var _current_drone_icon: Texture2D
var _font: Font
var _has_build_panel := false
var _last_size := Vector2.ZERO
var _symbol_material: ShaderMaterial
var _cargo_material: ShaderMaterial
var _frame_art: Array[Texture2D] = []
var _frame_slices: Dictionary={}
var _frame_source_regions: Array[Rect2i] = []
var _uniform_shells: Array[bool] = []
var _complete_shells: Array[bool] = []
const COMMON_SHELL={"crop":Rect2i(0,0,1963,330),"mini":Rect2(64,62,218,218),"detail":Rect2(362,90,826,190),"menu":Rect2(1254,42,166,27),"portrait":Rect2(1263,104,148,178),"command":Rect2(1490,66,416,228),"cols":[1490,1600,1710,1820],"rows":[66,150,234],"slot":Vector2(86,60)}
var _native_shell_geometry: Dictionary = {
	1:{"crop":Rect2i(10,237,1963,330),"mini":Rect2(98,308,210,216),"detail":Rect2(394,344,818,176),"menu":Rect2(1276,300,38,24),"portrait":Rect2(1280,348,148,178),"command":Rect2(1498,324,398,213),"cols":[1498,1604,1710,1816],"rows":[324,402,481],"slot":Vector2(80,56)},
	2:{"crop":Rect2i(15,218,1954,341),"mini":Rect2(120,295,220,210),"detail":Rect2(405,296,748,208),"menu":Rect2(1220,283,36,20),"portrait":Rect2(1218,327,150,180),"command":Rect2(1435,296,422,206),"cols":[1435,1546,1658,1769],"rows":[296,371,446],"slot":Vector2(88,56)}
}
var _frame_body_profiles: Array[PackedInt32Array] = []
var _body_materials: Array[Texture2D] = []
var _body_outline:=PackedVector2Array()
var _body_uvs:=PackedVector2Array()
var _body_outline_key=""
var _menu_caption: ShellMenuCaption
var _hover_help: Dictionary={}
var upgrade_layer: Control
var upgrade_badges: Array[Button]=[]

func configure(controller: Control) -> void:
	main=controller
	if not main.state.is_empty():race=int(main.state.players[main.local_slot].race)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_font=get_theme_default_font()
	_load_art()
	_build_controls()
	_portrait_canvas=PortraitCanvas.new()
	_portrait_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_canvas)
	_build_surrender_prompt()
	update_hud(true)

func _build_surrender_prompt() -> void:
	surrender_panel=PanelContainer.new();surrender_panel.hide();add_child(surrender_panel)
	surrender_panel.add_theme_stylebox_override("panel",ACRaceUI.board_style(race))
	if race==1:surrender_panel.custom_minimum_size=Vector2(520,300)
	var column=VBoxContainer.new();surrender_panel.add_child(column)
	column.add_theme_constant_override("separation",8)
	var heading=Label.new();heading.text="항복 요청";heading.add_theme_font_size_override("font_size",18)
	heading.add_theme_color_override("font_color",ACRaceUI.ACCENTS[race]);column.add_child(heading)
	surrender_caption=Label.new();column.add_child(surrender_caption)
	surrender_caption.add_theme_font_size_override("font_size",16)
	surrender_caption.custom_minimum_size.x=280
	surrender_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var row=HBoxContainer.new();column.add_child(row)
	if race==1:row.alignment=BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",12)
	for accept in [true,false]:
		var button=Button.new();button.text="승인" if accept else "거절";button.custom_minimum_size=Vector2(150,52);button.focus_mode=Control.FOCUS_NONE
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ACRaceUI.style_button(button,race)
		if race==1:ACEgyulNativeUI.button(button,ACEgyulNativeUI.DIALOG)
		button.custom_minimum_size=Vector2(145,44);button.size=Vector2(145,44);button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		var decision=accept
		button.pressed.connect(func():
			if surrender_bot>=0:main._send_command({"type":"surrender_response","bot":surrender_bot,"accept":decision}))
		row.add_child(button)

func _update_surrender_prompt() -> void:
	if surrender_panel==null:return
	var requests: Array=main.state.get("surrender_requests",[])
	surrender_bot=-1
	for request in requests:
		if int(request.recipient)==main.local_slot:surrender_bot=int(request.bot);break
	surrender_panel.visible=surrender_bot>=0 and not main.state.get("ended",false)
	if not surrender_panel.visible:return
	var player: Dictionary=main.state.players[surrender_bot]
	surrender_caption.text="%s의 항복을 받아들이시겠습니까?"%str(player.get("name","컴퓨터")).left(20)
	surrender_panel.reset_size()
	var mini=_minimap_frame_rect()
	var x=clampf(mini.position.x,12,maxf(12,size.x-surrender_panel.size.x-12))
	var top=size.y
	# Decorations rise well above the minimap aperture; clear their silhouette.
	for sample in range(int(x),int(x+surrender_panel.size.x)+1,2):top=minf(top,body_top_at(sample))
	surrender_panel.position=Vector2(x,maxf(44,top-surrender_panel.size.y-24))

func _process(_dt: float) -> void:
	if main==null or _portrait_canvas==null:return
	var showing=main.page=="game" and not main.state.is_empty()
	_portrait_canvas.visible=showing
	if not showing:return
	# Reflow the command buttons in the same frame as the shell on resize,
	# including paused battles, instead of waiting for the .2s snapshot refresh.
	if size!=_last_size:update_hud(true)
	var texture=_portrait
	var area=_portrait_rect()
	if _portrait_canvas.position!=area.position:_portrait_canvas.position=area.position
	if _portrait_canvas.size!=area.size:_portrait_canvas.size=area.size;_portrait_canvas.queue_redraw()
	if _portrait_canvas.texture!=texture:
		_portrait_canvas.texture=texture
		_portrait_canvas.queue_redraw()

func _load_art() -> void:
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 symbol_color : source_color = vec4(0.713725, 0.635294, 0.321569, 1.0);
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() { COLOR = vec4(symbol_color.rgb, texture(TEXTURE, UV).a * symbol_color.a) * vertex_tint; }
"""
	_symbol_material=ShaderMaterial.new()
	_symbol_material.shader=shader
	_symbol_material.set_shader_parameter("symbol_color",SYMBOL_COLOR)
	_cargo_material=ShaderMaterial.new();_cargo_material.shader=shader
	_cargo_material.set_shader_parameter("symbol_color",Color("829ba6"))
	for faction in range(3):
		var portrait_path="res://assets/portraits_%d_faces_v059.png"%faction
		var revised="res://assets/portraits_%d_faces_v060.png"%faction
		var safe_portrait=ResourceLoader.exists(revised)
		if safe_portrait:portrait_path=revised
		if ResourceLoader.exists(portrait_path):
			var sheet: Texture2D=load(portrait_path)
			for kind in range(14 if faction==1 else ACData.unit_count(faction)):
				var atlas=AtlasTexture.new()
				atlas.atlas=sheet
				atlas.region=Rect2(Vector2(kind%4,int(kind/4))*sheet.get_size()/4,sheet.get_size()/4)
				# Citrus source sheet has painted separators at its cell edges.
				atlas.region=atlas.region.grow(-3)
				var face=Rect2(.05,.03,.90,.90)
				if faction==1:
					face=[Rect2(.13,.04,.78,.78),Rect2(.28,.01,.70,.70),Rect2(.12,.05,.85,.85),Rect2(.15,.03,.82,.82),Rect2(.18,.08,.80,.80),Rect2(.36,.13,.62,.62),Rect2(.18,.22,.78,.78),Rect2(.30,.10,.68,.68),Rect2(.15,.17,.78,.78),Rect2(.27,.02,.70,.70),Rect2(.24,.19,.74,.74),Rect2(.16,.15,.82,.82),Rect2(.22,.20,.65,.65),Rect2(.12,.09,.82,.82)][kind]
				elif faction==0 and kind in [5,6]:face=Rect2(.22,.02,.74,.74)
				elif faction==2 and kind in [1,2,5,7]:face=Rect2(.25,.02,.73,.73)
				if not safe_portrait:atlas.region=Rect2(atlas.region.position+face.position*atlas.region.size,face.size*atlas.region.size)
				atlas.filter_clip=true
				portraits["%d:%d"%[faction,kind]]=atlas
	if ResourceLoader.exists("res://assets/building_portraits_v4.png"):
		var source: Texture2D=load("res://assets/building_portraits_v4.png")
		for faction in range(3):
			var portrait=AtlasTexture.new()
			portrait.atlas=source
			portrait.region=Rect2(faction*source.get_width()/3.0,0,source.get_width()/3.0,source.get_height())
			# Frame the face, not the chest; retain the original art and aspect.
			var face=[Rect2(.08,.06,.83,.52),Rect2(.08,.12,.84,.55),Rect2(.09,.08,.84,.52)][faction]
			portrait.region=Rect2(portrait.region.position+face.position*portrait.region.size,face.size*portrait.region.size)
			portrait.filter_clip=true
			building_portraits.append(portrait)
	if building_portraits.size()==3 and ResourceLoader.exists("res://assets/building_portrait_citrus_v4.png"):building_portraits[1]=load("res://assets/building_portrait_citrus_v4.png")
	if building_portraits.size()==3 and ResourceLoader.exists("res://assets/building_portrait_citrus_game_v4.png"):building_portraits[1]=load("res://assets/building_portrait_citrus_game_v4.png")
	if building_portraits.size()==3:
		var citrus=AtlasTexture.new()
		citrus.atlas=building_portraits[1]
		citrus.region=Rect2(citrus.atlas.get_size()*Vector2(.11,.23),citrus.atlas.get_size()*Vector2(.79,.55))
		citrus.filter_clip=true
		building_portraits[1]=citrus
	if ResourceLoader.exists("res://assets/armor_upgrade_v4.png"):
		var armor_pixels=load("res://assets/armor_upgrade_v4.png").get_image()
		var bounds=_button_region(armor_pixels)
		armor_upgrade_icon=ImageTexture.create_from_image(armor_pixels.get_region(bounds) if bounds.has_area() else armor_pixels)
	if ResourceLoader.exists("res://assets/menu_buttons_v051.png"):
		var pixels=load("res://assets/menu_buttons_v051.png").get_image()
		for band in [Rect2i(26,43,2120,291),Rect2i(27,365,2119,310)]:
			menu_art.append(ImageTexture.create_from_image(pixels.get_region(band)))
	var icon_path="res://assets/ui_icons_v05.png"
	if ResourceLoader.exists(icon_path):
		var sheet: Texture2D=load(icon_path)
		# Generated art is not a uniform 4x4 grid. Measured rectangles exclude
		# neighbours; independent textures cannot sample/repeat the whole atlas.
		var regions=[Rect2i(48,25,250,283),Rect2i(325,10,290,300),Rect2i(650,10,286,300),Rect2i(940,10,310,300),Rect2i(14,320,324,298),Rect2i(358,315,282,310),Rect2i(650,325,290,295),Rect2i(982,320,240,302),Rect2i(10,630,321,286),Rect2i(334,625,288,290),Rect2i(647,632,282,288),Rect2i(942,630,292,288),Rect2i(24,930,296,304),Rect2i(372,922,185,310),Rect2i(587,934,389,300),Rect2i(979,916,263,328)]
		var pixels=sheet.get_image()
		for region in regions:
			var scaled=Rect2i(Vector2(region.position)*sheet.get_size()/1263.0,Vector2(region.size)*sheet.get_size()/1263.0)
			icons.append(ImageTexture.create_from_image(pixels.get_region(scaled)))
	var resource_path="res://assets/resource_icons_v3.png"
	if ResourceLoader.exists(resource_path):
		var source=load(resource_path).get_image()
		for region in _resource_regions(source):
			var cell=source.get_region(region)
			var bounds=_button_region(cell)
			if bounds.has_area():cell=cell.get_region(bounds)
			resource_icons.append(ImageTexture.create_from_image(cell))
	var material_path="res://assets/hud_materials_v3.png"
	if ResourceLoader.exists(material_path):
		var sheet: Texture2D=load(material_path)
		var material_pixels=sheet.get_image()
		for band in [Vector2i(6,326),Vector2i(338,662),Vector2i(674,1018)]:
			_body_materials.append(ImageTexture.create_from_image(material_pixels.get_region(Rect2i(0,band.x,sheet.get_width(),band.y-band.x))))
	for faction in range(3):
		var path="res://assets/ui_hud_%d.png"%faction
		var native_path="res://assets/ui_hud_%d_native_v3.png"%faction
		if ResourceLoader.exists("res://assets/ui_hud_%d_native_v060.png"%faction):native_path="res://assets/ui_hud_%d_native_v060.png"%faction
		if faction==0 and ResourceLoader.exists("res://assets/ui_hud_0_native_v060.png"):
			native_path="res://assets/ui_hud_0_native_v060.png"
			_native_shell_geometry[0]=_native_shell_geometry[1].duplicate(true)
		var complete=ResourceLoader.exists("res://assets/ui_hud_%d_complete_v060.png"%faction)
		_complete_shells.append(complete)
		if complete:
			native_path="res://assets/ui_hud_%d_complete_v060.png"%faction
			_native_shell_geometry[faction]=COMMON_SHELL.duplicate(true)
			if faction==1 and ResourceLoader.exists("res://assets/ui/hud_citrus_top_restored_20261024.png"):
				native_path="res://assets/ui/hud_citrus_top_restored_20261024.png"
				_native_shell_geometry[faction].crop=Rect2i(0,0,1963,360)
				for bay in ["mini","detail","menu","portrait","command"]:
					_native_shell_geometry[faction][bay].position.y+=30
				for row in range(3):_native_shell_geometry[faction].rows[row]+=30
			if faction==1 and ResourceLoader.exists("res://assets/ui/hud_citrus_wood_new_20261024.png"):
				native_path="res://assets/ui/hud_citrus_wood_new_20261024.png"
				# Measured dark openings in newly authored art. Keep the previous
				# displayed height and nearly identical centers, with safe padding.
				_native_shell_geometry[faction]={"crop":Rect2i(0,135,2001,405),"display_height":360.0/1963.0,"mini":Rect2(55,243,244,233),"detail":Rect2(355,264,868,211),"menu":Rect2(1280,224,171,28),"portrait":Rect2(1277,276,176,204),"command":Rect2(1512,245,435,243),"cols":[1517,1631,1744,1856],"rows":[250,337,423],"slot":Vector2(86,60)}
			if faction==1 and ResourceLoader.exists("res://assets/ui/egyul_hud_living_common_20261024.png"):
				native_path="res://assets/ui/egyul_hud_living_common_20261024.png"
				_native_shell_geometry[faction]=COMMON_SHELL.duplicate(true)
				_frame_slices[faction]=living_egyul_slices()
				# Measure the approved art's actual dark openings, then keep the
				# same bay sizes as the other two races around these true centres.
				_native_shell_geometry[faction].mini=Rect2(72,62,218,218)
				_native_shell_geometry[faction].portrait=Rect2(1270,107,148,178)
				_native_shell_geometry[faction].menu=Rect2(1262,51,166,27)
				_native_shell_geometry[faction].cols=[1501,1606,1711,1817]
				_native_shell_geometry[faction].rows=[75,158,234]
		var native=_native_shell_geometry.has(faction) and ResourceLoader.exists(native_path)
		if native:path=native_path
		_frame_art.append(load(path) if ResourceLoader.exists(path) else null)
		_uniform_shells.append(native)
		var legacy_region=[Rect2i(0,200,1983,417),Rect2i(0,128,1983,502),Rect2i(0,110,1904,509)][faction]
		_frame_source_regions.append(_native_shell_geometry[faction].crop if native else legacy_region)
		_frame_body_profiles.append(_make_sliced_body_profile(_frame_art[faction],_frame_slices[faction]) if _frame_slices.has(faction) else _make_body_profile(_frame_art[faction],_frame_source_regions[faction]))

static func living_egyul_slices() -> Array:
	# Fit decorative margins to the common layout without editing source pixels.
	return [{"source":Rect2(0,134,2170,98),"target":Rect2(0,0,1963,62)},{"source":Rect2(0,232,2170,234),"target":Rect2(0,62,1963,218)},{"source":Rect2(0,466,2170,102),"target":Rect2(0,280,1963,50)}]

func _make_sliced_body_profile(texture: Texture2D,slices: Array) -> PackedInt32Array:
	var profile=PackedInt32Array();profile.resize(1963);profile.fill(-1)
	var image=texture.get_image()
	for x in range(1963):
		for slice in slices:
			var source: Rect2=slice.source;var target: Rect2=slice.target
			var column=clampi(int((x+.5)/1963.0*source.size.x),0,image.get_width()-1)
			for y in range(int(source.position.y),int(source.end.y)):
				if image.get_pixel(column,y).a>.5:
					profile[x]=roundi(target.position.y+(y-source.position.y)/source.size.y*target.size.y);break
			if profile[x]>=0:break
	return _complete_body_profile(profile,330)

func _make_body_profile(texture: Texture2D,crop: Rect2i) -> PackedInt32Array:
	var profile=PackedInt32Array()
	profile.resize(crop.size.x)
	profile.fill(-1)
	if texture!=null:
		var source=texture.get_image()
		for x in range(crop.size.x):
			for y in range(crop.size.y):
				if source.get_pixel(crop.position.x+x,crop.position.y+y).a>.5:
					profile[x]=y
					break
	return _complete_body_profile(profile,crop.size.y)

func _complete_body_profile(profile: PackedInt32Array,height: int) -> PackedInt32Array:
	# Some source canvases have empty edge columns. Continue the nearest frame
	# edge downward rather than leaving cracks along the bottom or screen sides.
	var previous=-1
	for x in range(profile.size()):
		if profile[x]>=0:previous=profile[x]
		elif previous>=0:profile[x]=previous
	var following=height-1
	for x in range(profile.size()-1,-1,-1):
		if profile[x]>=0:following=profile[x]
		else:profile[x]=following
	return profile

func _update_body_outline() -> void:
	var key="%d:%s"%[race,str(size)]
	if key==_body_outline_key:return
	_body_outline_key=key
	_body_outline.clear()
	if _frame_body_profiles.size()!=3 or size.x<=0:return
	var profile=_frame_body_profiles[race]
	var area=shell_draw_rect()
	var scale_x=area.size.x/profile.size()
	var scale_y=area.size.y/_frame_source_regions[race].size.y
	var bottom=area.position.y
	var previous=bottom+profile[0]*scale_y
	_body_outline.append(Vector2(0,previous))
	for x in range(1,profile.size()):
		var next=bottom+profile[x]*scale_y
		if not is_equal_approx(previous,next):
			_body_outline.append(Vector2(x*scale_x,previous))
			_body_outline.append(Vector2(x*scale_x,next))
			previous=next
	_body_outline.append(Vector2(size.x,previous))
	_body_outline.append(size)
	_body_outline.append(Vector2(0,size.y))
	_body_uvs.clear()
	if _body_materials.size()==3:
		var material_size=_body_materials[race].get_size()*(size.x/_body_materials[race].get_width())
		for point in _body_outline:_body_uvs.append((point-area.position)/material_size)

func body_top_at(screen_x: float) -> float:
	if _frame_body_profiles.size()!=3 or size.x<=0:return size.y-HEIGHT
	var profile=_frame_body_profiles[race]
	var column=clampi(int(floor(screen_x/size.x*profile.size())),0,profile.size()-1)
	var area=shell_draw_rect()
	return area.position.y+float(profile[column])*area.size.y/_frame_source_regions[race].size.y

func blocks_world_input(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO,size).has_point(point):return false
	if point.y<42:return point.x>=size.x-470
	if point.y<shell_draw_rect().position.y:return false
	return point.y>=body_top_at(point.x)

func _button_region(source: Image) -> Rect2i:
	# A neighboring plate may just touch a cell boundary. Choose the longest
	# solid band rather than including that neighboring plate or soft shadows.
	var best_start=0
	var best_length=0
	var start=-1
	for y in range(source.get_height()+1):
		var count=0
		if y<source.get_height():
			for x in range(0,source.get_width(),4):
				if source.get_pixel(x,y).a>.5:count+=1
		if count>3:
			if start<0:start=y
		elif start>=0:
			if y-start>best_length:best_start=start;best_length=y-start
			start=-1
	if best_length<=0:return source.get_used_rect()
	var left=source.get_width()
	var right=-1
	for y in range(best_start,best_start+best_length,2):
		for x in range(source.get_width()):
			if source.get_pixel(x,y).a>.5:left=mini(left,x);right=maxi(right,x)
	if right<left:return source.get_used_rect()
	left=maxi(0,left-3)
	right=mini(source.get_width()-1,right+3)
	var top=maxi(0,best_start-3)
	var bottom=mini(source.get_height(),best_start+best_length+3)
	return Rect2i(left,top,right-left+1,bottom-top)

func _resource_regions(source: Image) -> Array[Rect2i]:
	# Generated objects can cross equal-cell boundaries by a few pixels. Locate
	# the three isolated silhouettes so a helmet edge cannot enter the vial icon.
	var bands: Array[Vector2i]=[]
	var start=-1
	for x in range(source.get_width()+1):
		var count=0
		if x<source.get_width():
			for y in range(0,source.get_height(),4):
				if source.get_pixel(x,y).a>.15:count+=1
		if count>3:
			if start<0:start=x
		elif start>=0:
			if x-start>source.get_width()*.05:bands.append(Vector2i(start,x))
			start=-1
	var regions: Array[Rect2i]=[]
	if bands.size()==3:
		for band in bands:
			var left=maxi(0,band.x-3)
			var right=mini(source.get_width(),band.y+3)
			regions.append(Rect2i(left,0,right-left,source.get_height()))
	else:
		for index in range(3):
			var x0=int(source.get_width()*index/3)
			var x1=int(source.get_width()*(index+1)/3)
			regions.append(Rect2i(x0,0,x1-x0,source.get_height()))
	return regions

func _build_controls() -> void:
	selection_layer=Control.new()
	selection_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(selection_layer)
	action_layer=Control.new()
	action_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(action_layer)
	title_label=_label("",18)
	subtitle_label=_label("12기 선택 제한",11)
	title_label.hide()
	subtitle_label.hide()
	name_label=_label("",22)
	detail_label=_label("",15)
	description_label=_label("",13)
	description_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_layer=Control.new()
	detail_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_layer.clip_contents=true
	add_child(detail_layer)
	for label in [name_label,detail_label,description_label]:label.reparent(detail_layer)
	queue_layer=Control.new()
	queue_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(queue_layer)
	upgrade_layer=Control.new()
	upgrade_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(upgrade_layer)
	production_meter=SegmentedMeter.new()
	production_meter.fixed_segments=20
	production_meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_layer.add_child(production_meter)
	production_meter.hide()
	energy_label=_label("",10)
	energy_label.reparent(detail_layer)
	energy_label.hide()
	status_label=_label("",17)
	status_label.add_theme_color_override("font_color",Color("ffda8e"))
	timer_label=_label("",14)
	for i in range(3):
		resources.append(_label("0",20))
		resources[i].clip_text=true
		resources[i].vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		resources[i].add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
		resources[i].add_theme_constant_override("shadow_offset_x",1)
		resources[i].add_theme_constant_override("shadow_offset_y",2)
		var symbol=TextureRect.new()
		symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.texture=_resource_icon(i)
		# Dedicated resource art already uses the brass palette. Preserve its
		# generated highlights and depth; only the legacy fallback needs tinting.
		symbol.material=null if resource_icons.size()==3 else _symbol_material
		symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(symbol)
		resource_symbols.append(symbol)
	menu_button=Button.new()
	menu_button.focus_mode=Control.FOCUS_NONE
	menu_button.clip_contents=true
	menu_button.pressed.connect(func():_play_ui("confirm");main._pause_menu())
	_set_inline_help(menu_button,"메뉴 [Esc]","전투 메뉴를 엽니다.")
	add_child(menu_button)
	_menu_caption=ShellMenuCaption.new()
	_menu_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(_menu_caption)
	_layout()

func _label(text: String,font_size: int) -> Label:
	var label=Label.new()
	label.text=text
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e5e9e5"))
	add_child(label)
	return label

func _layout() -> void:
	if main==null:return
	_update_body_outline()
	var bottom=shell_draw_rect().position.y
	var content=_detail_content_rect()
	detail_layer.position=content.position
	detail_layer.size=content.size
	name_label.position=Vector2(4,2)
	name_label.size=Vector2(content.size.x-8,26)
	name_label.add_theme_font_size_override("font_size",17)
	detail_label.position=Vector2(100,27)
	detail_label.size=Vector2(content.size.x-104,content.size.y-27)
	detail_label.add_theme_font_size_override("font_size",13)
	detail_label.add_theme_constant_override("line_spacing",-2)
	description_label.position=Vector2(4,content.size.y-20)
	description_label.size=Vector2(content.size.x,20)
	description_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	description_label.clip_text=true
	description_label.add_theme_font_size_override("font_size",11)
	energy_label.position=Vector2(4,content.size.y-18)
	energy_label.size=Vector2(84,16)
	production_meter.position=Vector2(100,content.size.y-48)
	production_meter.size=Vector2(maxf(20,content.size.x-104),5)
	var menu=_menu_rect()
	menu_button.position=menu.position
	menu_button.size=menu.size
	_menu_caption.size=menu.size
	_menu_caption.queue_redraw()
	menu_button.add_theme_stylebox_override("normal",_shell_button_style(0))
	menu_button.add_theme_stylebox_override("hover",_shell_button_style(1))
	menu_button.add_theme_stylebox_override("pressed",_shell_button_style(2))
	timer_label.position=Vector2(18,14)
	timer_label.size=Vector2(200,23)
	var base=size.x-448
	for i in range(3):
		resources[i].position=Vector2(base+47+i*146,10)
		resources[i].size=Vector2(99,30)
		resource_symbols[i].position=Vector2(base+i*146+4,5)
		resource_symbols[i].size=Vector2(35,31)
	status_label.position=Vector2(22,bottom-35)
	status_label.size=Vector2(size.x-44,30)
	_last_size=size
	queue_redraw()

func _portrait_rect() -> Rect2:
	var original=shell_rect(_shell_geometry().portrait)
	var common=Vector2(144,174)*size.x/(1963.0 if _complete_shells[race] else 1983.0)
	return Rect2(original.get_center()-common*.5,common)

func _portrait_frame_rect() -> Rect2:
	return _portrait_rect()

func _detail_frame_rect() -> Rect2:
	return shell_rect(_shell_geometry().detail)

func _detail_content_rect() -> Rect2:
	var area=_detail_frame_rect()
	if _frame_slices.has(race):
		# Keep text clear of the living frame's inward roots and sap droplets.
		var inset=Vector2(26,24)*shell_draw_rect().size.x/1963.0
		return Rect2(area.position+inset,area.size-Vector2(inset.x*2,inset.y))
	return area

func _command_frame_rect() -> Rect2:
	return shell_rect(_shell_geometry().command)

func _minimap_frame_rect() -> Rect2:
	return shell_rect(_shell_geometry().mini)

func _menu_rect() -> Rect2:
	return shell_rect(_single_menu_source())

func _single_menu_source() -> Rect2:
	if _complete_shells[race]:return _shell_geometry().menu
	if race in [0,1] and _uniform_shells[race]:return Rect2(1267,292,177,42)
	if race==2 and _uniform_shells[race]:return Rect2(1207,275,170,38)
	return _shell_geometry().menu

func _unused_menu_cover_rect() -> Rect2:
	return Rect2()

func shell_rect(source: Rect2) -> Rect2:
	var crop: Rect2=Rect2(_frame_source_regions[race])
	var area=shell_draw_rect()
	var factor=area.size/crop.size
	return Rect2(area.position+(source.position-crop.position)*factor,source.size*factor)

func shell_draw_rect() -> Rect2:
	var height=HEIGHT
	if _uniform_shells.size()==3 and _uniform_shells[race]:
		var crop=_frame_source_regions[race]
		height=float(_native_shell_geometry[race].get("display_height",float(crop.size.y)/crop.size.x))*size.x
	return Rect2(0,size.y-height,size.x,height)

func _shell_geometry() -> Dictionary:
	if _uniform_shells.size()==3 and _uniform_shells[race]:return _native_shell_geometry[race]
	return [
		{"mini":Rect2(72,274,248,252),"detail":Rect2(420,314,708,212),"menu":Rect2(1203,282,168,24),"portrait":Rect2(1206,337,160,214),"command":Rect2(1470,290,425,277),"cols":[1470,1584,1699,1813],"rows":[290,391,491],"slot":Vector2(82,76)},
		{"mini":Rect2(82,254,233,237),"detail":Rect2(420,270,726,220),"menu":Rect2(1235,237,162,26),"portrait":Rect2(1237,300,156,214),"command":Rect2(1495,260,407,261),"cols":[1495,1603,1712,1820],"rows":[260,356,451],"slot":Vector2(82,70)},
		{"mini":Rect2(88,318,212,190),"detail":Rect2(390,340,692,182),"menu":Rect2(1156,297,156,20),"portrait":Rect2(1158,346,150,188),"command":Rect2(1409,317,396,234),"cols":[1409,1515,1621,1727],"rows":[317,404,489],"slot":Vector2(78,62)}
	][race]

func command_slot_rect(index: int) -> Rect2:
	var geometry=_shell_geometry()
	return shell_rect(Rect2(Vector2(geometry.cols[index%4],geometry.rows[int(index/4)]),geometry.slot))

func minimap_rect() -> Rect2:
	var hole=_minimap_frame_rect()
	# The painted opening has rounded inner corners and foliage/metal lips.
	# Use a square safely inside it, shared by terrain, markers and input.
	var inset=maxf(3.0,minf(hole.size.x,hole.size.y)*.035)
	var extent=maxf(1,minf(hole.size.x,hole.size.y)-inset*2)
	return Rect2(hole.get_center()-Vector2.ONE*extent*.5,Vector2.ONE*extent)

func view_rect() -> Rect2:
	return Rect2(0,42,size.x,maxf(1,size.y-HEIGHT-42))

func is_pointer_over_ui(point: Vector2) -> bool:
	return blocks_world_input(point)

func update_hud(force: bool=false) -> void:
	if main==null or main.state.is_empty():return
	_update_surrender_prompt()
	if size!=_last_size:_layout();force=true
	var state: Dictionary=main.state
	var player: Dictionary=state.players[main.local_slot]
	var new_race=int(player.race)
	if race!=new_race or force:
		race=new_race
		accent=[Color("dfb64d"),Color("f18b3f"),Color("cf555e")][race]
		_layout()
	main.selected=main.selected.filter(func(id):return not main._entity(int(id)).is_empty())
	if not main.selected.all(func(id):return _is_brood_entity(main._entity(int(id)))):main.selected=main.selected.slice(0,MAX_SELECTION)
	resources[0].text=str(int(player.get("as",0)))
	resources[0].add_theme_color_override("font_color",Color("f5cc50"))
	resources[1].text=str(int(player.get("tera",0)))
	resources[1].add_theme_color_override("font_color",Color("6ac8ff"))
	var population=float(player.get("used",0))+float(player.get("reserved",0))
	resources[2].text="%s / %d"%[_number(population),int(player.get("cap",0))]
	resources[2].add_theme_color_override("font_color",Color("ff8d7c") if population>=float(player.get("cap",0)) else Color("d8e0d7"))
	for label in resources:
		var font_size=20
		while font_size>14 and _font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>label.size.x:font_size-=1
		label.add_theme_font_size_override("font_size",font_size)
	var seconds=int(state.get("time",0))
	timer_label.text="%02d:%02d   ·   %s"%[int(seconds/60),seconds%60,"리플레이" if main.replay_mode else "실시간 전투"]
	title_label.text=str(ACData.get_data().race_names[race])
	title_label.add_theme_color_override("font_color",accent.lightened(.2))
	status_label.text=main.status_text if main.elapsed<main.status_until else ("공격할 위치를 지정하세요" if main.attack_mode else ("건설 위치를 지정하세요 · 우클릭 취소" if main.build_kind>=0 else ""))
	if float(player.get("hq_deadline",-1))>=0 and not player.get("lost",false):
		status_label.text="본진 상실 · %d초 이내 본진 건설을 완료해야 합니다"%maxi(0,ceili(float(player.hq_deadline)-float(state.time)))
	_update_details()
	var build_panel=bool(main.build_panel)
	if build_panel!=_has_build_panel:
		command_page=0
		_has_build_panel=build_panel
	var completed: Array=[]
	for building in state.get("buildings",[]):
		if int(building.owner)==main.local_slot and float(building.progress)>=1:completed.append(int(building.kind))
	completed.sort()
	var current_signature=str(main.selected)+str(build_panel)+str(command_page)+str(completed)+str(_resource.get("id",-1))+str([player.get("attack",0),player.get("armor",0),player.get("shield",0),player.get("technologies",{}),player.get("nukes",0)])
	if not _unit.is_empty() and _unit.has("progress"):
		current_signature+=str(_unit.get("nuke_job",{}).is_empty())+str(float(_unit.progress)>=1)+str(_unit.get("queue",[]).map(func(item):return item.kind))+str(_unit.get("research_queue",[]).map(func(item):return [item.kind,item.level]))
	elif not _unit.is_empty():current_signature+=str(_unit.get("brood_state",""))+str(_unit.get("morph_kind",-1))+str(_unit.get("cloak_active",false))+str(_unit.get("cargo",[]))+str(_unit.get("drones",[]))+str(_unit.get("drone_queue",[]).size())
	if _is_brood():current_signature+=str(main.selected.map(func(id):return main._entity(int(id)).get("brood_state","")))
	if not _unit.is_empty() and not _unit.has("progress"):current_signature+=str([_unit.get("anchored",false),_unit.has("deploy_until"),_unit.get("deploy_to",false)])
	if not _unit.is_empty():
		var owner: Dictionary=state.players[int(_unit.owner)]
		current_signature+=str([_unit.race,_unit.kind,_unit.owner,owner.get("attack",0),owner.get("armor",0),owner.get("shield",0)])
	if force or current_signature!=signature:
		signature=current_signature
		_build_selection()
		_build_commands()
		_build_queue()
		_build_upgrade_badges()
	_refresh_button_states(player,completed)
	_update_production_meter()
	_update_inline_help()
	queue_redraw()

func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value,round(value)) else "%.1f"%value

func _update_details() -> void:
	detail_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	detail_label.add_theme_font_size_override("font_size",14)
	_unit={}
	_resource={}
	_definition={}
	_portrait=null
	_unit_icon=null
	var count=main.selected.size()
	var content=_detail_content_rect()
	name_label.add_theme_color_override("font_color",Color("e5e9e5"))
	energy_label.hide()
	description_label.position=Vector2(4,content.size.y-20)
	description_label.size=Vector2(content.size.x-8,20)
	description_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	description_label.add_theme_font_size_override("font_size",11)
	if count==0 and main.has_method("_selected_resource_data"):
		_resource=main._selected_resource_data()
		if not _resource.is_empty():
			_update_resource_details()
			return
	name_label.visible=count<=1
	detail_label.position.x=100 if count==1 else 4
	detail_label.size.x=content.size.x-(104 if count==1 else 8)
	if count==0:
		name_label.hide()
		name_label.text=""
		detail_label.text=""
		description_label.text=""
		return
	_unit=main._entity(int(main.selected[0]))
	if _unit.is_empty():return
	var building=_unit.has("progress")
	_definition=(ACData.building(int(_unit.race),int(_unit.kind)) if building else ACData.entity_unit(_unit,main.state.get("players",[]))).duplicate()
	_definition.hp=ACData.max_health(_unit,main.state.get("players",[]))
	_unit_icon=_building_texture(int(_unit.race),int(_unit.kind)) if building else _unit_texture(int(_unit.race),int(_unit.kind))
	_portrait=portraits.get("%d:%d"%[int(_unit.race),int(_unit.kind)]) if not building else (building_portraits[int(_unit.race)] if building_portraits.size()==3 else _unit_icon)
	if _is_brood():
		_unit_icon=main.assets.unit(1,13,Vector2(1,1),"morph" if str(_unit.get("brood_state","idle"))=="morph" else "idle",float(main.state.get("time",0))).get("texture")
		_portrait=portraits.get("1:13",_unit_icon)
	if count>1:
		var leader=main._portrait_entity()
		if not leader.is_empty() and not leader.has("progress"):
			if int(leader.race)==1 and int(leader.kind)==13:
				_portrait=portraits.get("1:13")
			else:_portrait=portraits.get("%d:%d"%[int(leader.race),int(leader.kind)])
		name_label.text="연결 배양체 전체 선택 · %d마리"%main.selected.size() if _is_brood() else "선택한 부대  ·  %d / 12"%count
		detail_label.text=""
		description_label.text=""
		return
	name_label.text=str(_definition.name)
	# The card's central bay is reserved for live combat statistics; flavor text
	# remains available in production/build tooltips instead of covering costs.
	description_label.text=""
	var hp="체력  %d / %d"%[maxi(0,ceili(_unit.hp)),int(_definition.hp)]
	var shield="   실드  %d / %d"%[maxi(0,ceili(_unit.get("shield",0))),int(_definition.get("shield",0))] if float(_definition.get("shield",0))>0 else ""
	if _is_brood():
		var lines=[hp,"생산할 유닛으로 변태하는 배양체입니다."]
		if str(_unit.get("brood_state","idle"))=="morph":
			var target=ACData.unit(1,int(_unit.morph_kind))
			var progress=1-float(_unit.get("morph_left",0))/maxf(1,float(_unit.get("morph_total",1)))
			lines.append("변태 중  %s · %d%%"%[target.name,roundi(clampf(progress,0,1)*100)])
		detail_label.text="\n".join(lines)
		return
	if building:
		var lines=[hp+shield,_building_role(_definition)]
		if (int(_unit.race)==1 and int(_unit.kind) in [10,11]) or (int(_unit.race)!=1 and int(_unit.kind) in [11,12]):
			var anti_air=int(_unit.kind)==(11 if int(_unit.race)==1 else 12)
			lines.append("공중 전용 · 사거리 9 · 피해 24 · 공격 주기 1초" if anti_air else "지상 전용 · 사거리 8 · 피해 15 · 공격 주기 1초")
		if float(_unit.progress)<1:
			lines.append("건설 중  %d%%"%int(float(_unit.progress)*100))
		elif not _unit.get("queue",[]).is_empty():
			var queue: Array=_unit.queue
			var training: Dictionary=ACData.unit(int(_unit.race),int(queue[0].kind))
			var progress=1-float(queue[0].left)/maxf(.01,float(queue[0].total))
			lines=[hp+shield,"현재 생산  %s · %d%%"%[training.name,roundi(clampf(progress,0,1)*100)]]
			description_label.position=Vector2(4,content.size.y-27)
			description_label.size=Vector2(84,24)
			description_label.add_theme_font_size_override("font_size",10)
			description_label.text=_building_role(_definition).split("·")[0].strip_edges()
		elif str(_unit.get("research",""))!="":
			lines.append("연구 중  %d초"%ceili(_unit.get("research_left",0)))
		elif int(_unit.kind)==1:lines.append("테라 자동 추출  ·  3초마다 +8" if _unit.get("tera_active",false) else "비활성 · 14칸 이내 완성된 본진 필요")
		if int(_unit.race)==2 and not _unit.get("powered",true):lines.append("비활성 · 규율탑 지원 없음")
		if int(_unit.kind)==1:
			var catalyst=_building_catalyst(_unit)
			if not catalyst.is_empty():
				if float(_unit.progress)>=1 and float(catalyst.get("amount",0))<=0:lines[2]="테라 고갈 · 자동 추출 중지"
				var deposit="테라 남은 양  %s"%_amount_text(catalyst.get("amount",0))
				if catalyst.has("initial_amount"):deposit+="   초기 총량  %s"%_amount_text(catalyst.initial_amount)
				lines.append(deposit)
		if int(_unit.race)==1 and int(_unit.kind) in [0,3]:
			if not _unit.get("queue",[]).is_empty():lines[1]+=" · 배양체 %d"%int(_unit.get("larva",0))
			else:lines.append("연결 배양체  %d"%int(_unit.get("larva",0)))
			if int(_unit.kind)==3:lines.append("군체모수 연동 · 12칸" if _unit.get("brood_active",false) else "비활성 · 군체모수 연결 없음")
		if int(_unit.race)==0 and int(_unit.kind)==8:
			var job: Dictionary=_unit.get("nuke_job",{})
			lines.append("핵미사일 보유 %d / 3"%int(main.state.players[int(_unit.owner)].get("nukes",0)))
			if not job.is_empty():lines.append("핵미사일 제조 · %d%% · 남은 %d초"%[roundi(100*(1-float(job.left)/float(job.total))),ceili(float(job.left))])
		detail_label.text="\n".join(lines)

	else:
		var owner: Dictionary=main.state.players[int(_unit.owner)]
		var bonus=int(owner.get("attack",0))*2 if float(_definition.get("damage",0))>0 else 0
		var attack=int(_definition.get("damage",0))+bonus
		var armor=int(_definition.get("armor",0))+int(owner.get("armor",0))
		var lines=[hp+shield+" · "+("중장갑" if _definition.get("armor_class","")=="heavy" else "경장갑")+" · "+("기계" if _definition.get("material","")=="mechanical" else "생체"),"공격 %d (%d+%d)  방어 %d (%d+%d)"%[attack,int(_definition.get("damage",0)),bonus,armor,int(_definition.get("armor",0)),int(owner.get("armor",0))],"사거리 %s · 이동 %s · 인구 %s"%[_number(float(_definition.get("range",0))),_number(float(_definition.get("speed",0))),_number(float(_definition.get("pop",0)))]]
		if float(_definition.get("bonus_light",0))>0:lines[1]+=" · 경장갑 +%d"%int(_definition.bonus_light)
		if float(_definition.get("bonus_heavy",0))>0:lines[1]+=" · 중장갑 +%d"%int(_definition.bonus_heavy)
		if _definition.has("damage_air"):lines[1]+=" · 공중 %d"%int(_definition.damage_air)
		if int(_definition.get("burst_count",1))>1:
			var shots=int(_definition.burst_count)
			var total=float(_definition.damage)*(1 if _definition.get("burst_split_total",false) else shots)+bonus
			lines[1]="공격 %s × %d연발 · 총 %s · 방어 %d"%[_number(total/shots),shots,_number(total),armor]
			for armor_type in ["light","heavy"]:
				var extra=float(_definition.get("bonus_"+armor_type,0))*(1 if _definition.get("burst_split_total",false) else shots)
				if extra>0:lines[1]+=" · %s 총 +%s"%["경장갑" if armor_type=="light" else "중장갑",_number(extra)]
		if _definition.role=="carrier":lines[1]="요격 드론 %d / 8 · 생산 대기 %d"%[_unit.get("drones",[]).size(),_unit.get("drone_queue",[]).size()]
		if _definition.role=="flamer":lines[1]="초당 피해 %s · 방어 %d · 경장갑 초당 +%s"%[_number(float(attack)/float(_definition.period)),armor,_number(float(_definition.bonus_light)/float(_definition.period))]
		if _definition.role=="transport":
			var occupied=0.0
			for cargo_id in _unit.get("cargo",[]):
				var passenger=main._entity(int(cargo_id))
				if not passenger.is_empty():occupied+=maxf(1,float(ACData.entity_unit(passenger,main.state.get("players",[])).pop))
			lines[1]="탑승 %d기 · 사용 용량 %s / 8"%[_unit.get("cargo",[]).size(),_number(occupied)]
		if float(_unit.get("bloom_until",0))>float(main.state.time):lines[1]+=" · 개화: 공격속도 +25%% (%d초)"%ceili(float(_unit.bloom_until)-float(main.state.time))
		if _definition.role=="healer_detector":lines[2]+=" · 자동 치료 "+("켜짐" if _unit.get("sap_heal_enabled",true) else "꺼짐")
		if _uses_energy(_definition):
			var maximum=_max_energy(_definition)
			energy_label.text="%d / %d"%[int(_unit.get("energy",0)),int(maximum)]
			energy_label.show()
		detail_label.text="\n".join(lines)

func _update_resource_details() -> void:
	var catalyst=str(_resource.get("type","as"))=="tera"
	var index=1 if catalyst else 0
	var label="테라" if catalyst else "아스"
	name_label.visible=true
	name_label.text="테라 가스 촉매" if catalyst else "아스 광물"
	name_label.add_theme_color_override("font_color",Color("8bd1f0") if catalyst else Color("e6c764"))
	var content=_detail_content_rect()
	detail_label.position.x=100
	detail_label.size.x=content.size.x-104
	var initial=_amount_text(_resource.initial_amount) if _resource.has("initial_amount") else "기록 없음"
	var guide="정제시설이 자동 추출합니다." if catalyst else "일꾼이 채취합니다."
	if float(_resource.get("amount",0))<=0:guide="매장량이 소진되었습니다."
	detail_label.text="자원 종류  %s\n남은 양  %s\n초기 총량  %s"%[label,_amount_text(_resource.get("amount",0)),initial]
	description_label.text=guide
	var world_art=main.get("world_resources")
	if world_art is Array and world_art.size()>index:_unit_icon=world_art[index]
	else:_unit_icon=_resource_icon(index)
	_portrait=_unit_icon

func _amount_text(value) -> String:
	return str(ceili(maxf(0,float(value))))

func _building_role(definition: Dictionary) -> String:
	var description=str(definition.get("description",""))
	var sentences=description.split(".",false)
	return str(sentences[-1]).strip_edges() if not sentences.is_empty() else description

func _building_catalyst(building: Dictionary) -> Dictionary:
	var linked=int(building.get("tera_resource",-1))
	for resource in main.state.get("resources",[]):
		if str(resource.get("type",""))=="tera" and int(resource.id)==linked:return resource
	if not building.has("pos"):return {}
	var footprint=Rect2(ACData.point(building.pos),Vector2(_definition.w,_definition.h))
	for resource in main.state.get("resources",[]):
		if str(resource.get("type",""))=="tera" and footprint.has_point(ACData.point(resource.pos)):return resource
	return {}
func _unit_texture(faction: int,kind: int) -> Texture2D:
	if faction==0 and kind==8:
		if _current_drone_icon==null:
			var frame=main.assets.unit(0,8,Vector2(1,1),"idle",0)
			if not frame.is_empty():
				var icon=AtlasTexture.new();icon.atlas=frame.texture;icon.filter_clip=true
				icon.region=frame.get("sprite_bounds",Rect2(Vector2.ZERO,frame.texture.get_size())).grow(6).intersection(Rect2(Vector2.ZERO,frame.texture.get_size()))
				_current_drone_icon=icon
		if _current_drone_icon!=null:return _current_drone_icon
	var icon=command_art.texture(faction,"units",kind)
	if icon!=null:return icon
	return main.assets.unit(faction,kind,Vector2(1,1)).get("texture")

func _building_texture(faction: int,kind: int) -> Texture2D:
	var icon=command_art.texture(faction,"buildings",kind)
	return icon if icon!=null else main.assets.building(faction,kind)

func _max_energy(definition: Dictionary) -> float:
	return maxf(0,float(definition.get("max_energy",200 if str(definition.get("role","")) in ["medic","mage","priest"] else 0)))

func _uses_energy(definition: Dictionary) -> bool:
	return _max_energy(definition)>0

func _is_brood() -> bool:
	return not _unit.is_empty() and str(_definition.get("role",""))=="brood"

func _play_ui(kind: String) -> void:
	var audio=main.get("audio")
	if audio!=null and audio.has_method("play_ui"):audio.play_ui(kind)

func _set_inline_help(button: Button,title: String,text: String,activate: bool=true) -> void:
	button.tooltip_text=""
	button.set_meta("help_title",title)
	button.set_meta("help_text",text)
	if not activate:return
	button.mouse_entered.connect(func():_hover_help={"button":button};update_hud())
	button.mouse_exited.connect(func():
		if _hover_help.get("button")==button:
			_hover_help={}
			update_hud()
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and is_visible_in_tree() and main!=null and main.page=="game":
		if _portrait_rect().has_point(get_global_transform_with_canvas().affine_inverse()*event.position):
			main._focus_selection(true);get_viewport().set_input_as_handled();return
	# Disabled controls and their hit overlays must still explain their costs.
	if not event is InputEventMouseMotion or not is_visible_in_tree() or main==null or main.page!="game":return
	var hovered: Button=null
	var point=get_canvas_transform().affine_inverse()*event.position
	for button in action_buttons:
		if is_instance_valid(button) and button.is_visible_in_tree() and button.get_global_rect().has_point(point):hovered=button;break
	if hovered!=null and _hover_help.get("button")!=hovered:
		_hover_help={"button":hovered}
		update_hud()
	elif hovered==null and _hover_help.get("button") in action_buttons:
		_hover_help={}
		update_hud()

func _update_inline_help() -> void:
	selection_layer.show()
	queue_layer.show()
	upgrade_layer.show()
	if _hover_help.is_empty():return
	var button=_hover_help.get("button")
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		_hover_help={}
		return
	selection_layer.hide()
	queue_layer.hide()
	if not button.has_meta("upgrade_stat"):upgrade_layer.hide()
	production_meter.hide()
	energy_label.hide()
	name_label.show()
	name_label.text=str(button.get_meta("help_title"))
	name_label.add_theme_color_override("font_color",Color("d4c582"))
	var content=_detail_content_rect()
	detail_label.position.x=4
	detail_label.size.x=content.size.x-8
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text=true
	detail_label.text=str(button.get_meta("help_text"))
	description_label.text=""

func queue_slot_rect(index: int) -> Rect2:
	var content=_detail_content_rect()
	var gap=4.0
	var width=maxf(20,(content.size.x-104-gap*4)/5.0)
	return Rect2(content.position+Vector2(100+index*(width+gap),content.size.y-40),Vector2(width,32))

func _build_queue() -> void:
	for child in queue_layer.get_children():child.hide();child.queue_free()
	queue_buttons.clear()
	if not _unit.is_empty() and not _unit.has("progress") and main.selected.size()==1:
		_build_cargo()
		return
	if main.selected.size()!=1 or _unit.is_empty() or not _unit.has("progress"):return
	var researching=not _unit.get("research_queue",[]).is_empty()
	var queue: Array=_unit.get("research_queue",[]) if researching else _unit.get("queue",[])
	if queue.is_empty():return
	var building_id=int(_unit.id)
	for index in range(5):
		var button=Button.new()
		button.focus_mode=Control.FOCUS_NONE
		button.clip_contents=true
		var slot=queue_slot_rect(index)
		button.position=slot.position-detail_layer.position
		button.size=slot.size
		for state_index in range(3):button.add_theme_stylebox_override(["normal","hover","pressed"][state_index],_shell_button_style(state_index))
		button.add_theme_stylebox_override("disabled",_shell_button_style(0))
		button.set_meta("queue_index",index)
		if index<queue.size():
			var definition={"name":str(queue[index].name)+" %d"%int(queue[index].level)} if researching else ACData.unit(int(_unit.race),int(queue[index].kind))
			var image=TextureRect.new()
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture=command_art.research(int(_unit.race),str(queue[index].kind)) if researching else _unit_texture(int(_unit.race),int(queue[index].kind))
			image.position=Vector2(4,1)
			image.size=Vector2(slot.size.x-8,28)
			image.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(image)
			var progress=SegmentedMeter.new()
			progress.fixed_segments=10
			progress.position=Vector2(3,29)
			progress.size=Vector2(slot.size.x-6,2)
			progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(progress)
			button.set_meta("progress_bar",progress)
			_set_inline_help(button,("진행 중: " if index==0 else "대기: ")+str(definition.name),"클릭하면 이 항목을 취소하고 지불한 자원을 반환합니다.",false)
			var queue_index=index
			button.pressed.connect(func():_play_ui("confirm");main._send_command({"type":"cancel_research" if researching else "cancel","id":building_id,"queue_index":queue_index}))
			button.disabled=int(_unit.owner)!=main.local_slot or main.replay_mode or bool(main.state.get("ended",false))
		else:
			button.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.disabled=true
		queue_layer.add_child(button)
		queue_buttons.append(button)

func _build_cargo() -> void:
	var role=str(_definition.get("role",""))
	if role not in ["transport","carrier"]:return
	var ids: Array=_unit.get("drones",[]) if role=="carrier" else _unit.get("cargo",[])
	var content=_detail_content_rect();var width=minf(34,(content.size.x-104)/8.0)
	for index in range(8):
		var slot=Button.new();slot.focus_mode=Control.FOCUS_NONE
		slot.position=content.position-detail_layer.position+Vector2(100+index*width,content.size.y-32)
		slot.size=Vector2(width-2,29);slot.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var style=StyleBoxFlat.new();style.bg_color=Color("141a1c");style.border_color=accent.darkened(.25);style.set_border_width_all(1)
		slot.add_theme_stylebox_override("normal",style);slot.add_theme_stylebox_override("hover",style)
		if index<ids.size():
			var passenger=main._entity(int(ids[index]))
			if not passenger.is_empty():
				var icon=TextureRect.new();icon.texture=_unit_texture(int(passenger.race),int(passenger.kind));icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);icon.material=_cargo_material;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;slot.add_child(icon)
				var name=str(ACData.entity_unit(passenger,main.state.get("players",[])).name)
				_set_inline_help(slot,name,"탑승 중" if role=="transport" else "출격 중" if int(passenger.container)<0 else "탑재 중",false)
				var carrier_id=int(_unit.id);var passenger_id=int(passenger.id)
				slot.pressed.connect(func():
					if role=="transport":main._send_command({"type":"unload_one","id":carrier_id,"passenger":passenger_id})
					else:main._notify(name)
				)
		else:slot.disabled=true
		queue_layer.add_child(slot)

func _update_production_meter() -> void:
	production_meter.hide()
	if main.selected.size()!=1 or _unit.is_empty():return
	var content=_detail_content_rect()
	if _is_brood():
		if str(_unit.get("brood_state","idle"))=="morph":
			production_meter.position=Vector2(100,content.size.y-14)
			production_meter.size=Vector2(maxf(20,content.size.x-104),5)
			production_meter.set_values(1-float(_unit.get("morph_left",0))/maxf(1,float(_unit.get("morph_total",1))),1,accent)
			production_meter.show()
		return
	if not _unit.has("progress") and _definition.role=="carrier":
		var jobs: Array=_unit.get("drone_queue",[])
		if not jobs.is_empty():
			production_meter.position=Vector2(100,content.size.y-42)
			production_meter.size=Vector2(maxf(20,content.size.x-104),4)
			production_meter.set_values(1-float(jobs[0].left)/float(jobs[0].total),1,accent);production_meter.show()
		return
	if not _unit.has("progress"):return
	var queue: Array=_unit.get("research_queue",[]) if not _unit.get("research_queue",[]).is_empty() else _unit.get("queue",[])
	production_meter.position=Vector2(100,content.size.y-(48 if not queue.is_empty() else 14))
	production_meter.size=Vector2(maxf(20,content.size.x-104),5)
	var progress=-1.0
	if float(_unit.progress)<1:progress=float(_unit.progress)
	elif not queue.is_empty():progress=1-float(queue[0].left)/maxf(.01,float(queue[0].total))
	elif str(_unit.get("research",""))!="":progress=1-float(_unit.get("research_left",0))/maxf(1,float(_unit.get("research_total",45)))
	elif not _unit.get("nuke_job",{}).is_empty():progress=1-float(_unit.nuke_job.left)/float(_unit.nuke_job.total)
	if progress>=0:
		production_meter.set_values(clampf(progress,0,1),1,accent)
		production_meter.show()
	for index in range(mini(queue.size(),queue_buttons.size())):
		var meter=queue_buttons[index].get_meta("progress_bar")
		meter.set_values(1-float(queue[index].left)/maxf(.01,float(queue[index].total)),1,accent)

func _build_upgrade_badges() -> void:
	for child in upgrade_layer.get_children():child.hide();child.queue_free()
	upgrade_badges.clear()
	if main.selected.size()!=1 or _unit.is_empty() or _unit.has("progress") or _is_brood():return
	if _definition.role in ["carrier","transport"]:return
	var owner: Dictionary=main.state.players[int(_unit.owner)]
	var stats: Array[String]=[]
	if float(_definition.get("damage",0))>0:stats.append("attack")
	stats.append("armor")
	if float(_definition.get("shield",0))>0:stats.append("shield")
	var content=_detail_content_rect()
	var width=minf(100,(content.size.x-104)/stats.size())
	for index in range(stats.size()):
		var stat=stats[index]
		var level=int(owner.get(stat,0))
		var title={"attack":"공격","armor":"장갑","shield":"실드"}[stat]
		var button=Button.new()
		button.position=Vector2(100+index*width,content.size.y-23)
		button.size=Vector2(width-4,20)
		button.focus_mode=Control.FOCUS_NONE
		for state_index in range(3):button.add_theme_stylebox_override(["normal","hover","pressed"][state_index],_shell_button_style(state_index))
		var image=TextureRect.new()
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture=command_art.research(int(_unit.race),stat)
		image.material=null
		image.position=Vector2(1,2)
		image.size=Vector2(16,16)
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		var caption=Label.new()
		caption.text="%s %d"%[title,level]
		caption.position=Vector2(21,0)
		caption.size=Vector2(width-26,20)
		caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size",11)
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		var explanation="기본 공격력 %d + 연구 %d = %d"%[int(_definition.get("damage",0)),level*2,int(_definition.get("damage",0))+level*2] if stat=="attack" else ("기본 장갑 %d + 연구 %d = %d"%[int(_definition.get("armor",0)),level,int(_definition.get("armor",0))+level] if stat=="armor" else "실드가 받는 피해를 %d만큼 줄입니다."%level)
		_set_inline_help(button,"%s 연구 · %d / 3단계"%[title,level],explanation)
		button.set_meta("upgrade_stat",stat)
		button.set_meta("upgrade_level",level)
		upgrade_layer.add_child(button)
		upgrade_badges.append(button)

func _build_selection() -> void:
	for child in selection_layer.get_children():child.hide();child.queue_free()
	selection_buttons.clear()
	if main.selected.size()<=1:return
	var content=_detail_content_rect()
	var scale=1.0
	if size.x>1440:scale=maxf(1,minf(size.x/1440,minf(content.size.x/512,content.size.y/88)))
	var cell_width=minf(SELECTION_SIZE.x,floorf((content.size.x-12*scale)/(4*scale)))*scale
	var grid_left=content.get_center().x-(cell_width*4+12*scale)*.5
	var grid_top=content.get_center().y-(SELECTION_SIZE.y*3+4)*scale*.5
	for index in range(mini(MAX_SELECTION,main.selected.size())):
		var entity: Dictionary=main._entity(int(main.selected[index]))
		if entity.is_empty():continue
		var id=int(entity.id)
		var definition: Dictionary=ACData.building(int(entity.race),int(entity.kind)) if entity.has("progress") else ACData.entity_unit(entity,main.state.get("players",[]))
		var texture: Texture2D=_building_texture(int(entity.race),int(entity.kind)) if entity.has("progress") else _unit_texture(int(entity.race),int(entity.kind))
		if str(definition.get("role",""))=="brood":texture=main.assets.unit(1,13,Vector2(1,1),"morph" if str(entity.get("brood_state","idle"))=="morph" else "idle",float(main.state.get("time",0))).get("texture")
		var button=Button.new()
		button.focus_mode=Control.FOCUS_NONE
		button.position=Vector2(grid_left+index%4*(cell_width+4*scale),grid_top+int(index/4)*(SELECTION_SIZE.y+2)*scale)
		button.clip_contents=true
		var miniature=TextureRect.new()
		miniature.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		miniature.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		miniature.texture=texture
		miniature.position=Vector2(4,1)*scale
		miniature.size=Vector2(28,23)*scale
		miniature.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(miniature)
		var caption=Label.new()
		caption.text=str(definition.name)
		caption.position=Vector2(36,0)*scale
		var has_energy=not entity.has("progress") and _uses_energy(definition)
		caption.size=Vector2(cell_width-(58 if has_energy else 40)*scale,22*scale)
		caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		caption.clip_text=true
		caption.add_theme_font_size_override("font_size",roundi(10*scale))
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(caption)
		var maximum=ACData.max_health(entity,main.state.get("players",[]))
		_set_inline_help(button,str(definition.name),"체력 %d / %d\n클릭: 한 기 선택 · Shift: 선택 해제"%[ceili(entity.hp),int(maximum)],false)
		button.add_theme_stylebox_override("normal",_shell_button_style(0))
		button.add_theme_stylebox_override("hover",_shell_button_style(1))
		button.add_theme_stylebox_override("pressed",_shell_button_style(2))
		button.size=Vector2(cell_width,SELECTION_SIZE.y*scale)
		var hp=SegmentedMeter.new()
		hp.position=Vector2(3,21 if has_energy else 25)*scale
		hp.size=Vector2(cell_width-6*scale,2*scale)
		hp.set_values(float(entity.hp),maximum,Color("8bbf64"))
		hp.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(hp)
		button.set_meta("entity_id",id)
		button.set_meta("hp_bar",hp)
		button.set_meta("max_hp",maximum)
		if has_energy:
			var energy=SegmentedMeter.new()
			energy.position=Vector2(3,25)*scale
			energy.size=Vector2(cell_width-6*scale,2*scale)
			energy.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(energy)
			var number=Label.new()
			number.position=Vector2(cell_width-24*scale,0)
			number.size=Vector2(21,20)*scale
			number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			number.add_theme_font_size_override("font_size",roundi(9*scale))
			number.add_theme_color_override("font_color",Color("8baef0"))
			number.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.add_child(number)
			button.set_meta("energy_bar",energy)
			button.set_meta("energy_label",number)
			button.set_meta("max_energy",_max_energy(definition))
		button.pressed.connect(func():
			_play_ui("select")
			if Input.is_key_pressed(KEY_SHIFT):main.selected.erase(id)
			else:main.selected=[id]
			main._selection_voice()
			main.hud_signature=""
			update_hud(true)
		)
		selection_layer.add_child(button)
		selection_buttons.append(button)

func _command(title: String,key: int,key_name: String,icon: int,action: Callable,tip: String="",texture: Texture2D=null,cost: Dictionary={}) -> Dictionary:
	return {"title":title,"key":key,"key_name":key_name,"icon":icon,"action":action,"tip":tip,"texture":texture,"cost":cost}

func _can_rally() -> bool:
	if main.has_method("_building_accepts_rally"):return main._building_accepts_rally(_unit)
	if _unit.is_empty() or not _unit.has("progress") or float(_unit.progress)<1:return false
	if int(_unit.race)==1:return int(_unit.kind) in [0,3]
	for kind in range(ACData.unit_count(int(_unit.race))):
		if int(ACData.unit(int(_unit.race),kind).producer)==int(_unit.kind):return true
	return false

func _selected_carriers(available_only: bool=false) -> Array:
	var ids: Array=[]
	for id in main.selected:
		var carrier=main._entity(int(id))
		if carrier.is_empty() or carrier.has("progress") or int(carrier.owner)!=main.local_slot or int(carrier.race)!=0 or int(carrier.kind)!=14 or float(carrier.hp)<=0:continue
		if available_only and carrier.get("drones",[]).size()+carrier.get("drone_queue",[]).size()>=8:continue
		if int(id) not in ids:ids.append(int(id))
	return ids

func _build_commands() -> void:
	for child in action_layer.get_children():child.hide();child.queue_free()
	action_buttons.clear()
	action_specs.clear()
	hover_hotkeys.clear()
	if _unit.is_empty() or int(_unit.owner)!=main.local_slot:return
	var faction=int(_unit.race)
	var kind=int(_unit.kind)
	var building=_unit.has("progress")
	var id=int(_unit.id)
	var all: Array[Dictionary]=[]
	if not building:
		if _is_brood():
			var idle_pods=main.selected.filter(func(selected_id):
				var pod=main._entity(int(selected_id))
				return _is_brood_entity(pod) and int(pod.owner)==main.local_slot and float(pod.hp)>0 and str(pod.get("brood_state","idle"))=="idle"
			)
			if idle_pods.is_empty():
				command_page=0
				_present_commands([_command("배양 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel_morph","id":id,"ids":main.selected.duplicate()}),"선택한 배양체의 배양을 취소하고 비용을 돌려받습니다. 취소한 배양체는 사망합니다.")])
				return
			for train in range(13):
				var definition=ACData.unit(1,train)
				var train_id=train
				all.append(_command(str(definition.name),0,"",ICON_TRAIN,func():main._send_command({"type":"morph","id":id,"ids":main.selected.duplicate(),"kind":train_id}),_cost_tip(definition)+"\n"+str(definition.description),_unit_texture(1,train),definition))
			_show_paged(all,false,true)
			return
		if kind==0 and main.build_panel and faction==int(main.state.players[main.local_slot].race):
			for slot in range(13):
				var build=int(BUILD_ORDERS[faction][slot])
				var definition: Dictionary=ACData.building(faction,build)
				var build_id=build
				all.append(_command(str(definition.name),0,"",ICON_BUILD,func():main.set("pointer_order","");main.attack_mode=false;main.build_kind=build_id;main._notify(str(definition.name)+": 건설 위치 지정"),_cost_tip(definition)+"\n"+str(BUILD_ROLES[slot])+" · "+str(definition.description),_building_texture(faction,build),definition))
				all[-1]["building_kind"]=build_id
				all[-1]["build_role"]=BUILD_ROLES[slot]
			_show_paged(all,true)
			return
		all.append(_command("이동",KEY_M,"M",ICON_MOVE,func():_target_order("move"),"지정한 위치로 이동합니다."))
		if float(_definition.get("damage",0))>0 or _definition.get("role","")=="carrier" or main.selected.any(func(selected_id):
			var troop=main._entity(int(selected_id))
			return not troop.is_empty() and not troop.has("progress") and int(troop.owner)==main.local_slot and float(ACData.entity_unit(troop,main.state.get("players",[])).damage)>0):
			all.append(_command("공격",KEY_A,"A",ICON_ATTACK,func():main.set("pointer_order","");main.attack_mode=true;main.build_kind=-1,"적 유닛을 공격하거나 지정 위치로 공격 이동합니다."))
		all.append(_command("정지",KEY_S,"S",ICON_STOP,func():_send("stop"),"현재 명령을 중단합니다."))
		all.append(_command("위치 사수",KEY_H,"H",ICON_HOLD,func():_send("hold"),"위치를 지키며 사거리 안의 적을 공격합니다."))
		if kind==0:
			all.append(_command("아스 채취",KEY_G,"G",ICON_GATHER,func():_target_order("gather"),"황금 아스 수정으로 이동하여 채취합니다.\n테라는 추출 시설이 자동으로 생산합니다."))
			if faction==int(main.state.players[main.local_slot].race):all.append(_command("건설",KEY_B,"B",ICON_BUILD,func():main.set("pointer_order","");main.attack_mode=false;main.build_panel=true;command_page=0;update_hud(true),"종족의 건물을 선택합니다.\n건설 메뉴에서는 Q / W / E 등 표시된 키를 사용합니다."))
			if faction==0:
				all.append(_command("수리",KEY_R,"R",ICON_REPAIR,func():_target_order("repair"),"아스를 사용하여 기계와 건물을 수리합니다."))
		var role=str(_definition.get("role",""))
		if role in ["siege","fortress","tree"]:
			var names={"siege":"공성 전개","fortress":"요새 전개","tree":"뿌리 고정"}
			var title="전개 해제" if _unit.get("anchored",false) else names[role]
			var help="현재 위치에서 전개 상태를 전환합니다."
			if faction==0 and kind==5:
				help="전개 2.5초 · 해제 1.8초\n고정 시 사거리 +3 · 최소 사거리 2.5"
				if float(_unit.get("deploy_until",0))>float(main.state.time):title="전개 중" if _unit.get("deploy_to",false) else "해제 중"
			all.append(_command(title,KEY_Q,"Q",ICON_ABILITY,func():_ability(false),help))
			if faction==0 and kind==5:all[-1]["deploy_action"]=true
		elif role=="transport":
			all.append(_command("모두 내리기",KEY_D,"D",ICON_UNLOAD,func():_ability(false),"현재 위치에 탑승 유닛을 모두 내립니다.\n지상 유닛이 수송 유닛을 우클릭하면 탑승합니다."))
		elif faction==0 and kind==7:
			all.append(_command("은폐 해제" if _unit.get("cloak_active",false) else "은폐",KEY_C,"C",ICON_ABILITY,func():_ability(false),"시작 에너지 25 · 유지 초당 1\n공격해도 은폐가 유지됩니다."))
		var skill_keys=[KEY_W,KEY_E,KEY_T,KEY_F]
		var skill_names=["W","E","T","F"]
		var skills=ACAbilities.catalog(faction,kind)
		for index in range(skills.size()):
			var skill: Dictionary=skills[index]
			var skill_id=str(skill.id)
			all.append(_command(str(skill.name),skill_keys[index],skill_names[index],ICON_ABILITY,func():_skill(skill_id),_skill_tip(skill),command_art.skill(faction,skill_id),{"skill":skill_id}))
		if role=="priest":all.append(_command("자동 체력 회복",0,"",ICON_REPAIR,func():main._notify("에너지 2당 체력 1 자동 회복 · 초당 최대 10"),"부상한 아군 부엉이의 체력을 자동 회복합니다.
체력 1당 에너지 2 · 최대 초당 체력 10"))
		if role=="carrier":
			all.append(_command("요격 드론 생산",KEY_Q,"Q",ICON_TRAIN,func():main._send_command({"type":"produce_drone","id":id,"ids":_selected_carriers()}),"선택한 각 모함에 1기씩 생산 · 모함당 아스 25 · 테라 10 · 8초
모함당 생산 예약 포함 최대 8기",_unit_texture(0,15),{"as":25,"tera":10,"drone":true}))
			all.append(_command("드론 생산 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel_drone","id":id}),"마지막 드론 생산을 취소하고 비용을 반환합니다."))
	else:
		if float(_unit.progress)<1:
			all.append(_command("건설 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel","id":id}),"건설을 취소하고 비용의 75%를 돌려받습니다."))
		else:
			if faction==1 and kind in [0,3]:
				all.append(_command("연결된 배양체 전체 선택",KEY_V,"V",31,func():main._select_brood(id),"이 본진과 연동된 배양체를 선택합니다.\n각 배양체에서 독립적으로 유닛을 변태시키세요."))
			for train in range(ACData.unit_count(faction)) if faction!=1 else []:
				var definition: Dictionary=ACData.unit(faction,train)
				if (faction==1 and kind in [0,3]) or (faction!=1 and int(definition.producer)==kind):
					var train_id=train
					all.append(_command(str(definition.name),0,"",ICON_TRAIN,func():main._send_command({"type":"train","id":id,"kind":train_id}),_cost_tip(definition)+"\n인구 %s · 생산 %d초\n"%[_number(float(definition.pop)),int(definition.time)]+str(definition.description),_unit_texture(faction,train),definition))
			for research in ACResearch.catalog(faction,kind):
				var stat_id=str(research.id)
				var level=ACResearch.level(main.state.players[main.local_slot],stat_id)
				for job in _unit.get("research_queue",[]):
					if str(job.kind)==stat_id:level+=1
				var cost={"as":research.as+level*float(research.get("step",0)),"tera":research.tera+level*float(research.get("step",0)),"research_stat":stat_id,"level":level,"max_level":research.get("max_level",1),"requires":research.get("requires",[])}
				var effect_tip=str(research.get("description","완료 시 해당 기술의 대상 유닛에 적용됩니다."))+"\n연구 %d초"%int(research.time)
				all.append(_command(str(research.name),0,"",ICON_RESEARCH,func():main._send_command({"type":"research","id":id,"stat":stat_id}),_cost_tip(cost)+"\n예약 포함 %d / %d단계\n"%[level,int(research.get("max_level",1))]+effect_tip,command_art.research(faction,stat_id),cost))
			if faction==0 and kind==8:
				all.append(_command("핵미사일 생산",0,"",ICON_TRAIN,func():main._send_command({"type":"produce_nuke","id":id}),"아스 300 · 테라 200 · 75초
유도 연구 필요 · 최대 3발 보유",command_art.skill(faction,"nuclear"),{"as":300,"tera":200,"nuke":true}))
				if not _unit.get("nuke_job",{}).is_empty():all.append(_command("핵미사일 생산 취소",0,"",ICON_CANCEL,func():main._send_command({"type":"cancel_nuke","id":id}),"생산 취소 · 비용 전액 반환"))
			if all.size()>9:
				_show_paged(all,false)
				return
			for index in range(all.size()):
				all[index].key=PRODUCTION_KEYS[index]
				all[index].key_name=PRODUCTION_KEY_NAMES[index]
			if not _unit.get("queue",[]).is_empty() or str(_unit.get("research",""))!="":
				all.append(_command("생산 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel","id":id}),"마지막 생산 대기 항목 또는 진행 중인 연구를 취소합니다."))
			if _can_rally():
				all.append(_command("집결 지점",KEY_R,"R",ICON_RALLY,func():_target_order("rally"),"새로 생산한 유닛이 이동할 위치를 지정합니다."))
	_present_commands(all)

func _show_paged(all: Array[Dictionary],building_menu: bool,brood_menu: bool=false) -> void:
	var capacity=9 if building_menu else 8
	var pages=ceili(all.size()/float(capacity))
	command_page=clampi(command_page,0,maxi(0,pages-1))
	var visible: Array[Dictionary]=[]
	for index in range(command_page*capacity,mini(all.size(),command_page*capacity+capacity)):
		var spec: Dictionary=all[index].duplicate()
		var on_page=index-command_page*capacity
		spec.key=PAGE_KEYS[on_page] if building_menu else PRODUCTION_KEYS[on_page]
		spec.key_name=PAGE_KEY_NAMES[on_page] if building_menu else PRODUCTION_KEY_NAMES[on_page]
		visible.append(spec)
	while visible.size()<capacity:visible.append({})
	visible.append(_command("이전",KEY_BRACKETLEFT,"[",29,func():command_page=posmod(command_page-1,pages);update_hud(true),"이전 명령 페이지"))
	visible.append(_command("%d / %d 다음"%[command_page+1,pages],KEY_BRACKETRIGHT,"]",30,func():command_page=(command_page+1)%pages;update_hud(true),"다음 명령 페이지"))
	if building_menu:
		visible.append(_command("돌아가기",KEY_X,"X",ICON_CANCEL,func():main.build_panel=false;main.build_kind=-1;command_page=0;update_hud(true),"건설 메뉴를 닫습니다."))
	elif not brood_menu:
		var id=int(_unit.id)
		visible.append(_command("생산 취소",KEY_X,"X",ICON_CANCEL,func():main._send_command({"type":"cancel","id":id}),"마지막 생산 대기 항목을 취소합니다."))
		visible.append(_command("집결 지점",KEY_R,"R",ICON_RALLY,func():_target_order("rally"),"새로 생산한 유닛이 이동할 위치를 지정합니다."))
	_present_commands(visible)

func _present_commands(specs: Array[Dictionary]) -> void:
	specs=_arrange_commands(specs)
	action_specs=specs
	for index in range(mini(12,specs.size())):
		var spec: Dictionary=specs[index]
		if spec.is_empty():continue
		var button=Button.new()
		button.focus_mode=Control.FOCUS_NONE
		button.clip_contents=true
		var slot=command_slot_rect(index)
		button.position=slot.position
		button.size=slot.size
		button.add_theme_stylebox_override("normal",_command_style(0))
		button.add_theme_stylebox_override("hover",_command_style(1))
		button.add_theme_stylebox_override("pressed",_command_style(2))
		button.add_theme_stylebox_override("disabled",_command_style(0,true))
		_set_inline_help(button,"%s [%s]"%[spec.title,spec.key_name],spec.tip)
		button.set_meta("base_help",spec.tip)
		button.pressed.connect(func():_play_ui("confirm");spec.action.call())
		button.gui_input.connect(func(event):
			if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				_blocked_command_voice(button)
		)
		var texture: Texture2D=spec.texture if spec.texture!=null else _icon(int(spec.icon))
		if texture!=null:
			var image=TextureRect.new()
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter=Control.MOUSE_FILTER_IGNORE
			image.texture=texture
			image.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
			image.flip_h=false
			var glyph_size=Vector2(minf(54,slot.size.x-8),minf(46,slot.size.y-4))
			image.position=(slot.size-glyph_size)*.5
			image.size=glyph_size
			# Preserve full-colour building and equipment artwork.
			image.set_meta("command_image",true)
			button.add_child(image)
		var hotkey=ShellHotkey.new()
		hotkey.caption=spec.key_name
		hotkey.position=Vector2(1,1)
		hotkey.size=Vector2(11,12)
		hotkey.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(hotkey)
		var blocked_hit=Control.new()
		blocked_hit.name="BlockedVoiceHit"
		blocked_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		blocked_hit.mouse_filter=Control.MOUSE_FILTER_IGNORE
		blocked_hit.mouse_entered.connect(func():_hover_help={"button":button};update_hud())
		blocked_hit.mouse_exited.connect(func():
			if _hover_help.get("button")==button:_hover_help={};update_hud()
		)
		blocked_hit.gui_input.connect(func(event):
			if button.disabled and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				_blocked_command_voice(button)
		)
		button.add_child(blocked_hit)
		button.set_meta("spec",spec)
		button.set_meta("slot",index)
		action_layer.add_child(button)
		action_buttons.append(button)
		if int(spec.key)>0:hover_hotkeys[int(spec.key)]=button

func _arrange_commands(specs: Array[Dictionary]) -> Array[Dictionary]:
	var arranged: Array[Dictionary]=[];arranged.resize(12);arranged.fill({})
	var ordinary=[];var abilities=[];var cancellations=[]
	for original_slot in range(specs.size()):
		var spec=specs[original_slot]
		if spec.is_empty():continue
		if int(spec.icon) in [29,30]:arranged[original_slot]=spec
		elif int(spec.icon)==ICON_CANCEL:cancellations.append(spec)
		elif int(spec.icon) in [ICON_ABILITY,ICON_UNLOAD] or spec.get("cost",{}).has("skill"):abilities.append(spec)
		else:ordinary.append(spec)
	for index in range(abilities.size()):arranged[8+index]=abilities[index]
	if not cancellations.is_empty():arranged[11]=cancellations.back()
	# A rare second independent queue has its own cancel beside the main one.
	if cancellations.size()>1:ordinary.append_array(cancellations.slice(0,cancellations.size()-1))
	for spec in ordinary:
		var slot=0
		while slot<12 and not arranged[slot].is_empty():slot+=1
		if slot<12:arranged[slot]=spec
	return arranged

func _command_style(state_index: int,disabled: bool=false) -> StyleBox:
	return _shell_button_style(3 if disabled else state_index)

func _shell_button_style(state_index: int) -> StyleBox:
	if state_index==0:return StyleBoxEmpty.new()
	var style=StyleBoxFlat.new()
	style.bg_color=[Color.TRANSPARENT,Color(1,.9,.6,.12),Color(0,0,0,.35),Color(0,0,0,.5)][state_index]
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,0)
	return style

func _cost_tip(definition: Dictionary) -> String:
	var result="아스 %d · 테라 %d"%[int(definition.get("as",0)),int(definition.get("tera",0))]
	if definition.has("role") and not definition.has("w"):
		result+=" · 인구 %s · %d초"%[_number(float(definition.get("pop",0))*int(definition.get("production_count",1))),int(definition.get("time",0))]
		var targets=str(definition.get("targets",""))
		result+="\n%s · %s · %s"%["중장갑" if definition.get("armor_class","")=="heavy" else "경장갑","기계 (수리 가능)" if definition.get("material","")=="mechanical" else "생체","지상·공중 공격" if targets=="ga" else "지상 공격" if targets=="g" else "공중 공격" if targets=="a" else "지원 유닛 · 기본 공격 없음"]
		if float(definition.get("damage",0))>0:
			if definition.role=="flamer":result+="\n초당 피해 %s · 사거리 %s · 전방 범위 화염"%[_number(float(definition.damage)/float(definition.period)),_number(float(definition.range))]
			else:result+="\n피해 %d · 사거리 %s · 주기 %s초"%[int(definition.damage),_number(float(definition.range)),_number(float(definition.period))]
			if int(definition.get("burst_count",1))>1:
				var total=float(definition.damage)*(1 if definition.get("burst_split_total",false) else int(definition.burst_count))
				result+=" · %d연발 · 총 %s"%[int(definition.burst_count),_number(total)]
			if definition.has("damage_air"):result+=" · 공중 피해 %d"%int(definition.damage_air)
			if float(definition.get("bonus_light",0))>0:result+=(" · 경장갑 초당 +%s"%_number(float(definition.bonus_light)/float(definition.period))) if definition.role=="flamer" else " · 경장갑 +%d"%int(definition.bonus_light)
			if float(definition.get("bonus_heavy",0))>0:result+=" · 중장갑 +%d"%int(definition.bonus_heavy)
			if float(definition.get("splash_radius",0))>0:result+="\n범위 반경 %s · 주변 피해 %s%%"%[_number(float(definition.splash_radius)),_number(float(definition.get("splash_factor",1))*100)]
	return result

func _refresh_button_states(player: Dictionary,completed: Array) -> void:
	for button in selection_buttons:
		var entity: Dictionary=main._entity(int(button.get_meta("entity_id")))
		if entity.is_empty():continue
		var hp: SegmentedMeter=button.get_meta("hp_bar")
		var ratio=clampf(float(entity.hp)/maxf(1,float(button.get_meta("max_hp"))),0,1)
		hp.set_values(float(entity.hp),float(button.get_meta("max_hp")),Color("cf7052") if ratio<.35 else Color("8bbf64"))
		if button.has_meta("energy_bar"):
			var energy: SegmentedMeter=button.get_meta("energy_bar")
			var maximum=float(button.get_meta("max_energy"))
			energy.set_values(float(entity.get("energy",0)),maximum,Color("729bd9"))
			var label: Label=button.get_meta("energy_label")
			label.text=str(floori(float(entity.get("energy",0))))
	for button in action_buttons:
		var spec: Dictionary=button.get_meta("spec")
		var cost: Dictionary=spec.cost
		var reasons: Array[String]=[]
		if spec.get("deploy_action",false) and float(_unit.get("deploy_until",0))>float(main.state.time):reasons.append("변신 중")
		if race==1 and int(_unit.get("kind",-1))==3 and _unit.has("progress") and not _unit.get("brood_active",false):reasons.append("군체모수 연결 필요")
		if cost.has("skill"):
			var skill=ACAbilities.catalog(int(_unit.race),int(_unit.kind)).filter(func(d):return d.id==cost.skill)[0]
			if not ACAbilities.unlocked(player,skill):reasons.append("연구 필요: "+str(skill.name))
			if float(_unit.get("energy",0))<float(skill.energy):reasons.append("에너지 부족")
			if float(skill.get("hp_cost",0))>0 and float(_unit.hp)<=float(skill.hp_cost):reasons.append("체력%d 초과 필요"%int(skill.hp_cost))
			var remaining=float(_unit.get("skill_ready",{}).get(str(skill.id),0))-float(main.state.time)
			if skill.id=="mind_control":remaining=maxf(remaining,float(_unit.get("ability_cd",0)))
			if remaining>0:reasons.append("재사용 대기 %d초"%ceili(remaining))
			if float(_unit.get("silenced_until",0))>float(main.state.time):reasons.append("능력 봉인 중")
			if skill.id=="sap_reclaim" and float(_unit.get("energy",0))>=_max_energy(_definition):reasons.append("마나 최대치")
			if skill.id=="sap_heal":
				button.toggle_mode=true;button.set_pressed_no_signal(bool(_unit.get("sap_heal_enabled",true)))
		elif not cost.is_empty():
			if float(player.get("as",0))<float(cost.get("as",0)):reasons.append("아스 부족")
			if float(player.get("tera",0))<float(cost.get("tera",0)):reasons.append("테라 부족")
			var missing=ACData.missing_building_names(race,cost.get("requires",[]),completed)
			if not missing.is_empty():reasons.append("필요 건물: "+", ".join(missing))
			if cost.has("research_stat"):
				if int(cost.level)>=int(cost.get("max_level",3)):reasons.append("최대 연구 단계 또는 예약 완료")
				if _unit.get("research_queue",[]).size()>=ACResearch.CAPACITY:reasons.append("연구 대기열 가득 참")
			elif cost.has("nuke"):
				if ACResearch.level(player,"nuclear")==0:reasons.append("핵미사일 유도 연구 필요")
				if not _unit.get("nuke_job",{}).is_empty():reasons.append("핵미사일 생산 중")
				if int(player.get("nukes",0))>=3:reasons.append("핵미사일 최대 보유량")
			elif cost.has("drone"):
				if _selected_carriers(true).is_empty():reasons.append("선택한 모함 모두 드론 최대 8기")
			elif not cost.has("w"):
				if float(player.get("used",0))+float(player.get("reserved",0))+(float(cost.get("pop",0))*int(cost.get("production_count",1)))>float(player.get("cap",0)):reasons.append("인구 한도 부족")
				if not _is_brood() and _unit.get("queue",[]).size()>=5:reasons.append("생산 대기열 가득 참 · 최대 5기")
				if race==1 and not _is_brood() and int(_unit.get("larva",0))<=0:reasons.append("배양체 필요")
		button.disabled=not reasons.is_empty() or main.replay_mode or bool(main.state.get("ended",false))
		button.set_meta("blocked_reasons",reasons)
		var blocked_hit=button.get_node_or_null("BlockedVoiceHit")
		if blocked_hit!=null:blocked_hit.mouse_filter=Control.MOUSE_FILTER_STOP if button.disabled else Control.MOUSE_FILTER_IGNORE
		var help_lines: Array[String]=[]
		if not cost.is_empty() and not cost.has("skill"):help_lines.append(_cost_tip(cost)+(" · 건설 %d초"%int(cost.get("time",0)) if cost.has("w") else (" · 인구 %s · %d초"%[_number((float(cost.get("pop",0))*int(cost.get("production_count",1)))),int(cost.get("time",0))] if not cost.has("research_stat") and not cost.has("role") else "")))
		if int(cost.get("production_count",1))>1:help_lines.append("1회 생산: %d마리"%int(cost.production_count))
		var prerequisites: Array[String]=[]
		for kind in cost.get("requires",[]):prerequisites.append(str(ACData.building(race,int(kind)).name))
		if cost.has("w"):help_lines.append("선행 건물: "+(", ".join(prerequisites) if not prerequisites.is_empty() else "없음"))
		var missing=ACData.missing_building_names(race,cost.get("requires",[]),completed)
		if not missing.is_empty():help_lines.append("필요 건물: "+", ".join(missing))
		for reason in reasons:
			if not reason.begins_with("필요 건물"):help_lines.append(reason)
		var generated_cost_lines=_cost_tip(cost).split("\n") if not cost.is_empty() else PackedStringArray()
		var original=str(button.get_meta("base_help")).split("\n")
		for line in original:
			if help_lines.size()>=4:break
			if cost.has("role") and not cost.has("w"):continue
			if line in generated_cost_lines:continue
			if not cost.is_empty() and (line.begins_with("아스 ") or line.begins_with("인구 ") or line.begins_with("규격 ")):continue
			if line!="" and line not in help_lines:help_lines.append(line)
		button.set_meta("help_text","\n".join(help_lines.slice(0,4)))
		button.modulate=Color(.55,.6,.63) if button.disabled else Color.WHITE

func _icon(index: int) -> Texture2D:
	var replacement=command_art.texture(race,"commands",index)
	if replacement!=null:return replacement
	return icons[index] if index>=0 and index<icons.size() else null

func _resource_icon(index: int) -> Texture2D:
	return resource_icons[index] if index>=0 and index<resource_icons.size() else _icon(ICON_AS+index)

func _target_order(order: String) -> void:
	main.attack_mode=false
	main.build_kind=-1
	main.set("pointer_order",order)
	var names={"move":"이동 위치","gather":"아스 수정","repair":"수리 대상","ability":"능력 사용 위치","rally":"집결 위치"}
	main._notify(str(names.get(order,"명령 위치"))+"를 지정하세요 · 우클릭 취소")

func _send(type: String) -> void:
	main.set("pointer_order","")
	main.attack_mode=false
	main.build_kind=-1
	main._send_command({"type":type,"ids":main.selected.duplicate()})

func _ability(targeted: bool) -> void:
	if targeted:
		_target_order("ability")
		return
	main._send_command({"type":"ability","ids":main.selected.duplicate(),"pos":_unit.get("pos",[0,0])})

func handle_hotkey(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed:return false
	if not _resource.is_empty():return false
	var code=event.physical_keycode if event.physical_keycode not in [0,KEY_UNKNOWN] else event.keycode
	# Escape first closes a construction card; the main controller owns pause.
	if code==KEY_ESCAPE and main.build_panel:
		main.build_panel=false
		main.build_kind=-1
		command_page=0
		update_hud(true)
		get_viewport().set_input_as_handled()
		return true
	if hover_hotkeys.has(int(code)):
		var button: Button=hover_hotkeys[int(code)]
		if is_instance_valid(button) and not button.disabled:button.pressed.emit()
		elif is_instance_valid(button):_blocked_command_voice(button)
		get_viewport().set_input_as_handled()
		return true
	return false

func _blocked_command_voice(button: Button) -> void:
	if main.replay_mode or bool(main.state.get("ended",false)):return
	for reason in button.get_meta("blocked_reasons",[]):
		var message=str(reason)
		if message.begins_with("필요 건물:"):message="선행 건물이 필요합니다"
		if message=="배양체 필요":message="배양체가 부족합니다"
		if main.audio!=null and main.audio.director!=null and main.audio.director.error_event(message)!="":
			main._voice_error(message)
			return

func _draw() -> void:
	if main==null:return
	var mini=minimap_rect()
	# Keep the approved one-piece shell intact, including its silhouette and
	# its own painted command bays. No repeated trim or second panel overlays it.
	if _body_outline.size()>=3:
		if _body_materials.size()==3:draw_colored_polygon(_body_outline,_material_tint(),_body_uvs,_body_materials[race])
		else:draw_colored_polygon(_body_outline,[Color("514b35"),Color("593e2a"),Color("746b60")][race])
	# Opaque backing stops world flashes showing through painted frame edges.
	draw_rect(_minimap_frame_rect().grow(4),Color("101517"))
	if _frame_art.size()==3 and _frame_art[race]!=null:
		if _frame_slices.has(race):
			for slice in _frame_slices[race]:draw_texture_rect_region(_frame_art[race],shell_rect(slice.target),slice.source)
		else:draw_texture_rect_region(_frame_art[race],shell_draw_rect(),Rect2(_frame_source_regions[race]))
	# Clear painted/filtered slivers inside the known aperture after the shell.
	if not _frame_slices.has(race) and (race!=1 or not "hud_citrus_wood_new_20261024" in _frame_art[race].resource_path):
		draw_rect(_minimap_frame_rect().grow(-.5),Color("101517"))
	if main.has_method("_render_minimap"):main._render_minimap(self)
	draw_rect(mini.grow(.25),Color("101517"),false,1.5)
	var content=_detail_content_rect()
	if _hover_help.is_empty() and (main.selected.size()==1 or not _resource.is_empty()) and _unit_icon!=null:
		_draw_fit(_unit_icon,_unit_preview_rect())
	if _hover_help.is_empty() and main.selected.size()==1 and not _unit.is_empty():
		var preview=_unit_preview_rect()
		var bar=Rect2(Vector2(preview.position.x,preview.end.y+5),Vector2(84,3))
		_draw_segmented_meter(bar,float(_unit.hp),float(_definition.hp),Color("7fcf66"))
		if float(_definition.get("shield",0))>0:
			_draw_segmented_meter(Rect2(bar.position+Vector2(0,6),bar.size),float(_unit.get("shield",0)),float(_definition.shield),Color("d56a80"))
		if not _unit.has("progress") and _uses_energy(_definition):
			var offset=12 if float(_definition.get("shield",0))>0 else 6
			_draw_segmented_meter(Rect2(bar.position+Vector2(0,offset),bar.size),float(_unit.get("energy",0)),_max_energy(_definition),Color("729bd9"))
	# Compact top strip: each stockpile is identified by its generated icon.
	var base=size.x-448
	for index in range(3):
		var texture=_resource_icon(index)
		var area=Rect2(base+index*146+4,5,35,31)
		if texture==null:
			var color=SYMBOL_COLOR
			draw_circle(area.get_center(),8,color)
			draw_string(_font,area.position+Vector2(5,39),["아스","테라","인구"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,8,color)

func _unit_preview_rect() -> Rect2:
	var content=_detail_content_rect()
	var height=minf(76,content.size.y-50) if _uniform_shells[race] else 44.0
	if not _unit.is_empty() and _unit.has("progress") and not _unit.get("queue",[]).is_empty():height=minf(height,36)
	if not _unit.is_empty() and not _unit.has("progress") and _uses_energy(_definition):height=minf(height,content.size.y-70)
	return Rect2(content.position+Vector2(4,29),Vector2(84,height))

func _material_tint() -> Color:
	return [Color(.68,.68,.64),Color(.72,.63,.56),Color(.52,.56,.58)][race]

func _draw_segmented_meter(area: Rect2,current: float,total: float,color: Color) -> void:
	var count=clampi(ceili(total/20.0),1,maxi(1,mini(24,int(area.size.x/3))))
	var width=(area.size.x-count+1)/count
	var filled=clampf(current/maxf(1,total),0,1)*count
	for index in range(count):
		var cell=Rect2(area.position+Vector2(index*(width+1),0),Vector2(width,area.size.y))
		draw_rect(cell,Color("26312b"))
		var amount=clampf(filled-index,0,1)
		if amount>0:draw_rect(Rect2(cell.position,Vector2(cell.size.x*amount,cell.size.y)),color)

func _draw_fit(texture: Texture2D,area: Rect2) -> void:
	if texture==null or texture.get_width()<1 or texture.get_height()<1:return
	var factor=minf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	var dimensions=texture.get_size()*factor
	draw_texture_rect(texture,Rect2(area.get_center()-dimensions*.5,dimensions),false)

func _draw_cover(texture: Texture2D,area: Rect2) -> void:
	if texture==null or texture.get_width()<1 or texture.get_height()<1:return
	var factor=maxf(area.size.x/texture.get_width(),area.size.y/texture.get_height())
	var sample=area.size/factor
	draw_texture_rect_region(texture,area,Rect2((texture.get_size()-sample)*.5,sample))

func _is_brood_entity(entity: Dictionary) -> bool:
	return not entity.is_empty() and not entity.has("progress") and int(entity.race)==1 and int(entity.kind)==13

func _skill_tip(skill: Dictionary) -> String:
	var lines: Array[String]=[]
	var player: Dictionary=main.state.players[main.local_slot]
	if not ACAbilities.unlocked(player,skill):lines.append(str(ACData.building(int(skill.race),int(skill.building)).name)+" 연구 필요")
	if skill.id=="sap_heal":return "자동 치료 · 반경 4\n체력 초당 8 회복 · 마나 초당 4\n클릭하여 자동 치료 켜기/끄기"
	var cost="에너지 %d · "%int(skill.energy) if float(skill.energy)>0 else ""
	if float(skill.get("hp_cost",0))>0:cost+="체력 %d · "%int(skill.hp_cost)
	lines.append(cost+"사거리 %s · 재사용 %d초"%[_number(float(skill.range)),int(skill.cooldown)])
	lines.append(ACAbilities.description(str(skill.id)))
	return "\n".join(lines)

func _skill(key: String) -> void:
	var skill=ACAbilities.catalog(int(_unit.race),int(_unit.kind)).filter(func(d):return d.id==key)[0]
	if skill.target=="self":main._send_command({"type":"skill","skill":key,"ids":main.selected.duplicate(),"pos":_unit.pos})
	else:
		main.pointer_skill=key;_target_order("skill");main._notify(str(skill.name)+": 대상 지정 · 우클릭 취소")
