class_name ACAssets
extends RefCounted

# Unit anchoring remains relative to the original cell when alpha gets trimmed.
var unit_frames: Dictionary={}
var motion_frames: Dictionary={}
var propulsion_frames: Array=[]
var building_frames: Dictionary={}
var building_idle_frames: Dictionary={}
var building_idle_pixels: Dictionary={}
var cursor_frames: Dictionary={}
var brood_frames: Array=[]
var citrus_fx: Array=[]
var tera_plumes: Array=[]
var heal_frames: Array=[]
var vehicle_frames: Dictionary={}
var pilot_frames: Array=[]
var rally_frames: Array=[]
var air_pilot_mounts: Dictionary={}
var repaired_air: Dictionary={}
var directional_air: Dictionary={}
var drone_parts: Dictionary={}
var direction_repairs: Dictionary={}
var graphics_repairs: Dictionary={}
var repaired_fire: Dictionary={}
var ground_textures: Array=[]
var menu: Texture2D
var resource_frames: Array=[]
var sprite_regions: Dictionary={}
var motion_regions: Dictionary={}
var asset_regions: Dictionary={}
var building_revision: Dictionary={}
var _atlas_sources: Array=[]
var v060_units: Dictionary={}
var frame_cleanup: Dictionary={}
var v060_effects: Dictionary={}
var siege_layers: Dictionary={}
var siege_support_frames: Dictionary={}
var sprites=preload("res://scripts/sprite_library.gd").new()

func load_all() -> void:
	sprites.load_catalogs()
	direction_repairs.clear()
	var direction_path="res://data/art_direction_repairs_20261023.json"
	if FileAccess.file_exists(direction_path):
		var catalog=JSON.parse_string(FileAccess.get_file_as_string(direction_path))
		if catalog is Dictionary:
			for key in catalog.get("units",{}):
				var entry: Dictionary=catalog.units[key]
				if entry.get("status","")=="accepted_direction_repair":direction_repairs[str(key)]=entry
	_load_v060()
	unit_frames.clear()
	motion_frames.clear()
	propulsion_frames.clear()
	if ResourceLoader.exists("res://assets/movement_fx_v058.png"):
		var source: Texture2D=load("res://assets/movement_fx_v058.png")
		var cell=source.get_size()/Vector2(8,3)
		for race in range(3):
			var phases: Array=[]
			for phase in range(8):
				var frame=AtlasTexture.new();frame.atlas=source
				frame.region=Rect2(Vector2(phase,race)*cell,cell)
				phases.append(frame)
			propulsion_frames.append(phases)
	building_frames.clear()
	building_idle_frames.clear()
	building_idle_pixels.clear()
	cursor_frames.clear()
	brood_frames.clear()
	citrus_fx.clear()
	tera_plumes.clear()
	heal_frames.clear()
	vehicle_frames.clear()
	pilot_frames.clear()
	rally_frames.clear()
	air_pilot_mounts.clear()
	repaired_air.clear()
	directional_air.clear()
	drone_parts.clear()
	graphics_repairs.clear()
	repaired_fire.clear()
	ground_textures.clear()
	resource_frames.clear()
	_atlas_sources.clear()
	if FileAccess.file_exists("res://data/sprite_regions.json"):
		sprite_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/sprite_regions.json"))
	if FileAccess.file_exists("res://data/frame_cleanup_v061.json"):
		frame_cleanup=JSON.parse_string(FileAccess.get_file_as_string("res://data/frame_cleanup_v061.json")).repairs
	if FileAccess.file_exists("res://data/motion_regions.json"):
		motion_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_regions.json"))
	if FileAccess.file_exists("res://data/motion_cache_v04.json"):
		var cache=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_cache_v04.json"))
		var complete=cache.get("units",{}).size()==39
		for info in cache.get("units",{}).values():
			if not ResourceLoader.exists(String(info.file)):complete=false
		if complete:
			motion_regions.units.merge(cache.units,true)
			motion_regions.actions.merge(cache.get("actions",{}),true)
			motion_regions.action_fps=cache.get("action_fps",{})
	if FileAccess.file_exists("res://data/graphics_repairs_v05.json"):
		graphics_repairs=JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_repairs_v05.json"))
		motion_regions.units.merge(graphics_repairs.get("motions",{}),true)
	if FileAccess.file_exists("res://data/motion_expansion_v060.json"):
		var expanded=JSON.parse_string(FileAccess.get_file_as_string("res://data/motion_expansion_v060.json"))
		motion_regions.units.merge(expanded.units,true)
	if FileAccess.file_exists("res://data/asset_regions.json"):
		asset_regions=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_regions.json"))
	if FileAccess.file_exists("res://data/building_regions_v3.json"):
		building_revision=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_regions_v3.json"))
		asset_regions.get_or_add("buildings",{}).merge(building_revision.get("regions",{}),true)
		asset_regions.get_or_add("individual_buildings",{}).merge(building_revision.get("individual_buildings",{}),true)
	for race in range(3):
		_load_motions(race)
		_load_units(race,false)
		_load_units(race,true)
		var file="res://assets/buildings_%d.png"%race
		if race==1 and ResourceLoader.exists("res://assets/buildings_1_v2.png"):
			file="res://assets/buildings_1_v2.png"
		if building_revision.get("sheets",{}).has(str(race)):
			file=String(building_revision.sheets[str(race)])
		if ResourceLoader.exists(file):
			var image=load(file).get_image()
			for kind in range(13):
				var approved=building_revision.get("overrides",{}).get("%d:%d"%[race,kind],{})
				if not approved.is_empty() and ResourceLoader.exists(String(approved.file)):
					var replacement=load(String(approved.file)).get_image()
					var replacement_rect=_region_rect(approved.region,replacement.get_size()) if approved.has("region") else Rect2i(Vector2i.ZERO,replacement.get_size())
					building_frames["%d:%d"%[race,kind]]=_trim(replacement,replacement_rect)
					continue
				var individual=String(asset_regions.get("individual_buildings",{}).get("%d:%d"%[race,kind],""))
				if individual!="" and ResourceLoader.exists(individual):
					var standalone=load(individual).get_image()
					building_frames["%d:%d"%[race,kind]]=_trim(standalone,Rect2i(Vector2i.ZERO,standalone.get_size()))
					continue
				var cell=Rect2i(int(kind%4)*image.get_width()/4,int(kind/4)*image.get_height()/4,image.get_width()/4,image.get_height()/4)
				var key="%d:%d"%[race,kind]
				if asset_regions.get("buildings",{}).has(key):
					cell=_region_rect(asset_regions.buildings[key],image.get_size())
				building_frames["%d:%d"%[race,kind]]=_trim(image,cell,building_revision.get("excluded_fragments",{}).get(key,[]))
	# Building bodies remain static; production lights are a separate small part.
	if ResourceLoader.exists("res://assets/terrain.png"):
		var image=load("res://assets/terrain.png").get_image()
		for i in range(3):
			var piece=image.get_region(Rect2i(i*image.get_width()/3,0,image.get_width()/3,image.get_height()))
			piece.resize(256,256,Image.INTERPOLATE_LANCZOS)
			ground_textures.append(ImageTexture.create_from_image(piece))
	if ResourceLoader.exists("res://assets/menu.png"):
		menu=load("res://assets/menu.png")
	var resource_file="res://assets/resources_v2.png" if ResourceLoader.exists("res://assets/resources_v2.png") else "res://assets/resources.png"
	if ResourceLoader.exists(resource_file):
		var image=load(resource_file).get_image()
		for i in range(2):
			resource_frames.append(_trim(image,Rect2i(i*image.get_width()/2,0,image.get_width()/2,image.get_height())))
	_load_cursors()
	_load_auxiliary_sprites()
	for key in graphics_repairs.get("air",{}):
		var info=graphics_repairs.air[key]
		if ResourceLoader.exists(String(info.file)):
			var texture: Texture2D=load(String(info.file))
			repaired_air[key]={"texture":texture,"anchor":ACData.point(info.anchor),"scale_hint":float(info.scale_hint),"embedded_pilot":bool(info.embedded_pilot),"overhead":true,"cell_size":texture.get_size()}
	_load_graphics_v052()
	_load_citrus_bat()
	var fire: Dictionary=graphics_repairs.get("fire",{})
	if not fire.is_empty() and ResourceLoader.exists(String(fire.file)):
		var source: Texture2D=load(String(fire.file))
		var image=source.get_image()
		for row in range(int(fire.rows)):
			var sequence: Array=[]
			for col in range(int(fire.columns)):
				var begin=Vector2i(int(col*image.get_width()/5.0),int(row*image.get_height()/4.0))
				var end=Vector2i(int((col+1)*image.get_width()/5.0),int((row+1)*image.get_height()/4.0))
				var cell=Rect2i(begin,end-begin)
				var frame=_anchored_region(source,image,cell,Vector2(.5,.96),.84,cell,Vector2.INF,250)
				var used=image.get_region(cell).get_used_rect()
				frame.muzzle=ACData.point(fire.muzzles[row][col])*Vector2(cell.size)-Vector2(used.position)-frame.anchor
				frame=_repair_frame(frame,"fire:0:%d:%d"%[int(fire.kinds[row]),col])
				sequence.append(frame)
			repaired_fire["0:%d"%int(fire.kinds[row])]=sequence

