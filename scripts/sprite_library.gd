class_name ACSpriteLibrary
extends RefCounted
## Authored half-turn sprites, with fixed registration and shared textures.
## Release catalog entries may also be explicitly connected without art review.
var units: Dictionary={}
var buildings: Dictionary={}
var portraits: Dictionary={}
var effects: Dictionary={}
var diagnostics: Array[String]=[]
var _textures: Dictionary={}
var _frames: Dictionary={}

func load_catalogs() -> void:
	units.clear();buildings.clear();portraits.clear();effects.clear();diagnostics.clear()
	_textures.clear();_frames.clear()
	for race in range(3):
		var path="res://data/art_v062_race%d.json"%race
		if not FileAccess.file_exists(path):continue
		var catalog=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not catalog is Dictionary:
			diagnostics.append("Invalid sprite catalog: "+path);continue
		for section in ["units","buildings","portraits"]:
			var target: Dictionary=units if section=="units" else buildings if section=="buildings" else portraits
			for key in catalog.get(section,{}):
				var entry: Dictionary=catalog[section][key]
				if entry.get("status","accepted")!="accepted":continue
				if not entry.has("directions"):entry.directions=17 if section=="units" else 1
				target[str(key)]=entry
	var staged_path="res://data/art_staged16_units.json"
	if FileAccess.file_exists(staged_path):
		var staged=JSON.parse_string(FileAccess.get_file_as_string(staged_path))
		if staged is Dictionary:
			for key in staged.get("units",{}):
				var entry: Dictionary=staged.units[key]
				if entry.get("status","") in ["accepted","applied_unreviewed"]:units[str(key)]=entry
	# Construction-only overrides keep existing idle, attack and turret art.
	var construction_path="res://data/art_building_construction5.json"
	if FileAccess.file_exists(construction_path):
		var construction_catalog=JSON.parse_string(FileAccess.get_file_as_string(construction_path))
		if construction_catalog is Dictionary:
			for key in construction_catalog.get("buildings",{}):
				var addition: Dictionary=construction_catalog.buildings[key]
				if addition.get("status","")!="accepted":continue
				var clip: Dictionary=addition.get("actions",{}).get("construction",{})
				if int(clip.get("rows",0))!=5:continue
				var definition: Dictionary=buildings.get(str(key),{"directions":1,"actions":{}}).duplicate(true)
				definition.actions.construction=clip
				buildings[str(key)]=definition
	for effect_path in ["res://data/art_v062_effects.json","res://data/art_v062_nuclear.json"]:
		if not FileAccess.file_exists(effect_path):continue
		var catalog=JSON.parse_string(FileAccess.get_file_as_string(effect_path))
		if catalog is Dictionary:
			for key in catalog.get("effects",{}):
				var entry: Dictionary=catalog.effects[key]
				if entry.get("status","accepted")=="accepted":effects[str(key)]=entry

func effect_info(key: String) -> Dictionary:
	var entry: Dictionary=effects.get(key,{})
	if entry.is_empty():return {}
	var file=str(entry.get("file",""))
	if not ResourceLoader.exists(file):return {}
	if not _textures.has(file):_textures[file]=load(file)
	var result=entry.duplicate();result.texture=_textures[file]
	return result

func has_unit(race: int,kind: int) -> bool:
	return units.has("%d:%d"%[race,kind])

func has_action(race: int,kind: int,action: String) -> bool:
	var definition: Dictionary=units.get("%d:%d"%[race,kind],{})
	if definition.get("actions",{}).has(action):return true
	if definition.has("body"):definition=definition.body
	return definition.get("actions",{}).has(action)

func _action_name(definition: Dictionary,action: String) -> String:
	var actions: Dictionary=definition.get("actions",{})
	if actions.has(action):return action
	if action=="move":action="walk"
	if action in ["gather","harvest"]:action="work"
	if action in ["construct","repair"]:action="work"
	if action in ["heal","cast","morph"]:action="attack"
	return action if actions.has(action) else "idle"

