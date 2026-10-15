class_name ACConstructionVisual
extends RefCounted
## Complete generated construction phases share the final foundation anchor.
## The final phase crossfades into the finished building without slicing it.

const CATALOG := "res://data/construction_regions_v04.json"
const REVEAL := [0.08,0.20,0.68]
var frames: Dictionary={}
var diagnostics: Array=[]
var catalog: Dictionary={}
var _textures: Dictionary={}
var _images: Dictionary={}
var loaded := false

static func stage(progress: float) -> int:
	if not is_finite(progress):return 0
	if progress>=1.0:return -1
	return clampi(int(floor(maxf(0.0,progress)*3.0)),0,2)

static func stages_plan(texture_size: Vector2, rect: Rect2, progress: float) -> Dictionary:
	var index := stage(progress)
	var reveal := 1.0 if index<0 else float(REVEAL[index])
	var source := Rect2(Vector2(0,texture_size.y*(1.0-reveal)),Vector2(texture_size.x,texture_size.y*reveal))
	var destination := Rect2(rect.position+Vector2(0,rect.size.y*(1.0-reveal)),Vector2(rect.size.x,rect.size.y*reveal))
	return {"stage":index,"reveal":reveal,"source_rect":source,"final_rect":destination,"foundation":Vector2(rect.get_center().x,rect.end.y),"bounds":rect}

func load_all(path: String=CATALOG) -> void:
	frames.clear()
	diagnostics.clear()
	_textures.clear()
	_images.clear()
	catalog.clear()
	loaded=true
	if not FileAccess.file_exists(path):
		diagnostics.append("Missing construction catalog: "+path)
		return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		diagnostics.append("Invalid construction catalog: "+path)
		return
	catalog=parsed
	for race in range(3):
		for kind in range(13):
			var key := "%d:%d"%[race,kind]
			var definitions=catalog.get("entries",{}).get(key,[])
			if definitions is Dictionary:definitions=definitions.get("stages",[])
			if not definitions is Array or definitions.size()!=3:
				diagnostics.append("Missing three construction stages for "+key)
				continue
			var stages: Array=[]
			for index in range(3):
				var frame := _frame(definitions[index],key,index)
				if not frame.is_empty():stages.append(frame)
			if stages.size()==3:frames[key]=stages
	_images.clear()

func available(race: int, kind: int) -> bool:
	return frames.has("%d:%d"%[race,kind]) and frames["%d:%d"%[race,kind]].size()==3

func _frame(definition, key: String, index: int) -> Dictionary:
	if not definition is Dictionary:
		diagnostics.append("Invalid construction frame %s/%d"%[key,index])
		return {}
	var file := str(definition.get("file",""))
	if file.is_empty() or not ResourceLoader.exists(file):
		diagnostics.append("Missing generated scaffold %s/%d: %s"%[key,index,file])
		return {}
	if not _textures.has(file):
		var texture=ResourceLoader.load(file)
		if not texture is Texture2D:return {}
		_textures[file]=texture
		_images[file]=texture.get_image()
	var image: Image=_images[file]
	var source: Texture2D=_textures[file]
	var raw=definition.get("region",[0,0,image.get_width(),image.get_height()])
	if not raw is Array or raw.size()!=4:return {}
	var cell := Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
	if not cell.has_area() or cell!=cell.intersection(Rect2i(Vector2i.ZERO,image.get_size())):
		diagnostics.append("Out-of-bounds scaffold region %s/%d"%[key,index])
		return {}
	var used := image.get_region(cell).get_used_rect()
	if used.size.x<2 or used.size.y<2:
		diagnostics.append("Empty scaffold frame %s/%d"%[key,index])
		return {}
	var atlas := AtlasTexture.new()
	atlas.atlas=source
	var composite := bool(definition.get("composite",false))
	atlas.region=Rect2(cell) if composite else Rect2(Vector2(cell.position+used.position),Vector2(used.size))
	atlas.filter_clip=true
	# Without an explicit art pivot, transparent sheet gutters cannot lift the
	# scaffold off the foundation. Use the trimmed body's bottom center.
	var normalized=definition.get("anchor",[])
	var pivot := Vector2(used.size.x*.5,used.size.y)
	if normalized is Array and normalized.size()==2:
		pivot=Vector2(float(normalized[0])*cell.size.x,float(normalized[1])*cell.size.y)-Vector2(used.position)
	var width_factor := clampf(float(definition.get("width_factor",1.04)),.25,1.4)
	return {"texture":atlas,"pivot":pivot,"size":Vector2(cell.size if composite else used.size),"width_factor":width_factor,"file":file,"region":cell,"used":used,"stage":index,"race_kind":key,"composite":composite}

func scaffold_rect(frame: Dictionary, final_rect: Rect2) -> Rect2:
	var size_value: Vector2=frame.size
	var factor := final_rect.size.x*float(frame.get("width_factor",1.04))/maxf(1.0,size_value.x)
	factor=minf(factor,final_rect.size.y*1.12/maxf(1.0,size_value.y))
	var foundation := Vector2(final_rect.get_center().x,final_rect.end.y)
	return Rect2(foundation-Vector2(frame.pivot)*factor,size_value*factor)

func draw(canvas: CanvasItem, race: int, kind: int, final_texture: Texture2D, rect: Rect2, progress: float, _clock: float=0.0) -> void:
	if final_texture==null or not rect.has_area():return
	if not loaded:load_all()
	var plan := stages_plan(Vector2(final_texture.get_width(),final_texture.get_height()),rect,progress)
	if int(plan.stage)<0:
		canvas.draw_texture_rect(final_texture,rect,false,Color.WHITE)
		return
	if available(race,kind):
		var phase: Dictionary=frames["%d:%d"%[race,kind]][int(plan.stage)]
		var phase_rect=rect if phase.get("composite",false) else scaffold_rect(phase,rect)
		var blend=smoothstep(.86,1.0,progress)
		canvas.draw_texture_rect(phase.texture,phase_rect,false,Color(1,1,1,1-blend))
		if blend>0:canvas.draw_texture_rect(final_texture,rect,false,Color(1,1,1,blend))
		return
	# Missing art remains a complete ghost; never show a decapitated building.
	canvas.draw_texture_rect(final_texture,rect,false,Color(.8,.86,.9,.3+.7*progress))

func shadow_layers(race: int, kind: int, final_texture: Texture2D, rect: Rect2, progress: float) -> Array:
	if progress>=1 or not available(race,kind):return [{"texture":final_texture,"rect":rect,"opacity":1.0}]
	var phase: Dictionary=frames["%d:%d"%[race,kind]][stage(progress)]
	var phase_rect=rect if phase.get("composite",false) else scaffold_rect(phase,rect)
	var blend=smoothstep(.86,1.0,progress)
	var layers: Array=[{"texture":phase.texture,"rect":phase_rect,"opacity":1.0-blend}]
	if blend>0:layers.append({"texture":final_texture,"rect":rect,"opacity":blend})
	return layers
