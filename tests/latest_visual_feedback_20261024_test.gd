extends SceneTree
var main
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func frames(n=3):
	for _i in range(n):await process_frame
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	main._start_local({"map":1,"players":[{"race":2},{"race":0}]});main.paused=true;main.set_process(false);main.settings.edge_scroll=false;main.spectator=true
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.reset_solids([]);c.collision_index_valid=false
	var worker=c.add_unit(0,0,Vector2(64,64));worker.facing=[-1,0];worker.action="harvest";worker.action_clock=.2
	main.state=c.snapshot(-1);main._accept_visual_snapshot(main.state.units,c.time,true);main.camera=ACData.point(worker.pos);main.zoom=1.75;main._sync_world_canvas();await frames()
	var node=main._entity_canvases[int(worker.id)];var zooms=[]
	for i in range(24):
		node.next_pose=100000 # Isolate zoom changes from scheduled animation redraw.
		main.zoom=1.75+float(i+1)*.02;main._sync_world_canvas();await frames(1);await RenderingServer.frame_post_draw
		check(is_equal_approx(node.drawn_zoom,main.zoom),"body scale updates every display frame %d"%i);zooms.append(node.drawn_zoom)
	var lib=main.assets.sprites
	for heading in [12,14]:
		for phase in range(7):
			var pose=lib.unit(2,0,Vector2.UP.rotated(float(heading)*TAU/16),"harvest",float(phase)/12.0)
			check(pose.flip,"owl W/NW harvesting uses correctly reflected existing phase")
	for race in range(3):
		var d=ACData.building(race,0)
		for progress in [0.0,.01,.1,.5,.99,1.0]:
			var capacity=ACBuildingDamageVisual.health_capacity(d.hp,progress)
			check(ACBuildingDamageVisual.damage_stage(capacity-.00001,capacity)==0,"floating point construction growth does not emit flames")
			check(not ACBuildingDamageVisual.received_damage({"progress":progress,"hp":capacity*.5,"damaged":-99}),"unattacked construction never emits damage effect")
		check(ACBuildingDamageVisual.received_damage({"damaged":1}),"actual attack enables damage effect")
	# Show restrained orange/blue flame colors on existing finished art.
	c.units.clear();c.buildings.clear();c.collision_index_valid=false
	for race in [0,2]:
		c.players[race/2].race=race
		var b=c.add_building(race/2,0,Vector2(60+race*4,64),true);b.hp*=.5;b.damaged=c.time
	main.state=c.snapshot(-1);main.camera=Vector2(66,65);main.zoom=1.3;main._update_hud();main._sync_world_canvas();await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/player_colors_20261024/flames-and-terrain.png")
	var output={"checks":checks,"failures":failures,"zoom_rendered_each_frame":zooms}
	FileAccess.open("res://build/player_colors_20261024/latest-visual.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("LATEST_VISUAL ",JSON.stringify(output));main.queue_free();await frames(2);quit(0 if failures.is_empty() else 1)
