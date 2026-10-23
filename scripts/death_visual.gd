class_name ACDeathVisual
extends RefCounted
## The collapse, ground stain and airborne burst are independent visual layers.
var catalog: Dictionary={}
var textures: Dictionary={}
var frames: Dictionary={}

static func profile(race: int,kind: int,building: bool=false) -> Dictionary:
	var definition=ACData.building(race,kind) if building else ACData.unit(race,kind)
	var air=not building and bool(definition.get("air",false))
	var mechanical=building or definition.get("material","")=="mechanical" or (race==0 and kind==0)
	var key="blue_evaporation" if race==2 else "citrus_airburst" if race==1 and air else "juice_ground" if race==1 else "mechanical_airburst" if mechanical or air else "blood_ground"
	return {"key":key,"airborne":air,"ground":key in ["blood_ground","juice_ground"],"duration":8.0 if key in ["blood_ground","juice_ground"] else 1.15,"mechanical":mechanical}

static func timeline(key: String,age: float,duration: float) -> Dictionary:
	age=maxf(0,age);duration=maxf(.3,duration)
	if key in ["blood_ground","juice_ground"]:
		# Upper row: a quick splash. Lower row: a slowly fading settled stain.
		var frame=minf(3.999,age/.25*4) if age<.25 else 4+clampf((age-.25)/(duration-.25),0,1)*3
		return {"frame":frame,"opacity":1-smoothstep(.5,duration,age)}
	return {"frame":clampf(age/duration,0,1)*7,"opacity":1-smoothstep(duration*.72,duration,age)}

func load_catalog() -> void:
	catalog.clear();textures.clear();frames.clear()
	var path="res://data/art_deathfx_20261023.json"
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:catalog=data.get("effects",{})

func sample(key: String,age: float,duration: float) -> Dictionary:
	if catalog.is_empty():load_catalog()
	var entry: Dictionary=catalog.get(key,{})
	if entry.is_empty():return {}
	var file=str(entry.file)
	if not textures.has(file):textures[file]=load(file)
	if textures[file]==null:return {}
	var time=timeline(key,age,duration)
	var phase=clampi(int(time.frame),0,int(entry.count)-1)
	var frame_key=key+":"+str(phase)
	if not frames.has(frame_key):
		var atlas=AtlasTexture.new();atlas.atlas=textures[file];atlas.filter_clip=true
		atlas.region=Rect2(ACData.point(entry.frames[phase].region.slice(0,2)),ACData.point(entry.frames[phase].region.slice(2,4)))
		frames[frame_key]={"texture":atlas,"anchor":ACData.point(entry.anchor),"scale_hint":float(entry.scale_hint),"sprite_bounds":Rect2(ACData.point(entry.frames[phase].bounds.slice(0,2)),ACData.point(entry.frames[phase].bounds.slice(2,4))),"action":"death_effect","frame":phase}
	var result: Dictionary=frames[frame_key].duplicate()
	result.opacity=time.opacity;result.effect_key=key
	return result
