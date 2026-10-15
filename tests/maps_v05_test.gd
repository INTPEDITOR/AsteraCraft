extends SceneTree
var checks=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL "+label)
func run() -> void:
	var hashes=[]
	for race in range(3):
		var map=ACMap.new();map.make(race)
		check(map.symmetric(),"terrain/height/buildability symmetric map %d"%race)
		for axis in [1,2,3]:check(map.resources_symmetric(axis),"equal resources reflection %d/%d"%[race,axis])
		check(map.starts.size()==4,"four starts")
		var signature=hash([map.terrain,map.height_map,map.starts])
		check(signature not in hashes,"unique map layout");hashes.append(signature)
		var obstacles=[]
		for node in map.resources:
			var rect=ACCore.resource_rect(node)
			for y in range(ceili(rect.position.y),ceili(rect.end.y)):
				for x in range(ceili(rect.position.x),ceili(rect.end.x)):
					check(map.terrain[y*128+x]==0,"resource on land map%d id%d (%d,%d)"%[race,node.id,x,y])
					if node.type=="tera":check(map.buildable(Vector2i(x,y)),"refinery buildable map%d id%d (%d,%d)"%[race,node.id,x,y])
			for previous in obstacles:check(not rect.intersects(previous),"resource overlap map%d id%d"%[race,node.id])
			obstacles.append(rect)
		map.set_resource_obstacles(obstacles)
		var origin=ACData.point(map.starts[0])+Vector2(3,3)
		for slot in range(1,4):check(not map.path(origin,map.reflect(origin,slot)).is_empty(),"all main bases connected map%d"%race)
		for base in map.bases:
			var goal=ACData.point(base.grid_center)
			var reachable=not map.path(origin,goal).is_empty()
			check(reachable==(base.access=="ground"),"base access map%d %s slot%d"%[race,base.kind,base.slot])
		var image=Image.create(768,768,false,Image.FORMAT_RGB8)
		for y in range(128):
			for x in range(128):
				var i=y*128+x
				var color=Color("4e5451") if map.terrain[i]==0 else Color("202526")
				if map.terrain[i]==2:color=[Color("254a5b"),Color("734334"),Color("421e32")][race]
				elif map.terrain[i]==0:color=[Color("9e8761"),Color("687144"),Color("8d9698")][race].lightened(map.height_map[i]*.14)
				if map.surface_map[i]==3:color=color.lightened(.15)
				image.fill_rect(Rect2i(x*6,y*6,6,6),color)
		for node in map.resources:
			var rect=ACCore.resource_rect(node)
			image.fill_rect(Rect2i(rect.position*6,rect.size*6),Color("ffd24c") if node.type=="as" else Color("54c8ff"))
		for start in map.starts:image.fill_rect(Rect2i(ACData.point(start)*6-Vector2(9,6),Vector2(18,12)),Color("e9f4ed"))
		image.save_png("res://build/map-v05-%d.png"%race)
		print("MAP_V05 ",race," bases=",map.bases.size()," resources=",map.resources.size())
	print("MAPS_V05 checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
