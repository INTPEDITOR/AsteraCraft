extends SceneTree
var failures: Array=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize():call_deferred("run")
func run():
	var report: Array=[]
	for theme in range(3):
		for race in range(3):
			var c=ACCore.new();c.setup({"map":theme,"players":[{"race":race},{"race":(race+1)%3}]})
			c.units.clear();c.buildings.clear();c.collision_index_valid=false;c.map.reset_solids([])
			for vent in c.map.resources:
				if vent.type!="tera":continue
				c.buildings.clear();c.units.clear();c.collision_index_valid=false;c.map.reset_solids([])
				var base=c.map.bases[int(vent.base)]
				var hq=c.add_building(0,0,(ACData.point(base.pos)-Vector2(2,1.5)).floor(),true)
				c.map.reset_solids(c.buildings)
				var anchor=c.refinery_anchor(vent)
				check(anchor.is_finite(),"finite anchor %d/%d/%d"%[theme,race,vent.id])
				var error=c.placement(0,1,anchor,false)
				report.append({"map":theme,"race":race,"vent":vent.id,"pos":vent.pos,"anchor":ACData.packed(anchor),"error":error})
				check(error=="","placement %d/%d/%d: %s"%[theme,race,vent.id,error])
				if error!="":continue
				check(c.snap_refinery(0,anchor)==anchor,"snap matches %d/%d/%d"%[theme,race,vent.id])
				c.players[0].as=1000;c.players[0].tera=0
				var worker=c.add_unit(0,0,c.center(hq)+Vector2(0,3))
				var command_error=c.command(0,{"type":"build","kind":1,"pos":ACData.packed(anchor),"ids":[worker.id]})
				check(command_error=="","worker command %d/%d/%d: %s"%[theme,race,vent.id,command_error])
				if command_error!="":
					print("APPROACH_DEBUG ",worker.pos," anchor=",anchor," approach=",c.building_approach({"race":race,"kind":1,"pos":ACData.packed(anchor),"progress":0.0},ACData.point(worker.pos),worker))
					continue
				for tick in range(800):
					c.time+=.1
					if worker.hp>0:c._tick_unit(worker,.1)
					for building in c.buildings:
						if building.kind==1:c._tick_building(building,.1)
					if c.players[0].tera>0:break
				check(c.players[0].tera>0,"worker reaches completes and extracts %d/%d/%d"%[theme,race,vent.id])
	for theme in range(3):
		for race in range(3):
			var c=ACCore.new();c.setup({"map":theme,"spawn_slots":[0,1,2,3],"players":[{"race":race},{"race":race},{"race":race},{"race":race}]})
			for owner in range(4):
				var workers=c.units.filter(func(u):return u.owner==owner and u.kind==0)
				var hq=c.buildings.filter(func(b):return b.owner==owner and b.kind==0)[0]
				check(workers.size()==4,"four starting workers %d/%d/%d"%[theme,race,owner])
				if workers.size()!=4:continue
				check(workers.all(func(u):return is_equal_approx(float(u.pos[1]),float(workers[0].pos[1])) and float(u.pos[1])>float(hq.pos[1])+2 and u.order=="gather"),"auto-mining horizontal row below HQ %d/%d/%d"%[theme,race,owner])
				for worker in workers:check(c._unit_fits(worker,ACData.point(worker.pos)),"starting worker clear %d/%d/%d/%d"%[theme,race,owner,worker.id])
	var file=FileAccess.open("res://build/tera-map-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("TERA_MAP_AUDIT "+JSON.stringify({"checks":checks,"failures":failures,"sites":report.size()}));quit(0 if failures.is_empty() else 1)