func _load_citrus_bat() -> void:
	var path="res://assets/citrus_bat_leaf_v059.png"
	var expanded=ResourceLoader.exists("res://assets/citrus_bat_motion_v060.png")
	if expanded:path="res://assets/citrus_bat_motion_v060.png"
	if not ResourceLoader.exists(path):return
	var source: Texture2D=load(path)
	var phases=8 if expanded else 2
	var cell=source.get_size()/Vector2(5,phases)
	var frames=[]
	for row in range(phases):
		for col in range(5):
			var texture=AtlasTexture.new();texture.atlas=source
			texture.region=Rect2(Vector2(col,row)*cell,cell)
			# Register head/body pivots between raised and lowered wings.
			var shift=[Vector2(-1,-95.5),Vector2(35,-86.5),Vector2(-8,-109.5),Vector2(4,-131.5),Vector2(0,-115.5)][col] if row==1 and not expanded else Vector2.ZERO
			frames.append({"texture":texture,"anchor":cell*.5+shift,"scale_hint":224 if expanded else cell.x*.84,"embedded_pilot":true,"cell_size":cell})
	directional_air["1:10"]={"frames":frames,"columns":5,"phases":phases,"fps":12 if expanded else 5,"direction_flips":[false,false,false,false,false]}

func _load_graphics_v052() -> void:
	if not FileAccess.file_exists("res://data/graphics_v052.json"):return
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_v052.json"))
	for key in catalog.air:
		var info: Dictionary=catalog.air[key]
		var frames: Array=[]
		for path in info.frames:
			frames.append({"texture":load(path),"anchor":ACData.point(info.anchor),"scale_hint":info.scale_hint,"embedded_pilot":info.embedded_pilot,"cell_size":Vector2(320,320)})
		directional_air[key]={"frames":frames,"columns":int(info.columns),"phases":int(info.phases),"direction_flips":info.get("direction_flips",[false,false,false,false,false])}
		repaired_air.erase(key)
	var vehicle: Dictionary=catalog.vehicle
	var pairs: Array=[]
	for info in vehicle.frames:
		var pair={"mount":ACData.point(info.mount),"muzzle":ACData.point(info.muzzle),"pilot_mount":Vector2.ZERO,"turret_scale":float(vehicle.turret_scale),"embedded_pilot":true}
		for part in ["chassis","turret"]:pair[part]={"texture":load(info[part]),"anchor":ACData.point(vehicle.anchor),"scale_hint":float(vehicle.scale_hint),"cell_size":Vector2(320,320)}
		pairs.append(pair)
	vehicle_frames[vehicle.key]=pairs
	for part in ["bodies","rotors"]:
		var frames: Array=[]
		for path in catalog.drone[part]:frames.append({"texture":load(path),"anchor":Vector2(160,160),"scale_hint":210.0,"cell_size":Vector2(320,320),"embedded_pilot":true})
		drone_parts[part]=frames

func drone(direction: Vector2,clock: float) -> Dictionary:
	if drone_parts.is_empty():return {}
	var index=ACData.sprite_direction(direction,8)
	var hull=_direction_repair("0:8",direction)
	if hull.is_empty():
		hull=drone_parts.bodies[int(index.column)].duplicate()
		hull.flip=bool(index.flip)
	hull.separate_rotors=true
	var rotor: Dictionary=drone_parts.rotors[posmod(int(clock*24),5)].duplicate()
	if direction_repairs.get("0:8",{}).has("rotor"):
		rotor=sprites.sample(direction_repairs["0:8"].rotor,"idle",Vector2.DOWN,clock)
		rotor.rotor_component=true
	return {"hull":hull,"rotor":rotor}

