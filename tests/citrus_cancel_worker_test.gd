extends SceneTree
var checks=0
var failures=[]
func check(value,message):
	checks+=1
	if not value:failures.append(message);printerr(message)
func run_case(initiated: bool):
	var c=ACCore.new();c.setup({"map":0,"seed":617,"players":[{"race":1},{"race":0}]})
	var worker=c.units.filter(func(u):return u.owner==0 and u.kind==0)[0]
	var old_workers=c.units.filter(func(u):return u.owner==0 and u.kind==0 and u.hp>0).size()
	var b=c.add_building(0,2,Vector2(60,60),false);b.worker=worker.id
	worker.pos=ACData.packed(Vector2(c.footprint(b).position.x-c._body_size(worker).x*.5-.05,c.center(b).y));worker.order="construct";worker.target=b.id;worker.hp=19;worker.carried=5
	if initiated:
		c._tick_building(b,.05)
		check(b.get("initiated",false) and worker.hp==0,"builder consumed on arrival")
	var funds=c.players[0].as
	c.command(0,{"type":"cancel","id":b.id})
	check(c.units.filter(func(u):return u.owner==0 and u.kind==0 and u.hp>0).size()==old_workers,"exactly one worker restored or original retained")
	if initiated:
		var restored=c.units.back();check(restored.hp==19 and restored.carried==5,"builder health and carried resource preserved")
		check(c._unit_fits(restored,ACData.point(restored.pos),false),"restored worker not trapped in canceled footprint")
	var refund=c.players[0].as
	c.command(0,{"type":"cancel","id":b.id})
	check(c.players[0].as==refund and refund>funds,"refund only once")
	check(c.units.filter(func(u):return u.owner==0 and u.kind==0 and u.hp>0).size()==old_workers,"repeat cancel creates no extra worker")
func _initialize():call_deferred("run")
func run():
	run_case(true);run_case(false)
	print("CITRUS_CANCEL_WORKER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
