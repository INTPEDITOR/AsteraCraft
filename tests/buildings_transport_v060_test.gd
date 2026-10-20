extends "res://tests/view_input_v03_test.gd"
func present(c,e):
	main.state=c.snapshot(0);main.selected=[e.id];main.battle_hud.command_page=0;main._update_hud();await frames(2)
func run():
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);await frames(4)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);main.set_process(false)
	var audit=[]
	for race in range(3):
		main._start_local({"map":0,"players":[{"race":race},{"race":(race+1)%3}]});main.paused=true;main.set_process(false)
		var c=main.core;c.players[0].as=100000;c.players[0].tera=100000
		var buildings=[]
		for kind in range(13):buildings.append(c.add_building(0,kind,Vector2(40+kind%5*8,40+int(kind/5)*8),true))
		c._rebuild_collision_index()
		for b in buildings:
			await present(c,b)
			var d=ACData.building(race,int(b.kind));var hud=main.battle_hud
			check(hud.name_label.text==d.name and not hud.detail_label.text.is_empty(),"building identity and role %d:%d"%[race,b.kind])
			var research=ACResearch.catalog(race,int(b.kind));var produces=ACData.get_data().units[race].any(func(u):return int(u.get("producer",-1))==int(b.kind) and not u.get("spawn_only",false))
			check(hud.action_buttons.size()>0 or (not research.size()>0 and not produces) or race==1,"functional actions or documented passive role %d:%d"%[race,b.kind])
			audit.append({"race":race,"kind":b.kind,"name":d.name,"buttons":hud.action_buttons.size(),"research":research.size(),"role":str(d.description)})
		var kind=11
		var ship=c.add_unit(0,kind,Vector2(60,60));var rider=c.add_unit(0,1,Vector2(60,60))
		rider.container=ship.id;ship.cargo=[rider.id]
		await present(c,ship)
		check(main.battle_hud.queue_layer.get_child_count()==8,"eight cargo silhouette slots %d"%race)
		check(main.battle_hud.detail_label.text.contains("탑승 1기"),"cargo information %d"%race)
		main.battle_hud.queue_layer.get_child(0).pressed.emit()
		check(ship.cargo.is_empty() and rider.container<0,"cargo button actually unloads %d"%race)
		if race==0:
			var carrier=c.add_unit(0,14,Vector2(63,60));await present(c,carrier)
			check(main.battle_hud.action_specs.any(func(s):return s.get("key_name","")=="A"),"unarmed carrier still has attack command")
	FileAccess.open("res://build/qa-v060/building-roles.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"  "))
	print("BUILDINGS_TRANSPORT_V060 ",JSON.stringify({"checks":checks,"failures":failures}));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
