class_name ACAudio
extends Node
## Spatial RTS sound mixer. Call process_state once per displayed snapshot/frame.
## World positions and camera are build-grid coordinates, as in ACCore.

const VOICE_COUNT := 20
const COMBAT_LIMIT := 12
const PCM_RATE := 44100
const BUS_MUSIC := &"MUSIC"
const BUS_VOICE := &"VOICE"
const BUS_SFX := &"SFX"

var master_volume := 0.75
var music_volume := 0.60
var voice_volume := 0.80
var isometric_projection := false
var enabled := true
var _paused := false
var _voices: Array = []
var _streams: Dictionary = {}
var _seen_effects: Dictionary = {}
var _fired_marks: Dictionary = {}
var _mining_marks: Dictionary = {}
var _healing_marks: Dictionary = {}
var _construction_marks: Dictionary = {}
var _ui_marks: Dictionary = {}
var _entities: Dictionary = {}
var _camera := Vector2.ZERO
var _zoom := 1.0
var _last_time := -1.0
var _clean_at := 0.0
var _listener: AudioListener2D
var _music_player: AudioStreamPlayer
var _music_fade_player: AudioStreamPlayer
var _music_tween: Tween
var _music_tracks: Dictionary={}
var _music_streams: Dictionary={}
var current_music_name := ""
var requested_music_name := ""
var music_directories: Array=[]
var _voice_player: AudioStreamPlayer
var _serial := 0
var last_cue := ""
var director
var debug_stats := {"played": 0, "culled": 0, "duplicates": 0, "stolen": 0, "missing": 0}

func _ready() -> void:
	_ensure_buses()
	_listener = AudioListener2D.new()
	add_child(_listener)
	_listener.make_current()
	for i in range(VOICE_COUNT):
		var player := AudioStreamPlayer2D.new()
		player.name = "SFX%d" % i
		player.bus = BUS_SFX
		player.max_distance = 2400.0
		# Distance is shaped below around the camera. Native 2D panning remains active.
		player.attenuation = 0.01
		player.panning_strength = 0.8
		add_child(player)
		_voices.append({"player": player, "priority": 0, "started": 0.0, "group": ""})
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_music_fade_player = AudioStreamPlayer.new()
	_music_fade_player.name = "MusicFade"
	_music_fade_player.bus = BUS_MUSIC
	add_child(_music_fade_player)
	if FileAccess.file_exists("res://assets/music/manifest.json"):
		var music_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/manifest.json"))
		if music_manifest is Dictionary:
			for track in music_manifest.get("tracks",[]):_music_tracks[str(track.file).get_basename()]=track
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "Voice"
	_voice_player.bus = BUS_VOICE
	add_child(_voice_player)
	set_channel_volumes(music_volume,voice_volume,master_volume)
	director=load("res://scripts/voice_director.gd").new()
	director.mixer=self
	add_child(director)

func set_volume(linear: float) -> void:
	# Legacy API controls the SFX bus, including existing in-flight effects.
	set_channel_volumes(music_volume,voice_volume,linear)

func _ensure_buses() -> void:
	for bus in [BUS_MUSIC,BUS_VOICE,BUS_SFX]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,&"Master")

func set_channel_volumes(music: float, voice: float, effects: float) -> void:
	_ensure_buses()
	music_volume = clampf(music,0.0,1.0)
	voice_volume = clampf(voice,0.0,1.0)
	master_volume = clampf(effects,0.0,1.0)
	var levels := {BUS_MUSIC:music_volume,BUS_VOICE:voice_volume,BUS_SFX:master_volume}
	for bus in levels:
		var index := AudioServer.get_bus_index(bus)
		var value := float(levels[bus])
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,value)))
		AudioServer.set_bus_mute(index,value<=0.0001)

func play_music(stream: AudioStream, level: float=0.8) -> bool:
	if stream==null or not enabled or _music_player==null:
		return false
	stop_music()
	_music_player.stream=stream
	_music_player.volume_db=linear_to_db(clampf(level,0.0001,1.0))
	_music_player.play()
	return true