func drone_mounts(hull: Dictionary,direction: Vector2,extent: float) -> Array:
	var axis: Vector2=hull.get("rig_axis",direction)
	var forward=Vector2(axis.x,axis.y/.55).normalized()
	var side=Vector2(-forward.y,forward.x)
	var mounts: Array=direction_repairs.get("0:8",{}).get("rotor_mounts",[[-.46,.02],[.46,.02],[0,-.55]])
	var offsets: Array=[]
	for raw in mounts:
		var mount=ACData.point(raw)
		var offset=(side*mount.x+forward*mount.y)*extent
		offset.y*=.55
		offsets.append(offset)
	offsets.sort_custom(func(a,b):return a.y<b.y)
	return offsets

func _direction_repair(key: String,direction: Vector2) -> Dictionary:
	if not direction_repairs.has(key):return {}
	var frame=sprites.sample(direction_repairs[key],"idle",direction,0)
	if not frame.is_empty():
		frame.direction_repaired=true
		frame.separate_rotors=bool(direction_repairs[key].get("separate_rotors",false))
	return frame

func death_info(race: int,kind: int) -> Dictionary:
	var key="%d:%d"%[race,kind]
	if sprites.units.get(key,{}).get("staged16",false) and sprites.has_action(race,kind,"death"):
		return sprites.action_info(race,kind,"death")
	var clip: Dictionary=direction_repairs.get(key,{}).get("actions",{}).get("death",{})
	if not clip.is_empty():return clip
	return sprites.action_info(race,kind,"death") if sprites.has_action(race,kind,"death") else {}

func death_body(race: int,kind: int,direction: Vector2,clock: float) -> Dictionary:
	var key="%d:%d"%[race,kind]
	if sprites.units.get(key,{}).get("staged16",false) and sprites.has_action(race,kind,"death"):
		return sprites.unit(race,kind,direction,"death",clock)
	if direction_repairs.get(key,{}).get("actions",{}).has("death"):
		return sprites.sample(direction_repairs[key],"death",direction,clock)
	return sprites.unit(race,kind,direction,"death",clock) if sprites.has_action(race,kind,"death") else {}

func _load_auxiliary_sprites() -> void:
	var path="res://data/aux_sprites_v04.json"
	if not FileAccess.file_exists(path):return
	var catalog=JSON.parse_string(FileAccess.get_file_as_string(path))
	air_pilot_mounts=catalog.get("air_pilots",{})
	for type in ["brood","citrus_projectiles","tera_plume","medic_heal","pilots","rally"]:
		var info: Dictionary=catalog.get(type,{})
		if info.is_empty() or not ResourceLoader.exists(String(info.file)):continue
		var source: Texture2D=load(String(info.file))
		var image=source.get_image()
		_atlas_sources.append(source)
		var columns=int(info.columns)
		var rows=int(info.rows)
		for row in range(rows):
			var sequence: Array=[]
			for col in range(columns):
				var begin=Vector2i(int(float(col)*image.get_width()/columns),int(float(row)*image.get_height()/rows))
				var end=Vector2i(int(float(col+1)*image.get_width()/columns),int(float(row+1)*image.get_height()/rows))
				var cell=Rect2i(begin,end-begin)
				if type in ["citrus_projectiles","rally"]:
					if type=="rally":rally_frames.append(_trim(image,cell))
					else:citrus_fx.append(_trim(image,cell))
				else:
					var root=ACData.point(info.air_root if type=="pilots" and row==1 else info.root)
					var frame=_anchored_region(source,image,cell,Vector2(.5,.96),.84,cell,root,float(info.scale_hint))
					if type=="tera_plume":tera_plumes.append(frame)
					else:sequence.append(frame)
			if type=="brood":brood_frames.append(sequence)
			elif type=="medic_heal":
				if bool(info.get("reverse_columns",false)):sequence.reverse()
				heal_frames.append(sequence)
			elif type=="pilots":pilot_frames.append(sequence)
	if not brood_frames.is_empty():unit_frames["1:13"]=brood_frames[0]
	for key in catalog.get("vehicles",{}):
		var info: Dictionary=catalog.vehicles[key]
		if not ResourceLoader.exists(String(info.file)):continue
		var source: Texture2D=load(String(info.file))
		var image=source.get_image()
		_atlas_sources.append(source)
		var frames: Array=[]
		var source_column=0
		for definition in info.frames:
			var pair={"mount":ACData.point(definition.mount),"pilot_mount":ACData.point(definition.pilot_mount),"turret_scale":float(info.get("turret_scale",1)),"embedded_pilot":bool(info.get("embedded_pilot",false))}
			pair.muzzle=ACData.point(definition.get("muzzle",[0,-80]))
			for part in ["chassis","turret"]:
				var raw: Array=definition[part+"_region"]
				var cell=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
				pair[part]=_anchored_region(source,image,cell,Vector2(.5,.88),.84,cell,ACData.point(definition[part+"_root"]),float(info.scale_hint))
				if definition.has(part+"_excluded_fragments"):
					# Clean only this extracted cell. A fragment may be the valid
					# barrel of the adjacent direction, so never erase the atlas.
					var local_image=image.get_region(cell)
					for fragment in definition[part+"_excluded_fragments"]:
						var exclusion=Rect2i(fragment[0],fragment[1],fragment[2],fragment[3]).intersection(cell)
						if exclusion.has_area():local_image.fill_rect(Rect2i(exclusion.position-cell.position,exclusion.size),Color.TRANSPARENT)
					var local_source=ImageTexture.create_from_image(local_image)
					var local_cell=Rect2i(Vector2i.ZERO,cell.size)
					pair[part]=_anchored_region(local_source,local_image,local_cell,Vector2(.5,.88),.84,local_cell,ACData.point(definition[part+"_root"]),float(info.scale_hint))
				pair[part].source_mirror=bool(info.get("mirror_source",false)) or (part=="turret" and source_column in info.get("turret_mirror_columns",[]))
				pair[part]=_repair_frame(pair[part],"vehicle:%s:%d:%s"%[key,source_column,part])
			frames.append(pair)
			source_column+=1
		if bool(info.get("reverse_columns",false)):frames.reverse()
		vehicle_frames[String(key)]=frames

