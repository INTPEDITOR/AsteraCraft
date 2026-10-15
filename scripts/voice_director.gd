extends Node
## Presentation only: never modifies synchronized gameplay state or its RNG.
var catalog: Dictionary={}
var clips: Dictionary={}
var cache: Dictionary={}
var counts: Dictionary={}
var marks: Dictionary={}
var last_entity := -1
var last_click := -100.0
var burst := 0
var pending_selection := ""
var pending_notice := ""
var pending_priority := -1
var notice_priority := -1
var notice_until := -1.0
var unit_player: AudioStreamPlayer
var announcer: AudioStreamPlayer
var mixer
var last_played := ""
var baseline: Dictionary={}
var previous_time := -1.0
var next_scan := 0.0
var pings: Array=[]
var race := 0
var team_mode := false
var spoken_entity := -1
var attack_visible: Callable
var pending_attack_position := Vector2.INF

func _ready() -> void:
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/voices_v05.json"))
	for clip in catalog.get("clips",[]):clips[str(clip.id)]=clip
	unit_player=AudioStreamPlayer.new();unit_player.bus=&"VOICE";add_child(unit_player)
	announcer=AudioStreamPlayer.new();announcer.bus=&"VOICE";add_child(announcer)
	unit_player.volume_db=-3;announcer.volume_db=-2

func reset() -> void:
	unit_player.stop();announcer.stop()
	counts.clear();marks.clear();baseline.clear();pings.clear()
	last_entity=-1;last_click=-100;burst=0;previous_time=-1;next_scan=0
	pending_selection="";pending_notice="";pending_priority=-1;notice_priority=-1
	last_played=""
	spoken_entity=-1
	pending_attack_position=Vector2.INF

func _process(_delta: float) -> void:
	if mixer==null or not mixer.enabled or mixer._paused:return
	if not announcer.playing:
		if pending_notice!="":
			var id=pending_notice;var priority=pending_priority
			pending_notice="";pending_priority=-1
			var suppressed=pending_attack_position.is_finite() and attack_visible.is_valid() and bool(attack_visible.call(pending_attack_position))
			pending_attack_position=Vector2.INF
			if not suppressed and Time.get_ticks_msec()*.001<=notice_until:_play_notice(id,priority)
		elif not unit_player.playing and pending_selection!="":
			var id=pending_selection;pending_selection=""
			play_clip(id,unit_player)

func stream_for(id: String) -> AudioStream:
	if cache.has(id):return cache[id]
	if not clips.has(id):return null
	var path=str(clips[id].file)
	var stream: AudioStream
	if ResourceLoader.exists(path):stream=load(path)
	elif FileAccess.file_exists(path):stream=AudioStreamWAV.load_from_file(path)
	if stream!=null:
		# Keep the decoded voice cache bounded during long matches.
		if cache.size()>=64:cache.erase(cache.keys()[0])
		cache[id]=stream
	return stream

func play_clip(id: String, player: AudioStreamPlayer) -> bool:
	var stream=stream_for(id)
	if stream==null:return false
	player.stream=stream;player.play();last_played=id
	return true

func selection_clip(unit_race: int, kind: int, entity_id: int, now: float) -> String:
	var key="%d:%d"%[unit_race,kind]
	if not catalog.units.has(key):return ""
	# Tiny input bursts do not skip through five voice lines in one frame.
	if now-last_click<.32:return ""
	burst=burst+1 if entity_id==last_entity and now-last_click<=12.0 else 1
	last_entity=entity_id;last_click=now
	var special=burst>5
	var bank="special" if special else "normal"
	var index=int(counts.get(key+bank,0))%5
	counts[key+bank]=index+1
	return str(catalog.units[key][bank][index])

func select_unit(entity: Dictionary) -> void:
	if entity.is_empty() or entity.has("progress") or mixer==null or not mixer.enabled or mixer._paused:return
	var id=selection_clip(int(entity.race),int(entity.kind),int(entity.id),Time.get_ticks_msec()*.001)
	if id=="":return
	# A different unit answers immediately. Rapid repeated clicks remain
	# debounced; allow a new response after the opening syllables of one line.
	if announcer.playing or pending_notice!="":pending_selection=id
	elif unit_player.playing and spoken_entity==int(entity.id) and unit_player.get_playback_position()<.65:pending_selection=id
	else:
		pending_selection="";spoken_entity=int(entity.id)
		play_clip(id,unit_player)

func announce(event: String, faction: int=-1, cooldown: float=5.0, priority: int=1) -> bool:
	if mixer==null or not mixer.enabled or mixer._paused:return false
	var now=Time.get_ticks_msec()*.001
	if now-float(marks.get(event,-100.0))<cooldown:return false
	var r=race if faction<0 else faction
	var id=str(catalog.narration.get(str(r),{}).get(event,""))
	if id=="":return false
	marks[event]=now
	if announcer.playing and priority<=notice_priority:
		if priority>=pending_priority:
			pending_notice=id;pending_priority=priority;notice_until=now+4.0
		return true
	return _play_notice(id,priority)