func stop_music() -> void:
	if _music_tween!=null and _music_tween.is_valid():_music_tween.kill()
	if _music_player!=null:_music_player.stop()
	if _music_fade_player!=null:_music_fade_player.stop()
	current_music_name=""

func _music_gain(value: float, player: AudioStreamPlayer) -> void:
	player.volume_db=linear_to_db(maxf(.0001,value))

func music_source(name: String) -> Dictionary:
	# User-supplied embedded tracks can be replaced beside the EXE
	# without rebuilding the PCK, or keep a personal override in user://music.
	var folders := [OS.get_executable_path().get_base_dir().path_join("music"),"user://music","res://assets/music"]
	if not music_directories.is_empty():folders=music_directories
	for folder in folders:
		for extension in ["ogg","mp3","wav"]:
			var path:=str(folder).path_join(name+"."+extension)
			var embedded:=str(folder).begins_with("res://")
			if FileAccess.file_exists(path) or (embedded and _music_tracks.has(name) and ResourceLoader.exists(path)):
				return {"path":path,"extension":extension,"embedded":embedded}
	return {}

func _music_stream(name: String) -> AudioStream:
	if _music_streams.has(name):return _music_streams[name]
	var source:=music_source(name)
	if source.is_empty():return null
	var stream: AudioStream
	if bool(source.embedded) and ResourceLoader.exists(str(source.path)):
		var resource=ResourceLoader.load(str(source.path))
		if resource is AudioStream:stream=resource.duplicate()
	elif source.extension=="mp3":
		var mp3:=AudioStreamMP3.new()
		mp3.data=FileAccess.get_file_as_bytes(str(source.path))
		stream=mp3
	elif source.extension=="ogg":
		stream=AudioStreamOggVorbis.load_from_file(str(source.path))
	else:
		stream=AudioStreamWAV.load_from_file(str(source.path))
	if stream==null or stream.get_length()<=0:return null
	if stream is AudioStreamWAV:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop=true
		stream.loop_offset=0.0
	_music_streams[name]=stream
	return stream

func set_music_context(race: int=-1, fade_seconds: float=1.4) -> bool:
	if not enabled or _music_player==null:return false
	var name:="music_menu" if race<0 else "music_r%d"%clampi(race,0,2)
	requested_music_name=name
	if current_music_name==name and _music_player.playing:return true
	var stream:=_music_stream(name)
	if stream==null:
		stop_music()
		return false
	if _music_tween!=null and _music_tween.is_valid():_music_tween.kill()
	var previous:=_music_player
	_music_player=_music_fade_player
	_music_fade_player=previous
	_music_player.stop()
	_music_player.stream=stream
	_music_player.volume_db=-80.0
	_music_player.play()
	current_music_name=name
	var duration:=maxf(.02,fade_seconds)
	_music_tween=create_tween().set_parallel(true)
	_music_tween.tween_method(Callable(self,"_music_gain").bind(_music_player),0.0,.78,duration)
	_music_tween.tween_method(Callable(self,"_music_gain").bind(previous),db_to_linear(previous.volume_db),0.0,duration)
	_music_tween.chain().tween_callback(previous.stop)
	return true

func play_voice(stream: AudioStream, level: float=0.8) -> bool:
	if stream==null or not enabled or _voice_player==null or _paused:
		return false
	_voice_player.stream=stream
	_voice_player.volume_db=linear_to_db(clampf(level,0.0001,1.0))
	_voice_player.play()
	return true

func set_paused(value: bool) -> void:
	_paused = value
	if director!=null:
		director.unit_player.stream_paused=value
		director.announcer.stream_paused=value
	for voice in _voices:
		voice.player.stream_paused = value and voice.group!="ui"
	if _voice_player!=null:_voice_player.stream_paused=value

