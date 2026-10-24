extends "res://tests/view_input_v03_test.gd"
const KEY="frontline_vitality"
const OUT="res://build/frontline-20261024/"
func redraw() -> void:
	main.state=main.core.snapshot(0);main._sync_world_canvas();main.battle_hud.update_hud(true);main.queue_redraw();await frames(3)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames(3)
	main._start_local({"map":1,"seed":601,"mode":"ffa","players":[{"race":0},{"race":0},{"race":1}]})
	main.paused=true;main.set_process(false);main.spectator=true;main.camera=Vector2(42,40);main.zoom=2
	var c=main.core;c.units.clear();c.buildings.clear();c.effects.clear();c.map.resources.clear();c.map.reset_solids([])
	c.players[0].as=1000;c.players[0].tera=1000;c.players[0].cap=200;c.players[0].technologies={}
	var full=c.add_unit(0,1,Vector2(40,40));var wounded=c.add_unit(0,1,Vector2(42,40));wounded.hp=50
	var dead=c.add_unit(0,1,Vector2(39,39));dead.hp=0
	var enemy=c.add_unit(1,1,Vector2(44,40));var assault=c.add_unit(0,2,Vector2(40,42));var medic=c.add_unit(0,4,Vector2(40,41));medic.energy=100
	var barracks=c.add_building(0,7,Vector2(36,37),true)
	check(full.hp==70 and ACData.max_health(full,c.players)==70,"unresearched rifle remains70")
	check(ACResearch.catalog(0,7).filter(func(item):return item.id==KEY).size()==1,"single rifle health research in field infirmary")
	check(ACResearch.definition(0,3,KEY).is_empty(),"rifle production building no longer researches health")
	check(ACResearch.catalog(1,8).all(func(item):return item.id!=KEY),"parasite building receives no new passive")
	var definition=ACResearch.definition(0,7,KEY)
	check(definition.max_level==1,"research can be completed only once")
	check(ACResearch.enqueue(c,0,barracks,KEY)=="","queue accepts new research")
	check(c.players[0].as==900 and c.players[0].tera==900,"100/100 cost charged once")
	check(ACResearch.enqueue(c,0,barracks,KEY)!="" and c.players[0].as==900,"duplicate queue spends nothing")
	check(ACResearch.cancel(c,0,barracks)=="" and c.players[0].as==1000 and c.players[0].tera==1000,"cancel refunds research in full")
	check(ACResearch.level(c.players[0],KEY)==0 and full.hp==70,"cancel gives no health")
	check(ACResearch.enqueue(c,0,barracks,KEY)=="","research can restart after cancel")
	ACResearch.tick(c,barracks,44)
	check(full.hp==70 and ACResearch.level(c.players[0],KEY)==0,"no early health bonus")
	main.selected=[barracks.id];await redraw()
	check(main.battle_hud.action_specs.any(func(spec):return not spec.is_empty() and spec.get("cost",{}).get("research_stat","")==KEY),"actual production card contains health research")
	ACResearch.tick(c,barracks,1)
	check(ACResearch.level(c.players[0],KEY)==1,"completion records owner technology")
	check(full.hp==85 and wounded.hp==65,"existing full/wounded units gain15 and retain missing health")
	check(dead.hp==0,"completion does not resurrect dead units")
	check(enemy.hp==70 and assault.hp==110 and medic.hp==75,"other owners/kinds unchanged")
	check(ACData.unit(0,1).hp==70,"shared unit definition is not mutated")
	var trained=c.add_unit(0,1,Vector2(45,42));check(trained.hp==85,"new rifle spawns with85")
	check(ACResearch.enqueue(c,0,barracks,KEY)!="","completed research cannot repeat")
	ACResearch.tick(c,barracks,100);check(full.hp==85,"idle tick adds no second bonus")
	full.hp=84;wounded.hp=85;c._rebuild_collision_index();c._support(medic,ACData.unit(0,4),1)
	check(full.hp==85,"medical healing reaches new85 cap")
	var energy=medic.energy;c._support(medic,ACData.unit(0,4),1)
	check(full.hp==85 and medic.energy==energy,"full upgraded patient consumes no healing energy")
	c.visibility[0].fill(1);c.visibility[1].fill(1)
	var visible=c.snapshot(1);var visible_rifle=visible.units.filter(func(unit):return unit.id==full.id)[0]
	check(not visible.players[0].has("technologies") and visible_rifle.max_hp==85,"enemy snapshot includes visible cap without private research")
	check(ACData.max_health(visible_rifle,visible.players)==85,"enemy HUD reads public85 cap")
	main.selected=[full.id];await redraw()
	check(main.battle_hud._definition.hp==85 and "85 / 85" in main.battle_hud.detail_label.text,"single selection shows85/85")
	main.selected=[full.id,wounded.id];await redraw()
	check(main.battle_hud.selection_buttons.all(func(button):return button.get_meta("max_hp")==85),"multi selection uses85 health meters")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"researched-rifle-health.png")
	var caster=c.add_unit(2,8,Vector2(40,40));caster.energy=200;c.visibility[2].fill(1)
	check(c._mind_control(caster,full.id)=="" and full.owner==2 and full.hp==70,"capture by owner without research clamps health to70")
	check(ACData.max_health(full,c.players)==70,"captured unit uses new owner cap")
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"unit":"0:1","building":"0:7","base_hp":70,"researched_hp":85,"cost":[100,100],"time":45,"total_approved_passives":10},"\t"))
	print("FRONTLINE_VITALITY checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
