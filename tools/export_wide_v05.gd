extends SceneTree
func _initialize() -> void:
	for race in range(3):
		var path="res://assets/menu_planet_%d_wide_v05.png"%race
		var image=Image.load_from_file(path)
		var scale=mini(image.get_width()/16,image.get_height()/9)
		var dimensions=Vector2i(scale*16,scale*9)
		image.get_region(Rect2i((image.get_size()-dimensions)/2,dimensions)).save_png(path)
	var path="res://assets/tera_base_v05.png"
	var image=Image.load_from_file(path)
	image.get_region(image.get_used_rect()).save_png(path)
	quit()
