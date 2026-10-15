extends SceneTree

# Atlas extraction and registration only; artwork is generated separately.
func _initialize() -> void:
	var catalog={"schema":1,"air":{},"motions":{}}
	var regions=[[[18,25,442,625],[483,16,387,632],[885,34,724,602],[1654,60,500,598]],[[18,100,856,667],[825,39,935,824]],[[12,259,382,338],[461,128,419,496],[942,74,588,593],[1592,5,552,715]]]
	var kinds=[[8,9,10,11],[10,11],[6,9,11,12]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/air_registered_v05"))
	for race in range(3):
		var source=Image.load_from_file("res://assets/air_top_r%d_v05.png"%race)
		for n in range(kinds[race].size()):
			var raw=regions[race][n]
			var piece=source.get_region(Rect2i(raw[0],raw[1],raw[2],raw[3]))
			# Overlapping atlas bounding rectangles can contain a neighbour's
			# wingtip. Keep the connected object containing the central hull.
			if race==1:piece=isolate_component(piece)
			var used=piece.get_used_rect()
			piece=piece.get_region(used)
			var factor=288.0/maxf(piece.get_width(),piece.get_height())
			piece.resize(roundi(piece.get_width()*factor),roundi(piece.get_height()*factor),Image.INTERPOLATE_LANCZOS)
			var packed=Image.create(320,320,false,Image.FORMAT_RGBA8)
			packed.fill(Color.TRANSPARENT)
			packed.blit_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),(Vector2i(320,320)-piece.get_size())/2)
			var path="res://assets/air_registered_v05/r%d_u%d.png"%[race,kinds[race][n]]
			packed.save_png(path)
			catalog.air["%d:%d"%[race,kinds[race][n]]]={"file":path,"anchor":[160,160],"scale_hint":288,"native_heading":"north","embedded_pilot":race==0,"projection":"overhead","source": "res://assets/air_top_r%d_v05.png"%race}
	var source=Image.load_from_file("res://assets/medic_repaired_v05.png")
	var output=Image.create(5*288,4*320,false,Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for row in range(4):
		for col in range(5):
			var start=Vector2i(int(col*source.get_width()/5.0),int(row*source.get_height()/4.0))
			var end=Vector2i(int((col+1)*source.get_width()/5.0),int((row+1)*source.get_height()/4.0))
			var piece=source.get_region(Rect2i(start,end-start))
			var bounds=strong_bounds(piece)
			# All generated cells use one scale; contact row gets registered,
			# rather than scaling the raised healing hands to a different size.
			var offset=Vector2i(col*288+(288-piece.get_width())/2,row*320+292-bounds.end.y)
			output.blit_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),offset)
	output.save_png("res://assets/medic_registered_v05.png")
	catalog.motions["0:4"]={"file":"res://assets/medic_registered_v05.png","columns":5,"rows":4,"packed_root":[144,292],"scale_hint":250,"actions":{"idle":[0],"walk":[1,0,2,0],"move":[1,0,2,0],"heal":[3],"attack":[0],"harvest":[0]},"action_fps":{"walk":9,"move":9,"heal":8}}
	catalog.fire={"file":"res://assets/hyrax_fire_poses_v05.png","columns":5,"rows":4,"kinds":[1,2,3,7],"muzzles":[[[.40,.09],[.80,.20],[.97,.43],[.94,.75],[.53,.72]],[[.42,.09],[.85,.16],[.98,.40],[.98,.67],[.54,.73]],[[.33,.06],[.84,.14],[.96,.29],[.66,.47],[.52,.55]],[[.24,.04],[.84,.16],[.98,.40],[.99,.73],[.53,.74]]]}
	FileAccess.open("res://data/graphics_repairs_v05.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"  "))
	var buildings=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_regions_v3.json"))
	var art=Image.load_from_file("res://assets/owl_buildings_repaired_v05.png")
	for col in range(2):
		buildings.get_or_add("overrides",{})["2:%d"%(0 if col==0 else 3)]={"file":"res://assets/owl_buildings_repaired_v05.png","region":[0 if col==0 else 965,0,965 if col==0 else art.get_width()-965,art.get_height()]}
	FileAccess.open("res://data/building_regions_v3.json",FileAccess.WRITE).store_string(JSON.stringify(buildings,"  "))
	print("REGISTER_GRAPHICS_REPAIRS air=10 medic_frames=20 buildings=2")
	quit()

func strong_bounds(image: Image) -> Rect2i:
	var low=image.get_size();var high=Vector2i.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<.4:continue
			low=Vector2i(mini(low.x,x),mini(low.y,y));high=Vector2i(maxi(high.x,x),maxi(high.y,y))
	return Rect2i(low,high-low+Vector2i.ONE)

func isolate_component(image: Image) -> Image:
	var size_value=image.get_size()
	var seen=PackedByteArray();seen.resize(size_value.x*size_value.y)
	var seed=size_value/2
	var queue: Array[Vector2i]=[seed];seen[seed.y*size_value.x+seed.x]=1
	var cursor=0
	while cursor<queue.size():
		var p=queue[cursor];cursor+=1
		for delta in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
			var next=p+delta
			if next.x<0 or next.y<0 or next.x>=size_value.x or next.y>=size_value.y:continue
			var index=next.y*size_value.x+next.x
			if not seen[index] and image.get_pixelv(next).a>.005:seen[index]=1;queue.append(next)
	var result=Image.create(size_value.x,size_value.y,false,Image.FORMAT_RGBA8)
	for p in queue:result.set_pixelv(p,image.get_pixelv(p))
	return result