func vehicle(race: int,kind: int,body_direction: Vector2,turret_direction: Vector2,deploy_progress: float=0.0,action: String="idle",clock: float=0.0) -> Dictionary:
	if sprites.has_unit(race,kind):
		var result=sprites.vehicle(race,kind,body_direction,turret_direction,action,clock,deploy_progress)
		if race==0 and kind==5 and deploy_progress>0 and not siege_layers.is_empty() and not result.is_empty() and not sprites.units["0:5"].body.get("actions",{}).has("deploy"):
			# Use the complete authored deployment, including the hull over its
			# supports. Cutting a rectangular hull hole out of a second sprite
			# left exposed straight cuts where its legs met the newer chassis.
			var facing=ACData.sprite_direction(body_direction,8)
			var stage=clampi(roundi(deploy_progress*6),0,6)
			var entry: Dictionary=siege_layers.chassis[stage*5+int(facing.column)]
			var chassis: Dictionary=entry.frame.duplicate()
			var baseline: Dictionary=siege_layers.chassis[int(facing.column)]
			chassis.scale_hint=float(result.chassis.scale_hint)*float(baseline.draw[2])/maxf(1,result.chassis.get("sprite_bounds",Rect2(Vector2.ZERO,result.chassis.cell_size)).size.x)
			chassis.flip=bool(facing.flip);chassis.staged16=true;chassis.complete_deployment=true;chassis.action="deploy";chassis.frame=stage;chassis.stage=stage
			# The old atlas anchor included ground-shadow padding below the
			# support pads. Register the contact plane, keeping the selection
			# circle fixed. Ease this fixed correction during unfolding.
			var contact_offset=Vector2(0,32*smoothstep(0,1,deploy_progress))
			chassis.anchor-=contact_offset
			chassis.contact_offset=contact_offset
			result.chassis=chassis;result.mount=ACData.point(entry.mount)*Vector2(-1 if facing.flip else 1,1)+contact_offset;result.deployment_stage=stage
		return result
	var key="%d:%d"%[race,kind]
	if key=="0:5" and not siege_layers.is_empty():
		var body_index=ACData.sprite_direction(body_direction,8);var turret_index=ACData.sprite_direction(turret_direction,8)
		var stage=clampi(roundi(deploy_progress*6),0,6)
		var body: Dictionary=siege_layers.chassis[stage*5+int(body_index.column)]
		var weapon: Dictionary=siege_layers.turrets[int(turret_index.column)]
		var chassis: Dictionary=body.frame.duplicate();chassis.flip=bool(body_index.flip)
		var turret: Dictionary=weapon.frame.duplicate();turret.flip=bool(turret_index.flip)
		return {"chassis":chassis,"turret":turret,"mount":ACData.point(body.mount)*Vector2(-1 if chassis.flip else 1,1),"pilot_mount":Vector2.ZERO,"muzzle":ACData.point(weapon.muzzle)*Vector2(-1 if turret.flip else 1,1),"turret_scale":float(siege_layers.turret_scale),"embedded_pilot":true,"deployment_stage":stage}
	if key=="0:12" and v060_units.has(key):return {}
	if not vehicle_frames.has(key):return {}
	var directions=(vehicle_frames[key].size()-1)*2
	var body_index=ACData.sprite_direction(body_direction,directions)
	var turret_index=ACData.sprite_direction(turret_direction,directions)
	var body: Dictionary=vehicle_frames[key][int(body_index.column)]
	var weapon: Dictionary=vehicle_frames[key][int(turret_index.column)]
	var chassis: Dictionary=body.chassis.duplicate()
	chassis.flip=bool(body_index.flip)!=bool(chassis.get("source_mirror",false))
	var turret: Dictionary=weapon.turret.duplicate()
	turret.flip=bool(turret_index.flip)!=bool(turret.get("source_mirror",false))
	return {"chassis":chassis,"turret":turret,"mount":body.mount*Vector2(-1 if chassis.flip else 1,1),"pilot_mount":weapon.pilot_mount*Vector2(-1 if turret.flip else 1,1),"muzzle":weapon.muzzle*Vector2(-1 if turret.flip else 1,1),"turret_scale":body.turret_scale,"embedded_pilot":body.embedded_pilot}

func siege_supports(direction: Vector2,progress: float,body: Dictionary) -> Dictionary:
	if progress<=0 or siege_layers.is_empty() or body.is_empty():return {}
	var facing=ACData.sprite_direction(direction,8)
	var stage=clampi(roundi(progress*6),1,6)
	var key="%d:%d"%[int(facing.column),stage]
	var baseline: Dictionary=siege_layers.chassis[int(facing.column)]
	if not siege_support_frames.has(key):
		var entry: Dictionary=siege_layers.chassis[stage*5+int(facing.column)]
		var image: Image=entry.frame.texture.get_image()
		var bytes=image.get_data()
		var hull=Rect2i(baseline.draw[0],baseline.draw[1],baseline.draw[2],baseline.draw[3]).grow(1)
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if hull.has_point(Vector2i(x,y)):bytes[(y*image.get_width()+x)*4+3]=0
		var part=Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,bytes)
		var bounds=part.get_used_rect()
		siege_support_frames[key]={"texture":ImageTexture.create_from_image(part),"anchor":ACData.point(entry.anchor),"cell_size":Vector2(part.get_size()),"sprite_bounds":Rect2(bounds),"action":"deploy","frame":stage,"stage":stage,"v062":true}
	var result: Dictionary=siege_support_frames[key].duplicate()
	result.flip=bool(facing.flip)
	result.scale_hint=float(body.scale_hint)*float(baseline.draw[2])/maxf(1,body.get("sprite_bounds",Rect2(Vector2.ZERO,body.cell_size)).size.x)
	return result

func pilot(direction: Vector2,air: bool=false) -> Dictionary:
	if pilot_frames.size()!=2:return {}
	var index=ACData.sprite_direction(direction,16)
	var frame: Dictionary=pilot_frames[1 if air else 0][int(index.column)].duplicate()
	frame.flip=bool(index.flip)
	return frame

func air_pilot_mount(race: int,kind: int,direction: Vector2) -> Dictionary:
	var key="%d:%d"%[race,kind]
	if not air_pilot_mounts.has(key):return {}
	var definition: Dictionary=air_pilot_mounts[key]
	var index=ACData.sprite_direction(direction,16)
	var offset=ACData.point(definition.mounts[int(index.column)])-ACData.point(definition.root)
	if index.flip:offset.x=-offset.x
	return {"offset":offset,"width":float(definition.width)}

func rally(race: int) -> Texture2D:
	return rally_frames[3+clampi(race,0,2)] if rally_frames.size()==6 else null

