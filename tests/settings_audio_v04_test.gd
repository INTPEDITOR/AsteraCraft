extends SceneTree

class SettingsHost:
	extends Control
	var settings: Dictionary=ACSettings.defaults()
	var audio: ACAudio
	var saved: Dictionary={}
	func _set_setting(key: String,value,persist: bool=true) -> void:
		settings[key]=value
		settings=ACSettings.normalize(settings)
		audio.set_channel_volumes(float(settings.music_volume),float(settings.voice_volume),float(settings.sfx_volume))
		if persist:saved=settings.duplicate(true)

class PageControls:
	extends RefCounted
	func label(parent: Node,text: String,y: float,width=850,font_size=19,x=0.0) -> Label:
		var result:=Label.new()
		result.text=text
		result.position=Vector2(x,y)
		result.size=Vector2(width,36)
		result.add_theme_font_size_override("font_size",font_size)
		parent.add_child(result)
		return result
	func option(parent: Node,items: Array,x: float,y: float,width: float,index: int,action: Callable) -> OptionButton:
		var result:=OptionButton.new()
		result.position=Vector2(x,y)
		result.size=Vector2(width,44)
		for item in items:result.add_item(str(item))
		result.select(index)
		result.item_selected.connect(action)
		parent.add_child(result)
		return result
	func button(parent: Node,text: String,x: float,y: float,width: float,action: Callable,height=48) -> Button:
		var result:=Button.new()
		result.text=text
		result.position=Vector2(x,y)
		result.size=Vector2(width,height)
		result.pressed.connect(action)
		parent.add_child(result)
		return result

var checks:=0
var failures: Array=[]

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func bus_level(name: StringName) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(name)))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var old:=ACSettings.normalize({"volume":0.27,"fullscreen":true,"last_played_race":2})
	check(is_equal_approx(old.sfx_volume,.27) and old.window_mode=="fullscreen" and old.last_played_race==2,"legacy effects/fullscreen preferences migrate")
	var clean:=ACSettings.normalize({"edge_scroll_speed":999,"music_volume":-5,"voice_volume":2,"sfx_volume":NAN,"resolution":"broken","window_mode":"invalid"})
	check(clean.edge_scroll_speed==2.5 and clean.music_volume==0.0 and clean.voice_volume==1.0 and clean.sfx_volume==.65,"invalid preferences clamp safely")
	check(clean.resolution==[1600,900] and clean.window_mode=="windowed","invalid display preferences fall back safely")
	var audio:=ACAudio.new()
	root.add_child(audio)
	await process_frame
	audio.set_channel_volumes(.23,.45,0.0)
	check(is_equal_approx(bus_level(&"MUSIC"),.23) and is_equal_approx(bus_level(&"VOICE"),.45),"independent music and voice gains reach real AudioServer buses")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),"effects slider mutes real SFX bus")
	check(audio._voices[0].player.bus==&"SFX" and audio._music_player.bus==&"MUSIC" and audio._voice_player.bus==&"VOICE","players route to separate buses")
	var clip:=audio._stream("heal_medic")
	check(clip!=null and clip.get_length()>.6,"dedicated medical emitter WAV loads")
	check(audio.play_music(clip) and audio.play_voice(clip),"music and voice playback APIs use their actual players")
	audio.set_channel_volumes(0.0,.45,.8)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"MUSIC")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"VOICE")) and is_equal_approx(bus_level(&"SFX"),.8),"muting music preserves voice and effects")
	audio.clear()
	audio.set_paused(true)
	check(audio.play_ui("ready"),"UI click remains audible while local game is paused")
	check(not audio.play_unit(0,1,Vector2.ZERO),"paused battle does not start gunfire")
	audio.clear(true)
	var ui_alive:=false
	for voice in audio._voices:
		if voice.group=="ui" and voice.player.playing:ui_alive=true
	check(ui_alive,"menu transition preserves the initiating click")
	audio.clear()
	audio.set_paused(false)
	var host:=SettingsHost.new()
	host.audio=audio
	root.add_child(host)
	var panel:=ACSettingsPanel.new()
	host.add_child(panel)
	panel.configure(host,PageControls.new(),func():pass)
	check(panel.controls.has_all(["window_mode","resolution","edge_scroll","edge_scroll_speed","music_volume","voice_volume","sfx_volume"]),"settings exposes all requested controls")
	panel.controls.music_volume.value=.31
	panel.controls.voice_volume.value=.54
	panel.controls.sfx_volume.value=.42
	panel.controls.edge_scroll_speed.value=1.75
	check(is_equal_approx(bus_level(&"MUSIC"),.31) and is_equal_approx(bus_level(&"VOICE"),.54) and is_equal_approx(bus_level(&"SFX"),.42),"sliders update actual mix without reopening settings")
	check(host.saved.edge_scroll_speed==1.75,"scroll sensitivity changes persist through the controller")
	panel.controls.window_mode.item_selected.emit(1)
	check(host.settings.window_mode=="fullscreen" and panel.controls.resolution.disabled,"fullscreen uses monitor resolution and disables window-size control")
	panel.controls.window_mode.item_selected.emit(0)
	panel.controls.resolution.item_selected.emit(2)
	check(host.settings.resolution==[1600,900] and not panel.controls.resolution.disabled,"window resolution option sends the selected real size")
	var file:="user://settings-v04-%d.json"%Time.get_ticks_msec()
	check(ACSettings.save_file(host.saved,file),"settings file writes")
	var restored:=ACSettings.load_file(file)
	check(restored.resolution==[1600,900] and restored.edge_scroll_speed==1.75 and is_equal_approx(restored.music_volume,.31) and is_equal_approx(restored.voice_volume,.54) and is_equal_approx(restored.sfx_volume,.42),"display, scroll and all sound gains survive a full file round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	audio.clear()
	var medic:={"id":42,"kind":4,"race":0,"owner":0,"pos":[18,18],"fired":6.0,"healing":true,"heal_kind":"medic","heal_pulse":6.0}
	var heal:={"id":700,"type":"heal","unit":42,"race":0,"kind":4,"heal_kind":"medic","started":6.0,"until":6.45,"from":[18,18],"to":[19,18]}
	var state:={"time":6.0,"units":[medic],"effects":[heal]}
	var before:=int(audio.debug_stats.played)
	audio.process_state(state,0,Vector2(18,18),1.4)
	check(int(audio.debug_stats.played)==before+1 and audio.last_cue=="heal_medic","healing timestamp and effect produce exactly one medical cue")
	audio.process_state(state,0,Vector2(18,18),1.4)
	check(int(audio.debug_stats.played)==before+1,"repeated heal snapshot does not duplicate playback")
	check(not audio.play_unit(0,4,Vector2(18,18),"attack"),"medic cannot play a weapon attack cue")
	audio.clear()
	host.queue_free()
	audio.queue_free()
	await process_frame
	print("Settings/audio v0.4: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