func clear(keep_ui: bool=false) -> void:
	if director!=null:director.reset()
	for voice in _voices:
		if not keep_ui or voice.group!="ui":voice.player.stop()
	if _voice_player!=null:_voice_player.stop()
	if not keep_ui:stop_music()
	_seen_effects.clear()
	_fired_marks.clear()
	_mining_marks.clear()
	_healing_marks.clear()
	_construction_marks.clear()
	_ui_marks.clear()
	_entities.clear()
	_last_time = -1.0

func process_state(state: Dictionary, local_slot: int, camera: Vector2, zoom: float) -> void:
	if not enabled or _paused or state.is_empty():
		return
	var now := float(state.get("time", 0.0))
	if _last_time >= 0.0 and now < _last_time - 0.01:
		clear(true) # Replay seeks reset effects while the independent score continues.
	_camera = camera
	_zoom = clampf(zoom, 0.3, 2.0)
	if is_equal_approx(now,_last_time):return
	if director!=null:director.scan(state,local_slot)
	_zoom = clampf(zoom, 0.3, 2.0)
	_entities.clear()
	for key in ["units", "buildings"]:
		for entity in state.get(key, []):
			_entities[int(entity.get("id", -1))] = entity
	_construction_sounds(state.get("buildings",[]),now)
	# Fired timestamps survive a dropped snapshot, unlike a short projectile effect.
	for entity in _entities.values():
		var id := int(entity.get("id", -1))
		var heal_pulse := float(entity.get("heal_pulse",-99.0))
		if bool(entity.get("healing",false)) and heal_pulse>=0.0 and heal_pulse>float(_healing_marks.get(id,-99.0)):
			_healing_marks[id]=heal_pulse
			if now-heal_pulse<=0.8:play_heal(str(entity.get("heal_kind","medic")),_center(entity),int(entity.get("race",0)))
		var fired := float(entity.get("fired", -99.0))
		if fired < 0.0 or fired <= float(_fired_marks.get(id, -99.0)):
			continue
		_fired_marks[id] = fired
		if now - fired <= 0.65 and int(entity.get("container", -1)) < 0:
			var kind := _weapon_kind(entity)
			play_unit(int(entity.get("race", 0)), kind, _center(entity), "attack")
	consume_effects(state.get("effects", []), now)
	# Mining is audible when the worker is operating the tool beside its deposit.
	# This also supports older snapshots that have no explicit harvest events.
	for entity in state.get("units", []):
		if int(entity.get("kind", -1)) != 0 or int(entity.get("container", -1)) >= 0:
			continue
		if int(entity.get("owner", -1)) != local_slot and not bool(entity.get("visible", true)):
			continue
		var action := str(entity.get("action", ""))
		var mining := action in ["gather", "mine", "mining", "harvest"]
		mining = mining or (str(entity.get("order", "")) == "gather" and not bool(entity.get("moving", false)) and float(entity.get("gather_clock", 0.0)) > 0.04 and int(entity.get("carried", 0)) == 0)
		if mining:
			var id := int(entity.get("id", -1))
			if now >= float(_mining_marks.get(id, -1.0)):
				_mining_marks[id] = now + 0.68 + float(posmod(id * 17, 11)) * 0.013
				play_mining(int(entity.get("race", 0)), _center(entity))
	if now >= _clean_at:
		_clean_at = now + 3.0
		for key in _seen_effects.keys():
			if float(_seen_effects[key]) < now - 2.0:
				_seen_effects.erase(key)
		for id in _fired_marks.keys():
			if not _entities.has(id):
				_fired_marks.erase(id)
		for id in _mining_marks.keys():
			if not _entities.has(id):
				_mining_marks.erase(id)
		for id in _healing_marks.keys():
			if not _entities.has(id):_healing_marks.erase(id)
	_last_time = now

