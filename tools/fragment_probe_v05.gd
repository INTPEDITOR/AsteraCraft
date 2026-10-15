extends SceneTree

func regions(image: Image) -> Array:
	var size_value=image.get_size()
	var seen=PackedByteArray();seen.resize(size_value.x*size_value.y)
	var result: Array=[]
	for y in range(size_value.y):
		for x in range(size_value.x):
			var index=y*size_value.x+x
			if seen[index] or image.get_pixel(x,y).a<.08:continue
			var queue: Array[Vector2i]=[Vector2i(x,y)];seen[index]=1
			var low=Vector2i(x,y);var high=low
			var cursor=0
			while cursor<queue.size():
				var p=queue[cursor];cursor+=1
				low=Vector2i(mini(low.x,p.x),mini(low.y,p.y));high=Vector2i(maxi(high.x,p.x),maxi(high.y,p.y))
				for delta in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
					var n=p+delta
					if n.x<0 or n.y<0 or n.x>=size_value.x or n.y>=size_value.y:continue
					var next=n.y*size_value.x+n.x
					if not seen[next] and image.get_pixelv(n).a>=.08:seen[next]=1;queue.append(n)
			if queue.size()>3:result.append({"pixels":queue.size(),"rect":[low.x,low.y,high.x-low.x+1,high.y-low.y+1]})
	result.sort_custom(func(a,b):return a.pixels>b.pixels)
	return result.slice(0,12)

func _initialize() -> void:
	var image: Image=load("res://assets/buildings_1_tree_v3.png").get_image()
	for cell in [Rect2i(627,380,327,269),Rect2i(32,653,266,341)]:
		print("BUILDING ",cell," ",JSON.stringify(regions(image.get_region(cell))))
	image=load("res://assets/vehicle_layers_r0_u12_v4.png").get_image()
	for part in [Rect2i(836,0,209,418),Rect2i(836,418,234,418)]:
		print("WALKER ",part," ",JSON.stringify(regions(image.get_region(part))))
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/construction_source_regions_v04.json"))
	for race in range(3):
		image=load("res://assets/construction_unique_r%d_v4.png"%race).get_image()
		var raw=catalog.sources[str(race)].cells[2][2]
		var cell=image.get_region(Rect2i(raw[0],raw[1],raw[2],raw[3]))
		print("SCAFFOLD ",race," ",cell.get_used_rect()," ",JSON.stringify(regions(cell)))
	quit()