func tera_plume(clock: float) -> Dictionary:
	return tera_plumes[posmod(int(clock*10),tera_plumes.size())] if not tera_plumes.is_empty() else {}

func citrus_projectile(style: String,impact: bool=false) -> Texture2D:
	if citrus_fx.size()<6:return null
	var index=1 if style in ["acid","juice"] else (2 if style in ["spore","pulp"] else 0)
	return citrus_fx[index+(3 if impact else 0)]

func _load_cursors() -> void:
	var path="res://data/cursor_regions_v04.json"
	if not FileAccess.file_exists(path):return
	var catalog=JSON.parse_string(FileAccess.get_file_as_string(path))
	for definition in catalog.get("cursors",[]):
		var file=String(definition.file)
		if not ResourceLoader.exists(file):continue
		var source: Image=load(file).get_image()
		var raw: Array=definition.region
		var region=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3])).intersection(Rect2i(Vector2i.ZERO,source.get_size()))
		if not region.has_area():continue
		var piece=source.get_region(region)
		var factor=float(definition.get("display_size",48))/maxf(piece.get_width(),piece.get_height())
		piece.resize(maxi(1,roundi(piece.get_width()*factor)),maxi(1,roundi(piece.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		cursor_frames["%d:%s"%[int(definition.race),String(definition.get("mode","default"))]]={"texture":ImageTexture.create_from_image(piece),"hotspot":ACData.point(definition.get("hotspot",[0,0]))*factor}

func cursor(race: int,mode: String="default") -> Dictionary:
	if mode=="target":mode="move"
	return cursor_frames.get("%d:%s"%[race,mode],cursor_frames.get("%d:default"%race,{}))

func _load_units(race: int, air: bool) -> void:
	var sheet_name="air" if air else "ground"
	var rows=ACData.get_data().sprite_rows[sheet_name][race]
	var need_fallback=false
	for kind in rows:
		if not motion_frames.has("%d:%d"%[race,int(kind)]):need_fallback=true
	if not need_fallback:return
	var file="res://assets/%s_%d.png"%[sheet_name,race]
	if not ResourceLoader.exists(file):
		return
	var source: Texture2D=load(file)
	var image=source.get_image()
	_atlas_sources.append(source)
	var columns=19 if air else 9
	var stored=17 if air else 9
	for row in range(rows.size()):
		if motion_frames.has("%d:%d"%[race,int(rows[row])]):continue
		var frames: Array=[]
		for col in range(stored):
			var source_col=int(round(float(col)*(columns-1)/(stored-1)))
			var x0=int(float(source_col)*image.get_width()/columns)
			var x1=int(float(source_col+1)*image.get_width()/columns)
			var y0=int(float(row)*image.get_height()/rows.size())
			var y1=int(float(row+1)*image.get_height()/rows.size())
			if sprite_regions.has("%s_%d"%[sheet_name,race]):
				var region=sprite_regions["%s_%d"%[sheet_name,race]][row][source_col]
				x0=int(region[0])
				y0=int(region[1])
				x1=x0+int(region[2])
				y1=y0+int(region[3])
			frames.append(_anchored_region(source,image,Rect2i(x0,y0,x1-x0,y1-y0),Vector2(.5,.88),.9))
		unit_frames["%d:%d"%[race,int(rows[row])]]=frames

func _load_motions(race: int) -> void:
	for kind in range(13):
		var key="%d:%d"%[race,kind]
		if not motion_regions.get("units",{}).has(key):
			continue
		var info=motion_regions.units[key]
		var file=String(info.file)
		var recolor="res://assets/citrus_palette_v060/r1_u%02d.png"%kind
		if race==1 and ResourceLoader.exists(recolor):file=recolor
		if key=="0:4" and not info.has("packed_root") and ResourceLoader.exists("res://assets/medic_registered_v060.png"):file="res://assets/medic_registered_v060.png"
		if not ResourceLoader.exists(file):
			continue
		var source: Texture2D=load(file)
		var image=source.get_image()
		_atlas_sources.append(source)
		var columns=int(info.get("columns",9))
		var rows=int(info.get("rows",6))
		var anchor=ACData.point(info.get("anchor",[.5,.88]))
		var animations: Array=[]
		var measured={} if info.has("packed_root") else asset_regions.get("motions",{}).get(key,{})
		for row in range(rows):
			var frames: Array=[]
			for col in range(columns):
				var pose=measured.get("poses",[])
				var source_row=int(pose[row][col][0]) if not pose.is_empty() else row
				var source_col=int(pose[row][col][1]) if not pose.is_empty() else col
				var x0=int(float(source_col)*image.get_width()/columns)
				var x1=int(float(source_col+1)*image.get_width()/columns)
				var y0=int(float(source_row)*image.get_height()/rows)
				var y1=int(float(source_row+1)*image.get_height()/rows)
				var nominal=Rect2i(x0,y0,x1-x0,y1-y0)
				var cell=nominal
				if measured.has("regions"):cell=_region_rect(measured.regions[row][col],image.get_size())
				var root=ACData.point(info.packed_root) if info.has("packed_root") else Vector2.INF
				frames.append(_anchored_region(source,image,cell,anchor,float(info.get("scale_width",.84)),nominal,root,float(info.get("scale_hint",0))))
				frames[-1]=_repair_frame(frames[-1],"motion:%s:%d:%d"%[key,row,col])
			animations.append(frames)
		motion_frames[key]=animations
		unit_frames[key]=animations[0]

func _repair_frame(frame: Dictionary,key: String) -> Dictionary:
	if not frame_cleanup.has(key):return frame
	var repair: Dictionary=frame_cleanup[key]
	var texture=AtlasTexture.new();texture.atlas=load(str(repair.file));texture.filter_clip=true
	texture.region=Rect2(repair.region[0],repair.region[1],repair.region[2],repair.region[3])
	frame.texture=texture;frame.anchor+=ACData.point(repair.anchor_delta)
	frame.sprite_bounds=Rect2(repair.bounds[0],repair.bounds[1],repair.bounds[2],repair.bounds[3])
	frame.verified_cleanup=true
	return frame

func _region_rect(raw: Array,dimensions: Vector2i) -> Rect2i:
	var pad=int(asset_regions.get("padding",2))
	return Rect2i(int(raw[0])-pad,int(raw[1])-pad,int(raw[2])+pad*2,int(raw[3])+pad*2).intersection(Rect2i(Vector2i.ZERO,dimensions))

func _anchored_region(source: Texture2D, image: Image, cell: Rect2i, normalized_anchor: Vector2, scale_width: float,nominal: Rect2i=Rect2i(),registered_root: Vector2=Vector2.INF,scale_hint: float=0) -> Dictionary:
	if not nominal.has_area():nominal=cell
	var used=image.get_region(cell).get_used_rect()
	if used.size.x<2 or used.size.y<2:
		used=Rect2i(Vector2i.ZERO,cell.size)
	var atlas=AtlasTexture.new()
	atlas.atlas=source
	atlas.region=Rect2(Vector2(cell.position+used.position),Vector2(used.size))
	atlas.filter_clip=true
	var anchor=Vector2(nominal.position-cell.position)+Vector2(nominal.size)*normalized_anchor-Vector2(used.position)
	# Align the actual contact point with the simulation point even if a
	# generated row used a slightly different transparent bottom gutter.
	if registered_root.is_finite():anchor=registered_root-Vector2(used.position)
	else:anchor.y=_contact_y(image,cell,used)-float(used.position.y)
	return {"texture":atlas,"anchor":anchor,"scale_hint":scale_hint if scale_hint>0 else maxf(float(nominal.size.x),float(nominal.size.y))*scale_width,"cell_size":Vector2(nominal.size),"registered_root":registered_root}

func _contact_y(image: Image, cell: Rect2i, used: Rect2i) -> float:
	# Ignore transparent RGB padding, faint ground glow and antialias noise.
	# At least two opaque pixels form the foot/tread/airframe contact row.
	for y in range(used.end.y-1,maxi(used.position.y,used.end.y-32)-1,-1):
		var opaque=0
		for x in range(used.position.x,used.end.x):
			if image.get_pixel(cell.position.x+x,cell.position.y+y).a>=.65:
				opaque+=1
				if opaque>=2:
					return float(y)
	return float(used.end.y-1)

func _trim(source: Image, region: Rect2i, excluded: Array=[]) -> Texture2D:
	var piece=source.get_region(region)
	# Reviewed atlas fragments belong to adjacent cells, not this object.
	for raw in excluded:
		var fragment=Rect2i(int(raw[0]),int(raw[1]),int(raw[2]),int(raw[3]))
		fragment=fragment.intersection(region)
		if fragment.has_area():piece.fill_rect(Rect2i(fragment.position-region.position,fragment.size),Color.TRANSPARENT)
	var used=piece.get_used_rect()
	if used.size.x>1 and used.size.y>1:
		piece=piece.get_region(used)
	var limit=320.0
	if maxf(piece.get_width(),piece.get_height())>limit:
		var factor=limit/maxf(piece.get_width(),piece.get_height())
		piece.resize(maxi(1,int(piece.get_width()*factor)),maxi(1,int(piece.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(piece)

func unit_action_info(race: int,kind: int,action: String) -> Dictionary:
	var definition: Dictionary=sprites.units.get("%d:%d"%[race,kind],{})
	if action=="idle" and definition.get("staged16",false):
		action=str(definition.get("idle_visual_action",action))
	return sprites.action_info(race,kind,action)

# action: idle, move/walk, attack, harvest/gather. clock is action elapsed seconds.
func unit(race: int, kind: int, direction: Vector2, action: String="idle", clock: float=0.0) -> Dictionary:
	var key="%d:%d"%[race,kind]
	var completed_definition: Dictionary=sprites.units.get(key,{})
	if completed_definition.get("staged16",false):
		var visual_action=str(completed_definition.get("idle_visual_action","idle")) if action=="idle" else action
		var completed=sprites.unit(race,kind,direction,visual_action,clock)
		if not completed.is_empty():return completed
	if action!="death":
		var repair=_direction_repair(key,direction)
		if not repair.is_empty():
			repair.action=action
			return repair
	var authored=sprites.unit(race,kind,direction,action,clock)
	if not authored.is_empty():return authored
	if v060_units.has(key):
		var index=ACData.sprite_direction(direction,8)
		var phase=posmod(int(clock*12),8) if action in ["walk","move","attack"] or ACData.unit(race,kind).air else 0
		var frame: Dictionary=v060_units[key][int(index.column)*8+phase].duplicate()
		frame.flip=bool(index.flip);frame.rotation=0.0;frame.frame=phase;frame.action=action
		# The painted diagonal-down flamer row faces southwest. Canonical
		# half-sheets require southeast before mirroring the western headings.
		if key=="0:13" and int(index.column)==3:
			frame.flip=not frame.flip
			frame.source_mirror=true
		return frame
	if action=="attack" and repaired_fire.has(key):return fire_pose(race,kind,direction,clock)
	if key=="0:8" and not drone_parts.is_empty():return drone(direction,clock).hull
	if directional_air.has(key):
		var info: Dictionary=directional_air[key]
		var index=ACData.sprite_direction(direction,(int(info.columns)-1)*2)
		var phase=posmod(int(clock*float(info.get("fps",5))),int(info.phases))
		var frame: Dictionary=info.frames[phase*int(info.columns)+int(index.column)].duplicate()
		frame.flip=bool(index.flip)!=bool(info.direction_flips[int(index.column)]);frame.rotation=0.0;frame.frame=phase;frame.action=action
		return frame
	if repaired_air.has(key):
		var frame: Dictionary=repaired_air[key].duplicate()
		frame.rotation=Vector2.UP.angle_to(direction) if direction.length_squared()>.001 else 0.0
		frame.flip=false
		frame.action=action
		frame.frame=0
		return frame
	if key=="0:4" and action=="heal" and not graphics_repairs.get("motions",{}).has(key) and not heal_frames.is_empty():
		var index=ACData.sprite_direction(direction,16)
		var phase=posmod(int(clock*8),4)
		var frame: Dictionary=heal_frames[phase][int(index.column)].duplicate()
		frame.flip=bool(index.flip)
		frame.action=action
		frame.frame=phase
		return frame
	if key=="1:13" and not brood_frames.is_empty():
		var row=1 if action=="morph" else 0
		var phase=clampi(int(clock*5),0,3) if action=="morph" else posmod(int(clock*5),4)
		var frame: Dictionary=brood_frames[row][phase].duplicate()
		frame.flip=false
		frame.action=action
		frame.frame=phase
		return frame
	if key=="1:13" and not unit_frames.has(key):return unit(1,0,direction,"idle",0)
	if action in ["construct","repair"]:
		action="harvest"
	if motion_frames.has(key):
		var animations=motion_frames[key]
		var definition: Dictionary=motion_regions.units.get(key,{})
		var rows: Array=definition.get("actions",motion_regions.get("actions",{})).get(action,[0])
		var fps=float(definition.get("action_fps",motion_regions.get("action_fps",{})).get(action,12.0 if action in ["attack","harvest","gather"] else 9.0))
		var tick=maxi(0,int(floor(clock*fps)))
		var row=int(rows[mini(tick,rows.size()-1) if action=="attack" else tick%rows.size()])
		var index=ACData.sprite_direction(direction,(animations[0].size()-1)*2)
		# Legacy back-facing spit frames had been painted as front-facing attacks.
		# Keep the correct rear silhouette and let the registered projectile animate.
		if key=="1:2" and action=="attack" and int(index.column)<=2:row=0
		var frame=animations[mini(row,animations.size()-1)][int(index.column)].duplicate()
		frame.flip=index.flip
		var source_mirror=(key=="1:7" and action=="attack" and int(index.column) in [1,2,3,4,5,6]) or (key=="1:8" and action=="attack" and int(index.column) in [1,2]) or (key=="1:6" and int(index.column) in [1,2,3,4,5])
		if source_mirror:frame.flip=not frame.flip;frame.source_mirror=true
		frame.action=action
		frame.frame=row
		return frame
	if not unit_frames.has(key):
		return {}
	var frames=unit_frames[key]
	var dirs=32 if ACData.unit(race,kind).air else 16
	var index=ACData.sprite_direction(direction,dirs)
	var frame=frames[mini(int(index.column),frames.size()-1)].duplicate()
	frame.flip=index.flip
	frame.action="idle"
	frame.frame=0
	return frame

func _load_v060() -> void:
	if FileAccess.file_exists("res://data/siege_layers_v061.json"):
		siege_layers=JSON.parse_string(FileAccess.get_file_as_string("res://data/siege_layers_v061.json"))
		var source: Texture2D=load(str(siege_layers.file))
		for part in ["chassis","turrets"]:
			for entry in siege_layers[part]:
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(int(entry.heading),int(entry.stage))*256,Vector2(256,256))
				entry.frame={"texture":texture,"anchor":ACData.point(entry.anchor),"scale_hint":float(siege_layers.scale_hint),"cell_size":Vector2(256,256),"sprite_bounds":Rect2(entry.draw[0],entry.draw[1],entry.draw[2],entry.draw[3]),"layered_v061":true}
	if ResourceLoader.exists("res://assets/rubble_v060.png"):
		var source: Texture2D=load("res://assets/rubble_v060.png");var cell=source.get_size()/Vector2(6,3)
		for race in range(3):
			var frames=[]
			for kind in range(6):
				var texture=AtlasTexture.new();texture.atlas=source;texture.region=Rect2(Vector2(kind,race)*cell,cell);texture.filter_clip=true;frames.append(texture)
			v060_effects["rubble_%d"%race]=frames
	for item in [["nuclear",4,2],["warhead",8,2]]:
		var path="res://assets/%s_v060.png"%item[0]
		if item[0]=="nuclear" and ResourceLoader.exists("res://assets/nuclear32_v060.png"):path="res://assets/nuclear32_v060.png";item[2]=8
		if not ResourceLoader.exists(path):continue
		var source: Texture2D=load(path);var cell=source.get_size()/Vector2(item[1],item[2]);var frames=[]
		for index in range(int(item[1])*int(item[2])):
			var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
			texture.region=Rect2(Vector2(index%int(item[1]),index/int(item[1]))*cell,cell);frames.append(texture)
		v060_effects["nuclear_cloud" if item[0]=="nuclear" else "warhead"]=frames
	for item in [[0,13,"flamer"],[0,14,"carrier"],[0,15,"drone"],[2,13,"chaser"]]:
		var registration=JSON.parse_string(FileAccess.get_file_as_string("res://data/new_unit_frames_v060.json")).units.get(item[2],{})
		var path="res://assets/%s_v060.png"%item[2]
		var registered="res://assets/registered_v060/%s.png"%item[2]
		var packed=ResourceLoader.exists(registered)
		if packed:path=registered
		if not ResourceLoader.exists(path):continue
		var source: Texture2D=load(path);var cell=source.get_size()/Vector2(8,5);var frames=[]
		for direction in range(5):
			for phase in range(8):
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(phase,direction)*cell,cell)
				var airborne=ACData.unit(int(item[0]),int(item[1])).air
				frames.append({"texture":texture,"anchor":cell*Vector2(.5,(.5 if airborne else .875) if packed else (.5 if airborne else .79)),"scale_hint":224.0 if packed else cell.x*.82,"cell_size":cell})
				if packed and registration.has("frames"):
					var draw: Array=registration.frames[direction*8+phase].draw
					frames.back().sprite_bounds=Rect2(draw[0],draw[1],draw[2],draw[3])
		v060_units["%d:%d"%[item[0],item[1]]]=frames
	if FileAccess.file_exists("res://data/industrial_units_v060.json"):
		var industrial=JSON.parse_string(FileAccess.get_file_as_string("res://data/industrial_units_v060.json"))
		for key in industrial.units:
			var info: Dictionary=industrial.units[key]
			var source: Texture2D=load(str(info.file));var frames=[]
			for entry in info.frames:
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(int(entry.phase),int(entry.heading))*256,Vector2(256,256))
				frames.append({"texture":texture,"anchor":ACData.point(info.anchor),"scale_hint":224.0,"cell_size":Vector2(256,256),"embedded_pilot":true,"industrial":true,"sprite_bounds":Rect2(entry.draw[0],entry.draw[1],entry.draw[2],entry.draw[3])})
			v060_units[str(key)]=frames
	var catalogs={
		"skills_hyrax":["stim","smoke","nuclear","scan","overcharge","field_repair"],
		"skills_citrus":["neural","mind_control","shed","sap_cycle","sap_inject","carapace","scatter","root_surge"],
		"skills_owl":["judgment","silence","bind","discipline","march","barrier","purify","shockwave","pierce","verdict"],
		"death":["juice","blood","explosion","blue_flame"]}
	for key in catalogs:
		var path="res://assets/%s_v060.png"%key
		if not ResourceLoader.exists(path):continue
		var source: Texture2D=load(path);var cell=source.get_size()/Vector2(8,catalogs[key].size())
		for row in range(catalogs[key].size()):
			var frames=[]
			for phase in range(8):
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(phase,row)*cell,cell);frames.append(texture)
			v060_effects[catalogs[key][row]]=frames
	var support_path="res://assets/sap_support_v060.png"
	if ResourceLoader.exists(support_path):
		var source: Texture2D=load(support_path);var cell=source.get_size()/Vector2(8,4)
		var keys=["sap_heal","sap_reclaim","sap_bloom"]
		for row in range(keys.size()):
			var frames=[]
			for phase in range(8):
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(phase,row+1)*cell,cell);frames.append(texture)
			v060_effects[keys[row]]=frames
	for sheet in ["projectiles","impacts"]:
		var path="res://assets/weapon_%s_v060.png"%sheet
		if not ResourceLoader.exists(path):continue
		var source: Texture2D=load(path);var cell=source.get_size()/Vector2(8,8)
		var keys=["bullet","shell","missile","acid","seed","thorn","plasma","bolt"] if sheet=="projectiles" else ["claw","slash","bash","spark","flame","vine","beam","explosion"]
		for row in range(keys.size()):
			var frames=[]
			for phase in range(8):
				var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
				texture.region=Rect2(Vector2(phase,row)*cell,cell);frames.append(texture)
			v060_effects["weapon_"+keys[row]]=frames
	if FileAccess.file_exists("res://data/units_art_v061.json"):
		var carrier: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units_art_v061.json")).units.carrier
		var source: Texture2D=load(str(carrier.file));var frames=[]
		for entry in carrier.frames:
			var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
			texture.region=Rect2(Vector2(int(entry.phase),int(entry.heading))*256,Vector2(256,256))
			frames.append({"texture":texture,"anchor":ACData.point(carrier.anchor),"scale_hint":224.0,"cell_size":Vector2(256,256),"embedded_pilot":true,"sprite_bounds":Rect2(entry.draw[0],entry.draw[1],entry.draw[2],entry.draw[3])})
		v060_units["0:14"]=frames
	if FileAccess.file_exists("res://data/flame_stream_v061.json"):
		var info=JSON.parse_string(FileAccess.get_file_as_string("res://data/flame_stream_v061.json"))
		var source: Texture2D=load(str(info.file));var frames=[]
		for entry in info.frames:
			var texture=AtlasTexture.new();texture.atlas=source;texture.filter_clip=true
			texture.region=Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3]);frames.append(texture)
		v060_effects.weapon_flame=frames

