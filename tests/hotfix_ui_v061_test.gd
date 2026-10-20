extends "res://tests/view_input_v03_test.gd"
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4)
	main.settings.edge_scroll=false
	var buttons=0
	for race in range(3):
		main._start_local({"map":0,"seed":611,"players":[{"race":race},{"race":(race+1)%3}]})
		main.paused=true;main.set_process(false)
		var c=main.core;c.players[0].as=100000;c.players[0].tera=100000
		for kind in range(13):c.add_building(0,kind,Vector2(20+(kind%5)*8,20+(kind/5)*8),true)
		c._rebuild_collision_index();c._recalculate_supply()
		for building in c.buildings:
			if int(building.owner)!=0:continue
			main.state=c.snapshot(0);main.selected=[building.id];main.battle_hud.command_page=0;main._update_hud();await frames()
			for button in main.battle_hud.action_buttons:
				var spec: Dictionary=button.get_meta("spec");var cost: Dictionary=spec.cost
				if cost.has("role") and not cost.has("w"):
					buttons+=1
					check(not button.disabled and button.modulate.is_equal_approx(Color.WHITE),"affordable production is fully bright %d %s"%[race,spec.title])
					var lines=str(button.get_meta("help_text")).split("\n");var unique={};var duplicate=false
					for line in lines:
						if line!="" and unique.has(line):duplicate=true
						unique[line]=true
					check(not duplicate,"production tooltip lines are unique %d %s"%[race,spec.title])
		if race==0:
			var units=[]
			for kind in [5,6,8,9,10,11,12,13,14,15]:units.append(c.add_unit(0,kind,Vector2(62+(units.size()%5)*2.7,60+(units.size()/5)*4)))
			main.spectator=true;main.camera=Vector2(67,63);main.state=c.snapshot();main._accept_visual_snapshot(main.state.units,c.time,true)
			main.selected=[units[0].id];main._update_hud();main._sync_world_canvas();main.world_canvas.queue_redraw();await frames(4)
			for u in units:
				var bounds: Rect2=main.render_rects[u.id];var middle=main._selection_center(u)
				check(main._drag_hits_unit(Rect2(middle-Vector2(12,5),Vector2(24,10)),u),"drag across actual body selects %d"%int(u.kind))
				check(not main._drag_hits_unit(Rect2(bounds.end+Vector2(20,20),Vector2(8,8)),u),"empty space does not select %d"%int(u.kind))
				if int(u.kind)==13:check(bounds.size.x/main.zoom<50 and bounds.size.y/main.zoom<50,"flamer display size reduced and empty atlas padding excluded")
				if main._selection_bodies.has(int(u.id)):
					var chassis: Rect2=main._selection_bodies[int(u.id)]
					var lower_body=Rect2(chassis.position+chassis.size*Vector2(.1,.55),chassis.size*Vector2(.8,.4))
					check(main._drag_hits_unit(lower_body,u),"drag across lower chassis selects without touching tall gun or missile %d"%int(u.kind))
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://build/qa-v061-vehicles.png")
			main.spectator=false;var missile=units[1];main.selected=[missile.id];main._update_hud()
			var point=main._ground_point(ACData.point(missile.pos)+Vector2(2,0))
			var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=point;event.global_position=point;event.pressed=true
			root.push_input(event,true);await frames()
			check(missile.order=="move","physical right click reaches missile vehicle movement order")
			main.spectator=false
	check(buttons>=20,"production availability inspected across all faction buildings")
	var report={"checks":checks,"buttons":buttons,"failures":failures};FileAccess.open("res://build/qa-v061-ui.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HOTFIX_UI_V061 ",JSON.stringify(report));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
