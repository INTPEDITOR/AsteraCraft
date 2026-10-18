extends SceneTree
var failures=[]
var checks=0
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label);printerr("FAIL ",label)
func _initialize():
	var r=ACTerrainRenderer.new();r.load_art();var reports=[]
	for theme in range(3):
		var map=ACMap.new();map.make(theme)
		var fields=[]
		for i in range(7):
			var field=PackedFloat32Array();field.resize(257*257);fields.append(field)
		r._apply_surface_regions(map,fields)
		var counts=[0,0,0,0];var cores=[0,0,0,0];var changes=0;var total=0;var owners=[];var pools=0
		for y in range(128):
			for x in range(128):
				var i=(y*2+1)*257+x*2+1
				var weights=[1-fields[1][i]-fields[2][i]-fields[3][i],fields[2][i],fields[3][i],fields[1][i]]
				var owner=0
				for kind in range(4):
					if weights[kind]>weights[owner]:owner=kind
				owners.append(owner)
				if map.terrain[y*128+x]==0:
					counts[owner]+=1;total+=1
					if weights[owner]>.95:cores[owner]+=1
				if x>0 and owner!=owners[-2]:changes+=1
				if y>0 and owner!=owners[(y-1)*128+x]:changes+=1
				if map.visual_role(y*128+x)==3 and map.is_water(y*128+x):
					pools+=1
					check(map.source_walk_masks[y*128+x]==0,"new water excludes every walkable minitile")
		check(pools==[943,169,456][theme],"all wholly blocked obstacle interiors converted to water")
		for kind in range(4):
			check(counts[kind]>total*.02,"all four textures cover meaningful land districts")
			check(cores[kind]>20,"all four textures have full-strength interiors")
		check(changes<128*127*2*.15,"material districts form large contiguous areas")
		var props=r._scenery(map)
		for prop in props:
			check(not prop.get("source_obstacle",false),"sprite-per-obstacle grid removed")
			check(not map.is_water(int(prop.pos.y)*128+int(prop.pos.x)),"decoration never sits on a pool")
		reports.append({"theme":theme,"water_cells":pools,"material_cells":counts,"opaque_interiors":cores,"props":props.size(),"material_boundary_edges":changes})
	var result={"checks":checks,"failures":failures,"maps":reports}
	FileAccess.open("res://build/source-terrain/water-materials.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WATER_MATERIAL_REGIONS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