func skill_texture(key: String,progress: float) -> Texture2D:
	if not v060_effects.has(key):return null
	var frames: Array=v060_effects[key]
	return frames[clampi(int(progress*frames.size()),0,frames.size()-1)]

func warhead_texture(descending: bool,progress: float) -> Texture2D:
	if not v060_effects.has("warhead"):return null
	return v060_effects.warhead[(8 if descending else 0)+posmod(int(progress*32),8)]

func rubble_texture(race: int,kind: int) -> Texture2D:
	var key="rubble_%d"%race
	if not v060_effects.has(key):return null
	var variant=kind if kind<=2 else 3 if kind<=5 else 4 if kind<=10 else 5
	return v060_effects[key][variant]

func building(race: int, kind: int) -> Texture2D:
	var authored=sprites.building(race,kind,1.0,false,Vector2.DOWN,0)
	if not authored.is_empty():return authored.texture
	return building_frames.get("%d:%d"%[race,kind])

func fire_pose(race: int,kind: int,direction: Vector2,clock: float=0.0) -> Dictionary:
	var key="%d:%d"%[race,kind]
	if v060_units.has(key):return {}
	if not repaired_fire.has(key):return {}
	var index=ACData.sprite_direction(direction,8)
	var frame: Dictionary=repaired_fire[key][int(index.column)].duplicate()
	frame.flip=bool(index.flip)
	frame.action="attack"
	frame.frame=0
	# Gun kick settles quickly; there is no baked flash pointing elsewhere.
	var kick=sin(clampf(clock/.16,0,1)*PI)*3.0
	var local_direction=direction*Vector2(-1 if frame.flip else 1,1)
	frame.anchor+=local_direction*kick
	frame.muzzle=(frame.muzzle-local_direction*kick)*Vector2(-1 if frame.flip else 1,1)
	return frame

