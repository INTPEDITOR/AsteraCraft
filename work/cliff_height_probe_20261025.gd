extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var details=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_terrain_detail.json"));var report=[]
	for theme in range(3):
		var c=ACCore.new();c.setup({"map":theme,"players":[{"race":0},{"race":1}]})
		c.units.clear();c.buildings.clear();c.map.resource_obstacles.clear();c.map.reset_solids([])
		var mismatches=0;var mixed=0;var reported_mismatches=0;var foot_samples=0;var examples=[];var pushes=[]
		var size=c.collision_size(0,0)
		for y in range(2,510):
			for x in range(2,510):
				var tile=(y/4)*128+x/4;var bit=(y%4)*4+x%4
				if (c.map.source_walk_masks[tile]&(1<<bit))==0:continue
				var p=Vector2(x,y)*.25-Vector2.ONE*.375
				if not c._ground_fits_size(size,p):continue
				var local_height=(int(details.maps[theme].height_bits[tile])>>(bit*2))&3
				foot_samples+=1
				var reported=c.map.call("ground_level",p) if c.map.has_method("ground_level") else int(c.map.height_map[int(p.y)*128+int(p.x)])
				if int(reported)!=local_height:reported_mismatches+=1
				var used=int(c.map.height_map[int(p.y)*128+int(p.x)])
				var actual_coarse=int(c.map.height_map[(y/4)*128+x/4])
				var on_ramp=false
				for ramp in c.map.visual_ramps:
					var delta=p+Vector2.ONE*.5-ramp.center
					if absf(delta.dot(ramp.direction))<ramp.length*.5+1 and absf(delta.dot(Vector2(ramp.direction.y,-ramp.direction.x)))<ramp.width*.5+1:on_ramp=true;break
				if used>local_height and not on_ramp:
					mismatches+=1
					if actual_coarse>local_height:mixed+=1
					if examples.size()<8 and p.x>=8 and p.y>=8 and p.x<120 and p.y<120:
						var target=Vector2.INF
						for yy in range(maxi(1,int(p.y)-7),mini(127,int(p.y)+8)):
							for xx in range(maxi(1,int(p.x)-7),mini(127,int(p.x)+8)):
								var q=Vector2(xx,yy)
								if q.distance_to(p)>8 or int(c.map.height_map[yy*128+xx])<=local_height or not c._ground_fits_size(size,q):continue
								var sub=Vector2i(((q+Vector2.ONE*.5)*4).floor());var i=(sub.y/4)*128+sub.x/4;var b=(sub.y%4)*4+sub.x%4
								if ((int(details.maps[theme].height_bits[i])>>(b*2))&3)<=local_height:continue
								target=q;break
							if target.is_finite():break
						if target.is_finite():examples.append({"pos":ACData.packed(p),"used":used,"actual":local_height,"coarse":actual_coarse,"high_target":ACData.packed(target)})
				if on_ramp or pushes.size()>=8:continue
				for delta in [Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)]:
					var q=p+delta
					if q.x<1 or q.y<1 or q.x>126 or q.y>126 or not c._ground_fits_size(size,q):continue
					var cell=Vector2i(((q+Vector2.ONE*.5)*4).floor());var dest_tile=(cell.y/4)*128+cell.x/4;var dest_bit=(cell.y%4)*4+cell.x%4
					var dest_height=(int(details.maps[theme].height_bits[dest_tile])>>(dest_bit*2))&3
					if dest_height<=local_height or c._ground_sweep(size,p,q):continue
					pushes.append({"from":ACData.packed(p),"to":ACData.packed(q),"low":local_height,"high":dest_height});break
		var entry={"map":theme,"false_high_vision_sources":mismatches,"reported_height_mismatches":reported_mismatches,"walkable_foot_samples":foot_samples,"mixed_height_cells":mixed,"examples":examples,"pushes_over_cliff":pushes}
		report.append(entry);print("CLIFF_HEIGHT_PROBE ",JSON.stringify(entry))
	DirAccess.make_dir_recursive_absolute("res://build/cliff-fix-20261025")
	var phase="after" if "--after" in OS.get_cmdline_user_args() else "before"
	FileAccess.open("res://build/cliff-fix-20261025/height-probe-"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit()
