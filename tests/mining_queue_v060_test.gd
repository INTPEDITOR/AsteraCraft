extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var c=ACCore.new();c.setup({"map":0,"players":[{"race":0},{"race":1}]})
	c.units.clear();c.buildings.clear();c.map.terrain.fill(0);c.map.resources=[];c.map.reset_solids([])
	var home=c.add_building(0,0,Vector2(25,28),true)
	for item in [[100000,34.5,32,0],[100001,38.5,34,0],[100002,65.5,32,1]]:c.map.resources.append({"id":item[0],"pos":[item[1],item[2]],"type":"as","amount":1500,"initial_amount":1500,"busy":0,"base":item[3]})
	c._sync_resource_obstacles();c.map.reset_solids(c.buildings);c.collision_index_valid=false
	var first=c.add_unit(0,0,Vector2(33,32));first.order="gather";first.target=100000
	var second=c.add_unit(0,0,Vector2(37,34));second.order="gather";second.target=100001
	check(c._claim_miner(first,c.resource(100000)) and c._claim_miner(second,c.resource(100001)),"both local nodes occupied")
	var waiting=c.add_unit(0,0,Vector2(33.1,32));waiting.order="gather";waiting.target=100000;waiting.auto_mine_hq=home.id;waiting.mining_base=0;waiting.mining_anchor=[34.5,32]
	check(c._home_ore(waiting)==100000,"all occupied queues at closest local ore, ignores remote free ore")
	c._gather(waiting,.05)
	check(waiting.target==100000 and waiting.mining_state=="waiting" and not waiting.moving,"occupied closest ore waits in place")
	var later=c.add_unit(0,0,Vector2(33.1,32.2));later.order="gather";later.target=100000;later.mining_base=0;later.mining_anchor=[34.5,32]
	c._gather(later,.05)
	first.carried=5;c._release_mining_claim(first)
	check(not c._claim_miner(later,c.resource(100000)),"later arrival cannot jump queue")
	check(c._claim_miner(waiting,c.resource(100000)),"first waiting worker claims newly free resource")
	waiting.carried=5;c._release_mining_claim(waiting)
	check(c._claim_miner(later,c.resource(100000)),"next waiting worker gets a turn")
	for node in c.map.resources:
		if int(node.base)==0:node.amount=0
	c._sync_resource_obstacles();waiting.carried=8;waiting.order="gather";waiting.target=100000
	var before=c.players[0].as
	for tick in range(600):
		c.time+=.05;c.paths_this_tick=0;c.collision_index_valid=false;c._tick_unit(waiting,.05)
		if waiting.order=="idle":break
	check(waiting.order=="idle" and waiting.mining_state=="exhausted" and waiting.carried==0,"exhausted local field returns to HQ and stays idle")
	check(c.players[0].as==before+8,"final cargo is delivered before waiting")
	check(c.center(home).distance_to(ACData.point(waiting.pos))<5 and c.resource(100002).amount==1500,"does not cross map to remote ore")
	var pos=waiting.pos.duplicate()
	for tick in range(100):c.time+=.05;c._tick_unit(waiting,.05)
	check(waiting.pos==pos and waiting.order=="idle","no automatic remote mining after exhaustion")
	print("MINING_QUEUE_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
