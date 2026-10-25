extends "res://tests/abilities_v060_test.gd"

func old_prefix(map,context: Dictionary) -> PackedInt32Array:
	var solid: PackedByteArray=map._detail_solid.duplicate() if map.source_detail_active else PackedByteArray()
	if not map.source_detail_active:
		solid.resize(512*512)
		for y in range(512):
			for x in range(512):solid[y*512+x]=int(map.navigator.is_point_solid(Vector2i(x/4,y/4)))
	for corridor in context.corridors:
		var low=Vector2i(((corridor.position+Vector2.ONE*.5)*4).ceil()).max(Vector2i.ZERO)
		var high=Vector2i(((corridor.end+Vector2.ONE*.5)*4).floor()).min(Vector2i(512,512))
		for y in range(low.y,high.y):
			for x in range(low.x,high.x):
				var cell=Rect2(Vector2(x,y)*.25-Vector2.ONE*.5,Vector2.ONE*.25)
				if not map.terrain_ground_fits(Vector2.ONE*.24998,cell.get_center()):continue
				if map.resource_obstacles.any(func(r):return cell.intersects(r)):continue
				if context.foreign.any(func(r):return cell.intersects(r)):continue
				solid[y*512+x]=0
	var prefix=PackedInt32Array();prefix.resize(513*513);prefix.fill(0)
	for y in range(512):
		var row=0
		for x in range(512):
			row+=solid[y*512+x];prefix[(y+1)*513+x+1]=row+prefix[y*513+x+1]
	return prefix

func old_query(context: Dictionary,prefix: PackedInt32Array,dimensions: Vector2,pos: Vector2) -> bool:
	var aligned=false
	for line in context.centerlines:
		var axis=int(line.axis);var along=1-axis
		if absf(pos[axis]-float(line.edge))<=.0011 and pos[along]>=float(line.low)-dimensions[along]*.5-.01 and pos[along]<=float(line.high)+dimensions[along]*.5+.01:aligned=true;break
	if not aligned:return false
	var low=Vector2i(((pos-dimensions*.5+Vector2.ONE*.50001)*4).floor())
	var high=Vector2i(((pos+dimensions*.5+Vector2.ONE*.49999)*4).floor())+Vector2i.ONE
	if low.x<0 or low.y<0 or high.x>512 or high.y>512:return false
	return prefix[high.y*513+high.x]-prefix[low.y*513+high.x]-prefix[high.y*513+low.x]+prefix[low.y*513+low.x]==0

func run() -> void:
	for detailed in [false,true]:
		for race in range(3):
			var c=arena(race,race);c.map.source_detail_active=detailed
			var d=ACData.building(race,2)
			c.add_building(0,2,Vector2(40,40),true)
			var right=c.add_building(0,2,Vector2(40+d.w,40),true)
			c.add_building(0,2,Vector2(40,40+d.h),true)
			c.add_building(0,2,Vector2(40+d.w,40+d.h),true)
			for revision in range(3):
				right.owner=1 if revision==1 else 0
				c.map.set_resource_obstacles([Rect2(40+float(d.w)-.5,40.5,.25,.25)] if revision==2 else [])
				c.map.reset_solids(c.buildings)
				var context=c.map._worker_passage_context(0);var prefix=old_prefix(c.map,context)
				for axis in [0,1]:
					var edge=40+float(d.w if axis==0 else d.h)-.5
					for step in range(65):
						for offset in [0.0,-.125,.125]:
							var point=Vector2(edge+offset,38+step*.125) if axis==0 else Vector2(38+step*.125,edge+offset)
							var dimensions=ACCore.collision_size(race,0)
							check(c.map.worker_ground_fits(0,dimensions,point)==old_query(context,prefix,dimensions,point),"same exact quarter-cell geometry %s/%d/%d/%d"%[detailed,race,revision,step])
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Old full-map override prefix versus sparse body query, three races, native and ordinary masks, ownership and resource revisions."}
	DirAccess.make_dir_recursive_absolute("res://build/worker-centerline-20261026")
	FileAccess.open("res://build/worker-centerline-20261026/equivalence.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WORKER_PASSAGE_EQUIVALENCE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
