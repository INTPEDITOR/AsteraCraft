extends SceneTree
func _initialize():
	var sizes={}
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			if ACData.unit(race,kind).air:continue
			var key=Vector2i((ACCore.collision_size(race,kind)*16).ceil());sizes["%d,%d"%[key.x,key.y]]=Vector2(key)/16.0
	var maps=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme);map.resource_obstacles.clear();map.reset_solids([])
		var templates={}
		for key in sizes:
			var rectangles=[];var active={}
			for y in range(512):
				var next={};var x=0
				while x<512:
					if map.source_ground_fits(sizes[key],Vector2(x,y)*.25):x+=1;continue
					var first=x
					while x<512 and not map.source_ground_fits(sizes[key],Vector2(x,y)*.25):x+=1
					var span=Vector2i(first,x-first)
					if active.has(span):
						var index=int(active[span]);rectangles[index][3]+=1;next[span]=index
					else:next[span]=rectangles.size();rectangles.append([first,y,x-first,1])
				active=next
			templates[key]=rectangles
		maps.append(templates);print("CLEARANCE_TEMPLATE ",theme," sizes=",templates.size())
	FileAccess.open("res://data/clearance_v060.json",FileAccess.WRITE).store_string(JSON.stringify({"geometry_sha256":FileAccess.get_sha256("res://data/source_terrain_detail.json"),"cell_size":.25,"maps":maps}))
	quit()
