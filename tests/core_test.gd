extends SceneTree

var failures: Array=[]
var count=0

func check(condition: bool, message: String) -> void:
	count+=1
	if not condition:failures.append(message);printerr("FAIL: "+message)

func sim(c: ACCore, seconds: float, dt: float=.1) -> void:
	for i in range(ceili(seconds/dt)):
		c.step(dt)
		c.resolve_spells()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data=ACData.get_data()
	for race in range(3):
		check(data.units[race].size()==13,"13 unit definitions race%d"%race)
		check(data.buildings[race].size()==13,"13 building definitions race%d"%race)
		for d in data.units[race]:
			check(d.hp>0 and d.time>0 and d.pop>0 and d.producer>=0 and d.producer<13,"valid unit %s"%d.name)
		for d in data.buildings[race]:
			check(d.hp>0 and d.w>0 and d.h>0,"valid footprint %s"%d.name)
	for theme in range(3):
		var m=ACMap.new()
		m.make(theme)
		check(m.symmetric(),"both-axis symmetric terrain and elevation %d"%theme)
		for r in m.resources:
			var mirrored=true
			for slot in [1,2,3]:
				var counterpart=m.reflect(ACData.point(r.pos),slot)
				if not m.resources.any(func(v):return ACData.point(v.pos)==counterpart and v.type==r.type and v.amount==r.amount):mirrored=false
			check(mirrored,"symmetric resource %d/%d"%[theme,r.id])
		for slot in range(4):
			check(not m.path(ACData.point(m.starts[slot]),ACData.point(m.starts[(slot+1)%4])).is_empty(),"all starting quadrants are mutually reachable %d/%d"%[theme,slot])
	for directions in [16,32]:
		for i in range(directions):
			var vector=Vector2(sin(TAU*i/directions),-cos(TAU*i/directions))
			var v=ACData.sprite_direction(vector,directions)
			check(v.column>=0 and v.column<=directions/2,"valid direction column")
			if i>0 and i<directions/2:
				var mirror=ACData.sprite_direction(Vector2(-vector.x,vector.y),directions)
				check(mirror.column==v.column and mirror.flip!=v.flip,"mirrored half-circle mapping")
	for race in range(3):
		var c=ACCore.new()
		c.setup({"map":race,"players":[{"race":race},{"race":(race+1)%3}]})
		sim(c,30)
		check(c.players[0].gathered>0,"workers mine race%d"%race)
		c.players[0].as=5000
		c.players[0].tera=5000
		var site=Vector2.ZERO
		var home=ACData.point(c.entity(int(c.players[0].home)).pos)
		for x in range(int(home.x)-10,int(home.x)+11):
			for y in range(int(home.y)-10,int(home.y)+11):
				if c.placement(0,2,Vector2(x,y))=="":site=Vector2(x,y);break
			if site!=Vector2.ZERO:break
		check(site!=Vector2.ZERO,"supply site race%d"%race)
		check(c.command(0,{"type":"build","kind":2,"pos":ACData.packed(site)})=="","begin supply race%d"%race)
		check(c.placement(0,2,site)!="","reject overlap race%d"%race)
		sim(c,90)
		check(c.has_building(0,2),"supply completes race%d"%race)
		check(c.players[0].cap>10,"supply capacity race%d"%race)
		var hq=c.entity(int(c.players[0].home))
		var before=c.players[0].as
		check(c.command(0,{"type":"train","id":hq.id,"kind":0})=="","queue worker race%d"%race)
		check(c.players[0].reserved>0,"population reservation race%d"%race)
		c.command(0,{"type":"cancel","id":hq.id})
		check(c.players[0].as==before and c.players[0].reserved==0,"cancel refunds race%d"%race)
		check(c.command(1,{"type":"train","id":hq.id,"kind":0})!="","reject enemy production")
		check(c.placement(0,2,Vector2(-2,-2))!="","reject off map")
		var u=c.units.filter(func(v):return v.owner==0)[0]
		var hp=u.hp
		u.hp-=10
		u.shield=0
		u.damaged=-100
		sim(c,2)
		if race==0:check(u.hp==hp-10,"hyrax no natural regen")
		if race==1:check(u.hp>hp-10,"citrus natural regen")
		if race==2:check(u.hp==hp-10 and u.shield>0,"owl shield-only regen")
		var snap=c.snapshot(0)
		check(not snap.players[1].has("as"),"enemy economy hidden")
		check(not snap.buildings.any(func(v):return v.owner==1),"fog hides distant base")
		c.command(0,{"type":"surrender"})
		check(c.ended and c.winners==[1],"surrender winner")
	var bots=ACCore.new()
	bots.setup({"map":0,"players":[{"race":0,"bot":true},{"race":1,"bot":true},{"race":2,"bot":true}]})
	sim(bots,360,.2)
	for owner in range(3):
		var p=bots.players[owner]
		check(p.gathered>500,"bot mines owner%d"%owner)
		check(bots.buildings.filter(func(b):return b.owner==owner).size()>2,"bot expands production owner%d"%owner)
		check(bots.units.filter(func(u):return u.owner==owner and u.kind!=0).size()>0 or p.kills>0,"bot creates army owner%d"%owner)
		print("BOT ",owner," gathered=",p.gathered," buildings=",bots.buildings.filter(func(b):return b.owner==owner).size()," army=",bots.units.filter(func(u):return u.owner==owner and u.kind!=0).size())
	print("CORE_TEST checks=",count," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
