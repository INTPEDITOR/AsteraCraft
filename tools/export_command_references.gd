extends SceneTree
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute("res://build/icon-reference")
	var assets=ACAssets.new();assets.load_all()
	for race in range(3):
		for group in ["buildings","units"]:
			var sheet=Image.create(1536,1536,false,Image.FORMAT_RGBA8);sheet.fill(Color.TRANSPARENT)
			var count=13 if group=="buildings" else ACData.unit_count(race)
			for kind in range(count):
				var texture: Texture2D=assets.building(race,kind) if group=="buildings" else assets.unit(race,kind,Vector2(1,1),"idle",0).get("texture")
				if texture==null:continue
				var source=texture.get_image();var factor=300.0/maxf(source.get_width(),source.get_height())
				source.resize(maxi(1,roundi(source.get_width()*factor)),maxi(1,roundi(source.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
				var origin=Vector2i((kind%4)*384+192-source.get_width()/2,(kind/4)*384+192-source.get_height()/2)
				sheet.blit_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),origin)
			sheet.save_png("res://build/icon-reference/%s_%d.png"%[group,race])
	print("COMMAND_REFERENCES six current game-art sheets exported");quit()
