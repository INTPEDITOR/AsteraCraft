extends SceneTree

var main
var failures=[]
var report=[]

func frames(n=3):
	for _i in range(n):await process_frame

func check(ok,label):
	if not ok:failures.append(label);printerr("FAIL ",label)

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1440,900)
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	main._start_local({"map":0,"seed":925,"players":[{"race":0},{"race":2}]})
	main.paused=true;main.set_process(false);main.settings.edge_scroll=false;main.spectator=true
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.collision_index_valid=false
	var resource={}
	var nearest=INF
	for node in c.map.resources:
		if node.type=="tera":
			var distance=ACData.point(node.pos).distance_squared_to(Vector2(64,64))
			if distance<nearest:nearest=distance;resource=node
	check(not resource.is_empty(),"source map contains an actual catalyst")
	if resource.is_empty():quit(1);return
	var anchor=c.refinery_anchor(resource)
	check(anchor.is_finite(),"actual catalyst has an exact construction anchor")
	main.camera=ACData.point(resource.pos);main.zoom=2.0
	for race in range(3):
		c.buildings.clear();c.players[0].race=race
		var b=c.add_building(0,1,anchor,false)
		for progress in [.12,.6,.94,1.0]:
			b.progress=progress;b.hp=ACBuildingDamageVisual.health_capacity(ACData.building(race,1).hp,progress)
			main.state=c.snapshot(-1)
			main.state.resources=[resource.duplicate(true)]
			main._update_hud();main._sync_world_canvas();await frames(4)
			var vent_node=main._entity_canvases.get(int(resource.id))
			var building_node=main._entity_canvases.get(int(b.id))
			check(vent_node!=null and building_node!=null,"actual resource and construction remain renderable")
			if progress<1 and vent_node!=null and building_node!=null:
				check(vent_node.z_index<building_node.z_index,"original deposit stays beneath unfinished building race%d progress%.2f"%[race,progress])
			var presence=main._catalyst_presence(resource)
			check(presence>0 if progress<1 else presence==0,"deposit survives until completion race%d progress%.2f"%[race,progress])
			await RenderingServer.frame_post_draw
			var file="res://build/player_colors_20261024/catalyst-r%d-p%03d.png"%[race,roundi(progress*100)]
			root.get_texture().get_image().save_png(file)
			report.append({"race":race,"progress":progress,"presence":presence,"image":file})
	var result={"failures":failures,"frames":report}
	FileAccess.open("res://build/player_colors_20261024/catalyst-fusion.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CATALYST_FUSION ",JSON.stringify(result));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