func _construction_sounds(buildings: Array, now: float) -> void:
	var present={}
	for building in buildings:
		var id=int(building.get("id",-1));present[id]=true
		if building.get("remembered",false) or not building.get("visible",true) or float(building.get("hp",0))<=0:continue
		var progress=float(building.get("progress",1));var old: Dictionary=_construction_marks.get(id,{})
		var race=clampi(int(building.get("race",0)),0,2)
		if progress>=1:
			if not old.is_empty() and float(old.progress)<1:_play_at("construct_complete_%d"%race,_center(building),.28,1,"construction")
		elif old.is_empty() or (progress>float(old.progress)+.000001 and now>=float(old.next)):
			_play_at("construct_%d"%race,_center(building),.31,1,"construction")
			old.next=now+1.8+float(posmod(id,5))*.08
		_construction_marks[id]={"progress":progress,"next":old.get("next",now+1.8)}
	for id in _construction_marks.keys():
		if not present.has(id):_construction_marks.erase(id)

func consume_effects(effects: Array, now: float) -> void:
	if not enabled or _paused:
		return
	for effect in effects:
		var type := str(effect.get("type", ""))
		var key := _effect_key(effect)
		if _seen_effects.has(key):
			debug_stats.duplicates += 1
			continue
		_seen_effects[key] = float(effect.get("until", now + 0.5))
		var source := _source_entity(effect)
		var position := _point(effect.get("from", effect.get("to", [0, 0])))
		var race := int(effect.get("race", source.get("race", 0)))
		var kind := int(effect.get("kind", effect.get("unit_kind", source.get("kind", -1))))
		if type in ["shot", "projectile", "attack", "melee"]:
			# The unit timestamp was already consumed above. Multiple splash victims
			# share one muzzle report, even with older per-hit effect snapshots.
			if not source.is_empty() and now - float(source.get("fired", -99.0)) <= 0.65:
				continue
			if not source.is_empty():
				kind = _weapon_kind(source)
			if kind < 0:
				kind = [1, 2, 2][clampi(race, 0, 2)]
			play_unit(race, kind, position, "attack")
		elif type in ["explosion", "death", "destroy"]:
			var fatal=bool(effect.get("fatal",false)) or type=="death"
			var death_race=clampi(race,0,2)
			var cue="death_%d_%d"%[death_race,clampi(kind,0,ACData.unit_count(death_race)-1)] if fatal and not effect.get("source_building",false) else "explosion_%d"%death_race
			_play_at(cue, _point(effect.get("to", effect.get("from", [0, 0]))), 0.66, 4 if fatal else 3, "combat")
		elif type in ["harvest", "mine", "mining"]:
			# Older worker-state fallback and explicit events share a cooldown.
			var id := int(effect.get("unit_id", effect.get("unit", source.get("id", -1))))
			if id < 0 or now >= float(_mining_marks.get(id, -1.0)):
				if id >= 0:
					_mining_marks[id] = now + 0.68
				play_mining(race, position)
		elif type=="heal":
			var id := int(effect.get("unit_id",effect.get("unit",source.get("id",-1))))
			var stamp := float(effect.get("started",now))
			if id>=0 and absf(stamp-float(_healing_marks.get(id,-99.0)))<0.2:
				continue
			if id>=0:_healing_marks[id]=stamp
			play_heal(str(effect.get("heal_kind","medic" if race==0 else "sap" if race==1 else "shield")),position,race)
		elif type in ["board","unboard"]:
			_play_at("%s_%d"%[type,clampi(race,0,2)],position,.55,2,"transport")
		elif type=="nuclear_notice":
			if director!=null:director.announce("nuclear",-1,0,5)
		elif type in ["nuclear_ascent","nuclear_descent"]:
			_play_at(type,position,.65,4,"combat")
		elif type=="skill":
			var nuclear=str(effect.get("skill",""))=="nuclear"
			_play_at("skill_"+str(effect.get("skill","")).replace("_warning",""),position,.8 if nuclear else .45,5 if nuclear else 2,"combat")
		elif type in ["ability", "cast", "warning", "repair"]:
			if kind < 0:
				kind = [4, 9, 5][clampi(race, 0, 2)]
			play_unit(race, kind, position, "ability")

