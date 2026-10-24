extends SceneTree
var checks=0
var failures=[]
var records=[]
var output="res://build/group-move-continuity-20261025/"
var baseline=false
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output+=args[0]+"/"
	baseline="--baseline" in args
	DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: "+message)
func field(c,dimensions: Vector2) -> Vector2:
	for y in range(22,108,3):
		for x in range(22,100,3):
			var free=true
			for row in range(-4,5,2):
				if not c._ground_sweep(dimensions,Vector2(x-11,y+row),Vector2(x+13,y+row)):free=false;break
			if free:return Vector2(x,y)
	return Vector2.INF
func run() -> void:
	for map_id in range(3):
		var c=load("res://build/move-continuity-20261025/baseline_core.gd").new() if baseline else ACCore.new()
		c.setup({"map":map_id,"seed":251025,"players":[{"race":0},{"race":1},{"race":2}]})
		c.units.clear();c.buildings.clear();c.map.reset_solids([]);c.collision_index_valid=false
		for race in range(3):
			c.units.clear();c.collision_index_valid=false;c.path_cache.clear();c.crowd_arrival_cache.clear()
			var kind=[5,3,7][race]
			var centre=field(c,ACCore.collision_size(race,kind))
			check(centre!=Vector2.INF,"clear formation field exists %d:%d"%[map_id,race])
			if centre==Vector2.INF:continue
			var army=[];var distances={};var longest={};var waits={};var deferred={};var speed_samples=[]
			for index in range(12):
				var u=c.add_unit(race,kind,centre+Vector2(-10+floori(index/4.0)*1.8,(index%4-1.5)*1.8))
				army.append(u);distances[int(u.id)]=0;longest[int(u.id)]=0;waits[int(u.id)]=0;deferred[int(u.id)]=0
			var error=c.command(race,{"type":"context","ids":army.map(func(u):return u.id),"target":-1,"formation":true,"pos":ACData.packed(centre+Vector2(8,0))})
			check(error=="","right-click command accepted")
			for u in army:check(c._ground_fits_size(c._body_size(u),ACData.point(u.goal)),"formation destination fits actual body")
			var stopped_ticks=0;var deferred_stops=0;var max_wait=0;var arrival_tick=-1
			for tick in range(1,1101):
				c.time+=.05;c.paths_this_tick=0;c.path_time_this_tick=0;c.crowd_arrival_cache.clear();c._rebuild_collision_index()
				var active=0
				for u in army:
					var previous=ACData.point(u.pos);var far=previous.distance_to(ACData.point(u.goal))>4
					c._tick_unit(u,.05)
					var moved=previous.distance_to(ACData.point(u.pos))
					if tick>10 and far and moved<.0001:
						stopped_ticks+=1;waits[int(u.id)]+=1
						if u.get("_path_deferred",false):deferred_stops+=1;deferred[int(u.id)]+=1
					else:waits[int(u.id)]=0
					max_wait=maxi(max_wait,waits[int(u.id)])
					if u.order!="idle":active+=1
					check(c._ground_fits_size(c._body_size(u),ACData.point(u.pos)),"terrain bounds remain valid")
					if int(u.id)==int(army[0].id) and tick%2==0:speed_samples.append({"tick":tick,"x":u.pos[0],"y":u.pos[1],"distance":moved,"deferred":u.get("_path_deferred",false)})
				c._separate_units(.05,false)
				if active==0:arrival_tick=tick;break
			check(arrival_tick>0,"formation finishes %d:%d"%[map_id,race])
			for a in army:
				for b in army:
					if int(a.id)>=int(b.id):continue
					var overlap=ACCore.collision_rect(a).intersection(ACCore.collision_rect(b))
					check(overlap.size.x<=.003 or overlap.size.y<=.003,"settled formation retains hard body separation")
			var row={"map":map_id,"race":race,"kind":kind,"stopped_ticks_away_from_goal":stopped_ticks,"deferred_stops":deferred_stops,"max_stop_seconds":max_wait*.05,"arrival_seconds":arrival_tick*.05,"trajectory":speed_samples,"final_units":army.map(func(u):return {"id":u.id,"position":u.pos,"goal":u.goal,"order":u.order,"blocked":u.blocked_clock})}
			records.append(row);print("GROUP_MOVE_CASE ",JSON.stringify({"map":map_id,"race":race,"stops":stopped_ticks,"deferred_stops":deferred_stops,"max_stop":max_wait*.05,"arrival":arrival_tick*.05}))
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":records}
	FileAccess.open(output+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("GROUP_MOVE_COMPLETE ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures.size()}));quit(0 if failures.is_empty() else 1)
