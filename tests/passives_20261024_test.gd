extends "res://tests/abilities_v060_test.gd"
func run() -> void:
	var entries=ACData.get_data().research.filter(func(item):return item.has("unit_kind"))
	check(entries.size()==10,"exactly ten approved unit passives")
	var seen={};var movement=[];var shots=[]
	for item in entries:
		var key="%d:%d"%[int(item.race),int(item.unit_kind)]
		check(not seen.has(key) and item.max_level==1,"one one-time research per unit "+key);seen[key]=true
		check(not key in ["0:4","1:8","2:2","0:5","2:12"],"excluded strong/skilled units receive no passive")
		check((item.has("add") and not item.has("multiply")) or (item.has("multiply") and not item.has("add")),"one stat effect "+key)
		var c=arena(int(item.race),int(item.race));c.time=10
		c.map.source_walk_masks.clear();c.map.source_water_masks.clear();c.map.height_map.fill(0);c.map.reset_solids([])
		var base=ACData.unit(int(item.race),int(item.unit_kind));var expected=float(base[item.stat])*float(item.get("multiply",1))+float(item.get("add",0))
		var unit=c.add_unit(0,int(item.unit_kind),Vector2(40,40));var opponent=c.add_unit(1,int(item.unit_kind),Vector2(60,40));opponent.hp=100000
		unit.cooldown=float(base.period)*.6
		var building=c.add_building(0,int(item.building),Vector2(20,20),true)
		if not item.requires.is_empty():
			check(ACResearch.enqueue(c,0,building,item.id)!="" and c.players[0].as==10000,"advanced prerequisites checked before payment "+key)
		for kind in item.requires:c.add_building(0,int(kind),Vector2(20+int(kind)*4,20),true)
		check(ACResearch.enqueue(c,0,building,item.id)=="","research queues "+key)
		check(ACResearch.enqueue(c,0,building,item.id)!="","duplicate queue blocked "+key)
		ACResearch.tick(c,building,float(item.time))
		var effective=c.unit_data(unit)
		check(is_equal_approx(float(effective[item.stat]),expected),"existing unit effective stat "+key)
		for stat in ["hp","speed","range","period","damage","armor"]:
			if stat!=item.stat:check(effective[stat]==base[stat],"other stat unchanged "+key+" "+stat)
		check(c.unit_data(opponent)[item.stat]==base[item.stat],"enemy same kind not upgraded "+key)
		var fresh=c.add_unit(0,int(item.unit_kind),Vector2(44,44))
		check(is_equal_approx(float(c.unit_data(fresh)[item.stat]),expected),"new unit inherits "+key)
		check(unit.hp==effective.hp and fresh.hp==effective.hp,"full current/new HP caps "+key)
		check(is_equal_approx(float(unit.cooldown),float(effective.period)*.6),"remaining attack phase preserved "+key)
		check(ACResearch.enqueue(c,0,building,item.id)!="","completed research cannot repeat "+key)
		c.visibility[1].fill(1);var snapshot=c.snapshot(1);var visible=snapshot.units.filter(func(u):return u.id==unit.id)[0]
		check(is_equal_approx(float(ACData.entity_unit(visible,snapshot.players)[item.stat]),expected),"public effective stat without enemy research disclosure "+key)
		if item.stat=="speed":
			unit.path=[];unit.path_rev=-1;unit.repath=0;unit.pos=[40,40];c.collision_index_valid=false;c.paths_this_tick=0
			if base.air:
				for acceleration_tick in range(4):c._move(unit,Vector2(50,40),.1,.25)
			var start=ACData.point(unit.pos)
			c._move(unit,Vector2(50,40),.1,.25)
			var distance=ACData.point(unit.pos).distance_to(start);movement.append({"unit":key,"actual":distance,"expected":expected*.1})
			check(absf(distance-expected*.1)<.02,"actual movement uses upgraded speed "+key)
		if item.stat=="period":
			unit.cooldown=0;opponent.pos=[40.5,40];c._strike_unit(unit,opponent,effective)
			check(is_equal_approx(float(unit.cooldown),expected),"actual attack uses upgraded period "+key)
		if item.stat=="range":
			unit.order="hold";unit.target=opponent.id;unit._auto_target=opponent.id;unit.cooldown=0;unit.fired=-99;unit.pos=[40,40];opponent.pos=[40+expected-.1,40];c.visibility[0].fill(1);c._rebuild_collision_index()
			c._tick_unit_behavior(unit,.1)
			shots.append({"unit":key,"distance":expected-.1,"fired":unit.fired})
			check(float(unit.fired)>=c.time,"actual attack reaches beyond old range "+key)
	var result={"checks":checks,"failures":failures,"units":10,"movement":movement,"range_attacks":shots}
	DirAccess.make_dir_recursive_absolute("res://build/passives-20261024")
	FileAccess.open("res://build/passives-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PASSIVES_20261024 ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
