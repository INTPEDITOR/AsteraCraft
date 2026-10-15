extends SceneTree
var catalog={"air":{},"vehicle":{},"drone":{}}
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/registered_v052"))
	for race in range(3):
		var source=Image.load_from_file("res://assets/air_r%d_camera_v052.png"%race)
		var kinds=[9,10,11] if race==0 else ([10,11] if race==1 else [6,9,11,12])
		for index in range(kinds.size()):
			var rows=[index*2,index*2+1] if race==1 else [index]
			var frames: Array=[];var max_extent=1.0
			for row in rows:
				for col in range(5):
					var cell=piece(source,col,row,5,3 if race==0 else 4)
					if race==2 and row>=2 and col==1 and FileAccess.file_exists("res://assets/owl_ne_camera_v052.png"):
						var correction=Image.load_from_file("res://assets/owl_ne_camera_v052.png")
						cell=piece(correction,0,row-2,1,2)
						# Match corrected art's scale to the adjacent same-model direction.
						var reference=solid_bounds(piece(source,2,row,5,4)).size
						var current=solid_bounds(cell).size
						var ratio=float(maxi(reference.x,reference.y))/maxi(current.x,current.y)
						cell.resize(roundi(cell.get_width()*ratio),roundi(cell.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
					var bounds=solid_bounds(cell)
					var anchor=orange_center(cell,bounds) if race==1 else Vector2(bounds.get_center())
					var half=(Vector2(bounds.position)-anchor).abs().max((Vector2(bounds.end)-anchor).abs())
					max_extent=maxf(max_extent,maxf(half.x,half.y)*2)
					frames.append(cell)
			var outputs: Array=[]
			for n in range(frames.size()):
				var cell: Image=frames[n]
				var bounds=solid_bounds(cell)
				var anchor=Vector2(bounds.get_center())
				if race==1:anchor=orange_center(cell,bounds)
				var factor=260.0/max_extent
				var packed=pack(cell,anchor,factor,Vector2(160,160))
				var path="res://assets/registered_v052/r%d_u%d_%d.png"%[race,kinds[index],n]
				packed.save_png(path);outputs.append(path)
			catalog.air["%d:%d"%[race,kinds[index]]]={"frames":outputs,"columns":5,"phases":rows.size(),"anchor":[160,160],"scale_hint":260,"embedded_pilot":race==0}
			if race==1:catalog.air["%d:%d"%[race,kinds[index]]].direction_flips=[false,false,false,true,false]
	register_vehicle()
	register_drone()
	FileAccess.open("res://data/graphics_v052.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"  "))
	print("GRAPHICS_V052_REGISTERED");quit()

func solid_bounds(cell: Image) -> Rect2i:
	var lo=Vector2i(cell.get_width(),cell.get_height());var hi=Vector2i(-1,-1)
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			if cell.get_pixel(x,y).a>=.35:
				lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
	return Rect2i(lo,hi-lo+Vector2i.ONE) if hi.x>=0 else Rect2i(0,0,1,1)

func piece(source: Image,col: int,row: int,cols: int,rows: int) -> Image:
	var ya=separator(source,row,rows,false,0,source.get_width())
	var yb=separator(source,row+1,rows,false,0,source.get_width())
	var a=Vector2i(separator(source,col,cols,true,ya,yb),ya)
	var b=Vector2i(separator(source,col+1,cols,true,ya,yb),yb)
	return source.get_region(Rect2i(a,b-a))

func separator(source: Image,index: int,count: int,horizontal: bool,lo: int,hi: int) -> int:
	var extent=source.get_width() if horizontal else source.get_height()
	if index==0:return 0
	if index==count:return extent
	var expected=int(float(index)*extent/count)
	var radius=int(float(extent)/count*.25)
	var best=INF;var result=expected
	for candidate in range(maxi(1,expected-radius),mini(extent-1,expected+radius)):
		var mass=0.0
		for across in range(lo,hi):
			var color=source.get_pixel(candidate,across) if horizontal else source.get_pixel(across,candidate)
			if color.a>.35:mass+=1
		var score=mass*1000+abs(candidate-expected)
		if score<best:best=score;result=candidate
	return result

func pack(cell: Image,anchor: Vector2,factor: float,destination: Vector2) -> Image:
	var bounds=solid_bounds(cell).grow(3).intersection(Rect2i(Vector2i.ZERO,cell.get_size()))
	cell=cell.get_region(bounds)
	anchor-=Vector2(bounds.position)
	cell.resize(maxi(1,roundi(cell.get_width()*factor)),maxi(1,roundi(cell.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var result=Image.create(320,320,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	result.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),Vector2i(destination-anchor*factor))
	return result

func orange_center(cell: Image,bounds: Rect2i) -> Vector2:
	var sum=Vector2.ZERO;var weight=0.0
	for y in range(bounds.position.y,bounds.end.y,2):
		for x in range(bounds.position.x,bounds.end.x,2):
			var color=cell.get_pixel(x,y)
			if color.a>.8 and color.r>color.g*1.35 and color.g>color.b*1.2:
				sum+=Vector2(x,y);weight+=1
	return sum/weight if weight>0 else Vector2(bounds.get_center())

func register_vehicle() -> void:
	var source=Image.load_from_file("res://assets/vehicle_r0_u6_v052.png")
	var frames: Array=[]
	for col in range(5):
		var body=piece(source,col,0,5,2)
		var gun=piece(source,col,1,5,2)
		var b=solid_bounds(body);var g=solid_bounds(gun)
		var body_anchor=Vector2(b.get_center().x,b.end.y-12)
		var socket=Vector2(b.position)+Vector2(b.size)*[Vector2(.5,.10),Vector2(.51,.11),Vector2(.44,.12),Vector2(.50,.12),Vector2(.50,.10)][col]
		var gun_anchor=Vector2(g.get_center().x,g.end.y-18)
		var body_path="res://assets/registered_v052/vehicle_body_%d.png"%col
		var gun_path="res://assets/registered_v052/vehicle_turret_%d.png"%col
		var factor=.65
		pack(body,body_anchor,factor,Vector2(160,260)).save_png(body_path)
		pack(gun,gun_anchor,factor,Vector2(160,260)).save_png(gun_path)
		var muzzles=[Vector2(.50,.10),Vector2(.78,.16),Vector2(.95,.39),Vector2(.90,.55),Vector2(.60,.55)]
		frames.append({"chassis":body_path,"turret":gun_path,"mount":ACData.packed((socket-body_anchor)*factor),"muzzle":ACData.packed((Vector2(g.position)+Vector2(g.size)*muzzles[col]-gun_anchor)*factor)})
	catalog.vehicle={"key":"0:6","frames":frames,"anchor":[160,260],"scale_hint":205,"turret_scale":.82}

func register_drone() -> void:
	var source=Image.load_from_file("res://assets/drone_parts_v052.png")
	var bodies: Array=[];var rotors: Array=[]
	for col in range(5):
		for row in range(2):
			var cell=piece(source,col,row,5,2)
			var bounds=solid_bounds(cell)
			var factor=210.0/maxf(bounds.size.x,bounds.size.y)
			var path="res://assets/registered_v052/drone_%d_%d.png"%[row,col]
			pack(cell,Vector2(bounds.get_center()),factor,Vector2(160,160)).save_png(path)
			if row==0:bodies.append(path)
			else:rotors.append(path)
	catalog.drone={"bodies":bodies,"rotors":rotors,"anchor":[160,160],"scale_hint":210}
