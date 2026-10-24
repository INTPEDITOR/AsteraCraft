class_name ACSettings
extends RefCounted

const FILE := "user://settings.json"
const RESOLUTIONS := [[1280,720],[1440,900],[1600,900],[1920,1080],[2560,1440],[3840,2160]]
const WINDOW_MODES := ["windowed","fullscreen","borderless"]
const GAME_CANVAS := Vector2i(1600,900)

static func keep_game_aspect() -> void:
	var tree=Engine.get_main_loop() as SceneTree
	if tree==null:return
	var window=tree.root
	window.content_scale_size=GAME_CANVAS
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP

static func defaults() -> Dictionary:
	return {"edge_scroll":true,"edge_scroll_speed":1.0,"fullscreen":false,"window_mode":"windowed","resolution":[1600,900],"volume":0.65,"sfx_volume":0.65,"music_volume":0.60,"voice_volume":0.80,"last_played_race":0}

static func number(value, fallback: float) -> float:
	if not value is float and not value is int:
		return fallback
	var result := float(value)
	return result if is_finite(result) else fallback

static func normalize(stored: Dictionary) -> Dictionary:
	var value := defaults()
	value.merge(stored,true)
	if not stored.has("sfx_volume"):
		value.sfx_volume = number(stored.get("volume",0.65),0.65)
	for key in ["music_volume","voice_volume","sfx_volume"]:
		value[key] = clampf(number(value[key],float(defaults()[key])),0.0,1.0)
	value.volume = value.sfx_volume # Legacy effect-volume preference.
	value.edge_scroll = bool(value.edge_scroll)
	value.edge_scroll_speed = clampf(number(value.edge_scroll_speed,1.0),0.25,2.5)
	if not stored.has("window_mode"):
		value.window_mode = "fullscreen" if bool(stored.get("fullscreen",false)) else "windowed"
	if str(value.window_mode) not in WINDOW_MODES:
		value.window_mode = "windowed"
	value.fullscreen = value.window_mode != "windowed"
	var resolution = value.get("resolution",[1600,900])
	if not resolution is Array or resolution.size()!=2:
		resolution = [1600,900]
	var width := int(number(resolution[0],1600.0))
	var height := int(number(resolution[1],900.0))
	value.resolution = [clampi(width,960,7680),clampi(height,600,4320)]
	value.last_played_race = clampi(int(number(value.get("last_played_race",0),0.0)),0,2)
	return value

static func load_file(filename: String = FILE) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return defaults()
	var stored = JSON.parse_string(FileAccess.get_file_as_string(filename))
	return normalize(stored) if stored is Dictionary else defaults()

static func save_file(value: Dictionary, filename: String = FILE) -> bool:
	var file := FileAccess.open(filename,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(normalize(value)))
	file.flush()
	return true

static func apply_display(value: Dictionary) -> void:
	keep_game_aspect()
	if DisplayServer.get_name()=="headless":
		return
	var clean := normalize(value)
	var screen := DisplayServer.window_get_current_screen()
	if clean.window_mode=="fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif clean.window_mode=="borderless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
		DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,false)
		var extent := Vector2i(int(clean.resolution[0]),int(clean.resolution[1]))
		DisplayServer.window_set_size(extent)
		var usable := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(usable.position+Vector2i(maxi(0,(usable.size.x-extent.x)/2),maxi(0,(usable.size.y-extent.y)/2)))
