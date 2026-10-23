extends SceneTree
var checks=0
var failures: Array=[]
func check(value: bool,detail: String) -> void:
	checks+=1
	if not value:failures.append(detail);printerr("FAIL "+detail)
func digest(image: Image) -> String:
	image.convert(Image.FORMAT_RGBA8)
	var pixels=image.get_data()
	# Imported PNGs discard hidden RGB where alpha is exactly zero.
	for offset in range(0,pixels.size(),4):
		if pixels[offset+3]==0:pixels[offset]=0;pixels[offset+1]=0;pixels[offset+2]=0
	var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(pixels);return context.finish().hex_encode()
func _initialize() -> void:
	var art=ACAssets.new();art.load_all()
	var total=0
	for race in range(3):
		for kind in range(13):
			var hashes={}
			var phases=4 if race==1 else 5
			for stage in range(phases):
				var frame=art.sprites.building(race,kind,float(stage)/float(phases-1),false,Vector2.DOWN,0)
				check(not frame.is_empty(),"construction phase exists %d:%d/%d"%[race,kind,stage])
				if frame.is_empty():continue
				check((frame.action=="construction" and frame.frame==stage+(1 if race==1 else 0)) if stage<phases-1 else frame.action=="idle","unfinished phases then original finished art %d:%d/%d"%[race,kind,stage])
				var image: Image=frame.texture.get_image();hashes[digest(image)]=true
				check(image.get_width()>4 and image.get_height()>4 and image.get_used_rect().has_area(),"nonempty phase pixels")
				var scale_value=200.0/float(frame.scale_hint)
				var foundation=Vector2(300,400)
				var top_left=foundation-Vector2(frame.anchor)*scale_value
				check((top_left+Vector2(frame.anchor)*scale_value).is_equal_approx(foundation),"foundation pivot remains fixed")
				total+=1
			check(hashes.size()==phases,"all visible unfinished paintings plus distinct original complete art %d:%d"%[race,kind])
			var almost=art.sprites.building(race,kind,.999999,false,Vector2.DOWN,100)
			check(almost.action=="construction" and almost.frame==3,"complete art never appears before 100%% %d:%d"%[race,kind])
			var last=art.sprites.sample(art.sprites.buildings["%d:%d"%[race,kind]],"construction",Vector2.DOWN,0,4)
			check(digest(art.sprites.building(race,kind,1,false,Vector2.DOWN,0).texture.get_image())==digest(last.texture.get_image()),"completion displays exactly fifth construction painting %d:%d"%[race,kind])
	check(total==182,"39 buildings expose182 phases after removing13 citrus worker introductions")
	var result={"checks":checks,"failures":failures,"construction_frames":total,"passed":failures.is_empty()}
	var f=FileAccess.open("res://build/visual_feedback_20261024/construction-test.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("BUILDING_CONSTRUCTION5_TEST %d checks %d failures %d/182 phases"%[checks,failures.size(),total])
	quit(0 if failures.is_empty() else 1)
