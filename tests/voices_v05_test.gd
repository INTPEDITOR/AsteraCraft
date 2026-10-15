extends SceneTree
var checks := 0
var failures: Array=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var audio=ACAudio.new();root.add_child(audio);await process_frame
	var v=audio.director
	check(v!=null,"voice director attached")
	check(v.catalog.units.size()==40,"39 regular units plus brood")
	check(v.clips.size()==442,"400 unit reactions and 42 announcements")
	var paths: Dictionary={}
	for key in v.catalog.units:
		var entry=v.catalog.units[key]
		check(entry.normal.size()==5 and entry.special.size()==5,"five plus five: "+key)
		for id in entry.normal+entry.special:
			check(v.clips[id].type==("roar" if key.begins_with("1:") else "speech"),"race vocal type: "+id)
	for id in v.clips:
		var c=v.clips[id]
		check(not paths.has(c.file),"unique clip file: "+id);paths[c.file]=true
		var stream=v.stream_for(id)
		check(stream!=null and stream.get_length()>.25 and stream.get_length()<15,"nonempty playable WAV: "+id)
	check(v.cache.size()<=64,"bounded decoded cache")
	for race in range(3):
		var group: Array=[]
		for kind in range(13):group.append({"id":100+kind,"race":race,"kind":kind,"hp":100})
		check(int(ACData.portrait_leader(group).kind)==12,"capital portrait wins for race %d"%race)
		group.reverse()
		check(int(ACData.portrait_leader(group).kind)==12,"drag order does not change portrait")
		check(int(ACData.portrait_leader([group[0],{"id":9,"race":race,"kind":12,"hp":100}]).id)==9,"stable identity tie break")
		v.reset()
		var kind=1
		for n in range(10):
			var got=v.selection_clip(race,kind,42,n*1.0)
			check(got=="r%d_u1_%s%d"%[race,"n" if n<5 else "s",n%5],"normal to special sequence")
		check(v.selection_clip(race,kind,43,10)=="r%d_u1_n0"%race,"another individual resets special burst")
		check(v.selection_clip(race,kind,43,10.01)=="","debounce frame clicks")
		check(v.selection_clip(race,kind,43,30)=="r%d_u1_n1"%race,"long pause resets special burst")
		v.reset();check(v.announce("tera",race),"narrator starts")
		check(v.last_played=="r%d_ann_tera"%race,"faction narrator voice")
		check(not v.announce("tera",race),"narrator cooldown")
	for pair in [["아스가 부족합니다","as"],["테라가 부족합니다","tera"],["인구 한도가 부족합니다","supply"],["에너지가 부족합니다","energy"],["선행 기술 건물이 필요합니다","tech"]]:
		check(v.error_event(pair[0])==pair[1],"error category "+pair[1])
	var c=ACCore.new();c.setup({"map":0,"seed":91,"players":[{"name":"A","race":0},{"name":"B","race":2}]})
	c.players[0].as=0;c.players[0].tera=0
	check(c.resource_error(0,75,25)=="아스가 부족합니다","As first when both short")
	c.players[0].as=1000
	check(c.resource_error(0,75,25)=="테라가 부족합니다","Tera separately identified")
	c.players[0].race=2
	var caster=c.add_unit(0,5,Vector2(60,60));caster.energy=10
	check(c.command(0,{"type":"ability","ids":[caster.id],"pos":caster.pos})=="에너지가 부족합니다","ability failure reports low energy")
	check(caster.energy==10,"failed ability does not spend energy")
	caster.energy=100
	check(c.command(0,{"type":"ability","ids":[caster.id],"pos":caster.pos})=="" and caster.energy==25,"sufficient-energy ability still works")
	v.reset()
	var state={"time":1.0,"mode":"ffa","players":[{"race":0,"team":0},{"race":2,"team":0}],"units":[{"id":1,"owner":0,"race":0,"kind":1,"hp":70,"damaged":-99,"pos":[20,20]},{"id":2,"owner":1,"race":2,"kind":1,"hp":70,"damaged":-99,"pos":[30,30]}],"buildings":[],"effects":[]}
	v.scan(state,0);check(v.last_played=="","initial units are silent")
	state.time=1.5;state.units[1].damaged=1.4;v.scan(state,0)
	check(v.pings.is_empty(),"enemy hit gives no ping even with same team number in FFA")
	state.time=2.0;state.units[0].damaged=1.9;v.scan(state,0)
	check(v.pings.size()==1 and v.last_played=="r0_ann_attack","friendly hit alerts and pings")
	state.time=2.5;state.units[0].damaged=2.4;v.scan(state,0)
	check(v.pings.size()==1,"same location ping coalesced")
	state.time=7.0;v.scan(state,0);check(v.pings.is_empty(),"old ping expires")
	v.reset();v.scan(state,0)
	state.time=8.0;state.effects=[{"type":"explosion","attacker":55,"owner":0,"source_building":true,"started":7.9,"to":[40,40]}];v.scan(state,0)
	check(v.last_played=="r0_ann_base_attack" and v.pings.size()==1,"destroyed building still warns")
	v.reset();state.time=9;state.effects=[];v.scan(state,0)
	state.players[0].armor=1;state.time=9.5;v.scan(state,0)
	check(v.last_played=="r0_ann_research_ready","real research increment announces")
	v.reset();state.time=10;state.effects=[];v.scan(state,0)
	state.time=10.5;state.effects=[{"type":"explosion","owner":0,"projectile":"spell","started":10.4,"to":[40,40]}];v.scan(state,0)
	check(v.pings.is_empty(),"own spell explosion is not an attack warning")
	v.reset();v.attack_visible=func(point: Vector2):return point.x<50
	v.attack_notice(Vector2(20,20),11,false)
	check(v.last_played=="" and v.pings.size()==1,"visible battle is silent but still marked")
	check(not v.marks.has("attack"),"visible battle does not consume offscreen warning cooldown")
	v.attack_notice(Vector2(80,20),11.5,false)
	check(v.last_played=="r0_ann_attack","offscreen battle speaks immediately")
	v.reset();v.attack_notice(Vector2(20,20),12,true)
	check(v.last_played=="","visible building destruction is silent")
	v.attack_visible=Callable()
	v.reset();audio.set_paused(true);check(not v.announce("as",0),"pause suppresses new voices")
	audio.set_paused(false);v.announce("as",0);check(v.unit_player.bus==&"VOICE" and v.announcer.bus==&"VOICE","both players use dialogue slider")
	audio.clear();check(v.pings.is_empty() and not v.announcer.playing,"match cleanup")
	audio.queue_free();c=null;await process_frame;await process_frame
	print("VOICE_V05 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
