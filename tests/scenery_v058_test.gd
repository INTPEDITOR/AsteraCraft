extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label)
func _initialize():
	var renderer=ACTerrainRenderer.new();renderer.load_art()
	check(renderer.quiet_materials.size()==12,"coherent ground materials loaded")
	check(renderer.scenery_textures.size()==90,"90 separate props loaded including 54 new originals")
	check(renderer.world_materials.size()==9,"new cliff water and shore materials loaded")
	for texture in renderer.scenery_textures:
		var image=texture.diffuse_texture.get_image()
		check(image.detect_alpha()!=Image.ALPHA_NONE,"props have real transparency")
	var report=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme)
		var before=hash([map.terrain,map.height_map,map.resources,map.buildable_map])
		var props=renderer._scenery(map)
		check(props==renderer._scenery(map),"deterministic scenery")
		check(before==hash([map.terrain,map.height_map,map.resources,map.buildable_map]),"decorations leave gameplay unchanged")
		var kinds={}
		for prop in props:
			kinds[prop.kind]=true
			if prop.get("source_obstacle",false):
				for p in prop.cells:check(map.terrain[int(p.y)*128+int(p.x)]==1,"source obstacles preserve authored collision")
				continue
			check(renderer._scenery_safe(map,prop.pos),"resource/start/ramp clearance")
			if prop.structure:
				for offset in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
					var p=Vector2i(prop.pos+offset)
					check(map.terrain[p.y*128+p.x]==1,"solid-looking scenery never blocks a walkable passage")
		# Available artwork need not all be forced into every map. That old
		# assertion encouraged dense, unrelated clusters of structures.
		check(kinds.size()>=12,"varied natural scenery remains available on each map")
		var landmarks=[]
		for prop in props:
			check(prop.slot>=0 and prop.slot<renderer.scenery_textures.size(),"placed prop refers to available art")
			if prop.kind in [2,3,8,9,10,14,15,17,22,23,24,25,26,27]:landmarks.append(prop)
		check(landmarks.size()<props.size()*.1,"large structures remain sparse landmarks")
		for i in range(landmarks.size()):
			for j in range(i):check(landmarks[i].pos.distance_to(landmarks[j].pos)>=10,"large landmarks are separated")
		report.append({"theme":theme,"props":props.size(),"kinds":kinds.size()})
	var output={"checks":checks,"failures":failures,"maps":report}
	FileAccess.open("res://build/scenery-v058.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("SCENERY_V058 ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
