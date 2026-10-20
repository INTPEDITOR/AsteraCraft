extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func arena(race=0,enemy=2):
	var c=ACCore.new();c.setup({"map":0,"seed":601,"players":[{"race":race},{"race":enemy}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.reset_solids([]);c._sync_resource_obstacles();c.collision_index_valid=false
	c.players[0].as=10000;c.players[0].tera=10000;c.players[0].cap=200
	c.players[0].technologies={};c.players[0].nukes=0
	return c
func reveal(c):
	c._rebuild_collision_index();c._update_vision()
func cast(c,u,key,target={},point=Vector2.INF):
	var result=c.command(int(u.owner),{"type":"skill","skill":key,"ids":[u.id],"pos":ACData.packed(c.center(target) if not target.is_empty() else c.center(u) if not point.is_finite() else point),"target":target.get("id",-1)})
	if result!="":print("CAST ",key,": ",result)
	return result
func _initialize():call_deferred("run")
func run():
	for skill in ACData.get_data().abilities:
		var c=arena(int(skill.race));var u=c.add_unit(0,int(skill.kinds[0]),Vector2(40,40));var v=c.add_unit(1,1,Vector2(43,40));reveal(c)
		check(u.energy==25,"low initial energy "+skill.id)
		u.energy=200
		var target=c.add_unit(0,1,Vector2(41,40)) if skill.id=="sap_reclaim" else u if skill.target=="ally" else v
		if skill.id=="root_surge":u.anchored=true
		if skill.id=="sap_reclaim":u.energy=100
		var initial=u.energy
		if skill.id=="nuclear":c.players[0].nukes=1
		if not skill.get("base",false):
			check(cast(c,u,skill.id,target)!="" and u.energy==initial,"locked skill cannot spend "+skill.id)
			c.players[0].technologies[skill.id]=1
		check(cast(c,u,skill.id,target)=="","skill accepted "+skill.id)
		check(u.energy==initial+75 if skill.id=="sap_reclaim" else u.energy==initial-float(skill.energy),"exact energy "+skill.id)
		var energy=u.energy
		check(cast(c,u,skill.id,target)!="" and energy==u.energy,"cooldown no double charge "+skill.id)
	var c=arena(2);var mage=c.add_unit(0,5,Vector2(40,40));mage.energy=200;reveal(c)
	check(cast(c,mage,"judgment",{},Vector2(43,40))=="","empty ground spell")
	c.time=1.1;ACAbilities.update(c,0)
	check(c.ability_events.is_empty(),"empty area event resolves once")
	var enemy=c.add_unit(1,1,Vector2(42,40));var near=c.add_unit(1,1,Vector2(44,40));reveal(c)
	c.players[0].technologies.verdict=1
	var capital=c.add_unit(0,12,Vector2(40,40));capital.energy=200;reveal(c)
	check(cast(c,capital,"verdict",{},Vector2(50,40))=="","line spell accepted")
	var before=enemy.hp+enemy.shield;c.time+=1.1;ACAbilities.update(c,0)
	check(enemy.hp+enemy.shield<before,"line hits middle, not only endpoint")
	c=arena();var scout=c.add_unit(0,7,Vector2(40,40));scout.energy=200;c.players[0].technologies.nuclear=1;c.players[0].nukes=1;reveal(c)
	check(cast(c,scout,"nuclear",{},Vector2(44,40))=="" and c.players[0].nukes==0,"nuke reserves ammo")
	c.command(0,{"type":"stop","ids":[scout.id]});ACAbilities.update(c,0)
	check(c.players[0].nukes==1 and scout.channel.is_empty(),"interrupt returns ammo once")
	ACAbilities.update(c,0);check(c.players[0].nukes==1,"interrupt cannot duplicate ammo")
	scout.skill_ready={};scout.energy=200;cast(c,scout,"nuclear",{},Vector2(44,40));scout.hp=0;ACAbilities.update(c,0)
	check(c.players[0].nukes==1,"death returns reserved ammo")
	var facilities=[]
	for i in range(4):facilities.append(c.add_building(0,8,Vector2(20+i*6,25),true))
	c.players[0].nukes=0
	for i in range(3):check(c.command(0,{"type":"produce_nuke","id":facilities[i].id})=="","parallel nuke reservation")
	check(c.command(0,{"type":"produce_nuke","id":facilities[3].id})!="","reservation counts all facilities")
	var resources=c.players[0].as
	check(c.command(0,{"type":"cancel_nuke","id":facilities[0].id})=="" and c.players[0].as==resources+300,"nuke exact refund")
	c=arena();var carrier=c.add_unit(0,14,Vector2(40,40))
	for i in range(8):check(c.command(0,{"type":"produce_drone","id":carrier.id})=="","drone queue accepts eight")
	check(c.command(0,{"type":"produce_drone","id":carrier.id})!="","ninth drone rejected")
	for i in range(8):ACNewUnits.tick(c,carrier,8)
	check(carrier.drones.size()==8 and carrier.drone_queue.is_empty(),"eight physical drones")
	carrier.hp=0;ACNewUnits.cleanup(c)
	check(c.units.filter(func(u):return u.kind==15).all(func(u):return u.hp<=0),"mother destruction removes drones")
	c=arena(2);var priest=c.add_unit(0,4,Vector2(40,40));var patient=c.add_unit(0,1,Vector2(42,40));patient.hp-=20;priest.energy=20;reveal(c)
	c._support(priest,priest._definition,.5)
	check(patient.hp==ACData.unit(2,1).hp-15 and priest.energy==10,"automatic priest healing high energy cost")
	var attacker=c.add_unit(1,1,Vector2(42,41));patient.ward=10;patient.ward_until=5;var hp=patient.hp;var shield=patient.shield
	c._damage(attacker,patient,10,false,"spell")
	check(patient.hp==hp and patient.shield==shield and patient.ward==0,"ward absorbs exact amount")
	for race in range(3):
		c=arena(race);var b=c.add_building(0,8,Vector2(30,30),true);b.research_queue=[{"kind":"secret"}];b.nuke_job={"left":5};reveal(c)
		c.visibility[1].fill(1)
		var snap=c.snapshot(1);var visible=snap.buildings.filter(func(item):return item.id==b.id)[0]
		check(visible.research_queue.is_empty() and visible.nuke_job.is_empty() and not snap.players[0].has("technologies"),"enemy research privacy")
	print("ABILITIES_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
