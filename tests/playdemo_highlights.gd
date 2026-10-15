extends SceneTree

# Reframes the actual saved player's view. Does not run or alter the match.
func _initialize() -> void:call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var main=load("res://scripts/main.gd").new()
	root.add_child(main);main.size=Vector2(1440,900);main.set_process(false)
	var input=FileAccess.open_compressed("res://build/AsteraCraft-v0.4-gameplay.acr",FileAccess.READ,FileAccess.COMPRESSION_DEFLATE)
	var recording=input.get_var(false);input.close()
	main._start_local({"map":0,"seed":2026101571,"spawn_slots":[0,2],"mode":"ffa","players":[{"name":"자동 조작 시연","race":0,"bot":false,"team":0},{"name":"귤 군체 봇","race":1,"bot":true,"team":1}]})
	main.core=null;main.replay_mode=true;main.replay_frames=[]
	var records: Array=[]
	for compressed in recording.frames:records.append(main._replay_state(compressed))
	var overlays=CanvasLayer.new();overlays.layer=100;root.add_child(overlays)
	var backing=ColorRect.new();backing.position=Vector2(18,54);backing.size=Vector2(590,76);backing.color=Color(.025,.04,.06,.86);overlays.add_child(backing)
	var title=Label.new();title.position=Vector2(30,62);title.text="자동 조작 시연 · 정상 시작 · 3배속 하이라이트";title.add_theme_font_override("font",main.font);title.add_theme_font_size_override("font_size",20);overlays.add_child(title)
	var phase=Label.new();phase.position=Vector2(30,92);phase.add_theme_font_override("font",main.font);phase.add_theme_font_size_override("font_size",18);overlays.add_child(phase)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/playdemo-highlights"))
	var source_index=0
	var frame_index=0
	var windows=[[0.0,45.0],[90.0,135.0],[180.0,225.0],[240.0,375.0]]
	for window in windows:
		for tick in range(int((window[1]-window[0])/.6)):
			var stamp=window[0]+tick*.6
			while source_index<records.size()-1 and float(records[source_index+1].time)<=stamp:source_index+=1
			main.state=records[source_index].duplicate(true)
			var next: Dictionary=records[mini(source_index+1,records.size()-1)]
			var ratio=clampf((stamp-float(main.state.time))/maxf(.01,float(next.time)-float(main.state.time)),0,1)
			var next_units: Dictionary={}
			for unit in next.get("units",[]):next_units[int(unit.id)]=unit
			for unit in main.state.get("units",[]):
				if next_units.has(int(unit.id)) and int(unit.kind)==int(next_units[int(unit.id)].kind):unit.pos=ACData.packed(ACData.point(unit.pos).lerp(ACData.point(next_units[int(unit.id)].pos),ratio))
			main.state.time=stamp
			main._accept_visual_snapshot(main.state.units,stamp,true)
			var army=main.state.units.filter(func(u):return int(u.owner)==0 and int(u.kind)>0 and not u.get("technical",false))
			var home=Vector2(20,18)
			for building in main.state.buildings:
				if int(building.owner)==0 and int(building.kind)==0:home=main._center(building)
			var camera_goal=home
			if stamp>=225 and not army.is_empty():
				var enemies=main.state.units.filter(func(u):return int(u.owner)==1 and not u.get("technical",false))
				var best=INF
				var front: Dictionary={}
				for unit in army:
					if int(unit.kind)==4:continue
					var position=ACData.point(unit.pos)
					for enemy in enemies:
						var gap=position.distance_squared_to(ACData.point(enemy.pos))
						if gap<best:best=gap;front=unit;camera_goal=(position+ACData.point(enemy.pos))*.5
				if best>225:
					army.sort_custom(func(a,b):return ACData.point(a.pos).distance_squared_to(Vector2(109,108.5))<ACData.point(b.pos).distance_squared_to(Vector2(109,108.5)))
					camera_goal=ACData.point(army[0].pos)
				main.selected=army.slice(0,mini(12,army.size())).map(func(u):return u.id)
			else:
				main.selected=main.state.units.filter(func(u):return int(u.owner)==0 and int(u.kind)==0).slice(0,8).map(func(u):return u.id)
			main.camera=camera_goal if tick==0 else main.camera.lerp(camera_goal,.3)
			main._clamp_camera()
			phase.text="아스 채취 → 정비공 8기 → 보급·병영·정제소" if stamp<180 else ("사수·의무병 분대 생산" if stamp<225 else "실제 교전 · 사수·의무병 공격 이동")
			main._process(.2)
			main._update_hud()
			await process_frame
			await RenderingServer.frame_post_draw
			var image=root.get_texture().get_image()
			if int(stamp) in [240,250,260,290,300,310,360]:image.save_png("res://build/playdemo-battle-%03d.png"%int(stamp))
			image.resize(720,450,Image.INTERPOLATE_LANCZOS)
			image.save_png("res://build/playdemo-highlights/%05d.png"%frame_index)
			frame_index+=1
			if frame_index%50==0:print("PLAYDEMO_HIGHLIGHT frame=%d source=%.1f"%[frame_index,stamp])
	print("PLAYDEMO_HIGHLIGHTS_DONE frames=%d seconds=%.1f"%[frame_index,frame_index/5.0])
	quit()
