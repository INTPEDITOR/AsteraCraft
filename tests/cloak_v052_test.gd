extends SceneTree
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:
	for race in range(3):
		var c=ACCore.new()
		c.setup({"map":0,"players":[{"race":race},{"race":0}],"seed":75})
		var kind=[7,8,10][race]
		var u=c.add_unit(0,kind,Vector2(60,60))
		c.time=10
		c.visibility[1].fill(1)
		if race==0:
			check(not c.is_cloaked(u),"hyrax begins visible")
			check(u.max_energy==100 and u.energy==50,"hyrax energy initialized")
			check(c.command(0,{"type":"ability","ids":[u.id]})=="","cloak command accepted")
			check(c.is_cloaked(u) and u.energy==25,"cloak activation costs 25")
			u.fired=c.time
			check(c.is_cloaked(u),"hyrax firing never decloaks")
			c._tick_unit_behavior(u,1)
			check(u.energy==24,"drain is one per second without regeneration")
		elif race==1:
			u.fired=9
			check(not c.is_cloaked(u),"parasite exposed for first second")
			c.time=10.99;check(not c.is_cloaked(u),"parasite still exposed before two seconds")
			c.time=11;check(c.is_cloaked(u),"parasite recloaks after two seconds")
		else:
			u.fired=c.time
			check(c.is_cloaked(u),"owl permanent cloak survives attack")
			check(ACData.unit(2,10).as==250 and ACData.unit(2,10).tera==200,"owl upgraded cost")
		check(not c.can_see(1,u),"enemy cannot target undetected cloak")
		var snapshot=c.snapshot(1)
		check(not snapshot.units.any(func(x):return x.id==u.id),"undetected entity omitted from enemy unit list")
		check(snapshot.shimmers.any(func(x):return x.race==race and x.kind==kind),"visible territory contains cosmetic ripple")
		for shimmer in snapshot.shimmers:check(not shimmer.has("id") and not shimmer.has("hp"),"ripple exposes no target or health")
		c.visibility[1].fill(0)
		check(c.snapshot(1).shimmers.is_empty(),"fog hides every ripple")
		c.visibility[1].fill(1)
		var detector=c.add_unit(1,8,c.center(u)+Vector2(2,0))
		c.collision_index_valid=false
		check(c.can_see(1,u),"detector reveals cloaked target")
		if race==0:
			u.energy=.01;c._tick_unit_behavior(u,.1)
			check(not c.is_cloaked(u),"zero energy turns cloak off")
	print("CLOAK_V052 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
