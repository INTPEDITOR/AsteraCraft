extends SceneTree
var checks=0
var failures=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:
	var c=ACCore.new();c.setup({"map":0,"seed":413,"players":[{"race":0},{"race":1},{"race":0}]});c.units.clear();c.buildings.clear()
	c.players[0].as=1000;c.players[0].tera=1000
	var a=c.add_unit(0,14,Vector2(64,64));var b=c.add_unit(0,14,Vector2(68,64));var foreign=c.add_unit(2,14,Vector2(66,65));var infantry=c.add_unit(0,1,Vector2(61,64))
	var result=c.command(0,{"type":"produce_drone","ids":[a.id,b.id,a.id,foreign.id,infantry.id]})
	check(result=="","mixed selection safely produces for the valid owned carriers")
	check(a.drone_queue.size()==1 and b.drone_queue.size()==1,"one click queues one drone on each distinct carrier")
	check(foreign.get("drone_queue",[]).is_empty(),"foreign carrier is never charged or queued")
	check(c.players[0].as==950 and c.players[0].tera==980,"only the two accepted queues consume resources")
	ACNewUnits.tick(c,a,8);ACNewUnits.tick(c,b,8)
	var da=c.entity(int(a.drones[0]));var db=c.entity(int(b.drones[0]))
	check(da.mother==a.id and db.mother==b.id and da.id!=db.id,"completed drones retain their own distinct mothers")
	check(da.container==a.id and db.container==b.id,"each drone is stored inside the carrier that produced it")
	check(da.hp==70 and db.hp==70,"new drone health is 70")
	var d=ACData.unit(0,15)
	check(d.damage==4 and d.period==.65 and d.armor==0,"damage, attack interval and armor remain unchanged")
	c._rebuild_collision_index();c._update_vision();c.time=10
	a.order="attack";a.target=foreign.id;b.order="attack";b.target=foreign.id
	ACNewUnits.tick(c,a,.01);ACNewUnits.tick(c,b,.01)
	check(da.container<0 and db.container<0,"both mothers can launch their own produced drones")
	check(da.pos==a.pos and db.pos==b.pos,"launch origin is each drone's own carrier")
	for i in range(7):a.drone_queue.append({"kind":15,"left":8.0,"total":8.0})
	var old_count=b.drone_queue.size();result=c.command(0,{"type":"produce_drone","ids":[a.id,b.id]})
	check(result=="" and b.drone_queue.size()==old_count+1 and a.drone_queue.size()==7,"full first carrier does not block another selected carrier")
	c.players[0].as=25;c.players[0].tera=10;b.drone_queue.clear();a.drone_queue.clear()
	result=c.command(0,{"type":"produce_drone","ids":[a.id,b.id]})
	check(result=="" and a.drone_queue.size()+b.drone_queue.size()==1,"limited resources queue only an affordable drone without double spending")
	print("CARRIER_MULTI_PRODUCTION checks=%d failures=%d"%[checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/visual_feedback_20261024"))
	FileAccess.open("res://build/visual_feedback_20261024/carrier-multi.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()},"\t"))
	quit(0 if failures.is_empty() else 1)
