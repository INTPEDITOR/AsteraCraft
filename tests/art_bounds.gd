extends SceneTree
func _initialize() -> void:
	for race in range(3):
		var image=load("res://assets/ui_hud_%d.png"%race).get_image()
		var top=image.get_height();var bottom=0
		for y in range(image.get_height()):
			var count=0
			for x in range(0,image.get_width(),4):
				if image.get_pixel(x,y).a>.5:count+=1
			if count>3:top=mini(top,y);bottom=maxi(bottom,y)
		print("HUD ",race," size ",image.get_size()," used ",image.get_used_rect()," strong ",top,"..",bottom)
	quit()