func play_unit(race: int, kind: int, position: Vector2, category: String = "attack") -> bool:
	race=clampi(race,0,2)
	if race==1 and kind==13:return false
	kind=clampi(kind,0,ACData.unit_count(race)-1)
	if category=="attack" and float(ACData.unit(race,kind).damage)<=0.0:
		return false
	return _play_at("unit_%d_%d" % [race,kind], position, 0.74 if category == "attack" else 0.58, 3 if category == "attack" else 2, "combat")

func play_heal(kind: String, position: Vector2, race: int=0) -> bool:
	if kind=="medic" or race==0:
		return _play_at("heal_medic",position,0.48,2,"healing")
	return _play_at("unit_1_9" if kind=="sap" or race==1 else "unit_2_4",position,0.40,2,"healing")

func play_mining(race: int, position: Vector2) -> bool:
	return _play_at("mine_%d" % clampi(race, 0, 2), position, 0.32, 1, "mining")

func play_ui(name: String = "confirm") -> bool:
	var sound := name if name in ["confirm", "select", "error", "ready", "build"] else "confirm"
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_ui_marks.get(sound, -10.0)) < 0.065:
		return false
	_ui_marks[sound] = now
	return _play("ui_" + sound, 0.7, 5, "ui", Vector2.ZERO, 1.0)

func play_selection(race: int, kind: int) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_ui_marks.get("unit_select", -10.0)) < 0.42:
		return false
	_ui_marks["unit_select"] = now
	if race==1 and kind==13:return _play("ui_select",.19,4,"ui",Vector2.ZERO,1.13)
	# A brief low level mechanism/energy response complements the UI switch.
	race=clampi(race,0,2)
	kind=clampi(kind,0,ACData.unit_count(race)-1)
	var cue := "heal_medic" if race==0 and kind==4 else "unit_%d_%d" % [race,kind]
	return _play(cue,0.19,4,"ui",Vector2.ZERO,1.13)

func _play_at(name: String, position: Vector2, gain: float, priority: int, group: String) -> bool:
	var offset := position - _camera
	var screen := (Vector2((offset.x-offset.y)*32.0,(offset.x+offset.y)*16.0) if isometric_projection else offset*32.0)*_zoom
	var distance := Vector2(screen.x / 850.0, screen.y / 540.0).length()
	if distance >= 1.65:
		debug_stats.culled += 1
		return false
	var attenuation := pow(maxf(0.0, 1.0 - distance / 1.7), 1.35)
	var pitch := 1.0 + float(posmod(_serial * 37, 11) - 5) * 0.006
	return _play(name, gain * attenuation, priority, group, screen, pitch)

func _play(name: String, gain: float, priority: int, group: String, screen: Vector2, pitch: float) -> bool:
	if not enabled or (_paused and group!="ui") or master_volume <= 0.0 or _voices.is_empty():
		return false
	var stream := _stream(name)
	if stream == null:
		debug_stats.missing += 1
		return false
	if group=="construction":
		var active=0
		for voice in _voices:
			if voice.player.playing and voice.group=="construction":active+=1
		if active>=3:debug_stats.culled+=1;return false
	var active_combat := 0
	var chosen: Dictionary = {}
	var candidate: Dictionary = {}
	for voice in _voices:
		if not voice.player.playing:
			if chosen.is_empty():
				chosen = voice
		else:
			if voice.group == "combat":
				active_combat += 1
			if candidate.is_empty() or int(voice.priority) < int(candidate.priority) or (int(voice.priority) == int(candidate.priority) and float(voice.started) < float(candidate.started)):
				candidate = voice
	if group == "combat" and active_combat >= COMBAT_LIMIT:
		chosen = {}
		candidate = {}
		for voice in _voices:
			if voice.player.playing and voice.group == "combat" and (candidate.is_empty() or int(voice.priority)<int(candidate.priority) or (int(voice.priority)==int(candidate.priority) and float(voice.started)<float(candidate.started))):
				candidate = voice
	if chosen.is_empty():
		if candidate.is_empty() or int(candidate.priority) > priority:
			debug_stats.culled += 1
			return false
		chosen = candidate
		chosen.player.stop()
		debug_stats.stolen += 1
	chosen.player.stream = stream
	chosen.player.position = screen
	chosen.player.volume_db = linear_to_db(maxf(0.0001,gain))
	chosen.player.pitch_scale = pitch
	chosen.priority = priority
	chosen.group = group
	chosen.level = gain
	chosen.started = Time.get_ticks_msec() * 0.001
	chosen.player.stream_paused = false
	chosen.player.play()
	_serial += 1
	last_cue = name
	debug_stats.played += 1
	return true

