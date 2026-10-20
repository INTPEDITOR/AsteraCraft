extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():
	var original=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_terrain_detail.json"))
	for theme in range(3):
		var map=ACMap.new();map.make(theme);map.resource_obstacles.clear();map.reset_solids([])
		var opened=0;var walls=0;var water=0
		for y in range(2,126):
			for x in range(2,126):
				var index=y*128+x
				if (map.terrain[index]==0 or map.visual_role(index)==3) and int(original.maps[theme].walk_masks[index])!=0xffff:
					var flat=true
					for offset in [-128,-1,1,128]:
						if map.height_map[index+offset]!=map.height_map[index] or map.visual_role(index+offset) in [1,2]:flat=false
					if flat:
						check(map.source_ground_fits(Vector2(.2,.2),Vector2(x,y)),"apparently open ground has no hidden collision %d %d"%[theme,index]);opened+=1
				elif map.visual_role(index)==1 and int(original.maps[theme].walk_masks[index])==0:
					check(not map.source_ground_fits(Vector2(.2,.2),Vector2(x,y)),"visible wall remains solid");walls+=1
				elif map.is_water(index):
					check(not map.source_ground_fits(Vector2(.2,.2),Vector2(x,y)),"water remains solid");water+=1
		print("TERRAIN_POLICY_MAP ",theme," opened ",opened," walls ",walls," water ",water)
	print("TERRAIN_POLICY_V061 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
