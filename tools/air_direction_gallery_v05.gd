extends SceneTree

func _initialize() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_cache_v04.json"))
	for race in range(3):
		var kinds: Array=[]
		for kind in range(13):
			if ACData.unit(race,kind).air:kinds.append(kind)
		var gallery=Image.create(1530,kinds.size()*3*170,false,Image.FORMAT_RGBA8)
		gallery.fill(Color("26303a"))
		for unit_row in range(kinds.size()):
			var info=catalog.units["%d:%d"%[race,kinds[unit_row]]]
			var source=Image.load_from_file(info.file)
			for phase in range(3):
				var row=[0,2,4][phase]
				for col in range(9):
					var start=Vector2i(col*source.get_width()/9,row*source.get_height()/10)
					var end=Vector2i((col+1)*source.get_width()/9,(row+1)*source.get_height()/10)
					var piece=source.get_region(Rect2i(start,end-start))
					piece.resize(168,168,Image.INTERPOLATE_LANCZOS)
					gallery.blend_rect(piece,Rect2i(0,0,168,168),Vector2i(col*170,(unit_row*3+phase)*170))
		gallery.save_png("res://build/air-directions-raw-r%d-v05.png"%race)
	print("AIR_GALLERY_DONE")
	quit()
