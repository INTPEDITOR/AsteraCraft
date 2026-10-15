extends SceneTree

const OUT="res://build/graphics-review-v05/"

func stamp(target: Image, piece: Image, position: Vector2i, size_limit: Vector2i) -> void:
	var used=piece.get_used_rect()
	if not used.has_area():return
	piece=piece.get_region(used)
	var scale_value=minf(float(size_limit.x)/piece.get_width(),float(size_limit.y)/piece.get_height())
	piece.resize(maxi(1,roundi(piece.get_width()*scale_value)),maxi(1,roundi(piece.get_height()*scale_value)),Image.INTERPOLATE_LANCZOS)
	target.blend_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),position+(size_limit-piece.get_size())/2)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var art=ACAssets.new();art.load_all()
	var cache={"units":art.motion_regions.units}
	var total_frames=0
	var audit: Array=[]
	for race in range(3):
		var units=Image.create(1170,13*150,false,Image.FORMAT_RGBA8);units.fill(Color("26303a"))
		var buildings=Image.create(1000,3*240,false,Image.FORMAT_RGBA8);buildings.fill(Color("26303a"))
		for kind in range(13):
			stamp(buildings,art.building(race,kind).get_image(),Vector2i((kind%5)*200,int(kind/5)*240),Vector2i(196,230))
			var key="%d:%d"%[race,kind]
			var info=cache.units[key]
			if art.repaired_air.has(key):info={"file":art.graphics_repairs.air[key].file,"columns":1,"rows":1}
			var source: Image=load(info.file).get_image()
			var rows=int(info.rows);var columns=int(info.columns)
			var touching: Array=[]
			var empty: Array=[]
			for row in range(rows):
				for col in range(columns):
					var start=Vector2i(col*source.get_width()/columns,row*source.get_height()/rows)
					var end=Vector2i((col+1)*source.get_width()/columns,(row+1)*source.get_height()/rows)
					var cell=source.get_region(Rect2i(start,end-start))
					if not cell.get_used_rect().has_area():empty.append([row,col]);continue
					var edge=0
					for x in range(cell.get_width()):
						if cell.get_pixel(x,0).a>.65:edge+=1
						if cell.get_pixel(x,cell.get_height()-1).a>.65:edge+=1
					for y in range(cell.get_height()):
						if cell.get_pixel(0,y).a>.65:edge+=1
						if cell.get_pixel(cell.get_width()-1,y).a>.65:edge+=1
					if edge>1:touching.append({"row":row,"column":col,"opaque_edge_pixels":edge})
			for action_index in range(3):
				for heading in range(3):
					var action=["idle","walk","attack"][action_index]
					var direction=Vector2.UP.rotated(heading*PI*.5)
					var frame=art.unit(race,kind,direction,action,.12)
					var rendered=frame.texture.get_image()
					if bool(frame.get("flip",false)):rendered.flip_x()
					if frame.has("rotation"):
						for turn in range(posmod(roundi(float(frame.rotation)/(PI*.5)),4)):rendered.rotate_90(CLOCKWISE)
					stamp(units,rendered,Vector2i((action_index*3+heading)*130,kind*150),Vector2i(126,146))
			total_frames+=rows*columns
			audit.append({"unit":key,"name":ACData.unit(race,kind).name,"air":ACData.unit(race,kind).air,"empty_frames":empty,"edge_contacts":touching,"frames":rows*columns})
		units.save_png(OUT+"unit-atlas-r%d.png"%race)
		buildings.save_png(OUT+"building-atlas-r%d.png"%race)
	FileAccess.open(OUT+"asset-audit.json",FileAccess.WRITE).store_string(JSON.stringify({"units":audit,"note":"Opaque cell-edge contact flags possible clipping; it is not proof of clipping. Gallery columns: idle N/E/S, walk N/E/S, attack N/E/S. Rows: unit kinds 0..12."},"\t"))
	print("GRAPHICS_ASSET_AUDIT units=39 active_base_frames=",total_frames)
	quit()
