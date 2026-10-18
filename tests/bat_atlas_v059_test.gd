extends SceneTree
func _initialize():
	var sheet=load("res://assets/citrus_bat_leaf_v059.png").get_image()
	var cell=Vector2(sheet.get_size())/Vector2(5,2)
	var failures=[]
	for row in range(2):
		for col in range(5):
			var bounds=Rect2i(Vector2(col,row)*cell,cell)
			var pixels=sheet.get_region(bounds)
			var first=Vector2i(bounds.size);var last=Vector2i.ZERO
			for y in range(bounds.size.y):
				for x in range(bounds.size.x):
					if pixels.get_pixel(x,y).a>.25:first=first.min(Vector2i(x,y));last=last.max(Vector2i(x,y))
			var used=Rect2i(first,last-first+Vector2i.ONE)
			if used.position.x<8 or used.position.y<8 or used.end.x>bounds.size.x-8 or used.end.y>bounds.size.y-8:failures.append([row,col,used])
	print("BAT_ATLAS_GUTTERS ",failures)
	quit(0 if failures.is_empty() else 1)
