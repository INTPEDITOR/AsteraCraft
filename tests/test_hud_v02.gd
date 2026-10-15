extends SceneTree

const HUD=preload("res://scripts/rts_hud.gd")

class TestAudio extends RefCounted:
	var sounds: Array[String]=[]
	func play_ui(kind: String) -> void:sounds.append(kind)

class Harness extends Control:
	var state: Dictionary={}
	var assets=ACAssets.new()
	var audio=TestAudio.new()
	var selected: Array=[]
	var selected_resource=-1
	var world_resources: Array=[]
	var local_slot=0
	var build_panel=false
	var build_kind=-1
	var attack_mode=false
	var replay_mode=false
	var pointer_order=""
	var hud_signature=""
	var status_text=""
	var elapsed=0.0
	var status_until=0.0
	var commands: Array=[]
	func _entity(id: int) -> Dictionary:
		for collection in [state.units,state.buildings]:
			for entity in collection:
				if int(entity.id)==id:return entity
		return {}
	func _notify(text: String) -> void:status_text=text
	func _pause_menu() -> void:pass
	func _send_command(command: Dictionary) -> void:commands.append(command)
	func _selected_resource_data() -> Dictionary:
		for resource in state.get("resources",[]):
			if int(resource.id)==selected_resource:return resource
		return {}

func _initialize() -> void:
	call_deferred("_run")

func _color_channels(texture: Texture2D) -> Vector3:
	var pixels=texture.get_image()
	var channels=Vector3.ZERO
	for y in range(0,pixels.get_height(),5):
		for x in range(0,pixels.get_width(),5):
			var pixel=pixels.get_pixel(x,y)
			if pixel.a>.5:channels+=Vector3(pixel.r,pixel.g,pixel.b)
	return channels

