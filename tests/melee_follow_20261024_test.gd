extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var reports=[]
	for reverse in [false,true]:
		for order_first in [false,true]:
			var c=ACCore.new();c.setup({"map":0,"players":[{"race":1},{"race":2}]})
			c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c.collision_index_valid=false
			for fog in c.visibility:fog.fill(2)
			var target=c.add_unit(1,0,Vector2(64,64));target.hp=5000;target.shield=0;target.order="move";target.goal=[100,64]
			var attackers=[]
			for offset in [Vector2(-2,0),Vector2(-2,1),Vector2(-2,-1),Vector2(-3,2),Vector2(-3,-2)]:
				var u=c.add_unit(0,1,Vector2(64,64)+offset);u.order="attack";u.target=target.id;attackers.append(u)
			var shots=0;var attack_stops=0
			for tick in range(320):
				c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0
				if reverse and tick%80==0:target.goal=[100 if (tick/80)%2==0 else 45,64];target.order="move"
				if order_first:c._tick_unit(target,.05)
				for u in attackers:
					var fired=u.fired;c._tick_unit(u,.05)
					if u.fired!=fired:shots+=1
					if u.action=="attack" and not u.moving:attack_stops+=1
				if not order_first:c._tick_unit(target,.05)
			var label="reverses=%s target_first=%s"%[reverse,order_first]
			check(shots>=12,"melee damages retreating/advancing target "+label)
			check(attack_stops>=shots*2,"melee visibly plants its feet to strike "+label)
			reports.append({"case":label,"strikes":shots,"attack_pose_ticks":attack_stops,"target_hp":target.hp})
	var output={"checks":checks,"failures":failures,"cases":reports}
	FileAccess.open("res://build/player_colors_20261024/melee.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("MELEE_FOLLOW ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
