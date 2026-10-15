extends SceneTree

func _initialize() -> void:
	var assets=ACAssets.new()
	assets.load_all()
	var failures: Array=[]
	var animated=0
	for race in range(3):
		for kind in range(13):
			var key="%d:%d"%[race,kind]
			var original=assets.building(race,kind)
			var source=original.get_image().get_data()
			var dark=assets.building_idle(race,kind,0).get_image().get_data()
			var bright=assets.building_idle(race,kind,1.6).get_image().get_data()
			var changed=0
			if source.size()!=dark.size() or source.size()!=bright.size():
				failures.append("Dimensions changed: "+key)
				continue
			for offset in range(0,source.size(),4):
				if source[offset+3]!=dark[offset+3] or source[offset+3]!=bright[offset+3]:failures.append("Silhouette changed: "+key);break
				if dark[offset]!=bright[offset] or dark[offset+1]!=bright[offset+1] or dark[offset+2]!=bright[offset+2]:changed+=1
			if changed>0:animated+=1
			else:failures.append("No emissive idle detail: "+key)
			if not is_same(original,assets.building(race,kind)):failures.append("HUD icon texture replaced: "+key)
			if not is_same(assets.building_idle(race,kind,0),assets.building_idle(race,kind,3.2)):failures.append("Idle loop does not repeat: "+key)
	for failure in failures:printerr("FAIL ",failure)
	print("BUILDING_IDLE_V03 animated=",animated,"/39 alpha_and_dimensions_preserved=",failures.is_empty()," mask_pixels=",assets.building_idle_pixels)
	quit(0 if failures.is_empty() else 1)
