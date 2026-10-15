extends SceneTree
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_v052.json"))
	var paths: Array=[]
	for info in catalog.air.values():paths.append_array(info.frames)
	for info in catalog.vehicle.frames:paths.append(info.chassis);paths.append(info.turret)
	paths.append_array(catalog.drone.bodies);paths.append_array(catalog.drone.rotors)
	for path in paths:
		var texture=load(path);check(texture is Texture2D,"loaded "+path)
		var img=texture.get_image();var edge=false;var opaque=0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x,y).a>.35:
					opaque+=1
					if x<2 or y<2 or x>=img.get_width()-2 or y>=img.get_height()-2:edge=true
		check(not edge and opaque>100,"complete packed silhouette "+path)
	var assets=ACAssets.new();assets.load_all()
	for key in catalog.air:
		var race=int(key.split(":")[0]);var kind=int(key.split(":")[1])
		for i in range(8):
			var frame=assets.unit(race,kind,Vector2.UP.rotated(i*PI/4))
			check(frame.rotation==0 and frame.texture!=null,"fixed camera no plane rotation %s dir%d"%[key,i])
	for i in range(8):
		var body=Vector2.UP.rotated(i*PI/4);var vehicle=assets.vehicle(0,6,body,body.rotated(PI/2))
		check(vehicle.mount.y<0 and vehicle.mount.y> -220,"turret socket stays on chassis %d"%i)
	check(assets.drone_parts.bodies.size()==5 and assets.drone_parts.rotors.size()==5,"separate drone sensor and rotor frames")
	check(assets.unit(1,10,Vector2.RIGHT,"idle",0).texture!=assets.unit(1,10,Vector2.RIGHT,"idle",.25).texture,"citrus idle wing animation")
	print("GRAPHICS_V052 "+JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
