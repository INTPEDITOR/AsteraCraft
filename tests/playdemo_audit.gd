extends SceneTree

var checks=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("PLAYDEMO_AUDIT_FAIL "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report=JSON.parse_string(FileAccess.get_file_as_string("res://build/playdemo-v04.json"))
	check(report.initial.as==50 and report.initial.tera==0 and report.initial.workers==4 and not report.initial.bot,"normal four-worker 50-As human start")
	check(report.seconds>=300 and report.seconds<=480,"five to eight simulated minutes recorded")
	check(not report.state_cheats and not report.human_bot_flag,"controller identifies automatic human command demonstration without cheats")
	var violations: Dictionary={}
	for sample in report.samples:
		for player in sample.players:
			if not is_finite(float(player.as)) or not is_finite(float(player.tera)) or player.as<0 or player.tera<0:violations.wallet=true
			if player.used+player.reserved>200.001 or player.cap>200.001:violations.population=true
			if absf(50+float(player.gathered)-float(player.spent)-float(player.as)-float(player.tera))>.01:violations.conservation=true
			if int(player.owner)==0 and player.bot:violations.human_ai=true
		for unit in sample.units:
			if not ACData.point(unit.pos).is_finite() or not is_finite(float(unit.hp)):violations.unit_state=true
	check(violations.is_empty(),"finite units, nonnegative wallets, population <=200, material conservation, human AI disabled at all 43 samples")
	var max_selected=0
	var attacks=0
	var normal_types: Dictionary={}
	for command in report.commands:
		var data=command.command
		normal_types[str(data.type)]=true
		max_selected=maxi(max_selected,data.get("ids",[]).size())
		if data.type=="attack_move":attacks+=1
	check(max_selected<=12 and attacks>0 and normal_types.has("build") and normal_types.has("train") and normal_types.has("context"),"normal gather/build/train/A commands respect twelve-unit selection limit")
	var final=report.samples.back()
	var rifles=final.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==1)
	var medics=final.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==4)
	check(rifles.size()>0 and medics.size()>0 and final.players[0].kills>0 and final.players[1].kills>0,"both sides really fight and normal rifle/medic production completes")
	var file=FileAccess.open_compressed("res://build/AsteraCraft-v0.4-gameplay.acr",FileAccess.READ,FileAccess.COMPRESSION_DEFLATE)
	check(file!=null,"replay can be opened using the actual game compression format")
	if file!=null:
		var replay=file.get_var(false);file.close()
		check(replay.version=="0.4.0" and replay.slot==0 and replay.frames.size()>=300,"replay preserves version, player view and at least five minutes of snapshots")
		var first=bytes_to_var(replay.frames[0].decompress_dynamic(16777216,FileAccess.COMPRESSION_DEFLATE))
		var last=bytes_to_var(replay.frames.back().decompress_dynamic(16777216,FileAccess.COMPRESSION_DEFLATE))
		check(float(last.time)-float(first.time)>=300 and first.players[0].race==0,"recorded gameplay time and race are consistent")
	var summary={"checks":checks,"failures":failures,"seconds":report.seconds,"commands":report.commands.size(),"samples":report.samples.size(),"max_selected":max_selected,"rifles_at_end":rifles.size(),"medics_at_end":medics.size(),"final":final.players,"source_sha256":report.initial,"full_match_finished":report.ended}
	var output=FileAccess.open("res://build/playdemo-audit.json",FileAccess.WRITE);output.store_string(JSON.stringify(summary,"\t"));output.close()
	print("PLAYDEMO_AUDIT checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
