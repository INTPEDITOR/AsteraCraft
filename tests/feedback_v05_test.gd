extends SceneTree
var failures: Array=[]
var checks=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL "+label)
func arena(race: int=0) -> ACCore:
	var c=ACCore.new()
	c.setup({"seed":50,"players":[{"race":race},{"race":0}],"spawn_slots":[0,2]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.buildable_map.fill(1)
	c._sync_resource_obstacles();c.map.reset_solids([])
	return c
func run() -> void:
	for race in [0,1]:
		var c=arena(race)
		var patient=c.add_unit(0,3,Vector2(60,60));patient.hp=10
		var second=c.add_unit(0,3,Vector2(60,62));second.hp=10
		var healers=[]
		for n in range(4):healers.append(c.add_unit(0,4 if race==0 else 9,Vector2(58+n,58)))
		var before=float(patient.hp)
		c.time=.05
		for healer in healers:c._support(healer,healer._definition,.05)
		check(patient.hp-before<=.05*(6 if race==0 else 8)+.001,"one healing stream per patient race %d"%race)
		check(second.hp>10,"spare healer selects another patient race %d"%race)
		var holder=c.entity(int(patient._heal_owner));holder.hp=0;c.time+=.05
		for healer in healers:
			if healer.hp>0:c._support(healer,healer._definition,.05)
		check(int(patient._heal_owner)!=int(holder.id),"dead healer releases patient immediately")
	var c=arena()
	var medic=c.add_unit(0,4,Vector2(60,60));medic.energy=0
	for n in range(200):c.time+=.05;c._tick_unit(medic,.05)
	check(absf(medic.energy-3.0)<.01,"energy recovers 3 in ten seconds")
	for race in range(3):
		c=arena(race)
		var builder=c.add_unit(0,0,Vector2(55,55))
		var site=c.add_building(0,2,Vector2(58,58),false);site.progress=.4;site.worker=-1
		c.map.reset_solids(c.buildings)
		var old_cost=float(c.players[0].as)
		c.command(0,{"type":"context","ids":[builder.id],"target":site.id,"pos":site.pos})
		check(builder.order=="construct" and site.worker==builder.id,"right click resumes race %d"%race)
		for n in range(300):
			c.time+=.05;c.paths_this_tick=0;c._tick_unit(builder,.05);c._tick_building(site,.05)
		check(site.progress>.4,"resumed site advances race %d"%race)
		check(c.players[0].as==old_cost,"resume never charges twice")
	c=arena()
	var vent={"id":100000,"type":"tera","pos":[65.5,60.5],"amount":5000,"initial_amount":5000,"busy":0.0}
	c.map.resources.append(vent);c._rebuild_resources()
	var anchor=c.refinery_anchor(vent)
	check(c.placement(0,1,anchor,false).contains("본진"),"orphan refinery placement denied")
	var hq=c.add_building(0,0,Vector2(55,58),true)
	check(c.placement(0,1,anchor,false)=="","nearby complete own HQ permits refinery")
	var refinery=c.add_building(0,1,anchor,true)
	var before=float(c.players[0].tera)
	c._tick_tera(refinery,5)
	check(c.players[0].tera-before==24,"two extraction cycles yield 24")
	hq.hp=0;before=c.players[0].tera;c._tick_tera(refinery,10)
	check(not refinery.tera_active and c.players[0].tera==before,"HQ destruction disables extraction")
	hq.hp=100;c._tick_tera(refinery,2.5)
	check(refinery.tera_active and c.players[0].tera==before+12,"rebuilding reconnects extraction")
	print("FEEDBACK_V05 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
