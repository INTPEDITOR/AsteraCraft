extends SceneTree
var checks=0
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr(message)
func settle() -> void:
	await create_timer(.2).timeout;await process_frame;await process_frame
func run() -> void:
	var report=[];var value=ACSettings.defaults()
	var panel=ColorRect.new();panel.color=Color("d07d35");root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for mode in ACSettings.WINDOW_MODES:
		value.window_mode=mode;value.resolution=[1280,720];ACSettings.apply_display(value);await settle()
		var active=root.get_final_transform()*Rect2(Vector2.ZERO,panel.size)
		check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"aspect policy in "+mode)
		check(panel.size==Vector2(1600,900),"fixed16:9 canvas in "+mode)
		check(absf(active.size.x/active.size.y-16.0/9.0)<.001,"visible16:9 view in "+mode)
		report.append({"mode":mode,"window":str(root.size),"game_view":str(active),"logical_canvas":str(panel.size)})
	value.window_mode="windowed";ACSettings.apply_display(value);await settle()
	for extent in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(1920,800),Vector2i(2560,1080),Vector2i(3440,1440)]:
		root.size=extent;await settle();var active=root.get_final_transform()*Rect2(Vector2.ZERO,panel.size)
		check(panel.size==Vector2(1600,900),"canvas never expands at "+str(extent))
		check(absf(active.size.x/active.size.y-16.0/9.0)<.001,"projection16:9 at "+str(extent))
		check(absf(root.get_final_transform().x.length()-root.get_final_transform().y.length())<.001,"uniform scale at "+str(extent))
		if extent.x/float(extent.y)>1.9:check(active.position.x>0 and active.size.x<root.size.x,"pillarbox rather than21:9 expansion")
		report.append({"requested":str(extent),"window":str(root.size),"game_view":str(active)})
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"screen":str(DisplayServer.screen_get_size()),"modes":report}
	DirAccess.make_dir_recursive_absolute("res://build/aspect16x9-20261024");FileAccess.open("res://build/aspect16x9-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("ASPECT16X9 ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
