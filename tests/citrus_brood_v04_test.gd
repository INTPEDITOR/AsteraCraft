extends SceneTree
## Exercises real core entities and economy; no visual-only stand-ins.
var checks := 0
var failures: Array=[]

func check(value: bool, detail: String) -> void:
	checks+=1
	if not value:
		failures.append(detail)
		printerr("FAIL: "+detail)

func _initialize() -> void:
	call_deferred("run")

func prepared() -> ACCore:
	var core:=ACCore.new()
	core.setup({"seed":714,"map":0,"mode":"ffa","spawn_slots":[0,2],"players":[{"name":"Brood regression","race":1,"bot":false},{"name":"Opponent","race":0,"bot":false}]})
	core.players[0].as=10000.0
	core.players[0].tera=10000.0
	for kind in range(1,13):
		core.add_building(0,kind,Vector2(48+(kind%4)*8,48+(kind/4)*8),true)
	for index in range(24):core.add_building(0,2,Vector2(70+(index%5)*5,70+(index/5)*5),true)
	core._recalculate_supply()
	return core

func home(core: ACCore) -> Dictionary:
	return core.entity(int(core.players[0].home))

func advance_pod(core: ACCore, pod: Dictionary, seconds: float) -> void:
	core.time+=seconds
	ACCitrusBrood.tick_pod(core,pod,seconds)

