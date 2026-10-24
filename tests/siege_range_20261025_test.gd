extends SceneTree
var checks=0
var failures=[]
var cases=[]
const OUT="res://build/move-attack-followup-20261025/"
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func trial(c,origin: Vector2,distance: float,anchored: bool,expect_hit: bool) -> void:
	c.units.clear();c.collision_index_valid=false;c.threat_indexes.clear()
	var tank=c.add_unit(0,5,origin);var victim=c.add_unit(1,3,origin+Vector2(distance,0))
	tank.anchored=anchored;tank.order="hold";tank._scan_at=0;c.visibility[0].fill(1)
	var before=victim.hp;var start=tank.pos.duplicate();c._tick_unit(tank,.05)
	var hit=victim.hp<before
	check(hit==expect_hit,"range/minimum guard distance=%s deployed=%s"%[distance,anchored])
	check(tank.pos==start,"hold/deployed vehicle never walks to extend its range")
	cases.append({"distance":distance,"deployed":anchored,"hit":hit,"expected":expect_hit})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var c=ACCore.new();c.setup({"map":1,"seed":251026,"players":[{"race":0},{"race":1}]})
	c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
	var probe=c.add_unit(0,5,Vector2(67,52));var origin=Vector2.INF
	for y in range(24,100,3):
		for x in range(24,100,3):
			if c._ground_sweep(Vector2(1.6,1.6),Vector2(x,y),Vector2(x+14,y)):origin=Vector2(x,y);break
		if origin!=Vector2.INF:break
	check(origin!=Vector2.INF,"real terrain provides test firing lane")
	var d=ACData.unit(0,5)
	check(ACData.attack_range(d)==7.0,"mobile tank range remains seven")
	check(ACData.attack_range(d,true)==12.0,"deployed tank range is twelve")
	var fortress=ACData.unit(0,12)
	check(ACData.attack_range(fortress,true)==float(fortress.range)+3,"other deployed vehicle range remains unchanged")
	for item in [[11.5,true,true],[12.0,true,true],[12.2,true,false],[2.0,true,false],[2.6,true,true],[8.0,false,false],[6.9,false,true]]:
		trial(c,origin,item[0],item[1],item[2])
	c.units.clear();c.collision_index_valid=false
	var tank=c.add_unit(0,5,origin);var victim=c.add_unit(1,3,origin+Vector2(11.5,0))
	c.visibility[0].fill(1);var before=victim.hp
	c.command(0,{"type":"ability","ids":[tank.id]})
	c.time=float(tank.deploy_until)-.01;c._tick_unit(tank,.05)
	check(not tank.anchored and victim.hp==before,"deploy transition does not grant early fire")
	c.time+=.02;tank._scan_at=0;c._tick_unit(tank,.05)
	check(tank.anchored and victim.hp<before,"completed deployment acquires and fires in the expanded range")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"tank_mobile_range":7,"tank_deployed_range":12,"minimum_range":2.5,"cases":cases}
	FileAccess.open(OUT+"siege-range.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("SIEGE_RANGE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
