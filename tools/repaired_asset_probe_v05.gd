extends "res://tools/fragment_probe_v05.gd"

func _initialize() -> void:
	for file in ["air_top_r0_v05.png","air_top_r1_v05.png","air_top_r2_v05.png","medic_repaired_v05.png","owl_buildings_repaired_v05.png"]:
		var image=Image.load_from_file("res://assets/"+file)
		print(file," size=",image.get_size()," corners=",image.get_pixel(0,0).a,",",image.get_pixel(image.get_width()-1,image.get_height()-1).a)
		if file.begins_with("air_top"):
			print(JSON.stringify(regions(image)))
	quit()
