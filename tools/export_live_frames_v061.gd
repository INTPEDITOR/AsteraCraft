extends SceneTree
var sources={}
var entries=[]
func frame(key,info):
	var texture: Texture2D=info.texture
	var source=texture.atlas if texture is AtlasTexture else texture
	var region=texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	var id=source.get_instance_id()
	if not sources.has(id):
		var file="res://build/live-frame-sources-v061/%d.png"%sources.size()
		source.get_image().save_png(file);sources[id]=file
	entries.append({"key":key,"source":sources[id],"region":[int(region.position.x),int(region.position.y),int(region.size.x),int(region.size.y)],"anchor":[info.anchor.x,info.anchor.y],"scale_hint":info.scale_hint})
func _initialize():
	DirAccess.make_dir_recursive_absolute("res://build/live-frame-sources-v061")
	var art=ACAssets.new();art.load_all()
	for key in art.motion_frames:
		for row in range(art.motion_frames[key].size()):
			for col in range(art.motion_frames[key][row].size()):frame("motion:%s:%d:%d"%[key,row,col],art.motion_frames[key][row][col])
	for key in art.vehicle_frames:
		if key in ["0:5","0:12"]:continue
		for col in range(art.vehicle_frames[key].size()):
			for part in ["chassis","turret"]:frame("vehicle:%s:%d:%s"%[key,col,part],art.vehicle_frames[key][col][part])
	for key in art.v060_units:
		for index in range(art.v060_units[key].size()):frame("new:%s:%d"%[key,index],art.v060_units[key][index])
	for part in ["chassis","turrets"]:
		for index in range(art.siege_layers[part].size()):frame("siege:%s:%d"%[part,index],art.siege_layers[part][index].frame)
	for key in art.repaired_fire:
		if art.v060_units.has(key) or key=="0:5":continue
		for index in range(art.repaired_fire[key].size()):frame("fire:%s:%d"%[key,index],art.repaired_fire[key][index])
	for key in art.directional_air:
		if art.v060_units.has(key):continue
		for index in range(art.directional_air[key].frames.size()):frame("air:%s:%d"%[key,index],art.directional_air[key].frames[index])
	FileAccess.open("res://build/live-frame-sources-v061/frames.json",FileAccess.WRITE).store_string(JSON.stringify(entries))
	print("EXPORTED_LIVE_FRAMES ",entries.size()," sources ",sources.size());quit()
