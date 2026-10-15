extends SceneTree

# A scripted human build, sent exclusively through the normal client command API.
# Owner 0 remains bot=false. No wallet, spawn, production or visibility mutation.
var main: Control
var banner: Label
var phase: Label
var sim_clock=0.0
var control_clock=0.0
var sample_clock=0.0
var frame=0
var camera_clock=0.0
var last_capture=-1
var launched=false
var finishing=false
var commands: Array=[]
var samples: Array=[]
var initial: Dictionary={}
var attack_sent=false
var capture_frames=false

func _initialize() -> void:call_deferred("setup")

func setup() -> void:
	root.size=Vector2i(1440,900)
	main=load("res://scripts/main.gd").new()
	root.add_child(main)
	main.size=Vector2(1440,900)
	main.set_process(false)
	main._start_local({"map":0,"seed":2026101571,"spawn_slots":[0,2],"mode":"ffa","players":[{"name":"자동 조작 시연","race":0,"bot":false,"team":0},{"name":"귤 군체 봇","race":1,"bot":true,"difficulty":1,"team":1}]})
	initial={"as":main.core.players[0].as,"tera":main.core.players[0].tera,"workers":owned_units(0).filter(func(u):return int(u.kind)==0).size(),"bot":main.core.players[0].bot,"game_sha256":FileAccess.get_sha256("res://data/game.json"),"core_sha256":FileAccess.get_sha256("res://scripts/core.gd")}
	var overlay=CanvasLayer.new()
	overlay.layer=100
	root.add_child(overlay)
	var backing=ColorRect.new()
	backing.position=Vector2(18,54);backing.size=Vector2(530,76);backing.color=Color(0.025,.04,.06,.86);backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(backing)
	banner=Label.new();banner.position=Vector2(30,62);banner.text="자동 조작 시연 · 정상 시작 · 3배속";banner.add_theme_font_override("font",main.font);banner.add_theme_font_size_override("font_size",20);overlay.add_child(banner)
	phase=Label.new();phase.position=Vector2(30,92);phase.add_theme_font_override("font",main.font);phase.add_theme_font_size_override("font_size",18);phase.text="정비공 4기 · 아스 50 · 테라 0";overlay.add_child(phase)
	capture_frames="--capture-frames" in OS.get_cmdline_user_args()
	if capture_frames:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/playdemo-frames"))
	Engine.max_fps=20
	launched=true
	print("PLAYDEMO_INITIAL "+JSON.stringify(initial))
	await capture("playdemo-start.png")

func owned_units(owner: int) -> Array:return main.core.units.filter(func(u):return int(u.owner)==owner and not bool(u.get("technical",false)))
func buildings(kind: int,complete: bool=false) -> Array:return main.core.buildings.filter(func(b):return int(b.owner)==0 and int(b.kind)==kind and (not complete or float(b.progress)>=1))
func queued(kind: int) -> int:
	var result=0
	for b in main.core.buildings:
		if int(b.owner)==0:
			for q in b.queue:
				if int(q.kind)==kind:result+=1
	return result

func send(command: Dictionary) -> void:
	main.selected_resource=-1
	main.selected=command.get("ids",[command.id] if command.has("id") else [])
	main._send_command(command)
	commands.append({"time":snappedf(main.core.time,.05),"command":command.duplicate(true)})
	print("PLAYDEMO_COMMAND "+JSON.stringify(commands.back()))

func afford(data: Dictionary) -> bool:
	var player=main.core.players[0]
	return player.as>=data.as and player.tera>=data.tera

func train(kind: int) -> bool:
	var data=ACData.unit(0,kind)
	if not afford(data) or not main.core.prerequisites(0,data.requires):return false
	var p=main.core.players[0]
	if p.used+p.reserved+data.pop>p.cap:return false
	for b in buildings(int(data.producer),true):
		if b.queue.is_empty():send({"type":"train","id":b.id,"kind":kind});return true
	return false

func build(kind: int) -> bool:
	var data=ACData.building(0,kind)
	if not afford(data) or not main.core.prerequisites(0,data.requires):return false
	var hq=main.core.entity(int(main.core.players[0].home))
	if hq.is_empty():return false
	var home=main.core.center(hq)
	var possible: Array=[]
	if kind==1:
		for node in main.core.map.resources:
			if node.type=="tera" and ACData.point(node.pos).distance_to(home)<20:possible.append(main.core.refinery_anchor(node))
	else:
		for x in range(-12,13):
			for y in range(-12,13):
				var pos=(home+Vector2(x,y)).floor()
				if pos.distance_to(home)>=5:possible.append(pos)
		possible.sort_custom(func(a,b):return a.distance_squared_to(home)<b.distance_squared_to(home))
	for pos in possible:
		if main.core.placement(0,kind,pos)=="":
			var workers=owned_units(0).filter(func(u):return int(u.kind)==0 and u.order!="construct")
			if workers.is_empty():return false
			workers.sort_custom(func(a,b):return ACData.point(a.pos).distance_squared_to(pos)<ACData.point(b.pos).distance_squared_to(pos))
			send({"type":"build","kind":kind,"pos":ACData.packed(pos),"ids":[workers[0].id]})
			return true
	return false

