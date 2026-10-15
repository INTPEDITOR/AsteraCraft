extends "res://tests/view_input_v03_test.gd"

const OUT="res://build/graphics-review-v05/"
var captures: Array=[]

func capture(name: String) -> void:
	main._sync_world_canvas();main.queue_redraw()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	captures.append(name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1600,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(4)
	main.settings.edge_scroll=false
	for race in range(3):
		main.settings.last_played_race=race
		main._main_menu()
		main.ui.get_node("MainHub").choose_background(race)
		await capture("menu-r%d"%race)
		main._settings_menu()
		await capture("settings-r%d"%race)
		main._main_menu()
		main._start_local({"map":race,"seed":617,"players":[{"name":"Graphic review","race":race},{"name":"Review bot","race":(race+1)%3,"bot":true}]})
		main.paused=true;main.set_process(false)
		main.spectator=true
		main.state=main.core.snapshot()
		main._update_hud()
		await capture("map-start-r%d"%race)
		var c=main.core
		main.zoom=1.0
		c.units.clear();c.buildings.clear()
		var units: Array=[]
		for kind in range(13):
			var u=c.add_unit(0,kind,Vector2(51+(kind%7)*3.8,60+int(kind/7)*6))
			units.append(u)
		main.camera=Vector2(64,63);main._clamp_camera()
		for heading in range(4):
			var direction=Vector2.UP.rotated(heading*PI*.5)
			for u in units:
				u.facing=ACData.packed(direction);u.body_direction=u.facing.duplicate();u.turret_direction=u.facing.duplicate()
				u.action="walk";u.action_clock=.12;u.moving=true
			main.state=c.snapshot();main.selected=[units[4].id]
			main.visual_motion.clear();main._accept_visual_snapshot(main.state.units,c.time,true)
			main._update_hud()
			await capture("units-r%d-heading%d"%[race,heading])
		c.units.clear()
		var buildings: Array=[]
		for kind in range(13):
			buildings.append(c.add_building(0,kind,Vector2(48+(kind%5)*7,54+int(kind/5)*7),true))
		main.camera=Vector2(64,63)
		for phase in [1.0,.15,.5,.8]:
			for b in buildings:b.progress=phase
			main.state=c.snapshot();main.selected=[buildings[7].id];main._update_hud()
			await capture("buildings-r%d-phase%d"%[race,roundi(phase*100)])
		# Restore the actual base and its mineral/vent surroundings for terrain review.
		main._start_local({"map":race,"seed":617,"players":[{"name":"Graphic review","race":race},{"name":"Review bot","race":(race+1)%3,"bot":true}]})
		main.paused=true;main.spectator=true;main.set_process(false)
		main.camera=Vector2(32,32) if race==0 else (Vector2(36,29) if race==1 else Vector2(39,43))
		main._clamp_camera();main.state=main.core.snapshot();main._update_hud()
		await capture("ramp-r%d"%race)
		main.core.ended=true;main.core.winners=[0];main.state=main.core.snapshot()
		main._show_result()
		await capture("result-r%d"%race)
		main._main_menu()
	main._release_pointer()
	var pixels=root.get_texture().get_size()
	FileAccess.open(OUT+"capture-index.json",FileAccess.WRITE).store_string(JSON.stringify({"logical_resolution":[1600,900],"capture_resolution":[pixels.x,pixels.y],"captures":captures,"note":"Unit/building grids are controlled visual fixtures; map-start and ramp captures use the real maps."},"\t"))
	print("GRAPHICS_REVIEW captures=",captures.size())
	quit()