func action_info(race: int,kind: int,action: String) -> Dictionary:
	var definition: Dictionary=units.get("%d:%d"%[race,kind],{})
	if definition.get("actions",{}).has(action):return definition.actions[action]
	if definition.has("body"):definition=definition.body
	return definition.get("actions",{}).get(_action_name(definition,action),{})

func action_length(race: int,kind: int,action: String) -> float:
	var info=action_info(race,kind,action)
	return float(info.get("rows",info.get("count",1)))/maxf(1,float(info.get("fps",12)))

func _frame(definition: Dictionary,clip: Dictionary,index: int) -> Dictionary:
	var entries: Array=clip.get("frames",[])
	var item: Dictionary=entries[index] if index>=0 and index<entries.size() else {}
	var file=str(item.get("file",clip.get("file",definition.get("file",""))))
	if file.is_empty() or not ResourceLoader.exists(file):return {}
	if not _textures.has(file):_textures[file]=load(file)
	var source: Texture2D=_textures[file]
	if source==null:return {}
	var columns=maxi(1,int(clip.get("columns",1)))
	var rows=maxi(1,int(clip.get("rows",clip.get("count",1))))
	var cell=source.get_size()/Vector2(columns,rows)
	var raw=item.get("region",[posmod(index,columns)*cell.x,(index/columns)*cell.y,cell.x,cell.y])
	var region=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	if not region.has_area() or not Rect2(Vector2.ZERO,source.get_size()).encloses(region):return {}
	var anchor=ACData.point(item.get("anchor",clip.get("anchor",definition.get("anchor",[region.size.x*.5,region.size.y*.8]))))
	var scale_hint=float(item.get("scale_hint",clip.get("scale_hint",definition.get("scale_hint",maxf(region.size.x,region.size.y)))))
	var cache_key=file+"|"+str(region)+"|"+str(anchor)+"|"+str(scale_hint)
	if not _frames.has(cache_key):
		var atlas=AtlasTexture.new();atlas.atlas=source;atlas.region=region;atlas.filter_clip=true
		var frame={"texture":atlas,"anchor":anchor,"scale_hint":scale_hint,"cell_size":region.size,"flip":false,"rotation":0.0,"v062":true,"embedded_pilot":true}
		if bool(definition.get("staged16",false)):frame.staged16=true
		if item.has("bounds"):
			var b=item.bounds
			frame.sprite_bounds=Rect2(float(b[0]),float(b[1]),float(b[2]),float(b[3]))
		if item.has("muzzle"):frame.muzzle=ACData.point(item.muzzle)
		if item.has("muzzles"):
			frame.muzzles=[]
			for point in item.muzzles:frame.muzzles.append(ACData.point(point))
		if item.has("mount"):frame.mount=ACData.point(item.mount)
		if item.has("rig_axis"):frame.rig_axis=ACData.point(item.rig_axis)
		_frames[cache_key]=frame
	return _frames[cache_key]

func sample(definition: Dictionary,action: String,direction: Vector2,clock: float,phase: int=-1) -> Dictionary:
	var name=_action_name(definition,action)
	var clip: Dictionary=definition.get("actions",{}).get(name,{})
	if clip.is_empty():return {}
	var columns=maxi(1,int(clip.get("directions",definition.get("directions",clip.get("columns",1)))))
	var rows=maxi(1,int(clip.get("rows",clip.get("count",1))))
	var fps=maxf(1,float(clip.get("fps",12)))
	var loop=bool(clip.get("loop",name not in ["attack","death","construction","deploy"]))
	var tick=maxi(0,int(floor(clock*fps))) if phase<0 else phase
	var row=posmod(tick,rows) if loop else mini(tick,rows-1)
	var facing=ACData.sprite_direction(direction,(columns-1)*2) if columns>1 else {"column":0,"flip":false}
	if bool(definition.get("full_circle",false)) and columns>1:
		var angle=fposmod(Vector2.UP.angle_to(direction),TAU) if direction.length_squared()>.0001 else 0.0
		facing={"column":posmod(roundi(angle/TAU*columns),columns),"flip":false}
	# Missing authored attack headings stay visible without inventing animation.
	if name in ["attack","work","heal"] and int(facing.column) in clip.get("unavailable_headings",[]):
		return sample(definition,"idle",direction,0.0)
	var frame=_frame(definition,clip,row*columns+int(facing.column))
	if frame.is_empty():return {}
	frame=frame.duplicate()
	frame.flip=bool(facing.flip);frame.action=name;frame.frame=row;frame.fps=fps
	return frame

