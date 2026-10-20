extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var audio=ACAudio.new();root.add_child(audio);await process_frame
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest_v060.json"))
	check(catalog.cues.size()==123,"123 documented VARCO-derived runtime effects")
	for cue in catalog.cues:
		var stream=audio._stream(cue.name)
		check(stream!=null and not stream.data.is_empty(),"playable effect "+cue.name)
		check(stream!=null and absf(stream.get_length()-float(cue.duration))<.02,"correct effect duration "+cue.name)
		check(stream!=null and stream.mix_rate==24000,"imported 24k PCM "+cue.name)
		check(str(cue.source_sha256).length()==64,"source provenance "+cue.name)
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			check(audio._stream("unit_%d_%d"%[race,kind])!=null,"all unit weapon/support effects")
			check(audio._stream("death_%d_%d"%[race,kind])!=null,"all unit destruction effects")
		for action in ["board","unboard"]:check(audio._stream("%s_%d"%[action,race])!=null,"transport sound "+action)
	for skill in ACData.get_data().abilities:check(audio._stream("skill_"+skill.id)!=null,"each skill sound "+skill.id)
	check(is_equal_approx(audio._stream("nuclear_ascent").get_length(),4.0),"four second nuclear ascent")
	check(is_equal_approx(audio._stream("nuclear_descent").get_length(),3.0),"three second nuclear descent")
	audio.clear()
	check(audio._play("skill_nuclear",.7,5,"combat",Vector2.ZERO,1),"critical explosion starts")
	for i in range(40):audio._play("unit_0_10",.3,1,"combat",Vector2.ZERO,1)
	var playing=0;var combat=0;var nuclear=0
	for voice in audio._voices:
		if voice.player.playing:
			playing+=1
			if voice.group=="combat":combat+=1
			if voice.priority==5:nuclear+=1
	check(playing<=20 and combat<=12,"bounded battle effect voices")
	check(nuclear==1,"ordinary weapon spam cannot replace nuclear sound")
	audio.set_paused(true);check(not audio.play_unit(0,15,Vector2.ZERO),"paused drone starts no new sound")
	audio.set_paused(false);audio.clear();audio._camera=Vector2(18,18)
	var unit={"id":15,"race":0,"kind":10,"owner":0,"pos":[18,18],"fired":1.0,"container":-1}
	var shot={"id":1,"type":"shot","race":0,"kind":10,"unit":15,"from":[18,18],"to":[20,20],"until":1.3}
	var state={"time":1.0,"units":[unit],"effects":[shot]}
	var before=int(audio.debug_stats.played)
	audio.process_state(state,0,Vector2(18,18),.82);audio.process_state(state,0,Vector2(18,18),.82)
	check(int(audio.debug_stats.played)==before+1,"timestamp and projectile do not duplicate salvo audio")
	unit.fired=2.0;state.time=2.0;state.effects=[];audio.process_state(state,0,Vector2(118,118),.82)
	check(int(audio.debug_stats.played)==before+1,"offscreen weapons culled")
	audio.clear();audio.queue_free();audio=null;await process_frame;await process_frame;await create_timer(.08).timeout
	print("AUDIO_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
