extends "res://tests/view_input_v03_test.gd"
## Quick resource/draw/bounds pass only, not physical direction or animation approval.
class QuickProbe:
	extends "res://tests/menu_v04_harness.gd"
	var painted={}
	func _draw_unit(unit: Dictionary) -> void:
		painted[int(unit.id)]=true
		super._draw_unit(unit)

var report_path="res://build/sprite_connected_20261024/quick-review.json"
var cases=[]
var live=[]

func refresh() -> void:
	main.state=main.core.snapshot(-1)
	main._accept_visual_snapshot(main.state.units,main.core.time,true)
	main.painted.clear()
	for node in main._entity_canvases.values():node.next_pose=0
	main._sync_world_canvas();main.queue_redraw();await frames(3)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/sprite_connected_20261024/quick-%s.png"%label)

func sample_actions(race: int,kind: int,definition: Dictionary) -> void:
	var key="%d:%d"%[race,kind]
	var valid=true;var bounds_ok=true;var count=0
	for action in ["idle","walk","attack","work","heal","death"]:
		if not main.assets.sprites.has_action(race,kind,action):continue
		for h in range(16 if action!="death" else 1):
			for phase in [0,3,6]:
				var direction=Vector2.UP.rotated(TAU*h/16)
				var clock=(phase+.05)/14.0 if action=="attack" else (phase+.05)/9.0
				var pose=main.assets.unit(race,kind,direction,action,clock)
				valid=valid and not pose.is_empty() and pose.get("texture")!=null
				if not pose.is_empty():
					var b: Rect2=pose.get("sprite_bounds",Rect2(Vector2.ZERO,pose.cell_size))
					bounds_ok=bounds_ok and b.has_area() and Rect2(Vector2.ZERO,pose.cell_size).encloses(b)
				count+=1
	check(valid,key+": sampled actions/headings have loadable in-range texture regions")
	check(bounds_ok,key+": sampled cell bounds are nonempty and contained")
	cases.append({"key":key,"samples":count,"resource_pass":valid,"bounds_pass":bounds_ok,"full_art_review":false})

func run() -> void:
	root.content_scale_size=Vector2i(2000,1400);root.size=Vector2i(2000,1400)
	main=QuickProbe.new();root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":0,"seed":413,"players":[{"race":0},{"race":1},{"race":2}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.settings.edge_scroll=false;main.zoom=1.3
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles()
	c.time=10;main.camera=Vector2(64,64);main._clamp_camera();main._update_hud()
	var index=0
	for race in range(3):
		for kind in range(16 if race==0 else 14):
			var key="%d:%d"%[race,kind];var definition: Dictionary=main.assets.sprites.units.get(key,{})
			check(not definition.is_empty() and definition.get("staged16",false),key+": normal game catalog uses connected sprite")
			sample_actions(race,kind,definition)
			var screen=Vector2(210+(index%8)*225,165+(index/8)*160)
			var pos=main.screen_to_world(screen)
			var unit=c.add_unit(race,kind,pos);unit.pos=ACData.packed(pos);unit.goal=unit.pos.duplicate();unit.facing=[0,1];unit.body_direction=[0,1];unit.turret_direction=[0,1];unit.cooldown=100
			live.append(unit)
			var label=Label.new();label.text=key;label.position=screen+Vector2(-20,15);main.add_child(label)
			index+=1
	for action in ["idle","walk","attack"]:
		for unit in live:
			var definition: Dictionary=main.assets.sprites.units["%d:%d"%[unit.race,unit.kind]]
			var selected=action if main.assets.sprites.has_action(int(unit.race),int(unit.kind),action) else "idle"
			unit.action=selected;unit.action_started=c.time-.22;unit.action_clock=.22;unit.moving=selected=="walk";unit.fired=c.time-.22 if selected=="attack" else -99
			main.visual_motion[int(unit.id)]={"walking":selected=="walk","phase":3.05,"pos":ACData.point(unit.pos)}
		await refresh()
		check(main.painted.size()==44,action+": all44 actual entities reached the renderer")
		var visible=true
		for unit in live:
			var rect: Rect2=main.render_rects.get(int(unit.id),Rect2())
			visible=visible and rect.has_area() and Rect2(Vector2.ZERO,main.size).encloses(rect)
		check(visible,action+": all44 actual unit bounds stay fully on screen")
		await capture(action)
	for unit in live:
		c._death_visual(unit,-1)
	c.units.clear();c.time+=.35;await refresh();await capture("death")
	check(c.effects.filter(func(fx):return fx.type=="death").size()==44,"all44 faction death visual events are present")
	var result={"checks":checks,"failures":failures,"passed":failures.is_empty(),"unit_count":44,"cases":cases,"native":DisplayServer.get_name(),"scope":"Quick resource/action samples and actual all44 render bounds only; full direction/anatomy/animation review remains deferred."}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QUICK_RELEASE44 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
