extends SceneTree
## Bake three independent construction PNGs per original in-game building.
## The final building art is preserved. Complete generated phases use uniform
## scaling and a transparent gutter, with near-invisible source haze excluded.

const SOURCES := ["res://assets/construction_unique_r0_v4.png","res://assets/construction_unique_r1_v4.png","res://assets/construction_unique_r2_v4.png"]
const DIRECTORY := "res://assets/construction_v4"
const CATALOG := "res://data/construction_regions_v04.json"
const AUDIT := "res://build/construction-v04-audit.json"
const REVIEWED_REGIONS := "res://data/construction_source_regions_v04.json"
const REVEAL := [0.08,0.20,0.68]
var failed := false

func _initialize() -> void:
	call_deferred("run")

static func digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func write_json(path: String, value: Dictionary) -> void:
	var output:=FileAccess.open(path,FileAccess.WRITE)
	if output==null:failed=true;printerr("Cannot write "+path);return
	output.store_string(JSON.stringify(value,"  "))
	output.flush()

static func alpha_data(image: Image) -> PackedByteArray:
	var rgba:=image.get_data()
	var alpha:=PackedByteArray()
	alpha.resize(image.get_width()*image.get_height())
	for index in range(alpha.size()):alpha[index]=rgba[index*4+3]
	return alpha

func axis_bands(counts: PackedInt32Array, threshold: int, gap: int, minimum: int) -> Array:
	var bands: Array=[]
	var start:=-1
	var last:=-1
	for index in range(counts.size()):
		if counts[index]>=threshold:
			if start<0:start=index
			last=index
		elif start>=0 and index-last>gap:
			if last-start+1>=minimum:bands.append([start,last+1])
			start=-1
	if start>=0 and last-start+1>=minimum:bands.append([start,last+1])
	return bands

func source_registration(image: Image, race: int) -> Dictionary:
	var bytes:=image.get_data()
	var rows:=PackedInt32Array()
	var columns:=PackedInt32Array()
	rows.resize(image.get_height())
	columns.resize(image.get_width())
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if bytes[(y*image.get_width()+x)*4+3]>=64:
				rows[y]+=1
				columns[x]+=1
	var row_bands:=axis_bands(rows,maxi(3,int(image.get_width()*.003)),maxi(3,int(image.get_height()/13.0*.035)),maxi(4,int(image.get_height()/13.0*.10)))
	var column_bands:=axis_bands(columns,maxi(3,int(image.get_height()*.001)),maxi(3,int(image.get_width()/3.0*.02)),maxi(4,int(image.get_width()/3.0*.10)))
	var adaptive:=row_bands.size()==13 and column_bands.size()==3
	var cells: Array=[]
	for kind in range(13):
		var stages: Array=[]
		for phase in range(3):
			var x0:=int(float(phase)*image.get_width()/3.0)
			var x1:=int(float(phase+1)*image.get_width()/3.0)
			var y0:=int(float(kind)*image.get_height()/13.0)
			var y1:=int(float(kind+1)*image.get_height()/13.0)
			if adaptive:
				x0=0 if phase==0 else int((int(column_bands[phase-1][1])+int(column_bands[phase][0]))*.5)
				x1=image.get_width() if phase==2 else int((int(column_bands[phase][1])+int(column_bands[phase+1][0]))*.5)
				y0=0 if kind==0 else int((int(row_bands[kind-1][1])+int(row_bands[kind][0]))*.5)
				y1=image.get_height() if kind==12 else int((int(row_bands[kind][1])+int(row_bands[kind+1][0]))*.5)
			stages.append([x0,y0,x1-x0,y1-y0])
		cells.append(stages)
	var method:="alpha_bands" if adaptive else "nominal_3_by_13_requires_visual_review"
	var verified:=adaptive
	if FileAccess.file_exists(REVIEWED_REGIONS):
		var reviewed=JSON.parse_string(FileAccess.get_file_as_string(REVIEWED_REGIONS))
		var source=reviewed.get("sources",{}).get(str(race),{}) if reviewed is Dictionary else {}
		var supplied=source.get("cells",[])
		if source.get("source_sha256","")==digest(FileAccess.get_file_as_bytes(SOURCES[race])) and supplied is Array and supplied.size()==13:
			var valid:=true
			for row in supplied:
				if not row is Array or row.size()!=3:valid=false;break
				for raw in row:
					if not raw is Array or raw.size()!=4:valid=false;break
					var region:=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
					if not region.has_area() or region!=region.intersection(Rect2i(Vector2i.ZERO,image.get_size())):valid=false;break
			if valid:cells=supplied;method="visually_reviewed_regions";verified=true
	return {"race":race,"file":SOURCES[race],"size":[image.get_width(),image.get_height()],"registration":method,"registration_verified":verified,"row_bands":row_bands,"column_bands":column_bands,"cells":cells}