func _cache_building_idle() -> void:
	# These are bounded light changes on existing pixels, not independently
	# generated motion frames. Alpha, foundation and silhouette never change.
	# Cache once: a visible building still uses one normal texture draw.
	for key in building_frames:
		var race=int(String(key).get_slice(":",0))
		var source: Image=building_frames[key].get_image()
		if source.get_format()!=Image.FORMAT_RGBA8:source.convert(Image.FORMAT_RGBA8)
		var bytes=source.get_data()
		var candidates: Array=[]
		var opaque=0
		for offset in range(0,bytes.size(),4):
			if bytes[offset+3]<192:continue
			opaque+=1
			var red=float(bytes[offset])/255.0
			var green=float(bytes[offset+1])/255.0
			var blue=float(bytes[offset+2])/255.0
			var strength=0.0
			if race==0 and red>.58 and green>.23 and green<red*.68 and blue<green*.6:
				# Warm status lamps / furnace and exhaust highlights.
				strength=red-green*.45-blue*.5
			elif race==1 and minf(green,blue)>.35 and red<minf(green,blue)*.58 and maxf(green,blue)>.56:
				# Cyan grafted neural controllers; leaves and fruit stay still.
				strength=minf(green,blue)-red
			elif race==2 and red>.65 and maxf(green,blue)<red*.43:
				# Existing crimson core/crystal highlights, no floating rings.
				strength=red-maxf(green,blue)*.5
			if strength>0:candidates.append(Vector2(offset,strength))
		candidates.sort_custom(func(a,b):return a.y>b.y)
		# Restrict motion to a small luminous detail, never a whole painted body.
		var count=mini(candidates.size(),maxi(8,int(opaque*.025)))
		building_idle_pixels[key]=count
		var frames: Array=[]
		for intensity in [-.16,-.04,.08,.20]:
			var frame_bytes=bytes.duplicate()
			for index in range(count):
				var offset=int(candidates[index].x)
				var amount=float(intensity)*float(candidates[index].y)
				for channel in range(3):
					var value=float(bytes[offset+channel])
					frame_bytes[offset+channel]=clampi(int(round(value*(1.0+amount)+maxf(0,amount)*18)),0,255)
			var frame=Image.create_from_data(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8,frame_bytes)
			frames.append(ImageTexture.create_from_image(frame))
		building_idle_frames[key]=frames

func building_idle(race: int, kind: int, clock: float) -> Texture2D:
	return building(race,kind)