func unit(race: int,kind: int,direction: Vector2,action: String,clock: float) -> Dictionary:
	var definition: Dictionary=units.get("%d:%d"%[race,kind],{})
	if definition.get("actions",{}).has(action):return sample(definition,action,direction,clock)
	if definition.has("body"):definition=definition.body
	return sample(definition,action,direction,clock)

func vehicle(race: int,kind: int,body_direction: Vector2,turret_direction: Vector2,action: String,clock: float,deploy: float) -> Dictionary:
	var definition: Dictionary=units.get("%d:%d"%[race,kind],{})
	if not definition.has("body") or not definition.has("turret"):return {}
	var body_definition: Dictionary=definition.body
	var body_action="deploy" if deploy>0 and body_definition.get("actions",{}).has("deploy") else action
	var steps=int(body_definition.get("actions",{}).get("deploy",{}).get("rows",1))
	var body=sample(body_definition,body_action,body_direction,clock,roundi(deploy*(steps-1)) if body_action=="deploy" else -1)
	var turret=sample(definition.turret,action,turret_direction,clock)
	if body.is_empty() or turret.is_empty():return {}
	var mount: Vector2=body.get("mount",ACData.point(definition.get("mount",[0,-16])))
	if body.flip:mount.x=-mount.x
	var muzzle: Vector2=turret.get("muzzle",Vector2.ZERO)
	if turret.flip:muzzle.x=-muzzle.x
	return {"chassis":body,"turret":turret,"mount":mount,"muzzle":muzzle,"muzzles":turret.get("muzzles",[]),"turret_scale":float(definition.get("turret_scale",1)),"embedded_pilot":true,"pilot_mount":Vector2.ZERO}

func building(race: int,kind: int,progress: float,active: bool,direction: Vector2,clock: float,attack_clock: float=-1) -> Dictionary:
	var definition: Dictionary=buildings.get("%d:%d"%[race,kind],{})
	if definition.is_empty():return {}
	var action="construction" if progress<1 else "active" if active else "idle"
	var phase=clampi(int(progress*5),0,4) if progress<1 else -1
	if progress>=1 and attack_clock>=0 and definition.get("actions",{}).has("attack"):
		action="attack";clock=attack_clock
	return sample(definition,action,direction,clock,phase)

func building_turret(race: int,kind: int,direction: Vector2,clock: float,attack_clock: float=-1) -> Dictionary:
	var definition: Dictionary=buildings.get("%d:%d"%[race,kind],{})
	if not definition.has("turret"):return {}
	return sample(definition.turret,"attack" if attack_clock>=0 else "idle",direction,attack_clock if attack_clock>=0 else clock)

func portrait(race: int,kind: int,clock: float) -> Texture2D:
	var definition: Dictionary=portraits.get("%d:%d"%[race,kind],{})
	if definition.is_empty():return null
	var count=definition.get("frames",[]).size()
	if count==0:count=int(definition.get("columns",1))*int(definition.get("rows",1))
	var index=posmod(int(clock*float(definition.get("fps",8))),maxi(1,count))
	var durations: Array=definition.get("durations",[])
	if durations.size()==count:
		var total=0.0
		for duration in durations:total+=maxf(.01,float(duration))
		var phase=fposmod(clock,total);index=0
		while index<count-1 and phase>=maxf(.01,float(durations[index])):
			phase-=maxf(.01,float(durations[index]));index+=1
	return _frame(definition,definition,index).get("texture")
