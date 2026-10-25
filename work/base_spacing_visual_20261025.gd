extends "res://tests/view_input_v03_test.gd"
const OUT="res://build/base-resource-spacing-20261025/visual/"
var screens=[]
func capture(c,race: int,anchor: Vector2,expected: bool) -> void:
	main.state=c.snapshot(0);main._accept_visual_snapshot(main.state.units,c.time,true)
	main.build_kind=0;main.pointer_position=main._ground_point(anchor+Vector2(2,1.5))
	check(main._build_position(main.pointer_position)==anchor,"actual pointer resolves construction anchor race=%d"%race)
	main.battle_hud.update_hud(true)
	main._sync_player_overlays()
	main._sync_world_canvas();main.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	var ghost=main._player_overlay_canvases.get("ghost")
	check(ghost!=null and bool(ghost.data.valid)==expected,"actual construction preview validity race=%d allowed=%s"%[race,expected])
	var file="race%d-%s.png"%[race,"allowed-as2-tera2" if expected else "blocked-too-close"]
	root.get_texture().get_image().save_png(OUT+file)
	screens.append({"race":race,"file":file,"allowed":expected,"anchor":ACData.packed(anchor),"actual_ghost":ghost.data.duplicate() if ghost!=null else {},"pointer":ACData.packed(main.pointer_position)})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(4);main.set_process(false)
	main.set_process_input(false);main.set_process_unhandled_input(false)
	# The QA cursor is injected below. Desktop focus/mouse events must not
	# replace it halfway through a frame while the user reviews screenshots.
	for connection in root.mouse_exited.get_connections():
		if connection.callable.get_object()==main:root.mouse_exited.disconnect(connection.callable)
	root.size=Vector2i(1920,1080);ACSettings.keep_game_aspect();await frames(3)
	for race in range(3):
		main._start_local({"map":0,"seed":251025,"players":[{"race":race},{"race":(race+1)%3}]})
		main._stop_simulation_worker()
		main.set_process(false);main.settings.edge_scroll=false;main.spectator=false
		var c=main.core;c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		var good=ACData.point(c.map.headquarters_sites[3]);var bad=good-Vector2(0,1)
		var worker=c.add_unit(0,0,good+Vector2(5,2));c._update_vision()
		# Reveal the QA scene so the complete mineral line and vent fit in one
		# comparison. Player mode stays active for the actual build preview.
		c.visibility[0].fill(1);c.explored[0].fill(1);c.vision_revisions[0]=int(c.vision_revisions.get(0,0))+1
		main.selected=[worker.id];main.camera=good+Vector2(1.5,1);main.zoom=1.6
		main.camera.y-=(main._view_rect().get_center().y+24*main.zoom-main._ground_point(main.camera).y)/(32*main.zoom)
		await capture(c,race,bad,false)
		await capture(c,race,good,true)
		main.build_kind=-1;main.pointer_position=Vector2.INF
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screens":screens,"runtime":"actual source game renderer and construction preview at 1920x1080; all three factions"}
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BASE_SPACING_VISUAL ",JSON.stringify(result));main._release_pointer();quit(0 if failures.is_empty() else 1)