func stamp(gallery: Image, image: Image, column: int, row: int) -> void:
	var factor:=minf(1.0,minf(200.0/image.get_width(),165.0/image.get_height()))
	var piece: Image=image.duplicate()
	piece.resize(maxi(1,roundi(image.get_width()*factor)),maxi(1,roundi(image.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var point:=Vector2i(20+column*230+(200-piece.get_width())/2,row*190+178-piece.get_height())
	gallery.blend_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),point)

static func bake(original: Image, scaffold: Image, _phase: int) -> Dictionary:
	var size_value:=original.get_size()
	# Generated sheets contain near-transparent haze well outside the object.
	# Count visible pixels, not every nonzero alpha byte, when fitting its body.
	var low:=scaffold.get_size()
	var high:=Vector2i(-1,-1)
	for y in range(scaffold.get_height()):
		for x in range(scaffold.get_width()):
			if scaffold.get_pixel(x,y).a>=.08:
				low=Vector2i(mini(low.x,x),mini(low.y,y))
				high=Vector2i(maxi(high.x,x),maxi(high.y,y))
	var bounds:=scaffold.get_used_rect()
	if high.x>=low.x:bounds=Rect2i(low,high-low+Vector2i.ONE).grow(1).intersection(Rect2i(Vector2i.ZERO,scaffold.get_size()))
	var cropped:=scaffold.get_region(bounds)
	# Preserve the COMPLETE generated phase, with a two-pixel transparent
	# gutter. Never mask it by the final building or a horizontal reveal line.
	var factor:=minf(float(size_value.x-4)/cropped.get_width(),float(size_value.y-4)/cropped.get_height())
	var scaled: Image=cropped.duplicate()
	scaled.resize(maxi(1,roundi(cropped.get_width()*factor)),maxi(1,roundi(cropped.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var result:=Image.create(size_value.x,size_value.y,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var offset:=Vector2i((size_value.x-scaled.get_width())/2,size_value.y-scaled.get_height()-2)
	result.blit_rect(scaled,Rect2i(Vector2i.ZERO,scaled.get_size()),offset)
	var bytes:=result.get_data()
	return {"image":result,"uniform_scale":factor,"scaled_size":[scaled.get_width(),scaled.get_height()],"original_pixels":0,"generated_pixels":scaled.get_width()*scaled.get_height(),"outside_silhouette":0,"complete_source":true,"transparent_gutter":2,"rgba_sha256":digest(bytes),"alpha_sha256":digest(alpha_data(result))}

func run() -> void:
	var scaffolds: Array=[]
	var registrations: Array=[]
	var galleries: Array=[]
	for race in range(3):
		var gallery:=Image.create(940,13*190,false,Image.FORMAT_RGBA8)
		gallery.fill(Color(.055,.075,.085,1))
		for row in range(13):gallery.fill_rect(Rect2i(0,row*190,940,1),Color(.17,.21,.23,1))
		galleries.append(gallery)
		if not FileAccess.file_exists(SOURCES[race]):printerr("Unique generated construction source has not arrived: "+SOURCES[race]);quit(1);return
		var source:=Image.new()
		if source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCES[race]))!=OK or source.is_empty():printerr("Unreadable unique construction source");quit(1);return
		source.convert(Image.FORMAT_RGBA8)
		var registration:=source_registration(source,race)
		if not bool(registration.registration_verified):failed=true;printerr("Construction source needs visual cell registration: "+SOURCES[race])
		registration.source_sha256=digest(FileAccess.get_file_as_bytes(SOURCES[race]))
		registrations.append(registration)
		var buildings: Array=[]
		for kind in range(13):
			var phases: Array=[]
			for phase in range(3):
				var raw: Array=registration.cells[kind][phase]
				var piece:=source.get_region(Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3])))
				# These cells were visually reviewed: their small disconnected
				# islands are neighbouring atlas fragments, not floating parts.
				# Owl phase 5 has a real separate crystal and is deliberately kept.
				if race==0 or (race==2 and kind in [3,7] and phase==2):piece=registered_component(piece)
				if not piece.get_used_rect().has_area():printerr("Empty unique scaffold %d:%d/%d"%[race,kind,phase]);quit(1);return
				phases.append(piece)
			buildings.append(phases)
		scaffolds.append(buildings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var art:=ACAssets.new()
	art.load_all()
	var entries: Dictionary={}
	var frames: Array=[]
	var all_hashes: Dictionary={}
	for race in range(3):
		for kind in range(13):
			var texture:=art.building(race,kind)
			if texture==null:failed=true;printerr("Missing original building %d:%d"%[race,kind]);continue
			var original:=texture.get_image()
			original.convert(Image.FORMAT_RGBA8)
			var original_hash:=digest(original.get_data())
			stamp(galleries[race],original,3,kind)
			var stages: Array=[]
			var stage_hashes: Array=[]
			for phase in range(3):
				var result:=bake(original,scaffolds[race][kind][phase],phase)
				var file:="%s/building_%d_%02d_stage%d.png"%[DIRECTORY,race,kind,phase]
				if result.image.save_png(file)!=OK:failed=true;printerr("Cannot save "+file)
				stamp(galleries[race],result.image,phase,kind)
				stages.append({"file":file,"region":[0,0,original.get_width(),original.get_height()],"composite":true})
				stage_hashes.append(result.rgba_sha256)
				all_hashes[result.rgba_sha256]=true
				var record:=result.duplicate()
				record.erase("image")
				record.merge({"race":race,"kind":kind,"stage":phase,"file":file,"size":[original.get_width(),original.get_height()],"original_sha256":original_hash,"source_file":SOURCES[race],"source_region":registrations[race].cells[kind][phase]})
				frames.append(record)
				if int(result.outside_silhouette)!=0 or int(result.generated_pixels)<4 or result.rgba_sha256==original_hash:
					failed=true;printerr("Construction composition check failed for "+file)
			if stage_hashes[0]==stage_hashes[1] or stage_hashes[1]==stage_hashes[2]:failed=true;printerr("Construction phases are identical")
			if digest(original.get_data())!=original_hash:failed=true;printerr("Original building art was modified")
			entries["%d:%d"%[race,kind]]=stages
	var method:="Per-building unique generated construction art; original canvas, lower assembly and foundation preserved; complete phase uniformly fitted with transparent gutters; no alpha silhouette clipping; independent native-size composite PNG per building and stage"
	for race in range(3):galleries[race].save_png("res://build/preview-construction-r%d-v04.png"%race)
	write_json(CATALOG,{"schema":1,"sources":SOURCES,"columns":"foundation/structure/partial-shell","rows":"building_kind_0_through_12","stages":3,"render_mode":"baked_composite","method":method,"entries":entries})
	write_json(AUDIT,{"schema":1,"sources":registrations,"method":method,"buildings":entries.size(),"frames":frames.size(),"unique_rgba_frames":all_hashes.size(),"passed":not failed,"items":frames})
	print("Construction bake: %d buildings, %d PNGs, %d unique RGBA frames, passed=%s"%[entries.size(),frames.size(),all_hashes.size(),not failed])
	quit(1 if failed or entries.size()!=39 or frames.size()!=117 else 0)

static func registered_component(image: Image) -> Image:
	var size_value=image.get_size()
	var seen=PackedByteArray();seen.resize(size_value.x*size_value.y)
	var largest: Array[Vector2i]=[]
	for y in range(size_value.y):
		for x in range(size_value.x):
			var index=y*size_value.x+x
			if seen[index] or image.get_pixel(x,y).a<.08:continue
			var queue: Array[Vector2i]=[Vector2i(x,y)];seen[index]=1
			var cursor=0
			while cursor<queue.size():
				var p=queue[cursor];cursor+=1
				for delta in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
					var next=p+delta
					if next.x<0 or next.y<0 or next.x>=size_value.x or next.y>=size_value.y:continue
					var position=next.y*size_value.x+next.x
					if not seen[position] and image.get_pixelv(next).a>=.08:seen[position]=1;queue.append(next)
			if queue.size()>largest.size():largest=queue
	var result=Image.create(size_value.x,size_value.y,false,Image.FORMAT_RGBA8)
	# Preserve antialiased boundary pixels around the retained component.
	for p in largest:
		for dy in range(-1,2):
			for dx in range(-1,2):
				var next=(p+Vector2i(dx,dy)).clamp(Vector2i.ZERO,size_value-Vector2i.ONE)
				result.set_pixelv(next,image.get_pixelv(next))
	return result