func _run() -> void:
	# Render at exact pixel sizes without desktop DPI scaling or window limits.
	var stage=SubViewport.new()
	stage.size=Vector2i(1440,900)
	stage.transparent_bg=true
	stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var harness=Harness.new()
	harness.size=Vector2(1440,900)
	var hud_theme=Theme.new()
	hud_theme.default_font=load("res://assets/fonts/NotoSansKR-VF.ttf") if "--logic-only" in OS.get_cmdline_user_args() else preload("res://scripts/ui_font.gd").create()
	harness.theme=hud_theme
	stage.add_child(harness)
	harness.assets.load_all()
	var world_resource_pixels=load("res://assets/resources_v2.png").get_image()
	for index in range(2):
		var piece=world_resource_pixels.get_region(Rect2i(index*world_resource_pixels.get_width()/2,0,world_resource_pixels.get_width()/2,world_resource_pixels.get_height()))
		piece=piece.get_region(piece.get_used_rect())
		harness.world_resources.append(ImageTexture.create_from_image(piece))
	for race in range(3):
		harness.selected_resource=-1
		harness.state={"time":90,"players":[{"race":race,"as":9000,"tera":9000,"used":24,"reserved":0,"cap":200}],"units":[],"buildings":[],"resources":[{"id":7000,"type":"as","amount":1234,"initial_amount":1500,"pos":[20,20]},{"id":7001,"type":"tera","amount":4984,"initial_amount":5000,"pos":[30,30]}]}
		for kind in range(13):
			var definition=ACData.unit(race,kind)
			harness.state.units.append({"id":kind+1,"race":race,"kind":kind,"owner":0,"hp":definition.hp,"shield":definition.shield,"energy":200,"pos":[18,18],"anchored":false})
			var building=ACData.building(race,kind)
			harness.state.buildings.append({"id":100+kind,"race":race,"kind":kind,"owner":0,"hp":building.hp,"shield":building.shield,"progress":1.0,"queue":[],"research":"","larva":3})
		var hud=HUD.new()
		harness.add_child(hud)
		harness.selected=[1]
		hud.configure(harness)
		assert(hud.action_buttons.size()>=6,"worker cards")
		assert(hud._body_materials.size()==3,"each faction has its generated metal, bark or ivory background")
		assert(hud.resource_icons.size()==3,"the resource atlas contains only three dedicated icons")
		if race==1 and ResourceLoader.exists("res://assets/building_portrait_citrus_game_v4.png"):assert(hud.building_portraits[1].resource_path=="res://assets/building_portrait_citrus_game_v4.png","the painted single-eye citrus portrait takes priority over the discarded humanoid portrait")
		for symbol in hud.resource_symbols:
			assert(symbol.material==null,"dedicated resource icons retain their generated lighting")
			assert(symbol.texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"dedicated resource icon backgrounds are transparent")
			assert(symbol.texture.get_image().get_pixel(0,0).a==0,"resource icon corner pixels have fully transparent backgrounds")
		var catalyst: Texture2D=hud.resource_icons[1]
		assert(float(catalyst.get_width())/catalyst.get_height()<.75,"the catalyst icon contains only the vial, without a neighboring helmet edge")
		for button in hud.action_buttons:
			assert(button.get_theme_stylebox("normal") is StyleBoxEmpty,"the original shell supplies the button rim without a second PNG")
			for state_name in ["hover","pressed"]:assert(button.get_theme_stylebox(state_name) is StyleBoxFlat,"button feedback only shades the original command bay")
			for child in button.get_children():
				assert(Rect2(Vector2.ZERO,button.size).encloses(child.get_rect()),"glyph and hotkey remain in the measured original hole")
				if child is TextureRect:
					assert(child.material is ShaderMaterial,"action glyph uses brass silhouette material")
		assert(not hud.title_label.visible and not hud.subtitle_label.visible,"legacy overlapping race-name layers are hidden")
		var frame_path="res://assets/ui_hud_%d_native_v3.png"%race if hud._uniform_shells[race] else "res://assets/ui_hud_%d.png"%race
		assert(hud._frame_art.size()==3 and hud._frame_art[race].resource_path==frame_path,"approved faction frame supplies the armor, roots and feathers")
		assert(not hud.name_label.has_theme_font_override("font"),"HUD typography inherits the common game font")
		assert(hud.menu_button.get_rect().end.y<hud._portrait_frame_rect().position.y,"menu glyph and portrait occupy separate original holes")
		assert(hud.menu_button.text=="" and hud.menu_button.tooltip_text=="" and hud.menu_button.get_meta("help_title").contains("Esc"),"the narrow original menu uses a glyph and keeps its help inside the HUD")
		var event=InputEventKey.new()
		event.keycode=KEY_M
		event.pressed=true
		assert(hud.handle_hotkey(event),"move hotkey")
		assert(harness.pointer_order=="move","move pointer request")
		assert(harness.audio.sounds.back()=="confirm","command hotkeys play the same UI sound as clicks")
		event.keycode=KEY_NONE
		event.physical_keycode=KEY_M
		assert(hud.handle_hotkey(event) and harness.pointer_order=="move","physical hotkeys also work with an IME keyboard layout")
		event.keycode=KEY_M
		event.physical_keycode=KEY_UNKNOWN
		assert(hud.handle_hotkey(event) and harness.pointer_order=="move","an unknown physical key falls back to the valid Win32 logical key")
		harness.build_panel=true
		hud.update_hud(true)
		assert(hud.action_buttons.size()==12,"building first page 9+navigation")
		for index in range(9):
			var construction=InputEventKey.new()
			construction.pressed=true
			construction.physical_keycode=HUD.PAGE_KEYS[index]
			assert(hud.hover_hotkeys[HUD.PAGE_KEYS[index]].get_meta("spec").building_kind==HUD.BUILD_ORDERS[race][index],"each race displays the agreed common construction-role order")
			assert(hud.handle_hotkey(construction) and harness.build_kind==HUD.BUILD_ORDERS[race][index],"construction hotkeys dispatch the same building represented by their slot")
		harness.build_kind=-1
		for child in hud.hover_hotkeys[KEY_BRACKETLEFT].get_children():
			if child is TextureRect:assert(child.flip_h,"previous-page icon points left")
		for button in hud.action_buttons:
			var spec: Dictionary=button.get_meta("spec")
			if spec.cost.has("w"):
				for child in button.get_children():
					if child is TextureRect:assert(child.material is ShaderMaterial,"building image is brass silhouette")
		hud.command_page=1
		hud.update_hud(true)
		assert(hud.action_buttons.size()==7,"building second page 4+navigation")
		for index in range(4):
			var construction=InputEventKey.new()
			construction.pressed=true
			construction.physical_keycode=HUD.PAGE_KEYS[index]
			assert(hud.handle_hotkey(construction) and harness.build_kind==HUD.BUILD_ORDERS[race][index+9],"specialized and defensive buildings retain the same second-page keys")
		harness.build_kind=-1
		harness.build_panel=false
		harness.selected=range(1,14)
		hud.update_hud(true)
		assert(harness.selected.size()==12,"12 selection cap")
		assert(hud.selection_buttons.size()==12,"12 selection icons")
		assert(hud.selection_buttons.all(func(button):return button.size==Vector2(125,28)),"compact twelve-unit cards fit the original central window")
		assert(not hud.name_label.visible,"multi-selection reserves the entire original window for twelve icons")
		for button in hud.selection_buttons:assert(hud._detail_content_rect().encloses(button.get_rect()),"all twelve selected-unit cards stay inside the original central window")
		var hp=hud.selection_buttons[0].get_meta("hp_bar")
		var full_hp=float(hud.selection_buttons[0].get_meta("max_hp"))
		harness.state.units[0].hp=full_hp*.5
		hud.update_hud()
		assert(is_equal_approx(hp.value/hp.max_value,.5),"selection HP bar follows live damage")
		assert(hp.segment_count()==clampi(ceili(full_hp/20.0),1,24),"selection HP bar has separate 20-HP cells")
		assert(hud.minimap_rect().size.x==hud.minimap_rect().size.y,"minimap uses the largest square inside the original hole")
		assert(hud.view_rect().end.y==644,"battle viewport bottom")
		assert(not hud.blocks_world_input(Vector2(20,15)),"the unused top area remains playable terrain")
		assert(hud.blocks_world_input(Vector2(1400,15)),"the compact stockpile area still blocks world input")
		for button in hud.selection_buttons:
			var definition=ACData.unit(race,int(button.get_meta("entity_id"))-1)
			assert(button.has_meta("energy_bar")==hud._uses_energy(definition),"only actual mana users have a selection energy bar")
			if button.has_meta("energy_bar"):
				var mana=hud._max_energy(definition)*.25
				harness._entity(int(button.get_meta("entity_id"))).energy=mana
				hud.update_hud()
				assert(is_equal_approx(button.get_meta("energy_bar").value,mana),"selection mana updates live")
				assert(button.get_meta("energy_label").text==str(int(mana)),"selection mana includes its numeric remainder")
		for kind in range(13):
			harness.selected=[kind+1]
			hud.update_hud(true)
			assert(hud.action_buttons.size()>=3,"unit cards")
			var definition=ACData.unit(race,kind)
			var stats=hud.upgrade_badges.map(func(b):return b.get_meta("upgrade_stat"))
			assert(stats.has("attack")==bool(float(definition.get("damage",0))>0),"only actual attackers show an attack-upgrade badge")
			assert(stats.has("armor"),"ordinary units show their applied armor-upgrade level, including zero")
			assert(stats.has("shield")==bool(float(definition.get("shield",0))>0),"only units with shields show shield research")
			for badge in hud.upgrade_badges:assert(int(badge.get_meta("upgrade_level"))==0,"unresearched stats visibly remain level zero")
			harness.selected=[100+kind]
			hud.update_hud(true)
			if hud.building_portraits.size()==3:assert(hud._portrait==hud.building_portraits[race],"all thirteen buildings use their race's common architectural portrait")
		assert(hud.resources[0].text=="9000","As stockpile")
		assert(hud.resources[1].text=="9000","Tera stockpile")
		assert(hud.resources[2].text=="24 / 200","population")
		harness.state.players[0].used=200
		hud.update_hud()
		assert(hud._font.get_string_size(hud.resources[2].text,HORIZONTAL_ALIGNMENT_LEFT,-1,hud.resources[2].get_theme_font_size("font_size")).x<=hud.resources[2].size.x,"a full 200 / 200 count fits the compact top resource slot")
		harness.state.players[0].used=24
		harness.selected=[2]
		harness.state.players[0].attack=2
		harness.state.players[0].armor=1
		harness.state.players[0].shield=3
		hud.update_hud()
		for badge in hud.upgrade_badges:assert(int(badge.get_meta("upgrade_level"))==int(harness.state.players[0][badge.get_meta("upgrade_stat")]),"unit badges follow live research completion")
		var armor_badge=hud.upgrade_badges.filter(func(b):return b.get_meta("upgrade_stat")=="armor")[0]
		armor_badge.mouse_entered.emit()
		assert(hud.upgrade_layer.visible and hud.detail_label.text.contains("+"),"upgrade hover keeps its badge visible and explains the effective value inside the HUD")
		armor_badge.mouse_exited.emit()
		harness.state.players[0].attack=0
		harness.state.players[0].armor=0
		harness.state.players[0].shield=0
		harness.selected=[100]
		harness.state.buildings[0].queue=[{"kind":0,"left":8.0,"total":10.0},{"kind":1,"left":10.0,"total":10.0},{"kind":2,"left":10.0,"total":10.0},{"kind":0,"left":10.0,"total":10.0},{"kind":1,"left":10.0,"total":10.0}]
		hud.update_hud(true)
		assert(hud.queue_buttons.size()==5,"the central information bay has five total production slots")
		assert(hud.production_meter.visible and hud.production_meter.segment_count()==20,"production progress uses twenty separate cells")
		assert(hud.detail_label.get_line_count()==2,"queue statistics reserve their bottom row for progress without a third overlapping larva line")
		assert(is_equal_approx(hud.production_meter.value,.2),"the current production percentage follows its remaining time")
		for index in range(5):
			assert(hud._detail_content_rect().encloses(hud.queue_slot_rect(index)),"all five queue icons remain inside the native information window")
			if index<4:assert(not hud.queue_slot_rect(index).intersects(hud.queue_slot_rect(index+1)),"production slots do not overlap")
		hud.queue_buttons[2].pressed.emit()
		assert(harness.commands.back()=={"type":"cancel","id":100,"queue_index":2},"clicking a queue icon cancels that exact slot")
		for button in hud.action_buttons:
			if button.get_meta("spec").icon==HUD.ICON_TRAIN:assert(button.disabled and button.get_meta("help_text").contains("5"),"a full five-slot queue disables training and explains why")
		harness.state.buildings[0].queue.resize(1)
		hud.update_hud(true)
		assert(hud.queue_buttons.size()==5 and hud.queue_buttons[4].get_theme_stylebox("disabled") is StyleBoxEmpty,"unused queue positions never add default gray button backboards")
		harness.state.buildings[0].queue=[]
		hud.update_hud(true)
		assert(hud.queue_buttons.is_empty() and not hud.production_meter.visible,"production widgets clear after the queue empties")
		# Keep locked cards visible, with their price, key and missing technology.
		var stored_buildings=harness.state.buildings.duplicate(true)
		harness.state.buildings=harness.state.buildings.filter(func(b):return int(b.kind)==0)
		var found_locked=false
		for producer in stored_buildings:
			if found_locked:break
			if int(producer.kind)!=0:harness.state.buildings.append(producer)
			harness.selected=[producer.id]
			hud.command_page=0
			hud.update_hud(true)
			for button in hud.action_buttons:
				var cost: Dictionary=button.get_meta("spec").cost
				var missing=ACData.missing_building_names(race,cost.get("requires",[]),[0,int(producer.kind)])
				if not missing.is_empty():
					assert(button.disabled,"locked unit cards cannot be produced")
					assert(button.tooltip_text=="" and button.get_meta("help_text").contains(str(missing[0])) and button.get_meta("help_title").contains("[") and button.get_meta("help_text").contains(str(int(cost.get("as",0)))),"locked cards retain requirements, hotkeys and prices without a floating popup")
					button.mouse_entered.emit()
					assert(hud.detail_label.text.contains(str(missing[0])) and not hud.queue_layer.visible,"hover conditions occupy the fixed central bay without overlapping the production queue")
					button.mouse_exited.emit()
					found_locked=true
					break
			if int(producer.kind)!=0:harness.state.buildings.pop_back()
		assert(found_locked,"every race exposes its technology-locked production cards")
		harness.state.buildings=stored_buildings
		for building in harness.state.buildings:
			harness.selected=[building.id]
			hud.update_hud(true)
			if not hud._can_rally():assert(not hud.hover_hotkeys.has(KEY_R),"non-producing structures never advertise a rally command")
			if hud.armor_upgrade_icon!=null:
				for button in hud.action_buttons:
					var spec=button.get_meta("spec")
					if spec.cost.get("research_stat","")=="armor":assert(spec.texture==hud.armor_upgrade_icon,"armor research uses its dedicated generated icon")
		if race==1:
			var pod={"id":500,"race":1,"kind":13,"owner":0,"hp":60.0,"shield":0.0,"energy":0.0,"pos":[18,18],"brood_parent":100,"brood_state":"idle","morph_kind":-1,"morph_left":0.0,"morph_total":0.0}
			harness.state.units.append(pod)
			harness.selected=[500]
			hud.command_page=0
			hud.update_hud(true)
			assert(hud._definition.role=="brood" and hud.upgrade_badges.is_empty(),"technical brood has its own production information rather than army stats")
			assert(not hud.hover_hotkeys.has(KEY_R) and not hud.hover_hotkeys.has(KEY_M),"an anchored brood never shows move or rally actions")
			hud.hover_hotkeys[KEY_Q].pressed.emit()
			assert(harness.commands.back()=={"type":"morph","id":500,"kind":0},"selecting a specific brood morphs that exact entity")
			pod.brood_state="morph"
			pod.morph_kind=2
			pod.morph_left=4.0
			pod.morph_total=10.0
			hud.update_hud()
			assert(hud.production_meter.visible and is_equal_approx(hud.production_meter.value,.6),"an individual egg shows its own live morph progress")
			assert(hud.action_buttons.size()==1 and hud.hover_hotkeys.has(KEY_X),"a morphing egg only exposes its cancellation command")
			hud.hover_hotkeys[KEY_X].pressed.emit()
			assert(harness.commands.back()=={"type":"cancel_morph","id":500},"egg cancellation targets the selected brood")
			pod.kind=2
			hud.update_hud()
			assert(not hud._is_brood() and hud.hover_hotkeys.has(KEY_M),"finishing a same-ID morph immediately replaces egg commands with the completed unit's actions")
			pod.kind=13
		harness.selected=[100]
		hud.update_hud(true)
		assert(hud.hover_hotkeys.has(KEY_R),"headquarters advertises R for rally")
		assert(hud.hover_hotkeys[KEY_R].get_meta("spec").icon==HUD.ICON_RALLY,"R is reserved for rally in production cards")
		harness.attack_mode=true
		var rally=InputEventKey.new()
		rally.keycode=KEY_R
		rally.pressed=true
		assert(hud.handle_hotkey(rally),"rally hotkey is handled once")
		assert(harness.pointer_order=="rally" and not harness.attack_mode,"rally and attack target modes cannot remain active together")
		if race in [0,1]:
			harness.selected=[105] if race==0 else [100]
			hud.update_hud(true)
			assert(hud.hover_hotkeys.has(KEY_T),"the fourth production option uses T without colliding with R")
			assert(hud.hover_hotkeys[KEY_T].get_meta("spec").icon==HUD.ICON_TRAIN,"T remains a production card")
		harness.selected=[]
		harness.selected_resource=7000
		hud.update_hud(true)
		assert(hud.name_label.text=="아스 광물","As selection shows its resource name")
		assert(hud.detail_label.text.contains("1234") and hud.detail_label.text.contains("1500"),"resource card shows remaining and initial quantities")
		assert(hud.action_buttons.is_empty() and hud.hover_hotkeys.is_empty() and hud.selection_buttons.is_empty(),"resource cards cannot issue unit commands or production")
		assert(hud._unit.is_empty() and hud._definition.is_empty(),"resources never masquerade as units or buildings")
		assert(hud._unit_icon==harness.world_resources[0],"resource detail reuses the actual world crystal art")
		var gold=_color_channels(hud._unit_icon)
		assert(gold.x>gold.z*1.2 and gold.y>gold.z*1.1,"As detail art is gold, never legacy blue crystals")
		var actual_world_art=harness.world_resources
		harness.world_resources=[]
		hud.update_hud()
		assert(hud._unit_icon==hud.resource_icons[0],"missing world art falls back to the dedicated gold icon")
		harness.world_resources=actual_world_art
		hud.update_hud()
		assert(hud.detail_label.get_visible_line_count()>=hud.detail_label.get_line_count(),"all resource text lines fit inside the native faction window")
		var resource_attack=InputEventKey.new()
		resource_attack.pressed=true
		resource_attack.keycode=KEY_A
		assert(not hud.handle_hotkey(resource_attack),"resource selection has no attack hotkey")
		harness.state.resources[0].amount=1200
		hud.update_hud()
		assert(hud.detail_label.text.contains("1200") and hud.detail_label.text.contains("1500"),"live depletion updates while initial quantity stays fixed")
		harness.selected_resource=7001
		hud.update_hud()
		assert(hud.name_label.text=="테라 가스 촉매" and hud.description_label.text.contains("자동 추출"),"Tera card explains automatic refinery extraction")
		assert(hud._unit_icon==harness.world_resources[1],"resource detail reuses the actual world catalyst art")
		var blue=_color_channels(hud._unit_icon)
		assert(blue.z>blue.x*1.2,"Tera detail art is blue, never legacy green fumes")
		harness.state.resources[1].amount=0
		hud.update_hud()
		assert(hud.detail_label.text.contains("남은 양  0") and hud.detail_label.text.contains("5000") and hud.description_label.text.contains("소진"),"depleted resources retain their original quantity")
		harness.selected_resource=-1
		harness.selected=[101]
		harness.state.buildings[1].tera_resource=7001
		hud.update_hud(true)
		assert(hud.detail_label.text.contains("테라 남은 양  0") and hud.detail_label.text.contains("초기 총량  5000"),"a selected refinery also shows its linked deposit")
		assert(hud.detail_label.text.contains("추출 중지"),"a depleted refinery reports extraction has stopped")
		harness.state.buildings[1].tera_resource=-1
		harness.state.buildings[1].pos=[29,29]
		hud.update_hud()
		assert(hud.detail_label.text.contains("초기 총량  5000"),"legacy refineries find the catalyst inside their footprint")
		harness.selected=[1]
		hud.update_hud(true)
		assert(not hud.action_buttons.is_empty() and hud._resource.is_empty(),"unit commands return after leaving resource selection")
		assert(hud.name_label.get_theme_color("font_color")==Color("e5e9e5"),"unit names restore their normal color after a resource card")
		harness.selected=[]
		hud.update_hud(true)
		assert(not hud.name_label.visible and hud.detail_label.text=="" and hud.description_label.text=="" and hud.action_buttons.is_empty(),"an empty selection leaves the original bay empty without generic instructions")
		for resolution in [Vector2(1280,720),Vector2(1440,900),Vector2(1920,1080),Vector2(2560,1080)]:
			stage.size=Vector2i(resolution)
			harness.size=resolution
			harness.selected=[1]
			harness.build_panel=true
			hud.update_hud(true)
			var panel: Rect2=hud._command_frame_rect()
			for index in range(12):
				var slot: Rect2=hud.command_slot_rect(index)
				assert(slot.size.x>45 and slot.size.y>25,"original command bay retains enough room for a glyph and keycap")
				assert(panel.grow(.01).encloses(slot),"command cell stays in its original panel")
				for next in range(index+1,12):assert(not slot.intersects(hud.command_slot_rect(next)),"command cells never overlap")
			for button in hud.action_buttons:
				var slot: Rect2=hud.command_slot_rect(int(button.get_meta("slot")))
				assert(button.get_rect().is_equal_approx(slot),"button exactly matches its command cell: %s / %s"%[str(button.get_rect()),str(slot)])
			assert(not hud._detail_frame_rect().intersects(hud._portrait_frame_rect()),"detail and portrait panels never overlap")
			assert(not hud._portrait_frame_rect().intersects(panel),"portrait and command panels never overlap")
			assert(hud._minimap_frame_rect().grow(.01).encloses(hud.minimap_rect()),"minimap never covers the original shell ornament")
			if hud._uniform_shells[race]:
				var crop: Rect2i=hud._frame_source_regions[race]
				var drawn: Rect2=hud.shell_draw_rect()
				assert(is_equal_approx(drawn.size.x/crop.size.x,drawn.size.y/crop.size.y),"the new native banner is scaled uniformly with no axis stretching")
			for frame in [hud._detail_frame_rect(),hud._portrait_frame_rect(),panel,hud._minimap_frame_rect(),hud._menu_rect()]:
				assert(hud.shell_draw_rect().grow(.01).encloses(frame),"original content apertures remain inside the actual banner drawing")
			if race==2:
				var empty_cover=hud._unused_menu_cover_rect()
				assert(empty_cover.has_area() and not empty_cover.intersects(hud._menu_rect()) and not empty_cover.intersects(hud._portrait_rect()) and not empty_cover.intersects(panel),"only the owl's two unused painted menu slots are covered by matching ivory material")
			assert(not Geometry2D.triangulate_polygon(hud._body_outline).is_empty(),"the original alpha contour forms one valid continuous HUD body")
			for screen_x in range(0,int(resolution.x),37):
				var contour=Vector2(screen_x+.5,hud.body_top_at(screen_x+.5))
				assert(not hud.blocks_world_input(contour-Vector2(0,2)),"terrain cutouts above the original silhouette accept world input")
				assert(hud.blocks_world_input(contour+Vector2(0,2)),"the body below the same contour blocks world input")
				assert(hud.blocks_world_input(Vector2(screen_x+.5,resolution.y-1)),"the entire bottom edge blocks world input")
			for area in [hud._detail_frame_rect(),hud._portrait_rect(),hud.minimap_rect(),hud._menu_rect()]:
				assert(hud.blocks_world_input(area.get_center()),"live information windows cannot click through to hidden units")
			harness.selected=range(1,13)
			hud.update_hud(true)
			for button in hud.selection_buttons:assert(hud._detail_content_rect().grow(.01).encloses(button.get_rect()),"twelve selection cards fit even at 1280 pixels")
			if resolution.x>1440:assert(hud.selection_buttons[0].size.x>125 and hud.selection_buttons[0].size.y>28,"large viewports scale selection icons, labels and bars together within the original bay")
			harness.selected=[1]
			hud.update_hud(true)
			assert(hud.name_label.position.y>=0 and hud.name_label.get_rect().end.y<hud.detail_layer.size.y,"the name has positive top padding and is not clipped")
		stage.size=Vector2i(1440,900)
		harness.size=Vector2(1440,900)
		harness.build_panel=false
		if "--capture" in OS.get_cmdline_user_args():
			var resolutions=[Vector2i(1440,900)] if "--sample" in OS.get_cmdline_user_args() else [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1080)]
			for resolution in resolutions:
				stage.size=resolution
				harness.size=Vector2(resolution)
				var views=["single","multi","build","production","resource-as","resource-tera","energy","locked","upgraded","empty","research"]
				if "--sample" in OS.get_cmdline_user_args():views=["single","production","energy","locked","upgraded","research"]
				if race==1:views.append_array(["brood-idle","brood-morph"])
				for view in views:
					harness.state.buildings=stored_buildings.duplicate(true)
					hud._hover_help={}
					harness.state.players[0].attack=2 if view=="upgraded" else 0
					harness.state.players[0].armor=1 if view=="upgraded" else 0
					harness.state.players[0].shield=3 if view=="upgraded" else 0
					harness.selected=range(1,13) if view=="multi" else ([100] if view=="production" else ([1] if view=="build" else [2]))
					harness.selected_resource=-1
					if view=="empty":harness.selected=[]
					if view=="research":harness.selected=[105 if race==1 else 106]
					if view=="production":harness.state.buildings[0].queue=[{"kind":0,"left":6.0,"total":10.0},{"kind":1,"left":10.0,"total":10.0},{"kind":2,"left":10.0,"total":10.0},{"kind":0,"left":10.0,"total":10.0},{"kind":1,"left":10.0,"total":10.0}]
					if view=="energy":
						for unit in harness.state.units:
							if hud._uses_energy(ACData.unit(race,int(unit.kind))):
								harness.selected=[unit.id]
								unit.energy=75
								break
					if view.begins_with("brood-"):
						harness.selected=[500]
						var pod=harness._entity(500)
						pod.brood_state="morph" if view=="brood-morph" else "idle"
						pod.morph_kind=2
						pod.morph_left=4.0
						pod.morph_total=10.0
					if view.begins_with("resource-"):
						harness.selected=[]
						harness.selected_resource=7000 if view=="resource-as" else 7001
						harness.state.resources[1].amount=4984
					harness.build_panel=view=="build"
					hud.update_hud(true)
					if view=="locked":
						var hover_button: Button
						for producer in stored_buildings:
							harness.state.buildings=[producer]
							harness.selected=[producer.id]
							hud.command_page=0
							hud.update_hud(true)
							for button in hud.action_buttons:
								if button.get_meta("help_text").contains("필요 건물"):
									hover_button=button
									break
							if hover_button!=null:break
						assert(hover_button!=null,"a locked production card is available for the fixed-help capture")
						hover_button.mouse_entered.emit()
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var capture=stage.get_texture().get_image()
					assert(capture.get_size()==resolution,"GPU capture uses the exact requested resolution")
					assert(capture.get_pixel(resolution.x-468,1).a<.01,"resource counters have no background strip, only transparent icons and shadowed text")
					if view.begins_with("resource-"):
						assert(hud.detail_label.get_visible_line_count()>=hud.detail_label.get_line_count(),"resource labels fit at both native banner resolutions")
						assert(hud.action_buttons.is_empty(),"no unit action cards appear for either resource")
					if view in ["single","energy","production","locked","upgraded","brood-idle","brood-morph"]:
						assert(hud.name_label.position.y>=0,"HUD headings have no negative offset")
						assert(hud.detail_label.get_visible_line_count()>=hud.detail_label.get_line_count(),"every HUD detail line fits the actual native window at all four resolutions")
					for button in hud.action_buttons+hud.selection_buttons+hud.queue_buttons+hud.upgrade_badges:assert(button.tooltip_text=="","the HUD never creates a floating tooltip popup")
					var outside_frame=Vector2i(resolution.x/2,floori(hud.shell_draw_rect().position.y)-2)
					assert(capture.get_pixelv(outside_frame).a<.1,"the original shell exterior remains transparent, with no black backboard")
					var inset_probe=Vector2i(hud._detail_content_rect().end-Vector2(4,4))
					var crop: Rect2i=hud._frame_source_regions[race]
					var source_point=Vector2(crop.position)+(Vector2(inset_probe)+Vector2(.5,.5)-hud.shell_draw_rect().position)/hud.shell_draw_rect().size*Vector2(crop.size)
					var original=hud._frame_art[race].get_image().get_pixelv(Vector2i(source_point))
					var actual=capture.get_pixelv(inset_probe)
					assert(absf(original.r-actual.r)+absf(original.g-actual.g)+absf(original.b-actual.b)<.12,"the functional information window retains its native background without a material overlay")
					for screen_x in range(resolution.x):assert(capture.get_pixel(screen_x,resolution.y-1).a>.99,"the entire screen bottom is covered by one continuous HUD body")
					for screen_x in range(0,resolution.x,37):
						var below=mini(resolution.y-1,ceili(hud.body_top_at(screen_x+.5)+2))
						assert(capture.get_pixel(screen_x,below).a>.99,"the body below the source contour fully occludes the world")
					capture.save_png("res://build/v4-hud-race%d-%dx%d-%s.png"%[race,resolution.x,resolution.y,view])
					if resolution.x==1440 and view=="single":capture.save_png("res://build/preview-hud%d.png"%race)
			stage.size=Vector2i(1440,900)
			harness.size=Vector2(1440,900)
			harness.build_panel=false
		harness.remove_child(hud)
		hud.free()
	print("HUD v0.4 PASS: native shells/backplate-only, 1280/1440/1920/2560 bounds, 5-slot production and individual cancel, segmented progress/HP/energy, locked cards with fixed HUD help, no floating tooltips, physical hotkeys and UI sounds")
	harness.free()
	stage.free()
	quit(0)
