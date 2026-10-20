extends SceneTree
var checks=0
var failures: Array=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var audio=ACAudio.new();root.add_child(audio);await process_frame
	var v=audio.director
	check(v.catalog.units.size()==44,"all 43 regular units plus brood have voices")
	check(v.clips.size()==265,"195 performed lines and 70 new biomechanical creature responses")
	var hashes: Dictionary={}
	for key in v.catalog.units:
		var entry=v.catalog.units[key]
		check(entry.normal.size()==3 and entry.special.size()==2,"short normal and special banks: "+key)
		var pair=str(key).split(":");var race=int(pair[0]);var kind=int(pair[1])
		v.reset()
		for n in range(18):
			var id=v.selection_clip(race,kind,12,n*1.0)
			check(id in entry.normal+entry.special,"repeated selections never exceed bank: "+key)
			check(id in entry.special if n>=5 else id in entry.normal,"special reaction threshold: "+key)
		check(v.selection_clip(race,kind,13,18) in entry.normal,"another individual restores normal voice")
		check(v.selection_clip(race,kind,13,18.01)=="","rapid duplicate click silent")
	for id in v.clips:
		var c=v.clips[id];var stream=v.stream_for(id)
		check(stream!=null and stream.get_length()>.25 and stream.get_length()<3.3,"short complete playable clip: "+id)
		var hash=FileAccess.get_sha256(c.file)
		check(not hashes.has(hash),"distinct active waveform: "+id);hashes[hash]=true
		check(c.provider==("VARCO Sound" if c.get("type","")=="roar" else "ElevenLabs"),"correct voice provider: "+id)
	check(v.cache.size()<=64,"bounded decoded dialogue cache")
	for race in range(3):
		v.reset();check(v.announce("tera",race),"faction narrator starts")
		check(v.last_played=="r%d_ann_tera"%race,"faction voice selected")
		check(not v.announce("tera",race),"repeated warning cooldown")
		v.reset();v.race=race;check(v.announce("nuclear",race,0,5),"critical nuclear narration starts")
		check(v.last_played=="r%d_ann_nuclear"%race,"faction nuclear message selected")
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/elevenlabs_voices_v060.json"))
	var queen=source.banks.filter(func(b):return b.id=="r1_ann")[0]
	check(queen.pitch==1.0 and is_equal_approx(queen.speed,1.10),"approved female timbre retained with ten percent faster delivery")
	check(v.clips.r0_ann_nuclear.text=="핵 발사가 감지되었습니다.","military nuclear wording")
	check(v.clips.r1_ann_nuclear.text!=v.clips.r2_ann_nuclear.text,"species retain unique warnings")
	v.reset();audio.set_paused(true);check(not v.announce("as",0),"pause suppresses dialogue")
	audio.set_paused(false);audio.clear();check(not v.announcer.playing,"cleanup stops narration")
	audio.queue_free();v=null;audio=null;await process_frame;await process_frame
	await create_timer(.08).timeout
	print("VOICES_V060 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