func _stream(name: String) -> AudioStreamWAV:
	return _wav_stream("res://assets/audio/%s.wav"%name,name)

func _wav_stream(path: String, name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	# Exported WAV resources are remapped to imported .sample files in the PCK.
	# Their original bytes need not be present at the logical .wav path.
	if ResourceLoader.exists(path):
		var imported = ResourceLoader.load(path)
		if imported is AudioStreamWAV:
			_streams[name] = imported
			return imported
	if not FileAccess.file_exists(path):
		return null
	# Read original PCM directly, so exports need no imported audio cache files.
	var wav := FileAccess.get_file_as_bytes(path)
	if wav.size() < 44 or wav.slice(0, 4).get_string_from_ascii() != "RIFF" or wav.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var offset := 12
	var mix_rate := PCM_RATE
	var stereo := false
	var pcm := PackedByteArray()
	while offset + 8 <= wav.size():
		var chunk := wav.slice(offset, offset + 4).get_string_from_ascii()
		var length := int(wav.decode_u32(offset + 4))
		var begin := offset + 8
		if length < 0 or begin + length > wav.size():
			return null
		if chunk == "fmt ":
			if length < 16 or wav.decode_u16(begin) != 1 or wav.decode_u16(begin + 14) != 16:
				return null
			stereo = wav.decode_u16(begin + 2) == 2
			mix_rate = int(wav.decode_u32(begin + 4))
		elif chunk == "data":
			pcm = wav.slice(begin, begin + length)
		offset = begin + length + length % 2
	if pcm.is_empty():
		return null
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.stereo = stereo
	result.mix_rate = mix_rate
	result.data = pcm
	_streams[name] = result
	return result

func _effect_key(effect: Dictionary) -> String:
	if effect.has("uid"):
		return "u:" + str(effect.uid)
	if effect.has("id"):
		return "i:" + str(effect.id)
	return "%s:%s:%s:%s:%s:%s" % [effect.get("type", ""), effect.get("race", 0), effect.get("kind", -1), effect.get("from", []), effect.get("to", []), snappedf(float(effect.get("until", 0.0)), 0.001)]

func _source_entity(effect: Dictionary) -> Dictionary:
	for key in ["unit_id", "unit", "attacker_id", "source_id", "caster"]:
		if effect.has(key) and _entities.has(int(effect[key])):
			return _entities[int(effect[key])]
	var from := _point(effect.get("from", effect.get("to", [0, 0])))
	var best: Dictionary = {}
	var nearest := 5.0
	for entity in _entities.values():
		if int(entity.get("race", 0)) != int(effect.get("race", 0)):
			continue
		var distance := _center(entity).distance_squared_to(from)
		if distance < nearest:
			nearest = distance
			best = entity
	return best

func _weapon_kind(entity: Dictionary) -> int:
	if entity.has("progress"):
		return [6, 7, 3][clampi(int(entity.get("race", 0)), 0, 2)]
	return clampi(int(entity.get("kind", 0)), 0, 12)

func _center(entity: Dictionary) -> Vector2:
	var p := _point(entity.get("pos", [0, 0]))
	if entity.has("progress"):
		var d := ACData.building(int(entity.get("race", 0)), int(entity.get("kind", 0)))
		p += Vector2(float(d.w), float(d.h)) * 0.5
	return p

func _point(value) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
