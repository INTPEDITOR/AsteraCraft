extends SceneTree
var main
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func frames(n=2):
	for _i in range(n):await process_frame
func select(ids):
	main.selected=ids;main.state=main.core.snapshot(-1);main._update_hud();main.battle_hud.update_hud(true)
func run():
	main=load("res://tests/menu_v04_harness.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	main._start_local({"map":0,"players":[{"race":1},{"race":0}]});main.paused=true;main.set_process(false)
	var c=main.core;c.players[0].as=5000;c.players[0].tera=5000;c.players[0].cap=200
	var hq=c.entity(c.players[0].home);var pods=ACCitrusBrood.idle_pods(c,hq);var first=pods[0];var second=pods[1]
	check(c.command(0,{"type":"morph","id":first.id,"kind":0})=="","first pod begins morph")
	select([first.id,second.id]);var hud=main.battle_hud
	check(hud.action_buttons.any(func(b):return int(b.get_meta("spec").icon)==hud.ICON_TRAIN),"mixed selection shows unit production even when leader is morphing")
	check(not hud.action_buttons.any(func(b):return int(b.get_meta("spec").icon)==hud.ICON_CANCEL),"mixed selection does not show cancellation")
	check(c.command(0,{"type":"morph","ids":[first.id,second.id],"kind":0})=="" and second.brood_state=="morph","production applies only to selected idle pod")
	select([first.id,second.id])
	check(hud.action_buttons.size()==1 and int(hud.action_buttons[0].get_meta("slot"))==11,"all morphing pods show only bottom-right cancel")
	var before=c.players[0].as
	check(c.command(0,{"type":"cancel_morph","ids":[first.id,second.id]})=="","group morph cancellation succeeds")
	check(first.hp==0 and second.hp==0 and c.players[0].as==before+100,"each cancelled pod dies and refunds exactly once")
	for race in range(3):
		c.players[0].race=race
		for kind in range(ACData.unit_count(race)):
			var u=c.add_unit(0,kind,Vector2(64,64));select([u.id])
			for button in hud.action_buttons:
				var spec=button.get_meta("spec");var slot=int(button.get_meta("slot"))
				if int(spec.icon)==hud.ICON_ABILITY or spec.cost.has("skill") or int(spec.icon)==hud.ICON_UNLOAD:check(slot>=8 and slot<=10,"unit skill stays bottom-left %d:%d"%[race,kind])
				if int(spec.icon)==hud.ICON_CANCEL:check(slot==11,"unit cancel stays bottom-right")
			c.units.erase(u);c.collision_index_valid=false
		var b=c.add_building(0,2,Vector2(40,40),false);select([b.id])
		check(hud.action_buttons.size()==1 and int(hud.action_buttons[0].get_meta("slot"))==11,"construction cancel bottom-right race%d"%race)
	var output={"checks":checks,"failures":failures};FileAccess.open("res://build/player_colors_20261024/command-layout.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("COMMAND_LAYOUT ",JSON.stringify(output));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
