extends "res://tools/fragment_probe_v05.gd"

func _initialize() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/construction_source_regions_v04.json"))
	for race in range(3):
		var source=Image.load_from_file("res://assets/construction_unique_r%d_v4.png"%race)
		for kind in range(13):
			for phase in range(3):
				var raw=catalog.sources[str(race)].cells[kind][phase]
				var found=regions(source.get_region(Rect2i(raw[0],raw[1],raw[2],raw[3])))
				if found.size()>1:print("%d:%d:%d "%[race,kind,phase],JSON.stringify(found))
	quit()
