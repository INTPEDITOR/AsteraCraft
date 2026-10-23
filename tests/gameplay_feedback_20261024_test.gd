extends SceneTree
var checks=0
var failures=[]
class AudioProbe:
	extends ACAudio
	var cues=[]
	func _play_at(cue: String,_where: Vector2,_gain: float,_priority: int,_group: String) -> bool:
		cues.append(cue);return true
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var original=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	var maps=[]
	for id in range(3):
		var map=ACMap.new();map.make(id);map.resource_obstacles.clear();map.reset_solids([])
		var changed=0;var nav_changed=0;var blocked=0
		for tile in range(128*128):
			var mask=int(original.maps[id].walk_masks[tile])
			if map.source_walk_masks[tile]!=mask:changed+=1
			for bit in range(16):
				var x=(tile%128)*4+bit%4;var y=(tile/128)*4+bit/4
				var solid=(mask&(1<<bit))==0
				if solid:blocked+=1
				if bool(map._detail_solid[y*512+x])!=solid:nav_changed+=1
		check(changed==0 and nav_changed==0,"map %d all262144 original 8px cells and active navigation match"%id)
		check(map.source_detail_active and map.source_info.exact_source,"map %d uses imported fine collision"%id)
		maps.append({"id":id,"name":original.maps[id].name,"mask_changes":changed,"navigation_changes":nav_changed,"blocked_cells":blocked})
	var a=AudioProbe.new()
	for race in range(3):
		for prefix in ["construct_","construct_complete_"]:
			var stream=load("res://assets/audio/%s%d.wav"%[prefix,race])
			check(stream is AudioStreamWAV and stream.get_length()>.5,"race %d construction sound loads %s"%[race,prefix])
		var building={"id":race+1,"race":race,"kind":0,"pos":[64,64],"hp":100,"progress":.01}
		a.cues.clear();a._construction_marks.clear();a._construction_sounds([building],0)
		check(a.cues==["construct_%d"%race],"construction starts race-specific sound")
		a._construction_sounds([building],5)
		check(a.cues.size()==1,"stalled construction stays quiet")
		building.progress=.5;a._construction_sounds([building],5)
		check(a.cues.size()==2,"advancing construction resumes after cooldown")
		building.progress=1.0;a._construction_sounds([building],6);a._construction_sounds([building],7)
		check(a.cues.size()==3 and a.cues.back()=="construct_complete_%d"%race,"completion sounds once")
	a.free()
	var c=ACCore.new();c.setup({"map":0,"seed":413,"players":[{"race":1},{"race":2}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.resources.clear();c.map.resource_obstacles.clear();c.map.reset_solids([]);c.collision_index_valid=false
	for fog in c.visibility:fog.fill(2)
	var target=c.add_unit(1,0,Vector2(63,64));target.order="move";target.goal=[98,64];target.hp=5000;target.shield=0
	var chasing=[]
	for offset in [Vector2(-2,0),Vector2(-2,1),Vector2(-2,-1),Vector2(-3,2),Vector2(-3,-2)]:
		var u=c.add_unit(0,1,Vector2(63,64)+offset);u.order="attack";u.target=target.id;chasing.append(u)
	var shots=0
	for step in range(200):
		c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._tick_unit(target,.05)
		for u in chasing:
			var fired=u.fired;c._tick_unit(u,.05)
			if u.fired!=fired:shots+=1
	print("MELEE_MOVING_TARGET shots=",shots," remaining=",target.hp," target=",target.pos)
	check(shots>=10,"melee group reaches and repeatedly damages a moving slower worker")
	c.units.clear();c.collision_index_valid=false
	var near=c.add_unit(0,1,Vector2(60,60));var victim=c.add_unit(1,0,Vector2(60.98,60));victim.shield=0
	near.order="attack";near.target=victim.id;var hp=victim.hp
	c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c._tick_unit(near,.05)
	check(victim.hp<hp,"melee resolves an attack in the same step it reaches contact")
	check(near.action=="attack" and not near.moving,"contact strike shows attack pose instead of being overwritten by walk")
	var brood=ACCore.new();brood.setup({"map":0,"seed":413,"players":[{"race":1},{"race":0}]})
	brood.players[0].as=500;brood.players[0].tera=500
	var hq=brood.entity(int(brood.players[0].home));var pod=ACCitrusBrood.idle_pods(brood,hq)[0];var before=brood.players[0].as
	check(brood.command(0,{"type":"morph","id":pod.id,"kind":0})=="","brood accepts paid morph")
	check(brood.command(0,{"type":"cancel_morph","id":pod.id})=="","morph cancellation accepted")
	check(pod.hp==0 and pod.brood_state=="cancelled" and brood.players[0].as==before,"cancellation refunds but kills the selected brood")
	check(not pod._morph_reserved and brood.players[0].reserved==0 and hq.queue.is_empty(),"cancel releases population and mirrored queue once")
	check(brood.effects.any(func(fx):return fx.type=="death" and int(fx.get("unit",-1))==int(pod.id)),"cancelled brood emits its race death effect")
	brood.command(0,{"type":"cancel_morph","id":pod.id});check(brood.players[0].as==before,"repeated cancel cannot duplicate a refund")
	var duel=ACCore.new();duel.setup({"map":0,"seed":413,"players":[{"race":0},{"race":2,"bot":true}]})
	for index in range(12):duel.add_unit(0,14,Vector2(55+index%4,55+index/4))
	var ai=preload("res://scripts/ai_surrender.gd")
	duel.time=180;ai.tick(duel,1);check(duel.surrender_requests.is_empty(),"computer waits for a sustained large deficit")
	duel.time=201;ai.tick(duel,1)
	check(duel.surrender_requests.size()==1 and not duel.players[1].lost,"outmatched computer requests approval without ending play")
	check(duel.snapshot(0).surrender_requests.size()==1 and duel.snapshot(1).surrender_requests.is_empty(),"only the intended human receives the request")
	check(duel.command(1,{"type":"surrender_response","bot":1,"accept":true})!="" and not duel.players[1].lost,"another owner cannot approve a request")
	check(duel.command(0,{"type":"surrender_response","bot":1,"accept":false})=="" and not duel.ended,"rejecting a request continues the battle")
	duel.time=250;ai.tick(duel,1);check(duel.surrender_requests.is_empty(),"rejected computer cannot immediately ask again")
	duel.time=322;ai.tick(duel,1);duel.time=343;ai.tick(duel,1)
	check(duel.command(0,{"type":"surrender_response","bot":1,"accept":true})=="" and duel.ended and duel.winners==[0],"approval defeats the computer and awards victory")
	var win=ACCore.new();win.setup({"map":0,"seed":413,"players":[{"race":0},{"race":2}]})
	for building in win.buildings:
		if building.owner==1:building.hp=0
	check(win.units.any(func(u):return u.owner==1 and u.hp>0),"victory fixture retains enemy living units")
	win._check_end();check(win.ended and win.winners==[0],"destroying every enemy building wins without hunting remaining units")
	var result={"checks":checks,"failures":failures,"passed":failures.is_empty(),"maps":maps,"melee_attacks":shots}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/visual_feedback_20261024"))
	FileAccess.open("res://build/visual_feedback_20261024/gameplay.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("GAMEPLAY_FEEDBACK checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
