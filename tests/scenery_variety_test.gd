extends SceneTree
func _initialize():
	var r=ACTerrainRenderer.new();r.load_art();var report=[];var failures=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme);var props=r._scenery(map)
		var identical=0;var similar=0;var overlaps=0;var source_identical=0
		for i in range(props.size()):
			for j in range(i):
				var a=props[i];var b=props[j];var distance=a.pos.distance_to(b.pos)
				var both_source=a.get("source_obstacle",false) and b.get("source_obstacle",false)
				if both_source:
					if a.kind==b.kind and distance<3.6:source_identical+=1
					if distance<4.2:overlaps+=1
					continue
				if a.kind==b.kind and distance<3.6:identical+=1
				elif r._decor_family(a.kind)==r._decor_family(b.kind) and distance<2.2:similar+=1
				if distance<1.6:overlaps+=1
		if identical+similar+overlaps+source_identical>0:failures.append("scenery still repeats or overlaps on map %d"%theme)
		report.append({"theme":theme,"props":props.size(),"identical_close_pairs":identical,"similar_close_pairs":similar,"overlaps":overlaps,"authored_obstacle_identical_pairs":source_identical})
	print("SCENERY_VARIETY ",JSON.stringify({"failures":failures,"maps":report}));quit(0 if failures.is_empty() else 1)