func control_build() -> void:
	var units=owned_units(0)
	var workers=units.filter(func(u):return int(u.kind)==0)
	for worker in workers:
		if worker.order=="idle":
			var ore=main.core.nearest_available_resource(ACData.point(worker.pos),-1,int(worker.id),24)
			if ore>=0:send({"type":"context","ids":[worker.id],"target":ore})
	var p=main.core.players[0]
	if workers.size()+queued(0)<8:
		phase.text="아스 채취 · 정비공 8기 확보"
		train(0);return
	if buildings(2).is_empty():phase.text="기반 시설 · 보급창고 건설";build(2);return
	if buildings(3).is_empty():phase.text="기반 시설 · 전투병영 건설";build(3);return
	if buildings(1).is_empty():phase.text="테라 자동 추출 · 정제소 건설";build(1);return
	if buildings(7).is_empty():phase.text="야전의료소 · 의무병 해금";build(7);return
	if p.used+p.reserved>=p.cap-2 and buildings(2).size()<5 and not buildings(2).any(func(b):return b.progress<1):build(2)
	if buildings(3,true).size()<2 and not buildings(3).any(func(b):return b.progress<1) and p.as>280:build(3)
	var rifles=units.filter(func(u):return int(u.kind)==1)
	var medics=units.filter(func(u):return int(u.kind)==4)
	if medics.size()+queued(4)<maxi(1,int(rifles.size()/5)) and rifles.size()>=3 and buildings(7,true).size()>0:train(4)
	else:train(1)
	phase.text="전열사수 %d기 · 야전의무병 %d기 · 분대 편성"%[rifles.size(),medics.size()]
	var army=units.filter(func(u):return int(u.kind)>0)
	if (army.size()>=8 and medics.size()>0) or main.core.time>300:
		if not attack_sent or int(main.core.time)%12==0:
			var target=main.core.map.starts[2]
			for enemy in main.core.buildings:
				if int(enemy.owner)==1 and int(enemy.kind)==0:target=main.core.center(enemy);break
			for index in range(0,army.size(),12):send({"type":"attack_move","ids":army.slice(index,mini(index+12,army.size())).map(func(u):return u.id),"pos":ACData.packed(ACData.point(target)),"formation":true})
			attack_sent=true
		phase.text="사수·의무병 분대 · 적 진영으로 공격 이동"

func telemetry() -> void:
	var record={"time":snappedf(main.core.time,.1),"players":[],"units":[]}
	for owner in range(2):
		var p=main.core.players[owner]
		record.players.append({"owner":owner,"race":p.race,"bot":p.bot,"as":p.as,"tera":p.tera,"gathered":p.gathered,"spent":p.spent,"used":p.used,"reserved":p.reserved,"cap":p.cap,"kills":p.kills,"lost":p.lost,"units":owned_units(owner).size()})
	for u in main.core.units:record.units.append({"id":u.id,"owner":u.owner,"kind":u.kind,"hp":u.hp,"pos":u.pos,"order":u.order})
	samples.append(record)
	print("PLAYDEMO_PROGRESS "+JSON.stringify({"time":record.time,"players":record.players,"phase":phase.text}))

func camera_follow() -> void:
	if not attack_sent:return
	var army=owned_units(0).filter(func(u):return int(u.kind)>0)
	if army.is_empty():return
	var middle=Vector2.ZERO
	for unit in army:middle+=ACData.point(unit.pos)
	middle/=army.size()
	main.camera=main.camera.lerp(middle,.075)
	main._clamp_camera()

func _process(_delta: float) -> bool:
	if not launched or finishing:return false
	for tick in range(3):
		if not main.core.ended:
			control_clock+=.05
			if control_clock>=.5:control_clock=0;control_build()
		main._process(.05)
	frame+=1
	camera_follow()
	if main.core.time>=sample_clock:sample_clock=main.core.time+10;telemetry()
	var stamp=int(main.core.time/30)
	if stamp>last_capture:
		last_capture=stamp
		capture("playdemo-%03d.png"%int(main.core.time))
	if capture_frames and frame%4==0:capture_small(frame/4)
	if main.core.time>=420 or main.core.ended:finish()
	return false

func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+filename)

func capture_small(index: int) -> void:
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	image.resize(720,450,Image.INTERPOLATE_LANCZOS)
	image.save_png("res://build/playdemo-frames/%05d.png"%index)

func finish() -> void:
	finishing=true
	telemetry()
	main._save_replay()
	var saved=[]
	for file in DirAccess.get_files_at("user://replays"):
		if file.ends_with(".acr"):
			var target="res://build/AsteraCraft-v0.4-gameplay.acr"
			DirAccess.copy_absolute(ProjectSettings.globalize_path("user://replays/"+file),ProjectSettings.globalize_path(target));saved.append(target)
	var report={"kind":"scripted_human_build_demonstration","human_bot_flag":false,"state_cheats":false,"initial":initial,"seconds":main.core.time,"commands":commands,"samples":samples,"ended":main.core.ended,"winners":main.core.winners,"replays":saved}
	var file=FileAccess.open("res://build/playdemo-v04.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	await capture("playdemo-final.png")
	print("PLAYDEMO_DONE seconds=%.2f commands=%d samples=%d"%[main.core.time,commands.size(),samples.size()])
	quit()
