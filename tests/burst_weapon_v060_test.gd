extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena(attacker_kind=10):
	var c=ACCore.new();c.setup({"map":0,"seed":601,"players":[{"race":0},{"race":0}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	var u=c.add_unit(0,attacker_kind,Vector2(40,40));var target=c.add_unit(1,6,Vector2(43,40))
	target.hp=1000;target.shield=0;target.order="hold";u.order="attack";u.target=target.id
	c._rebuild_collision_index();c._update_vision()
	return [c,u,target]
func _initialize():call_deferred("run")
func run():
	var data=ACData.unit(0,10)
	check(data.damage==8 and data.burst_count==5 and data.period==2,"five shots preserve forty base damage per cycle")
	for upgrades in [0,2]:
		for armor in [0,5]:
			var a=arena();var c=a[0];var u=a[1];var t=a[2];c.players[0].attack=upgrades;c.players[1].armor=armor
			var before=t.hp
			c._tick_unit_behavior(u,.01)
			check(u.burst_left==4 and c.effects.filter(func(e):return e.type=="shot").size()==1,"first shot starts immediately")
			for i in range(1,11):
				c.time=i*.05;c._tick_unit_behavior(u,.05)
			check(u.burst_left==0 and c.effects.filter(func(e):return e.type=="shot").size()==5,"five separately timed projectile effects")
			var expected=40+upgrades*2-float(t._definition.armor)-armor
			check(is_equal_approx(before-t.hp,expected),"armor and upgrades applied once across the full salvo")
			c.time=.7;c._tick_unit_behavior(u,.2)
			check(c.effects.filter(func(e):return e.type=="shot").size()==5,"no sixth shot before cooldown")
	for action in ["stop","move","hold","attack_move"]:
		var a=arena();var c=a[0];var u=a[1];var t=a[2];c._tick_unit_behavior(u,.01)
		c.command(0,{"type":action,"ids":[u.id],"pos":[60,60]})
		check(u.burst_left==0,"new manual order interrupts burst: "+action)
	for reason in ["dead","allied","distant","hidden"]:
		var a=arena();var c=a[0];var u=a[1];var t=a[2];c._tick_unit_behavior(u,.01)
		if reason=="dead":t.hp=0
		elif reason=="allied":c.mode="teams";c.players[1].team=c.players[0].team
		elif reason=="distant":t.pos=[80,80]
		else:c.visibility[0].fill(0)
		c.time=.15;ACCore.BURST.tick(c,u)
		check(u.burst_left==0,"invalid target cancels remaining shots: "+reason)
	# An explicit Attack on one's own unit is legal in the current rules.
	# It must not be confused with attacking another allied player's unit.
	var own=arena();var own_core=own[0];var own_unit=own[1];var own_target=own[2]
	own_core._tick_unit_behavior(own_unit,.01);own_target.owner=0;own_core.time=.15;ACCore.BURST.tick(own_core,own_unit)
	check(own_unit.burst_left==3,"explicit own-target attack permission remains unchanged")
	var a=arena();var c=a[0];var u=a[1];var t=a[2];t.hp=1;c._tick_unit_behavior(u,.01);c.time=.15;ACCore.BURST.tick(c,u)
	check(c.players[0].kills==1,"lethal burst counts one kill")
	for upgrades in [0,2]:
		for armor in [0,5]:
			a=arena(12);c=a[0];u=a[1];t=a[2];c.players[0].attack=upgrades;c.players[1].armor=armor
			var bystander=c.add_unit(1,1,Vector2(43,40.5));bystander.hp=1000;c._rebuild_collision_index();c._update_vision()
			c._tick_unit_behavior(u,.01)
			check(u.burst_left==2,"fortress starts three shell salvo")
			for i in range(1,11):c.time=i*.05;c._tick_unit_behavior(u,.05)
			var shots=c.effects.filter(func(e):return e.type=="shot")
			check(shots.size()==3 and shots.map(func(e):return e.barrel)==[0,1,2],"three cannon barrels fire in sequence")
			check(is_equal_approx(1000-t.hp,48+upgrades*2-float(t._definition.armor)-armor),"fortress keeps total damage and heavy bonus")
			check(bystander.hp<1000,"three cannon shells damage nearby enemies with splash")
	a=arena(12);c=a[0];u=a[1];t=a[2];u.anchored=true;t.pos=[48,40];c._rebuild_collision_index();c._update_vision();c._tick_unit_behavior(u,.01)
	c.time=.25;ACCore.BURST.tick(c,u)
	check(u.burst_left==1,"anchored range bonus retained during all three shots")
	u.self_repair_until=5;c._tick_unit_behavior(u,.01)
	check(u.burst_left==0,"emergency repair cancels remaining cannon shots")
	print("BURST_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