func run() -> void:
	check(ACData.get_data().units[1].size()==13,"the original citrus roster still has exactly thirteen kinds")
	var core:=prepared()
	var hq:=home(core)
	var pods:=ACCitrusBrood.idle_pods(core,hq)
	check(pods.size()==3 and int(hq.larva)==3,"setup creates three real selectable HQ brood entities")
	if pods.size()!=3:
		print("Citrus brood: %d checks, %d failures"%[checks,failures.size()])
		quit(1)
		return
	check(pods[0].id!=pods[1].id and pods[1].id!=pods[2].id and int(pods[0].kind)==13,"each brood has an independent entity ID and technical kind")
	check(ACData.unit(1,13).pop==0 and ACData.unit(1,13).damage==0,"technical brood has no population cost or weapon")
	var snapshot:=core.snapshot(0)
	var snapshot_pods:=0
	for unit in snapshot.units:
		if ACCitrusBrood.is_pod(unit) and unit.has("brood_parent") and unit.has("brood_state"):snapshot_pods+=1
	check(snapshot_pods==3,"network and rendering snapshots contain the three real brood bodies")
	var before_as:=float(core.players[0].as)
	var before_tera:=float(core.players[0].tera)
	var before_reserved:=float(core.players[0].reserved)
	for index in range(3):
		check(core.command(0,{"type":"train","id":pods[index].id,"kind":index})=="","individually selected brood accepts target kind %d"%index)
	check(hq.queue.size()==3 and int(hq.larva)==0,"producer queue mirrors three distinct active bodies")
	var cost:=0.0
	var tera_cost:=0.0
	var population:=0.0
	for kind in range(3):
		cost+=float(ACData.unit(1,kind).as)
		tera_cost+=float(ACData.unit(1,kind).tera)
		population+=float(ACData.unit(1,kind).pop)
	check(is_equal_approx(before_as-float(core.players[0].as),cost) and is_equal_approx(before_tera-float(core.players[0].tera),tera_cost) and is_equal_approx(float(core.players[0].reserved)-before_reserved,population),"three individual morphs pay both resources and reserve population exactly once")
	for pod in pods:advance_pod(core,pod,1.0)
	check(is_equal_approx(float(pods[0].morph_left),float(ACData.unit(1,0).time)-1.0) and is_equal_approx(float(pods[2].morph_left),float(ACData.unit(1,2).time)-1.0),"individual morph timers advance concurrently")
	var middle_as:=float(core.players[0].as)
	var middle_pop:=float(core.players[0].reserved)
	check(core.command(0,{"type":"cancel","id":hq.id,"queue_index":1})=="","building compatibility queue cancels the specified body")
	check(str(pods[1].brood_state)=="idle" and str(pods[0].brood_state)=="morph" and str(pods[2].brood_state)=="morph" and hq.queue.size()==2,"middle cancellation preserves the other independent jobs")
	check(is_equal_approx(float(core.players[0].as)-middle_as,float(ACData.unit(1,1).as)) and is_equal_approx(middle_pop-float(core.players[0].reserved),float(ACData.unit(1,1).pop)),"cancel refunds the selected target and releases its reserved population")
	var repeated_as:=float(core.players[0].as)
	ACCitrusBrood.cancel(core,0,pods[1])
	check(is_equal_approx(float(core.players[0].as),repeated_as),"repeated cancellation cannot duplicate a refund")
	var worker_id:=int(pods[0].id)
	advance_pod(core,pods[0],float(pods[0].morph_left))
	check(int(pods[0].kind)==0 and int(pods[0].id)==worker_id and pods[0].order=="gather","completed worker keeps its selected identity and begins gathering")
	check(str(pods[2].brood_state)=="morph" and hq.queue.size()==1,"finishing one body does not finish another body")
	var failed_as:=float(core.players[0].as)
	var failed_pop:=float(core.players[0].reserved)
	check(ACCitrusBrood.train(core,1,pods[1],0)!="" and ACCitrusBrood.train(core,0,pods[1],13)!="","wrong ownership and technical-kind targets are rejected")
	check(float(core.players[0].as)==failed_as and float(core.players[0].reserved)==failed_pop,"invalid targets leave economy unchanged")
	core.players[0].as=0.0
	check(ACCitrusBrood.train(core,0,pods[1],0)!="" and str(pods[1].brood_state)=="idle","unaffordable morph leaves the brood idle")
	core.players[0].as=1000.0
	core.players[0].cap=core.players[0].used+core.players[0].reserved
	check(ACCitrusBrood.train(core,0,pods[1],0)!="","population limit is checked before a morph starts")
	core.players[0].cap=200.0
	var requires: Array=ACData.unit(1,12).requires
	var hidden: Array=[]
	for building in core.buildings:
		if int(building.owner)!=0:continue
		for required in requires:
			if int(building.kind)==int(required):
				hidden.append(building)
				building.hp=0.0
	core.collision_index_valid=false
	check(not requires.is_empty() and ACCitrusBrood.train(core,0,pods[1],12)!="","target technology prerequisites remain enforced")
	for building in hidden:building.hp=100.0
	core.collision_index_valid=false
	# Exercise every original target definition, including aircraft and support.
	var roster_core:=prepared()
	var roster_hq:=home(roster_core)
	for kind in range(13):
		var available:=ACCitrusBrood.idle_pods(roster_core,roster_hq)
		if available.is_empty():ACCitrusBrood.producer(roster_core,roster_hq,15.0);available=ACCitrusBrood.idle_pods(roster_core,roster_hq)
		var pod: Dictionary=available[0]
		var id:=int(pod.id)
		check(ACCitrusBrood.train(roster_core,0,pod,kind)=="","roster kind %d can be selected as a morph target"%kind)
		advance_pod(roster_core,pod,float(ACData.unit(1,kind).time))
		check(int(pod.kind)==kind and int(pod.id)==id and not pod.anchored and int(pod.collision_layer)==ACCore.collision_layer(1,kind),"roster kind %d emerges with its correct identity and collider"%kind)
	check(is_zero_approx(float(roster_core.players[0].reserved)) and roster_hq.queue.is_empty(),"all completed morphs release reservations and queue mirrors")
	# Regeneration is capped at three idle bodies for both producer kinds.
	var regen:=prepared()
	var regen_hq:=home(regen)
	var dead: Dictionary=ACCitrusBrood.idle_pods(regen,regen_hq)[0]
	dead.hp=0.0
	ACCitrusBrood.producer(regen,regen_hq,14.9)
	check(ACCitrusBrood.idle_pods(regen,regen_hq).size()==2,"HQ regeneration waits fifteen seconds")
	ACCitrusBrood.producer(regen,regen_hq,.1)
	ACCitrusBrood.producer(regen,regen_hq,100.0)
	check(ACCitrusBrood.idle_pods(regen,regen_hq).size()==3,"HQ regenerates one real body and stops at its idle cap")
	var cancelling: Dictionary=ACCitrusBrood.idle_pods(regen,regen_hq)[0]
	var cancelling_id:=int(cancelling.id)
	ACCitrusBrood.train(regen,0,cancelling,0)
	ACCitrusBrood.producer(regen,regen_hq,45.0)
	ACCitrusBrood.cancel(regen,0,cancelling)
	check(ACCitrusBrood.idle_pods(regen,regen_hq).size()==3 and int(cancelling.id)==cancelling_id and regen.units.has(cancelling),"cancel after regeneration preserves the selected ID and the strict three-idle cap")
	var nursery: Dictionary={}
	for building in regen.buildings:
		if int(building.owner)==0 and int(building.kind)==3:nursery=building;break
	ACCitrusBrood.producer(regen,nursery)
	check(ACCitrusBrood.idle_pods(regen,nursery).size()==3,"additional nursery also owns three real bodies")
	ACCitrusBrood.idle_pods(regen,nursery)[0].hp=0.0
	ACCitrusBrood.producer(regen,nursery,24.9)
	check(ACCitrusBrood.idle_pods(regen,nursery).size()==2,"additional nursery uses its twenty-five-second interval")
	ACCitrusBrood.producer(regen,nursery,.1)
	check(ACCitrusBrood.idle_pods(regen,nursery).size()==3,"additional nursery replenishes after its own interval")
	# Compatibility train picks an actual idle body; all entry points share 5 slots.
	var queue_core:=prepared()
	var queue_hq:=home(queue_core)
	for index in range(5):
		if ACCitrusBrood.idle_pods(queue_core,queue_hq).is_empty():ACCitrusBrood.producer(queue_core,queue_hq,15.0)
		check(queue_core.command(0,{"type":"train","id":queue_hq.id,"kind":12})=="","HQ compatibility train assigns a distinct body %d"%index)
	ACCitrusBrood.producer(queue_core,queue_hq,15.0)
	var sixth: Dictionary=ACCitrusBrood.idle_pods(queue_core,queue_hq)[0]
	check(queue_hq.queue.size()==5 and ACCitrusBrood.train(queue_core,0,sixth,0)!="" and queue_core.command(0,{"type":"train","id":queue_hq.id,"kind":0})!="","direct and HQ morph entry points enforce the same five-job cap")
	var dying: Dictionary=queue_core.entity(int(queue_hq.queue[1].brood))
	var reserved:=float(queue_core.players[0].reserved)
	var no_refund:=float(queue_core.players[0].as)
	var lost_pop:=float(dying.morph_pop)
	dying.hp=0.0
	ACCitrusBrood.cleanup_dead(queue_core)
	ACCitrusBrood.cleanup_dead(queue_core)
	check(is_equal_approx(float(queue_core.players[0].reserved),reserved-lost_pop) and float(queue_core.players[0].as)==no_refund and queue_hq.queue.size()==4,"destroyed morph releases population once, removes its queue mirror and grants no refund")
	var tera_before_cancel:=float(queue_core.players[0].tera)
	var as_before_cancel:=float(queue_core.players[0].as)
	check(ACCitrusBrood.cancel_queue(queue_core,0,queue_hq,2)=="" and float(ACData.unit(1,12).tera)>0.0 and is_equal_approx(float(queue_core.players[0].tera)-tera_before_cancel,float(ACData.unit(1,12).tera)) and is_equal_approx(float(queue_core.players[0].as)-as_before_cancel,float(ACData.unit(1,12).as)),"expensive morph cancellation refunds exact As and Tera costs")
	# A living orphan egg retains its prepaid morph when the parent is destroyed.
	var orphan: Dictionary=queue_core.entity(int(queue_hq.queue[0].brood))
	var orphan_id:=int(orphan.id)
	var orphan_pop:=float(orphan.morph_pop)
	reserved=float(queue_core.players[0].reserved)
	queue_hq.hp=0.0
	ACCitrusBrood.cleanup_dead(queue_core)
	check(float(queue_core.players[0].reserved)==reserved,"destroying a parent does not cancel living egg reservations")
	advance_pod(queue_core,orphan,float(orphan.morph_left))
	check(int(orphan.id)==orphan_id and int(orphan.kind)==12 and is_equal_approx(float(queue_core.players[0].reserved),reserved-orphan_pop),"orphan morph completes with its original identity and releases its reservation")
	print("Citrus brood v0.4: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
