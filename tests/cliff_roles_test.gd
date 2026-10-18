extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label)
func _initialize():
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps.json"))
	var artist=ACTerrainRenderer.new();artist.load_art()
	var report=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme)
		check(map.visual_roles.size()==16384,"separate visual roles loaded")
		check(map.terrain==PackedByteArray(source.maps[theme].terrain),"original navigation unchanged")
		check(map.height_map==PackedByteArray(source.maps[theme].height_map),"original height levels unchanged")
		check(map.buildable_map==PackedByteArray(source.maps[theme].buildable_map),"original construction unchanged")
		var counts=[0,0,0,0];var represented={}
		for prop in artist._scenery(map):
			if prop.get("source_obstacle",false):
				for p in prop.cells:represented[int(p.y)*128+int(p.x)]=true
		for i in range(16384):
			var role=map.visual_role(i);counts[role]+=1
			if role==3:
				check(represented.has(i),"no invisible obstacle left after cliff removal")
				check(is_equal_approx(map.visual_cell_elevation(i%128,i/128),float(map.height_map[i])*map.ELEVATION_PIXELS),"flat obstacles do not create fake ground elevation")
			if role==1:
				var high=map.height_map[i];var low=high
				for dy in range(-3,4):
					for dx in range(-3,4):
						var x=i%128+dx;var y=int(i/128)+dy
						if x<0 or y<0 or x>=128 or y>=128:continue
						var j=y*128+x
						if map.terrain[j]==2:continue
						high=maxi(high,map.height_map[j]);low=mini(low,map.height_map[j])
				check(high>low,"every cliff belongs to an actual height boundary")
		check(counts[1]>0 and counts[2]>0 and counts[3]>0,"cliffs shores and obstacles remain distinct")
		if theme==0:
			for p in [Vector2i(57,44),Vector2i(53,46),Vector2i(53,47),Vector2i(53,48)]:
				check(map.visual_role(p.y*128+p.x)==3,"reported isolated doodads are not cliffs")
		report.append({"theme":theme,"roles":counts})
	print("CLIFF_ROLES ",JSON.stringify({"checks":checks,"failures":failures,"maps":report}))
	quit(0 if failures.is_empty() else 1)
