extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var assets=ACAssets.new();assets.load_all()
	var report=[]
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			var hashes=[]
			for phase in range(16):
				var f=assets.unit(race,kind,Vector2(1,.5),"walk",float(phase)/18.0)
				var image=f.texture.get_image().duplicate()
				if image.is_compressed():image.decompress()
				var key=hash(image.get_data());if not key in hashes:hashes.append(key)
			var air=bool(ACData.unit(race,kind).air)
			var vehicle=not assets.vehicle(race,kind,Vector2.RIGHT,Vector2.RIGHT).is_empty()
			check(hashes.size()>1 or air or vehicle,"movement frames or animated chassis %d/%d"%[race,kind])
			report.append({"race":race,"kind":kind,"sprite_poses":hashes.size(),"propulsion":air,"chassis_gait":vehicle})
	check(assets.propulsion_frames.size()==3,"three faction propulsion sheets")
	for race in range(3):
		var hashes=[]
		for frame in assets.propulsion_frames[race]:
			var image=frame.get_image();check(image.detect_alpha()!=Image.ALPHA_NONE,"transparent propulsion")
			var key=hash(image.get_data());if not key in hashes:hashes.append(key)
		check(hashes.size()==8,"eight distinct propulsion poses")
	var renderer=ACTerrainRenderer.new();renderer.load_art()
	check(renderer.planet_materials.size()==48,"48 terrain materials")
	FileAccess.open("res://build/motion-v058-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOTION_V058 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
