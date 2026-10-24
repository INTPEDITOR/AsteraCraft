extends SceneTree
var checks=0
var failures=[]
var cases=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func reset(c) -> void:
	c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
	c.path_cache.clear();c.crowd_arrival_cache.clear();c.paths_this_tick=0;c.path_time_this_tick=0
func run() -> void:
	var c=ACCore.new();c.setup({"map":1,"seed":251027,"players":[{"race":0},{"race":1},{"race":2},{"race":0}]})
	reset(c)
	var centre=Vector2.INF
	for y in range(28,100,3):
		for x in range(28,100,3):
			if c._ground_sweep(Vector2(4.4,4.4),Vector2(x-3,y-3),Vector2(x+3,y+3)):centre=Vector2(x,y);break
		if centre!=Vector2.INF:break
	check(centre!=Vector2.INF,"native map has a clear melee contact arena")
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			var d=ACData.unit(race,kind)
			if d.air or float(d.damage)<=0 or float(d.range)>1.5:continue
			for building in [false,true]:
				for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
					reset(c)
					var target=c.add_building(3,0,centre-Vector2(2,1),true) if building else c.add_unit(3,12,centre)
					target.hp=100000;target.shield=0;target.anchored=true;target.order="hold"
					c.map.reset_solids(c.buildings);c.collision_index_valid=false
					var attacker=c.add_unit(race,kind,centre+direction*5)
					attacker.order="attack";attacker.target=target.id;c.visibility[race].fill(1)
					var before=target.hp;var attack_tick=-1
					for tick in range(500):
						c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0
						c._tick_unit(attacker,.05)
						if target.hp<before:attack_tick=tick;break
					var label="%d:%d building=%s direction=%s"%[race,kind,building,direction]
					check(attack_tick>=0,"melee attacks a large target "+label)
					var gap=c.combat_body_gap(attacker,target)
					var allowed=float(d.range)+(1.35 if building else 0)
					check(gap<=.122 or c.center(attacker).distance_to(c.center(target))<=allowed+.002,"damage occurs within physical reach "+label)
					var overlap=c.collision_rect(attacker).intersection(c.footprint(target) if building else c.collision_rect(target))
					check(overlap.size.x<=.003 or overlap.size.y<=.003,"melee never enters the target body "+label)
					cases.append({"race":race,"kind":kind,"building":building,"direction":ACData.packed(direction),"attack_seconds":attack_tick*.05,"body_gap":gap})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases}
	DirAccess.make_dir_recursive_absolute("res://build/move-attack-followup-20261025/")
	FileAccess.open("res://build/move-attack-followup-20261025/melee-scenarios.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("MELEE_SCENARIOS ",JSON.stringify({"passed":result.passed,"checks":checks,"cases":cases.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