func _play_notice(id: String, priority: int) -> bool:
	unit_player.stop();pending_selection="";notice_priority=priority
	if priority>=3:pending_notice="";pending_priority=-1
	return play_clip(id,announcer)

func error_event(message: String) -> String:
	if "아스" in message and "부족" in message:return "as"
	if "테라" in message and "부족" in message:return "tera"
	if "인구" in message and "부족" in message:return "supply"
	if "대기열" in message:return "queue"
	if "배양체" in message and ("없" in message or "부족" in message):return "brood"
	if "에너지" in message and "부족" in message:return "energy"
	if "선행" in message or "기술 건물" in message:return "tech"
	return ""

func error_notice(message: String, faction: int=-1) -> void:
	var event=error_event(message)
	if event!="":announce(event,faction,3.5,2)

func is_ally(players: Array, local_slot: int, owner: int) -> bool:
	if owner==local_slot:return true
	if owner<0 or owner>=players.size():return false
	var team=int(players[local_slot].get("team",-1))
	return team_mode and team>=0 and team==int(players[owner].get("team",-2))

func scan(state: Dictionary, local_slot: int) -> void:
	if bool(state.get("ended",false)):return
	if local_slot<0 or local_slot>=state.get("players",[]).size():return
	var now=float(state.get("time",0))
	if previous_time>=0 and now<previous_time:reset()
	if now<next_scan:return
	next_scan=now+.2
	race=int(state.players[local_slot].race)
	team_mode=str(state.get("mode",""))=="teams"
	var first=previous_time<0
	# Destruction effects remain after a one-shot victim leaves the unit snapshot.
	if not first:
		for effect in state.get("effects",[]):
			if str(effect.get("type",""))!="explosion" or not effect.has("attacker") or float(effect.get("started",-1))<=previous_time:continue
			if not is_ally(state.players,local_slot,int(effect.get("owner",-1))):continue
			attack_notice(ACData.point(effect.get("to",[0,0])),now,bool(effect.get("source_building",false)))
	var current: Dictionary={}
	for group in ["units","buildings"]:
		for e in state.get(group,[]):
			var owner=int(e.get("owner",-1))
			if not is_ally(state.players,local_slot,owner):continue
			var id=int(e.id);var old: Dictionary=baseline.get(id,{})
			var building=e.has("progress")
			current[id]={"damaged":float(e.get("damaged",-99)),"progress":float(e.get("progress",1)),"research":str(e.get("research","")),"kind":int(e.kind)}
			var hit=float(e.get("damaged",-99))
			if not first and hit>float(old.get("damaged",-99)) and now-hit<1.0:
				var pos=ACData.point(e.pos)
				if building:
					var d=ACData.building(int(e.race),int(e.kind));pos+=Vector2(d.w,d.h)*.5
				attack_notice(pos,now,building)
			if first or owner!=local_slot:continue
			if building and not old.is_empty() and float(old.progress)<1 and float(e.progress)>=1:announce("building_ready",race,4.0)
			if not building and (old.is_empty() or int(old.kind)!=int(e.kind)) and ACData.unit(int(e.race),int(e.kind)).get("role","")!="brood":announce("unit_ready",race,5.0)
	# Research completion is read from actual upgrade levels, so canceling it never speaks.
	var player=state.players[local_slot]
	var upgrades={"attack":player.get("attack",0),"armor":player.get("armor",0),"shield":player.get("shield",0)}
	if not first:
		for stat in upgrades:
			if int(upgrades[stat])>int(baseline.get("upgrades",{}).get(stat,0)):announce("research_ready",race,3.0)
	current["upgrades"]=upgrades.duplicate()
	baseline=current;previous_time=now
	pings=pings.filter(func(p):return now-float(p.time)<4.0)

func attack_notice(pos: Vector2, now: float, building: bool) -> void:
	add_ping(pos,now)
	if attack_visible.is_valid() and bool(attack_visible.call(pos)):return
	var event="base_attack" if building else "attack"
	if announce(event,race,10.0,3) and pending_notice==str(catalog.narration.get(str(race),{}).get(event,"")):
		pending_attack_position=pos

func add_ping(pos: Vector2, now: float) -> void:
	for p in pings:
		if pos.distance_to(p.pos)<6 and now-float(p.time)<2:return
	if pings.size()>=8:pings.pop_front()
	pings.append({"pos":pos,"time":now})

func draw_pings(canvas: CanvasItem, rect: Rect2, now: float) -> void:
	for ping in pings:
		var age=now-float(ping.time)
		if age<0 or age>=4:continue
		var center=rect.position+ping.pos/float(ACMap.SIZE)*rect.size
		for wave in range(3):
			var phase=fposmod(age*.85+wave/3.0,1.0)
			var radius=3+phase*15
			var color=Color(1,.24,.12,(1-phase)*minf(1,(4-age)*1.5))
			# Clip each segment: rings cannot spill onto HUD command slots.
			for segment in range(32):
				var a=center+Vector2.from_angle(TAU*segment/32.0)*radius
				var b=center+Vector2.from_angle(TAU*(segment+1)/32.0)*radius
				if rect.has_point(a) and rect.has_point(b):canvas.draw_line(a,b,color,1.6,true)
