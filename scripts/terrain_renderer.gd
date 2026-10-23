class_name ACTerrainRenderer
extends RefCounted

## Orthogonal 32px gameplay; continuous visual fields and flat staggered diamonds.
const WORLD_PIXELS := 4096.0
const STEP := 16.0
const GRID := 256
const STRIDE := 257
const DETAIL_WORLD_PIXELS := 512.0
const MATERIAL_WORLD_PIXELS := 256.0
const CLIFF_WORLD_PIXELS := Vector2(128,96)
const WATER_SLOT := 10
const WATER_COLOR := Color("112d3b")
const WATER_MODULATE := Color(.72,.82,.98,1)
const PALETTE := [Color("756c5f"),Color("69645a"),Color("777a74"),Color("86877f"),Color("747b7d"),Color("93918a"),Color("4b5050"),Color("a39475"),Color("62635c"),Color("5c5c55"),Color("112d3b"),Color("88835e"),Color("484b48"),Color("7b6253"),Color("4c5354"),Color("4b4d49")]
var loaded := false
var atlas: Texture2D
var atlas_cell := Vector2(256,256)
var water_texture: Texture2D
var material_textures: Array[Texture2D] = []
var ground_detail_textures: Array[Texture2D] = []
var planet_materials: Array[Texture2D] = []
var diamond_materials: Array[Texture2D] = []
var quiet_materials: Array[Texture2D] = []
var world_materials: Array[Texture2D] = []
var bank_materials: Array[Texture2D] = []
var scenery_textures: Array[Texture2D] = []
const DIAMOND_SIZE=Vector2(192,96)
const QUIET_WORLD_SPAN=384.0
var relief_textures: Array[Texture2D] = []
var prop_textures: Array[Texture2D] = []
var transition_textures: Array[Texture2D] = []
var fog_samples := PackedFloat32Array()
var last_stats: Dictionary = {}
var _cache: Dictionary = {}
var cache_builds=0

func load_art() -> void:
	loaded = true
	var source = _read_image("res://assets/terrain_macro.png")
	if source == null or source.is_empty():source = _read_image("res://assets/terrain_tiles.png")
	material_textures.clear()
	if source != null and not source.is_empty():
		atlas = ImageTexture.create_from_image(source)
		atlas_cell = Vector2(source.get_width()/4.0,source.get_height()/4.0)
		for slot in range(16):
			# Isolated textures prevent filtering across neighboring atlas cells.
			var origin = Vector2i((Vector2(slot%4,slot/4)*atlas_cell).ceil())+Vector2i(2,2)
			var size = Vector2i(atlas_cell.floor())-Vector2i(4,4)
			var material_image = source.get_region(Rect2i(origin,size))
			if slot!=WATER_SLOT:material_image.adjust_bcs(1.0,.78,.88)
			# Material-specific filtering leaves sprite/HUD sampling unchanged.
			material_textures.append(ImageTexture.create_from_image(material_image) if slot==WATER_SLOT else _filtered_texture(material_image))
		water_texture = material_textures[WATER_SLOT]
	ground_detail_textures.clear()
	planet_materials.clear()
	diamond_materials.clear()
	for theme in range(3):
		var source_diamonds=_read_image("res://assets/terrain_diamonds_v058_%d.png"%theme)
		if source_diamonds==null:continue
		var cell=Vector2i(source_diamonds.get_width()/4,source_diamonds.get_height()/4)
		for slot in range(16):
			var tile=source_diamonds.get_region(Rect2i(Vector2i(slot%4,slot/4)*cell,cell))
			diamond_materials.append(_filtered_texture(tile))
	for theme in range(3):
		var planet=_read_image("res://assets/terrain_atlas_v058_%d.png"%theme)
		if planet==null:continue
		var cell=Vector2i(planet.get_width()/4,planet.get_height()/4)
		for slot in range(16):
			var tile=planet.get_region(Rect2i(Vector2i(slot%4,slot/4)*cell+Vector2i(2,2),cell-Vector2i(4,4)))
			planet_materials.append(_filtered_texture(tile))
	for theme in range(3):
		var detail=_read_image("res://assets/terrain_detail_%d.png"%theme)
		ground_detail_textures.append(_filtered_texture(detail) if detail!=null and not detail.is_empty() else null)
	relief_textures.clear()
	var flat_relief=ResourceLoader.exists("res://assets/terrain_faces_v05.png")
	var relief=_read_image("res://assets/terrain_faces_v05.png" if flat_relief else "res://assets/terrain_relief_v4.png")
	if relief!=null and not relief.is_empty():
		var cell=Vector2i(relief.get_width()/3,relief.get_height()/2)
		for slot in range(6):
			var image=relief.get_region(Rect2i(Vector2i(slot%3,slot/3)*cell,cell))
			# The source is an isometric object, not a rectangular wall tile.
			# Sample its actual face/floor so diagonal end caps cannot become
			# repeated tiny billboards when laid along continuous map geometry.
			var sample=Rect2i(Vector2i(Vector2(cell)*Vector2(.32,.44)),Vector2i(Vector2(cell)*Vector2(.34,.22))) if slot<3 else Rect2i(Vector2i(Vector2(cell)*Vector2(.32,.30)),Vector2i(Vector2(cell)*Vector2(.34,.30)))
			if flat_relief:sample=Rect2i(Vector2i(4,4),cell-Vector2i(8,8))
			if image.get_used_rect().has_area():
				image=image.get_region(sample)
				if flat_relief and slot>=3:image.adjust_bcs(.96,.78,.55)
				image.fix_alpha_edges()
				relief_textures.append(_filtered_texture(image))
			else:relief_textures.append(null)
	prop_textures = _load_cells("res://assets/map_decor.png",true)
	quiet_materials=_load_theme_cells("res://assets/terrain_ground_worldart_v2.png",false)
	for theme in range(3):
		var hd=_read_image("res://assets/terrain_floor_hd_%d.png"%theme)
		if hd!=null and quiet_materials.size()==12:quiet_materials[theme*4]=_filtered_texture(hd)
	world_materials=_load_theme_cells("res://assets/terrain_relief_worldart_v2.png",false,3)
	for texture in world_materials:
		# Narrow rock faces compress V much more than U. Isotropic mip levels
		# otherwise erase horizontal detail even with correct arc-length UVs.
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	bank_materials=_load_bank_art()
	for texture in bank_materials:texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	scenery_textures=_load_theme_cells("res://assets/map_decor_v058.png",true)
	scenery_textures.append_array(_load_theme_cells("res://assets/map_decor_extra_v058.png",true,8))
	scenery_textures.append_array(_load_theme_cells("res://assets/map_decor_worldart.png",true,6))
	for biome in ["frontier","basin","highland"]:
		scenery_textures.append_array(_load_theme_cells("res://assets/map_decor_%s_worldart.png"%biome,true))
	transition_textures = _load_cells("res://assets/terrain_transitions.png",false)
	_cache.clear()

func _load_bank_art() -> Array[Texture2D]:
	var result: Array[Texture2D]=[]
	var source=_read_image("res://assets/terrain_banks_modular_v2.png")
	if source==null:return result
	# Use the actual painted cell boundaries rather than assuming the
	# generated atlas has mathematically equal gutters. Exclude divider ink.
	var columns=[0.0,.203,.390,.584,.798,1.0];var rows=[0.0,.330,.663,1.0]
	for row in range(3):
		for column in range(5):
			var start=Vector2i(ceili(columns[column]*source.get_width())+7,ceili(rows[row]*source.get_height())+7)
			var end=Vector2i(floori(columns[column+1]*source.get_width())-7,floori(rows[row+1]*source.get_height())-7)
			result.append(_filtered_texture(source.get_region(Rect2i(start,end-start))))
	return result

func _load_theme_cells(path: String, trim: bool, columns: int=4) -> Array[Texture2D]:
	var result: Array[Texture2D]=[]
	var source=_read_image(path)
	if source==null:return result
	var cell=Vector2i(source.get_width()/columns,source.get_height()/3)
	for slot in range(columns*3):
		var image=source.get_region(Rect2i(Vector2i(slot%columns,slot/columns)*cell,cell))
		if trim:
			var used=image.get_used_rect()
			if used.has_area():image=image.get_region(used)
		else:image=image.get_region(Rect2i(Vector2i(3,3),cell-Vector2i(6,6)))
		result.append(_filtered_texture(image))
	return result

func _filtered_texture(image: Image) -> CanvasTexture:
	if image.is_compressed():image.decompress()
	image.generate_mipmaps()
	var texture=CanvasTexture.new()
	texture.diffuse_texture=ImageTexture.create_from_image(image)
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture.texture_repeat=CanvasItem.TEXTURE_REPEAT_MIRROR
	return texture

func _read_image(file: String) -> Image:
	if ResourceLoader.exists(file):
		var texture = ResourceLoader.load(file)
		if texture is Texture2D:return texture.get_image()
	if FileAccess.file_exists(file):
		var image = Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(file)) == OK:return image
	return null

func _load_cells(path: String, trim: bool) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var source = _read_image(path)
	if source == null or source.is_empty():return result
	var cell = Vector2i(source.get_width()/4,source.get_height()/4)
	for slot in range(16):
		var image = source.get_region(Rect2i(Vector2i(slot%4,slot/4)*cell,cell))
		var used = image.get_used_rect() if trim else Rect2i(Vector2i.ZERO,cell)
		result.append(ImageTexture.create_from_image(image.get_region(used)) if used.has_area() else null)
	return result

func draw(canvas: CanvasItem, map: ACMap, view: Rect2, zoom: float, project: Callable, _unproject: Callable, fog: Callable, _clock: float, fog_revision: int=-1,draw_fog: bool=true) -> void:
	var started = Time.get_ticks_usec()
	if not loaded:load_art()
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	canvas.draw_rect(view,Color.BLACK)
	var key = map.get_instance_id()
	var signature = map.render_signature
	if not _cache.has(key) or _cache[key].signature != signature:
		if not _cache.has(key) and _cache.size()>=3:_cache.erase(_cache.keys()[0])
		_cache[key] = _build_cache(map,signature)
	var data: Dictionary = _cache[key]
	var transform = Transform2D(Vector2(zoom,0),Vector2(0,zoom),project.call(Vector2.ZERO))
	var origin: Vector2 = project.call(Vector2.ZERO)
	var end: Vector2 = project.call(Vector2(128,128))
	var world_rect = Rect2(origin,end-origin).abs()
	var clip = world_rect.intersection(view)
	if not clip.has_area():return
	var calls = 0
	for layer in data.layers:
		canvas.draw_mesh(layer.mesh,_texture(layer.slot),transform,layer.tint)
		calls += 1
	_draw_props(canvas,map,clip,zoom,project,fog)
	if draw_fog:_update_fog(data,fog,fog_revision)
	if draw_fog and data.fog_texture != null:
		_draw_cropped(canvas,data.fog_texture,world_rect,clip,Color.WHITE)
		calls += 1
	var detail=_texture(16+map.theme)
	last_stats = {"draw_commands":calls,"mesh_vertices":data.vertices,"cache_build_ms":data.build_ms,"draw_cpu_ms":float(Time.get_ticks_usec()-started)/1000.0,"map_bounds":world_rect,"material_signature":signature,"detail_resolution":Vector2i(detail.get_width(),detail.get_height()) if detail!=null else Vector2i.ZERO,"detail_world_span":DETAIL_WORLD_PIXELS,"detail_texels_per_screen_pixel":float(detail.get_width())/(DETAIL_WORLD_PIXELS*zoom) if detail!=null else 0.0}

func _texture(slot: int) -> Texture2D:
	if slot<0:return null
	if slot>=240:return bank_materials[slot-240] if bank_materials.size()>slot-240 else null
	if slot>=224:return world_materials[slot-224] if world_materials.size()>slot-224 else null
	if slot>=192:return quiet_materials[slot-192] if quiet_materials.size()>slot-192 else null
	if slot>=128:return diamond_materials[slot-128] if diamond_materials.size()>slot-128 else null
	if slot>=64:return planet_materials[slot-64] if planet_materials.size()>slot-64 else null
	if slot>=32:return relief_textures[slot-32] if relief_textures.size()>slot-32 else null
	if slot>=16:return ground_detail_textures[slot-16] if ground_detail_textures.size()>slot-16 else null
	return material_textures[slot] if material_textures.size()==16 else null

## Call after every world entity/projectile/selection. The logical rectangular
## canvas clip alone cannot cover the strip below a raised southern map edge.
func draw_boundary_mask(canvas: CanvasItem, map: ACMap, _view: Rect2, zoom: float, project: Callable) -> void:
	var key=map.get_instance_id()
	if not _cache.has(key):return
	var data: Dictionary=_cache[key]
	if not data.has("boundary_mask"):data.boundary_mask=_boundary_mask_mesh(map)
	var transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),project.call(Vector2.ZERO))
	canvas.draw_mesh(data.boundary_mask,null,transform,Color.BLACK)
	last_stats["boundary_mask_draw_commands"]=1

func _boundary_mask_mesh(map: ACMap) -> ArrayMesh:
	var builder=_builder()
	var boundary=map.visual_boundary()
	var center=Vector2.ONE*WORLD_PIXELS*.5
	# This closed ring is drawn as one cached mesh. Its inner edge exactly
	# follows all 1024 terrain perimeter segments, including the x/y=128 edge.
	# The outer edge sits far beyond the existing rectangular viewport clip.
	for index in range(boundary.size()):
		var a=boundary[index]
		var b=boundary[(index+1)%boundary.size()]
		var inner_a=Vector2(a.x*32,a.y*32-a.z)
		var inner_b=Vector2(b.x*32,b.y*32-b.z)
		var outer_a=center+(inner_a-center)*16.0
		var outer_b=center+(inner_b-center)*16.0
		_append_quad(builder,PackedVector2Array([inner_a,inner_b,outer_b,outer_a]),PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]),PackedFloat32Array([1,1,1,1]))
	return _mesh(builder)

func prepare(map: ACMap,progress: Callable=Callable()) -> void:
	var key=map.get_instance_id()
	if not _cache.has(key) or _cache[key].signature!=map.render_signature:
		if not _cache.has(key) and _cache.size()>=3:_cache.erase(_cache.keys()[0])
		_cache[key]=_build_cache(map,map.render_signature,progress)
	# Also prepare the southern boundary before the first playable frame.
	_cache[key].boundary_mask=_boundary_mask_mesh(map)
	if progress.is_valid():progress.call(1.0,"전장 화면 준비 완료")

func _build_cache(map: ACMap, signature: int,progress: Callable=Callable()) -> Dictionary:
	cache_builds+=1
	var started = Time.get_ticks_usec()
	var classes := PackedByteArray()
	classes.resize(128*128)
	for i in range(classes.size()):
		var surface = int(map.surface_map[i]) if map.surface_map.size()>i else _surface_fallback(map,i)
		# Collision alone cannot distinguish a cliff, shore, rock or doodad.
		classes[i] = 5 if map.is_water(i) else (4 if map.visual_role(i) in [1,3] else (6 if map.visual_role(i)==2 else (1 if surface==3 else (2 if surface==4 else (3 if surface==5 else (6 if surface==1 else 0))))))
	var fields: Array = []
	for layer in range(7):
		var field := PackedFloat32Array()
		field.resize(STRIDE*STRIDE)
		fields.append(field)
	var points := PackedVector2Array()
	points.resize(STRIDE*STRIDE)
	var levels=PackedFloat32Array();levels.resize(STRIDE*STRIDE)
	for gy in range(STRIDE):
		for gx in range(STRIDE):
			var p = Vector2(gx*.5,gy*.5)
			# Boundary displacement affects art alone, preserving every nav cell.
			var warp = Vector2(sin(p.y*1.31+p.x*.17),sin(p.x*1.13-p.y*.23))*.18
			var sample = p+warp
			var x = int(floor(sample.x))
			var y = int(floor(sample.y))
			var fraction = sample-Vector2(x,y)
			fraction.x = smoothstep(0.0,1.0,fraction.x)
			fraction.y = smoothstep(0.0,1.0,fraction.y)
			var rise = 0.0
			var index = gy*STRIDE+gx
			for dy in range(2):
				for dx in range(2):
					var weight = (fraction.x if dx==1 else 1.0-fraction.x)*(fraction.y if dy==1 else 1.0-fraction.y)
					var source = clampi(y+dy,0,127)*128+clampi(x+dx,0,127)
					fields[classes[source]][index] += weight
					levels[index]+=weight*float(map.height_map[source])
					rise += weight*_rise(map,source%128,source/128)
			points[index] = Vector2(p.x*32.0,clampf(p.y*32.0-rise,0,WORLD_PIXELS))
	_apply_surface_regions(map,fields)
	if progress.is_valid():progress.call(.16,"지형 표면 준비 중")
	var layers: Array = []
	var vertices = 0
	var default_slot = 1 if map.theme==0 else (13 if map.theme==1 else 3)
	var ground_slot=16+map.theme if _texture(16+map.theme)!=null else default_slot
	var floor_slot=35+map.theme if _texture(35+map.theme)!=null else 8
	var slots = [ground_slot,floor_slot,ground_slot,ground_slot,floor_slot,10,ground_slot]
	var planet_base=64+map.theme*16
	var rich=planet_materials.size()==48
	var diamond=diamond_materials.size()==48
	if rich:
		ground_slot=planet_base;floor_slot=planet_base+4
		# Horizontal cliff tops use ground material. Vertical faces are drawn
		# separately below, only where the actual terrain elevation changes.
		slots=[ground_slot,floor_slot,planet_base+5,planet_base+12,planet_base+6,planet_base+11,planet_base+13]
	if quiet_materials.size()==12:
		ground_slot=192+map.theme*4;slots[0]=ground_slot;slots[4]=ground_slot+1
		floor_slot=ground_slot+3
	if world_materials.size()==9:slots[5]=225+map.theme*3
	for layer in range(7):
		if diamond and layer in [1,2,3,6]:continue
		if progress.is_valid():progress.call(.16+float(layer)*.065,"지형 표면 준비 중")
		var builder = _builder()
		for gy in range(GRID):
			for gx in range(GRID):
				var indices = [gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
				var alpha = PackedFloat32Array([1,1,1,1]) if layer==0 else PackedFloat32Array([fields[layer][indices[0]],fields[layer][indices[1]],fields[layer][indices[2]],fields[layer][indices[3]]])
				if layer==5:
					for corner in range(4):alpha[corner]=smoothstep(.40,.52,alpha[corner])
				# Secondary surfaces blend with the same planet's base material;
				# they must not look like a pasted patch from another tileset.
				if not rich and layer in [1,2,3]:
					for corner in range(4):alpha[corner]*=.32 if layer==1 else .48
				if not rich and layer==4:
					for corner in range(4):alpha[corner]*=.46
				if layer>0 and maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
				# Detail has uniform texel density on both axes. The old 2:1 UV
				# magnified one axis, turning a 313px crop into several screen px
				# per source pixel at zoom2. Water keeps its previous UV unchanged.
				var pixel = Vector2(gx*STEP,gy*STEP)
				var span=_material_span(slots[layer]) if slots[layer]>=192 else (256.0 if rich else (DETAIL_WORLD_PIXELS if layer in [0,2,3,6] else MATERIAL_WORLD_PIXELS))
				var legacy=not rich and (layer==5 or (layer in [0,6] and ground_slot==default_slot))
				var uv=PackedVector2Array()
				for offset in [Vector2.ZERO,Vector2(STEP,0),Vector2(STEP,STEP),Vector2(0,STEP)]:
					uv.append(_ground_uv(pixel+offset) if legacy else _detail_uv(pixel+offset,span))
				_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
				if layer!=5:
					# Slow world-space variation breaks up mirrored texture motifs
					# without introducing per-tile borders or new draw calls.
					var base=builder.colors.size()-4
					for corner in range(4):
						var p=Vector2(indices[corner]%STRIDE,indices[corner]/STRIDE)*STEP
						var shade=_level_light(levels[indices[corner]]) if quiet_materials.size()==12 else 1.0+.035*sin(p.x*.006+p.y*.003)+.025*cos(p.y*.009-p.x*.002)
						builder.colors[base+corner]=Color(shade,shade,shade,alpha[corner])
		if not builder.vertices.is_empty():
			var tint = Color(.93,.92,.89,1) if layer!=5 else WATER_MODULATE
			if layer==6:tint=Color(1.04,1.02,.98,1)
			if layer==2:tint=Color(.85,.88,.88,1)
			if layer==3:tint=Color(1.06,1.03,.97,1)
			if _texture(slots[layer])==null:tint *= PALETTE[slots[layer]]
			layers.append({"mesh":_mesh(builder),"slot":slots[layer],"tint":tint})
			vertices += builder.vertices.size()
	if diamond:
		var tiles=_diamond_layers(map,fields,levels)
		layers.append_array(tiles.layers);vertices+=int(tiles.vertices)
	if progress.is_valid():progress.call(.72,"절벽과 경사로 준비 중")
	if rich and not diamond:
		for material in [1,2,3,6,7,9,10,14,15]:
			var noise=FastNoiseLite.new();noise.seed=7319+map.theme*127+material*83
			noise.frequency=.0035;noise.fractal_octaves=3
			var patch=_builder()
			for gy in range(0,GRID,2):
				for gx in range(0,GRID,2):
					var indices=[gy*STRIDE+gx,gy*STRIDE+gx+2,(gy+2)*STRIDE+gx+2,(gy+2)*STRIDE+gx]
					var alpha=PackedFloat32Array();var uv=PackedVector2Array();var quad=PackedVector2Array()
					for index in indices:
						var pixel=Vector2(index%STRIDE,index/STRIDE)*STEP
						var mask=(1.0-fields[5][index]-fields[4][index])
						if material==9:mask=fields[4][index]
						if material==10:mask=fields[5][index]*(1.0-fields[5][index])*4.0
						alpha.append(smoothstep(-.08,.36,noise.get_noise_2d(pixel.x,pixel.y))*mask*.48)
						uv.append(_detail_uv(pixel,320.0));quad.append(points[index])
					if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))>.01:_append_quad(patch,quad,uv,alpha)
			if not patch.vertices.is_empty():
				layers.append({"mesh":_mesh(patch),"slot":planet_base+material,"tint":Color.WHITE})
				vertices+=patch.vertices.size()
	for variation in range(0 if diamond else 2):
		var builder = _builder()
		for row in range(-1,34):
			for col in range(-1,10):
				if posmod(row*17+col*31,2)!=variation:continue
				var center = Vector2(col*512.0+posmod(row,2)*256.0,row*128.0)
				for iy in range(4):
					for ix in range(4):
						var quad := PackedVector2Array()
						var uv := PackedVector2Array()
						var alpha := PackedFloat32Array()
						for corner in [Vector2(ix,iy),Vector2(ix+1,iy),Vector2(ix+1,iy+1),Vector2(ix,iy+1)]:
							var fraction: Vector2 = corner/4.0
							var local = fraction*2.0-Vector2.ONE
							var point = center+Vector2((local.x+local.y)*128.0,(local.y-local.x)*64.0)
							point = point.clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS)
							var field_index = clampi(int(point.y/STEP),0,GRID)*STRIDE+clampi(int(point.x/STEP),0,GRID)
							var edge = 1.0-maxf(absf(local.x),absf(local.y))
							quad.append(Vector2(point.x,points[field_index].y))
							uv.append(fraction)
							alpha.append(edge*(fields[0][field_index]+fields[6][field_index])*.10)
						_append_quad(builder,quad,uv,alpha)
		var slot=default_slot if variation==0 else (0 if map.theme==0 else (13 if map.theme==1 else 6))
		layers.append({"mesh":_mesh(builder),"slot":slot,"tint":Color(.95,.94,.90,1) if _texture(slot)!=null else PALETTE[slot]})
		vertices += builder.vertices.size()
	var ramps_mesh=_ramp_mesh(map,points,levels)
	if ramps_mesh!=null:layers.append({"mesh":ramps_mesh,"slot":192+map.theme*4 if quiet_materials.size()==12 else floor_slot,"role":"ramp","tint":Color(.93,.92,.89,1)})
	# Imported minitiles also contain low rocks and irregular cliff feet. The
	# smoothed height contours alone left these original obstacles looking flat.
	var blockers=_source_blocker_geometry(map)
	if progress.is_valid():progress.call(.84,"장애물과 물가 준비 중")
	if blockers.mesh!=null:
		layers.append({"mesh":blockers.mesh,"slot":192+map.theme*4+1 if quiet_materials.size()==12 else cliff_material_slot(map.theme),"role":"source_blockers","tint":Color(.66,.64,.60,1)})
		vertices+=blockers.vertices
	var cliffs = _cliff_mesh(map,points,fields[4]) if world_materials.size()!=9 else null
	var cliff_slot=32+map.theme if _texture(32+map.theme)!=null else 9
	if rich:cliff_slot=planet_base+8
	if world_materials.size()==9:cliff_slot=224+map.theme*3
	if cliffs != null:layers.append({"mesh":cliffs,"slot":cliff_slot,"role":"cliff","tint":Color(.70,.69,.66,1) if map.theme==0 else (Color(.65,.61,.57,1) if map.theme==1 else Color(.60,.63,.68,1))})
	var lighting=_relief_lighting(points,fields[4],fields[5]) if world_materials.size()!=9 else [null,null]
	if lighting[0]!=null:layers.append({"mesh":lighting[0],"slot":-1,"role":"foot_shadow","tint":Color(.045,.039,.033,1)})
	if lighting[1]!=null:layers.append({"mesh":lighting[1],"slot":ground_slot,"role":"upper_lip","tint":Color(1.45,1.37,1.23,1)})
	if world_materials.size()==9:
		# Distinct water/lowland/highland contours. These are opaque rock banks,
		# separate from seamless material transitions within a single level.
		layers.append_array(_contour_banks(map,fields[5],.5,PackedFloat32Array(),false,"coast"))
		for level in [.5,1.5]:layers.append_array(_contour_banks(map,levels,level,fields[4],true,"height_bank",fields[5]))
	if progress.is_valid():progress.call(.94,"전장 장식 준비 중")
	return {"signature":signature,"layers":layers,"vertices":vertices,"source_blocked_cells":blockers.cells,"props":_scenery(map),"build_ms":float(Time.get_ticks_usec()-started)/1000.0,"fog_texture":null,"fog_hash":0,"fog_updated":-1000}

func cliff_material_slot(theme: int) -> int:
	return 32+theme if _texture(32+theme)!=null else 9

func _source_blocker_geometry(map: ACMap) -> Dictionary:
	var builder=_builder();var cells=0
	if map.source_walk_masks.size()!=128*128:return {"mesh":null,"cells":0,"vertices":0}
	for y in range(512):
		var x=0
		while x<512:
			if not _source_land_blocked(map,x,y):x+=1;continue
			var start=x
			# Short runs preserve the same subdivided terrain elevation plane.
			while x<512 and x<start+2 and _source_land_blocked(map,x,y):x+=1;cells+=1
			var low=(Vector2(start,y)*.25-Vector2.ONE*.5).max(Vector2.ZERO)
			var high=(Vector2(x,y+1)*.25-Vector2.ONE*.5).min(Vector2.ONE*128)
			if high.x<=low.x or high.y<=low.y:continue
			var quad=PackedVector2Array();var uv=PackedVector2Array()
			for p in [low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)]:
				quad.append(Vector2(p.x*32,p.y*32-map.visual_elevation(p)-3.0))
				uv.append(p*32/128.0)
			_append_quad(builder,quad,uv,PackedFloat32Array([1,1,1,1]))
	return {"mesh":_mesh(builder) if not builder.vertices.is_empty() else null,"cells":cells,"vertices":builder.vertices.size()}

func _source_land_blocked(map: ACMap,x: int,y: int) -> bool:
	var index=(y/4)*128+x/4
	return not map.is_water(index) and (map.source_walk_masks[index]&(1<<((y%4)*4+x%4)))==0

func _apply_surface_regions(map: ACMap, fields: Array) -> void:
	# Four coherent districts. Their shared world-space weights are constant
	# inside a region and blend only near region boundaries, never per tile.
	var noises=[]
	for material in range(4):
		var noise=FastNoiseLite.new();noise.seed=4381+map.theme*127+material*1931
		noise.frequency=.032;noise.fractal_octaves=1;noises.append(noise)
	for y in range(STRIDE):
		for x in range(STRIDE):
			var index=y*STRIDE+x;var scores=[];var best=-INF;var total=0.0;var weights=[]
			for noise in noises:
				var score=noise.get_noise_2d(x*.5,y*.5);scores.append(score);best=maxf(best,score)
			for score in scores:
				var weight=smoothstep(best-.10,best,score);weights.append(weight);total+=weight
			fields[2][index]=weights[1]/total
			fields[3][index]=weights[2]/total
			fields[1][index]=weights[3]/total

func _contour_banks(map: ACMap, field: PackedFloat32Array, threshold: float, gate: PackedFloat32Array, downhill: bool, role: String, exclude: PackedFloat32Array=PackedFloat32Array()) -> Array:
	var segments=[]
	for y in range(GRID):
		for x in range(GRID):
			var corners=[y*STRIDE+x,y*STRIDE+x+1,(y+1)*STRIDE+x+1,(y+1)*STRIDE+x]
			for tri in [[0,1,2],[0,2,3]]:
				var ends=[]
				for edge in range(3):
					var a=corners[tri[edge]];var b=corners[tri[(edge+1)%3]]
					if (field[a]>=threshold)==(field[b]>=threshold):continue
					var t=(threshold-field[a])/(field[b]-field[a])
					ends.append(Vector2(a%STRIDE,a/STRIDE).lerp(Vector2(b%STRIDE,b/STRIDE),t)*STEP)
				if ends.size()!=2 or ends[0].distance_to(ends[1])<.001:continue
				if not gate.is_empty() and _field_at(gate,(ends[0]+ends[1])*.5)<.12:continue
				if not exclude.is_empty() and _field_at(exclude,(ends[0]+ends[1])*.5)>.05:continue
				segments.append(ends)
	var faces=[_builder(),_builder(),_builder()];var lip=_builder();var shadow=_builder()
	var counts={"straight":0,"convex":0,"concave":0,"ramp_end":0};var joins=[]
	for raw in _bank_chains(segments):
		var chain=_clean_bank_chain(raw)
		if chain.size()<2:continue
		var closed=chain[0].is_equal_approx(chain[-1])
		if closed:chain.remove_at(chain.size()-1)
		var count=chain.size();var edge_count=count if closed else count-1
		var directions=[];var normals=[];var distances=[0.0]
		for i in range(edge_count):
			var a=chain[i];var b=chain[(i+1)%count];var tangent=(b-a).normalized()
			var normal=Vector2(-tangent.y,tangent.x);var p=(a+b)*.5
			var gradient=Vector2(_field_at(field,p+Vector2(4,0))-_field_at(field,p-Vector2(4,0)),_field_at(field,p+Vector2(0,4))-_field_at(field,p-Vector2(0,4)))
			if normal.dot(gradient)*(-1.0 if downhill else 1.0)<0:normal=-normal
			directions.append(tangent);normals.append(normal);distances.append(distances[-1]+a.distance_to(b))
		var total=float(distances[-1]);var period=maxf(1,roundf(total/256.0))*256.0/total if closed else 1.0
		var entries=[];var exits=[];var cuts=[]
		for i in range(count):
			var endpoint=not closed and (i==0 or i==count-1)
			var before=posmod(i-1,edge_count);var after=mini(i,edge_count-1)
			if endpoint:before=after if i==0 else before;after=before
			var turn=float(directions[before].cross(directions[after]))
			var cut=0.0 if endpoint or absf(turn)<.12 else minf(10.0,minf(chain[i].distance_to(chain[posmod(i-1,count)]),chain[i].distance_to(chain[(i+1)%count]))*.24)
			cuts.append(cut)
			var entry=chain[i]-directions[before]*cut;var leave=chain[i]+directions[after]*cut
			var taper=.08 if endpoint and _near_bank_ramp(map,chain[i]) else 1.0
			var a=_bank_section(map,entry,normals[before],role,taper)
			var b=_bank_section(map,leave,normals[after],role,taper)
			if cut<.001 and not endpoint:
				var shared_normal=(normals[before]+normals[after]).normalized()
				a=_bank_section(map,chain[i],shared_normal/maxf(.7,shared_normal.dot(normals[after])),role)
				b=a
			entries.append(a);exits.append(b)
			if cut<.001:continue
			# A bounded miter is shared by the two halves of a corner. The
			# straight modules meet these exact same entry/exit connectors.
			var average=(normals[before]+normals[after]).normalized()
			var miter=average/maxf(.7,average.dot(normals[after]))
			var middle=_bank_section(map,chain[i],miter,role)
			var side=directions[before].cross(normals[before])
			var kind=1 if turn*side<0 else 2
			_emit_bank_piece(faces[kind],lip,shadow,a,middle,.5-cut/128.0,.5)
			_emit_bank_piece(faces[kind],lip,shadow,middle,b,.5,.5+cut/128.0)
			counts["convex" if kind==1 else "concave"]+=1
			joins.append({"entry":a.top,"exit":b.top,"center":chain[i],"kind":kind})
		for i in range(edge_count):
			var next=(i+1)%count;var a=exits[i];var b=entries[next]
			var start=chain[i]+directions[i]*cuts[i];var end=chain[next]-directions[i]*cuts[next]
			var length=start.distance_to(end)
			if length<.001:continue
			var modules=maxi(1,ceili(length/64.0))
			for part in range(modules):
				var t0=float(part)/modules;var t1=float(part+1)/modules
				var s0=a if part==0 else _bank_section(map,start.lerp(end,t0),normals[i],role,lerpf(a.scale,b.scale,t0))
				var s1=b if part==modules-1 else _bank_section(map,start.lerp(end,t1),normals[i],role,lerpf(a.scale,b.scale,t1))
				var u0=(distances[i]+cuts[i]+t0*length)*period/128.0
				var u1=(distances[i]+cuts[i]+t1*length)*period/128.0
				_emit_bank_piece(faces[0],lip,shadow,s0,s1,u0,u1)
				counts.straight+=1
			if a.scale<1 or b.scale<1:counts.ramp_end+=1
	var result=[]
	for kind in range(3):
		if faces[kind].vertices.is_empty():continue
		var slot=240+map.theme*5+(3 if role=="coast" else kind) if bank_materials.size()==15 else 224+map.theme*3
		result.append({"mesh":_mesh(faces[kind]),"slot":slot,"role":role,"piece_kind":kind,"modules":counts,"joins":joins if kind==0 else [],"tint":Color(.86,.85,.82,1)})
	if lip.vertices.is_empty():return []
	result.append({"mesh":_mesh(lip),"slot":226+map.theme*3,"role":role+"_rim","tint":Color(1.08,1.06,1.00,1)})
	if not shadow.vertices.is_empty():result.append({"mesh":_mesh(shadow),"slot":-1,"role":role+"_shadow","tint":Color(.035,.035,.04,1)})
	return result

func _bank_section(map: ACMap, point: Vector2, normal: Vector2, role: String, scale: float=1.0) -> Dictionary:
	# Sample the two landings outside the interpolation band. Sampling inside
	# it flattened rear walls and inverted tight corners into triangular spikes.
	var upper=3.0 if role=="coast" else 4.0
	var lower=4.0 if role=="coast" else 6.0
	var direction=normal.normalized()
	var high=map.visual_elevation((point-direction*28.0)/32.0)
	var low=map.visual_elevation((point+direction*28.0)/32.0)
	var middle=(high+low)*.5
	var rise=clampf(high-low,12.0,42.0) if role=="coast" else clampf(high-low,20.0,26.0)
	# The fixed camera looks from the south. A north-facing drop is hidden
	# by its upper landing; it must not expose a vertical wall or foot shadow.
	# Collapse the cross-section at the silhouette as it turns away, so side
	# corners meet continuously instead of ending in a rectangular cap.
	var visibility=smoothstep(0.0,.35,direction.y)
	var silhouette=_bank_point(map,point)
	var top=silhouette.lerp(point-normal*upper*scale-Vector2(0,middle+rise*.5*scale),visibility)
	var bottom=silhouette.lerp(point+normal*lower*scale-Vector2(0,middle-rise*.5*scale),visibility)
	return {"top":top.clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS),"bottom":bottom.clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS),
		"rim":(top-normal*3.0*scale).clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS),"foot":(bottom+normal*4.0*scale*visibility).clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS),
		"shade":.94+.10*direction.dot(Vector2(-.6,-.8)),"scale":scale,"facing":direction.y,"silhouette":silhouette}

func _emit_bank_piece(face: Dictionary, lip: Dictionary, shadow: Dictionary, a: Dictionary, b: Dictionary, u0: float, u1: float) -> void:
	# The thin ground rim is visible around the whole outline, including the
	# far edge. Only camera-facing portions receive a rock face and shadow.
	var quad=PackedVector2Array([a.rim,b.rim,b.top,a.top]);var uv=PackedVector2Array()
	for p in quad:uv.append(p/128.0)
	_append_quad(lip,quad,uv,PackedFloat32Array([.8,.8,1,1]))
	if a.facing<=0.0 and b.facing<=0.0:return
	if a.facing<0.0 or b.facing<0.0:
		var t=float(a.facing)/(a.facing-b.facing)
		var edge=a.silhouette.lerp(b.silhouette,t)
		var cut={"top":edge,"bottom":edge,"foot":edge,"shade":lerpf(a.shade,b.shade,t)}
		var u=lerpf(u0,u1,t)
		if a.facing<0.0:a=cut;u0=u
		else:b=cut;u1=u
	# Match U/V texel density; fitting an entire square swatch into a thin
	# wall made rock strata look like stretched planks and corners like posts.
	var va=.25+a.top.distance_to(a.bottom)/128.0;var vb=.25+b.top.distance_to(b.bottom)/128.0
	_append_quad(face,PackedVector2Array([a.top,b.top,b.bottom,a.bottom]),PackedVector2Array([Vector2(u0,.25),Vector2(u1,.25),Vector2(u1,vb),Vector2(u0,va)]),PackedFloat32Array([1,1,1,1]))
	var base=face.colors.size()-4
	for i in range(4):
		var shade=a.shade if i in [0,3] else b.shade
		face.colors[base+i]=Color(shade,shade,shade,1)
	_append_quad(shadow,PackedVector2Array([a.bottom,b.bottom,b.foot,a.foot]),uv,PackedFloat32Array([.6,.6,0,0]))

func _near_bank_ramp(map: ACMap, pixel: Vector2) -> bool:
	for ramp in map.visual_ramps:
		var d=pixel/32.0-ramp.center;var axis: Vector2=ramp.direction
		if absf(d.dot(axis))<ramp.length*.5+1 and absf(d.dot(Vector2(axis.y,-axis.x)))<ramp.width*.5+1:return true
	return false

func _bank_chains(segments: Array) -> Array:
	var graph={};var visited={};var result=[];var seeds=[]
	for i in range(segments.size()):
		for point in segments[i]:
			var key=point.snapped(Vector2.ONE*.001)
			if not graph.has(key):graph[key]=[]
			graph[key].append(i)
	# Start open chains at their actual terminal, even if source triangles
	# arrived out of order. This prevents artificial endcaps along straight walls.
	for key in graph:
		if graph[key].size()!=2:seeds.append(key)
	seeds.append_array(graph.keys())
	for seed in seeds:
		var node=seed;var chain=PackedVector2Array([node])
		while true:
			var next=-1
			for candidate in graph[node]:
				if not visited.has(candidate):next=candidate;break
			if next<0:break
			visited[next]=true
			var pair=segments[next];var other=pair[1] if pair[0].snapped(Vector2.ONE*.001)==node else pair[0]
			node=other.snapped(Vector2.ONE*.001);chain.append(node)
			if node==seed:break
		if chain.size()>1:result.append(chain)
	return result

func _clean_bank_chain(points: PackedVector2Array) -> PackedVector2Array:
	# RDP has a measured 2px maximum deviation (1/16 of a gameplay cell).
	# Never move endpoints, bridge separate contours, or alter collision data.
	if points.size()<3:return points
	if points[0].is_equal_approx(points[-1]):
		var split=1;var far=0.0
		for i in range(1,points.size()-1):
			var d=points[0].distance_squared_to(points[i])
			if d>far:far=d;split=i
		var first=_simplify_bank_span(points.slice(0,split+1));var second=_simplify_bank_span(points.slice(split))
		first.append_array(second.slice(1));return first
	return _simplify_bank_span(points)

func _simplify_bank_span(points: PackedVector2Array) -> PackedVector2Array:
	var keep={0:true,points.size()-1:true};var stack=[[0,points.size()-1]]
	while not stack.is_empty():
		var span=stack.pop_back();var split=-1;var far=2.0
		for i in range(span[0]+1,span[1]):
			var d=points[i].distance_to(Geometry2D.get_closest_point_to_segment(points[i],points[span[0]],points[span[1]]))
			if d>far:far=d;split=i
		if split>=0:keep[split]=true;stack.append([span[0],split]);stack.append([split,span[1]])
	var result=PackedVector2Array()
	for i in range(points.size()):
		if keep.has(i):result.append(points[i])
	return result

func _bank_paths(segments: Array) -> Array:
	# Arc length, not X/Y projection: even vertical/diagonal banks retain their
	# full horizontal texel density. Shared nodes keep corners continuous.
	var graph={};var visited={};var result=[]
	for i in range(segments.size()):
		for p in segments[i]:
			var key=p.snapped(Vector2.ONE*.001)
			if not graph.has(key):graph[key]=[]
			graph[key].append(i)
	for first in range(segments.size()):
		if visited.has(first):continue
		var start=segments[first][0].snapped(Vector2.ONE*.001)
		var other=segments[first][1].snapped(Vector2.ONE*.001)
		if graph[other].size()==1:start=other
		var node=start;var length=0.0;var chain=[]
		while true:
			var next=-1
			for candidate in graph[node]:
				if not visited.has(candidate):next=candidate;break
			if next<0:break
			visited[next]=true
			var pair=segments[next].duplicate()
			if pair[0].snapped(Vector2.ONE*.001)!=node:pair.reverse()
			var end=length+pair[0].distance_to(pair[1])
			chain.append({"ends":pair,"u0":length/128.0,"u1":end/128.0})
			length=end;node=pair[1].snapped(Vector2.ONE*.001)
		var factor=(maxf(1,roundf(length/256.0))*256.0/length) if node==start and length>.001 else 1.0
		for segment in chain:segment.u0*=factor;segment.u1*=factor;result.append(segment)
	return result

func _material_span(slot: int) -> float:
	if slot>=224:return 128.0
	return QUIET_WORLD_SPAN if posmod(slot-192,4)==0 else 160.0

func _bank_point(map: ACMap, pixel: Vector2) -> Vector2:
	pixel=pixel.clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS)
	return Vector2(pixel.x,clampf(pixel.y-map.visual_elevation(pixel/32.0),0,WORLD_PIXELS))

func _level_light(level: float) -> float:
	return .80+.18*clampf(level,0,2)

func _diamond_layers(map: ACMap, fields: Array, levels: PackedFloat32Array=PackedFloat32Array()) -> Dictionary:
	# Edge-to-edge 192x96 diamonds. Texture coordinates AND material weights
	# belong to the world, never to a tile. Overlapping feathered tiles changed
	# coverage at every diamond edge, creating a repeating translucent lattice.
	var builders: Array=[]
	for i in range(4):builders.append(_builder())
	for row in range(87):
		for column in range(23):
			var center=Vector2(column*DIAMOND_SIZE.x+posmod(row,2)*DIAMOND_SIZE.x*.5,row*DIAMOND_SIZE.y*.5)
			for iy in range(8):
				for ix in range(8):
					var quad=PackedVector2Array();var uv=PackedVector2Array();var detail_uv=PackedVector2Array();var shades=PackedFloat32Array();var masks=[PackedFloat32Array(),PackedFloat32Array(),PackedFloat32Array(),PackedFloat32Array()]
					for corner in [Vector2(ix,iy),Vector2(ix+1,iy),Vector2(ix+1,iy+1),Vector2(ix,iy+1)]:
						var q=corner/8.0
						var pixel=center+Vector2((q.x-q.y)*DIAMOND_SIZE.x*.5,(q.x+q.y-1)*DIAMOND_SIZE.y*.5)
						pixel=pixel.clamp(Vector2.ZERO,Vector2.ONE*WORLD_PIXELS)
						var opacity=clampf(1.0-_field_at(fields[4],pixel)-smoothstep(.28,.42,_field_at(fields[5],pixel)),0,1)
						quad.append(Vector2(pixel.x,clampf(pixel.y-map.visual_elevation(pixel/32.0),0,WORLD_PIXELS)))
						uv.append(_detail_uv(pixel,QUIET_WORLD_SPAN))
						detail_uv.append(_detail_uv(pixel,160.0))
						shades.append(_level_light(_field_at(levels,pixel)) if not levels.is_empty() else 1.0)
						masks[0].append(opacity)
						# Alpha-over weights preserve each district's full material.
						# Only their boundaries mix; the previous .45/.55 multipliers
						# left every area looking predominantly like the first texture.
						var grit=clampf(_field_at(fields[2],pixel),0,1)
						var moss=clampf(_field_at(fields[3],pixel),0,1)
						var rock=clampf(_field_at(fields[1],pixel),0,1)
						masks[1].append(opacity*clampf(grit/maxf(.0001,1.0-moss-rock),0,1))
						masks[2].append(opacity*clampf(moss/maxf(.0001,1.0-rock),0,1))
						masks[3].append(opacity*rock)
					for group in range(4):
						var alpha: PackedFloat32Array=masks[group]
						if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))>.001:
							_append_quad(builders[group],quad,uv if group==0 else detail_uv,alpha)
							var base=builders[group].colors.size()-4
							for corner in range(4):builders[group].colors[base+corner]=Color(shades[corner],shades[corner],shades[corner],alpha[corner])
	var result=[];var vertices=0
	for i in range(4):
		if builders[i].vertices.is_empty():continue
		result.append({"mesh":_mesh(builders[i]),"slot":192+map.theme*4+i,"tint":Color(.93,.92,.89,1),"diamond":true})
		vertices+=builders[i].vertices.size()
	return {"layers":result,"vertices":vertices}

func _field_at(field: PackedFloat32Array, pixel: Vector2) -> float:
	# Bilinear sampling keeps transitions continuous across diamond boundaries.
	var p=(pixel/STEP).clamp(Vector2.ZERO,Vector2(GRID,GRID))
	var x=mini(int(p.x),GRID-1);var y=mini(int(p.y),GRID-1)
	var f=p-Vector2(x,y);var index=y*STRIDE+x
	return lerpf(lerpf(field[index],field[index+1],f.x),lerpf(field[index+STRIDE],field[index+STRIDE+1],f.x),f.y)

func _macro_uv(pixel: float) -> float:
	var sample = fposmod(pixel,1024.0)/512.0
	return sample if sample<=1.0 else 2.0-sample

func _ground_uv(pixel: Vector2) -> Vector2:
	# Large diamond sampling belongs to the visual plane; logical paths and
	# buildings remain on their original horizontal/vertical tile grid.
	return Vector2(pixel.x*.75+pixel.y*1.5,-pixel.x*.75+pixel.y*1.5)/512.0

func _detail_uv(pixel: Vector2, span: float=DETAIL_WORLD_PIXELS) -> Vector2:
	# Orthogonal rotation gives the same density in either screen direction.
	# Continuous low-frequency warp removes long straight repeat axes; it is
	# shared by adjacent vertices, so it cannot open cracks at cell borders.
	pixel+=Vector2(pow(sin(pixel.y*.0027),2),pow(sin(pixel.x*.0021),2))*34.0
	return Vector2(pixel.x+pixel.y,-pixel.x+pixel.y)*.7071067811865476/span

func _builder() -> Dictionary:
	return {"vertices":PackedVector2Array(),"uv":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}

func _append_quad(builder: Dictionary, vertices: PackedVector2Array, uv: PackedVector2Array, alpha: PackedFloat32Array) -> void:
	var offset = builder.vertices.size()
	builder.vertices.append_array(vertices)
	builder.uv.append_array(uv)
	for value in alpha:builder.colors.append(Color(1,1,1,value))
	builder.indices.append_array(PackedInt32Array([offset,offset+1,offset+2,offset,offset+2,offset+3]))

func _mesh(builder: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.vertices
	arrays[Mesh.ARRAY_COLOR] = builder.colors
	arrays[Mesh.ARRAY_TEX_UV] = builder.uv
	arrays[Mesh.ARRAY_INDEX] = builder.indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func _cliff_mesh(_map: ACMap, points: PackedVector2Array, rock: PackedFloat32Array) -> ArrayMesh:
	var builder=_builder()
	var opacity=PackedFloat32Array()
	opacity.resize(STRIDE*STRIDE)
	# Shade the same continuous surface instead of drawing separate tile-wall
	# billboards. A south-facing height drop exposes the generated rock face;
	# the interpolated unwalkable-rock mask excludes every walkable ramp.
	for gy in range(STRIDE):
		for gx in range(STRIDE):
			var index=gy*STRIDE+gx
			var north=maxi(0,gy-1)*STRIDE+gx
			var south=mini(GRID,gy+1)*STRIDE+gx
			var high=float(maxi(0,gy-1))*STEP-points[north].y
			var low=float(mini(GRID,gy+1))*STEP-points[south].y
			var mask=maxf(rock[index],maxf(rock[north],rock[south]))
			var west=gy*STRIDE+maxi(0,gx-1)
			var east=gy*STRIDE+mini(GRID,gx+1)
			var side=absf(points[west].y-points[east].y)
			mask=maxf(mask,maxf(rock[west],rock[east]))
			var slope=maxf(maxf(high-low,(low-high)*.65),side*.85)
			opacity[index]=smoothstep(6.0,25.0,slope)*mask*.98
	for gy in range(GRID):
		for gx in range(GRID):
			var indices=[gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
			var alpha=PackedFloat32Array([opacity[indices[0]],opacity[indices[1]],opacity[indices[2]],opacity[indices[3]]])
			if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
			var uv=PackedVector2Array()
			for index in indices:uv.append(points[index]/CLIFF_WORLD_PIXELS)
			_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
	return _mesh(builder) if not builder.vertices.is_empty() else null

func _relief_lighting(points: PackedVector2Array, rock: PackedFloat32Array, water: PackedFloat32Array) -> Array:
	var shadow=PackedFloat32Array()
	var rim=PackedFloat32Array()
	shadow.resize(STRIDE*STRIDE)
	rim.resize(STRIDE*STRIDE)
	for gy in range(STRIDE):
		for gx in range(STRIDE):
			var index=gy*STRIDE+gx
			var height=float(gy)*STEP-points[index].y
			var high=height
			var low=height
			var mask=rock[index]
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var other=Vector2i(clampi(gx+offset.x,0,GRID),clampi(gy+offset.y,0,GRID))
				var next=other.y*STRIDE+other.x
				var rise=float(other.y)*STEP-points[next].y
				high=maxf(high,rise)
				low=minf(low,rise)
				mask=maxf(mask,rock[next])
			var span=high-low
			if span<12:continue
			var fraction=(height-low)/span
			var strength=smoothstep(12.0,32.0,span)*mask*(1-water[index])
			shadow[index]=(1-smoothstep(.12,.62,fraction))*strength*.48
			rim[index]=smoothstep(.60,.94,fraction)*strength*.42
	var meshes: Array=[]
	for alpha_field in [shadow,rim]:
		var builder=_builder()
		for gy in range(GRID):
			for gx in range(GRID):
				var indices=[gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
				var alpha=PackedFloat32Array([alpha_field[indices[0]],alpha_field[indices[1]],alpha_field[indices[2]],alpha_field[indices[3]]])
				if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
				var uv=PackedVector2Array()
				for index in indices:uv.append(_detail_uv(Vector2(index%STRIDE,index/STRIDE)*STEP))
				_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
		meshes.append(_mesh(builder) if not builder.vertices.is_empty() else null)
	return meshes

func _ramp_mesh(map: ACMap, points: PackedVector2Array, levels: PackedFloat32Array=PackedFloat32Array()) -> ArrayMesh:
	var builder=_builder()
	var opacity=PackedFloat32Array()
	var light=PackedFloat32Array()
	opacity.resize(STRIDE*STRIDE)
	light.resize(STRIDE*STRIDE)
	for gy in range(STRIDE):
		for gx in range(STRIDE):
			var point=Vector2(gx*.5,gy*.5)
			var cell=Vector2i(point.clamp(Vector2.ZERO,Vector2(127.999,127.999)))
			if map.terrain[cell.y*128+cell.x]!=0:continue
			var index=gy*STRIDE+gx
			for region in map.visual_ramps:
				var direction: Vector2=region.direction
				var tangent=Vector2(direction.y,-direction.x)
				var delta: Vector2=point-region.center
				var fraction=Vector2(.5+delta.dot(tangent)/float(region.width),.5+delta.dot(direction)/float(region.length))
				if fraction.x<=0 or fraction.x>=1 or fraction.y<=0 or fraction.y>=1:continue
				var edge=smoothstep(0.0,.18,minf(fraction.x,1-fraction.x))*smoothstep(0.0,.15,minf(fraction.y,1-fraction.y))
				if edge*.65<=opacity[index]:continue
				opacity[index]=edge*.65
				# A slope is the same continuous soil as its upper/lower landing,
				# read through a gentle height gradient, not a separate gravel road.
				light[index]=lerpf(1.08,.90,smoothstep(0.0,1.0,fraction.y))
	for gy in range(GRID):
		for gx in range(GRID):
			var indices=[gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
			var alpha=PackedFloat32Array([opacity[indices[0]],opacity[indices[1]],opacity[indices[2]],opacity[indices[3]]])
			if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
			var uv=PackedVector2Array()
			for index in indices:uv.append(_detail_uv(Vector2(index%STRIDE,index/STRIDE)*STEP,QUIET_WORLD_SPAN if quiet_materials.size()==12 else MATERIAL_WORLD_PIXELS))
			_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
			var base=builder.colors.size()-4
			for vertex in range(4):
				var shade=light[indices[vertex]]*(_level_light(levels[indices[vertex]]) if not levels.is_empty() else 1.0)
				builder.colors[base+vertex]=Color(shade,shade,shade,alpha[vertex])
	return _mesh(builder) if not builder.vertices.is_empty() else null

func _update_fog(data: Dictionary, fog: Callable, revision: int=-1) -> void:
	if revision!=-1 and data.get("fog_revision",-2)==revision and data.fog_texture!=null:return
	var now = Time.get_ticks_msec()
	if now-int(data.fog_updated)<100:return
	data.fog_updated=now
	data.fog_revision=revision
	var bytes := PackedByteArray()
	bytes.resize(128*128*4)
	fog_samples.resize(128*128)
	for index in range(128*128):
		var state = int(fog.call(index))
		var light = 1.0 if state==2 else (.32 if state==1 else 0.0)
		fog_samples[index]=light
		bytes[index*4+3] = roundi((1.0-light)*255.0)
	var signature = hash(bytes)
	if data.fog_texture!=null and signature==data.fog_hash:return
	data.fog_hash=signature
	var image = Image.create_from_data(128,128,false,Image.FORMAT_RGBA8,bytes)
	# Hardware filtering reconstructs the cover from source cells. Entity
	# visibility remains strict; no full-map cubic CPU resize is needed.
	if data.fog_texture==null:data.fog_texture=ImageTexture.create_from_image(image)
	else:data.fog_texture.update(image)

func _draw_cropped(canvas: CanvasItem, texture: Texture2D, destination: Rect2, clip: Rect2, color: Color) -> void:
	var cropped = destination.intersection(clip)
	if not cropped.has_area():return
	var scale = Vector2(texture.get_width(),texture.get_height())/destination.size
	canvas.draw_texture_rect_region(texture,cropped,Rect2((cropped.position-destination.position)*scale,cropped.size*scale),color,false,true)

func _draw_props(canvas: CanvasItem, map: ACMap, clip: Rect2, zoom: float, project: Callable, fog: Callable) -> void:
	if scenery_textures.size()>=36 and _cache.has(map.get_instance_id()):
		for prop in _cache[map.get_instance_id()].props:
			var p: Vector2=prop.pos
			if int(fog.call(int(p.y)*128+int(p.x)))==0:continue
			var point: Vector2=project.call(p)
			point.y-=map.visual_elevation(p)*zoom
			if not clip.grow(120).has_point(point):continue
			var texture=scenery_textures[prop.slot]
			var width=float(prop.width)*zoom
			var height=width*texture.get_height()/texture.get_width()
			_draw_cropped(canvas,texture,Rect2(point-Vector2(width*.5,height*.86),Vector2(width,height)),clip,Color(.94,.93,.90,1))
		return
	if prop_textures.is_empty():return
	for prop in map.decorations:
		var p = ACData.point(prop.pos)
		if not map.inside(Vector2i(p)):continue
		if int(fog.call(int(p.y)*128+int(p.x)))==0:continue
		var point: Vector2 = project.call(p+Vector2(.5,.5))
		point.y -= map.visual_elevation(p+Vector2(.5,.5))*zoom
		if not clip.grow(100).has_point(point):continue
		var slots = [0,1,2,3,11] if map.theme==0 else ([8,9,10,11] if map.theme==1 else [0,3,5,12])
		var slot = slots[posmod(int(prop.get("kind",0))+int(prop.get("variant",0)),slots.size())]
		var texture = prop_textures[slot]
		if texture==null:continue
		var width = (42.0 if slot in [8,11] else 68.0)*float(prop.get("scale",1.0))*zoom
		var height = width*float(texture.get_height())/float(texture.get_width())
		_draw_cropped(canvas,texture,Rect2(point-Vector2(width*.5,height*.82),Vector2(width,height)),clip,Color(.92,.91,.87,1))

func _scenery(map: ACMap) -> Array:
	# Visual-only deterministic scatter. It never modifies collision/navigation.
	var result=[]
	var rng=RandomNumberGenerator.new();rng.seed=61937+map.theme*971
	var clusters=FastNoiseLite.new();clusters.seed=27193+map.theme*811;clusters.frequency=.065
	for y in range(3,125,5):
		for x in range(3,125,5):
			# Broad quiet combat areas, with small patches near terrain features.
			var density=smoothstep(-.08,.32,clusters.get_noise_2d(x,y))
			var feature=false
			for offset in [Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3)]:
				var q=Vector2i(x,y)+offset
				if map.inside(q) and (map.terrain[q.y*128+q.x]!=0 or map.height_map[q.y*128+q.x]!=map.height_map[y*128+x]):feature=true
			if rng.randf()>density*(.80 if feature else .22):continue
			var center=Vector2(x,y)+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))
			for member in range(rng.randi_range(1,2)):
				var p=center+Vector2(rng.randf_range(-2.4,2.4),rng.randf_range(-2.4,2.4))
				if not _scenery_safe(map,p):continue
				var rock=map.terrain[int(p.y)*128+int(p.x)]==1
				var choices=([0,4,5,6,7,11] if member==0 else [0,4,5,6,11]) if not rock else [1,2,3,6,8,9,10]
				if scenery_textures.size()>=54:choices.append_array([12,16] if not rock else [13,14,15,17])
				if scenery_textures.size()==90:choices.append_array([18,19,20,21,28,29] if not rock else [22,23,24,25,26,27])
				var kind=int(choices[rng.randi_range(0,choices.size()-1)])
				var structure=kind in [1,2,3,8,9,10,13,14,15,17,22,23,24,25,26,27]
				if structure:
					var solid=true
					for offset in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
						var q=Vector2i(p+offset)
						if map.terrain[q.y*128+q.x]!=1:solid=false
					if not solid:continue
					if not _bank_decor_clear(map,p):continue
				var slot=map.theme*4+kind if kind<4 else 12+map.theme*8+kind-4
				if kind>=12:slot=36+map.theme*6+kind-12
				if kind>=18:slot=54+map.theme*12+kind-18
				var width=([35,63,84,62,27,38,28,50,76,54,58,34,40,65,86,64,44,84,34,44,26,40,50,72,52,78,62,70,32,25][kind])*rng.randf_range(.8,1.15)
				result.append({"pos":p,"slot":slot,"kind":kind,"width":width,"structure":structure})
	result=_diversify_scenery(map,result)
	# These are authored solid rocks, not optional decorative scatter. They
	# must remain visible even near bases and ramps, at their actual footprint.
	if map.source_walk_masks.size()==128*128:
		for y in range(1,127):
			for x in range(1,127):
				var index=y*128+x
				if map.visual_role(index)!=3 or map.source_walk_masks[index]!=0 or (x+y)%2!=0:continue
				var kind=1 if (x*7+y*13)%3!=0 else 13
				var slot=map.theme*4+1 if kind==1 else 13+map.theme*8
				if slot>=scenery_textures.size():continue
				result.append({"pos":Vector2(x,y),"slot":slot,"kind":kind,"width":33.0,"structure":true,"source_obstacle":true})
	result.sort_custom(func(a,b):return a.pos.y<b.pos.y)
	return result

func _decor_family(kind: int) -> int:
	for family in [[0,4,12,18],[5,7,16,19],[6,11,20,29],[21],[28],[1,13],[2,8,14,23],[3,9,15,24],[10,17,25],[22,26,27]]:
		if kind in family:return family[0]
	return kind

func _diversify_scenery(map: ACMap, candidates: Array) -> Array:
	var result=[];var buckets={}
	for original in candidates:
		var p: Vector2=original.pos;var cell=Vector2i((p/4.0).floor());var neighbors=[]
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):neighbors.append_array(buckets.get(Vector2i(x,y),[]))
		var source=original.get("source_obstacle",false)
		var choices=[0,4,5,6,7,11,12,16,18,19,20,21,28,29]
		if original.structure:choices=[1,2,3,8,9,10,13,14,15,17,22,23,24,25,26,27]
		if source:choices=[1,13,20,29,6,11]
		if original.structure and not _bank_decor_clear(map,p):choices=[1,13,20,29,6,11] if source else [1,13]
		var best=-1;var best_score=INF
		var seed=posmod(int(p.x*137+p.y*239)+map.theme*197,choices.size())
		for offset in range(choices.size()):
			var kind=choices[(offset+seed)%choices.size()];var score=offset*.002
			var tall=kind in [2,3,8,9,10,14,15,17,22,23,24,25,26,27]
			if tall:
				for placed in result:
					if placed.kind in [2,3,8,9,10,14,15,17,22,23,24,25,26,27] and p.distance_squared_to(placed.pos)<100:score+=1000;break
			for nearby in neighbors:
				var distance=p.distance_to(nearby.pos)
				if kind==nearby.kind and distance<3.6:score+=100+(3.6-distance)*20
				elif _decor_family(kind)==_decor_family(nearby.kind) and distance<2.2:score+=10+(2.2-distance)*5
				if not source and distance<1.6:score+=1000
			if score<best_score:best=kind;best_score=score
		# Continuous rock material already marks source obstacles; every sprite
		# is optional when a pocket has no distinct, spaced combination left.
		if best_score>=10:continue
		var prop=original.duplicate();prop.kind=best
		prop.slot=map.theme*4+best if best<4 else 12+map.theme*8+best-4
		if best>=12:prop.slot=36+map.theme*6+best-12
		if best>=18:prop.slot=54+map.theme*12+best-18
		if not source:
			var widths=[35,63,84,62,27,38,28,50,76,54,58,34,40,65,86,64,44,84,34,44,26,40,50,72,52,78,62,70,32,25]
			prop.width=widths[best]*(.85+float(posmod(int(p.x*173+p.y*97),100))*.0025)
		elif best in [1,13,20,29,6,11]:
			prop.width=minf(float(prop.width),52.0)*(.72+float(posmod(int(p.x*173+p.y*97),100))*.003)
		result.append(prop)
		if not buckets.has(cell):buckets[cell]=[]
		buckets[cell].append(prop)
	return result

func _bank_decor_clear(map: ACMap, p: Vector2) -> bool:
	# Keep tall scenery off the silhouette and ramp mouths. Authored low
	# obstacle markers remain visible; this applies only to extra scenery.
	var cell=Vector2i(p);var height=map.height_map[cell.y*128+cell.x]
	for y in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			if x<0 or y<0 or x>=128 or y>=128:return false
			var index=y*128+x
			if map.is_water(index) or map.height_map[index]!=height or map.visual_role(index)==1:return false
	return not _near_bank_ramp(map,p*32.0)

func _scenery_safe(map: ACMap, p: Vector2) -> bool:
	if p.x<2 or p.y<2 or p.x>125 or p.y>125:return false
	if map.is_water(int(p.y)*128+int(p.x)):return false
	if map.visual_role(int(p.y)*128+int(p.x))==3:return false
	for start in map.starts:
		if p.distance_to(ACData.point(start))<8:return false
	for resource in map.resources:
		if p.distance_to(ACData.point(resource.pos))<4:return false
	for base in map.bases:
		if p.distance_to(ACData.point(base.get("center",base.get("pos",[0,0]))))<5:return false
	for ramp in map.ramps:
		if p.distance_to(ACData.point(ramp.center))<float(ramp.get("width",4))*.5+2:return false
	return true

func _surface_fallback(map: ACMap, index: int) -> int:
	return 7 if map.terrain[index]==2 else (6 if map.terrain[index]==1 else (1 if map.height_map[index]>0 else 0))

func _rise(map: ACMap, x: int, y: int) -> float:
	return map.visual_cell_elevation(x,y)

func _water_source_rect(world_pixels: Vector2, clock: float) -> Rect2:
	if water_texture==null:return Rect2()
	var size = Vector2(water_texture.get_width(),water_texture.get_height())-Vector2.ONE
	var scale = size/256.0
	var pan = Vector2(sin(clock*.12)*7.0,cos(clock*.09)*5.0)
	return Rect2(Vector2(.5,.5)+Vector2(fposmod(world_pixels.x+pan.x,224.0),fposmod(world_pixels.y+pan.y,224.0))*scale,Vector2(32,32)*scale)

func terrain_color(map: ACMap, index: int) -> Color:
	if index<0 or index>=map.terrain.size():return Color.BLACK
	if map.is_water(index):return WATER_COLOR
	var surface = int(map.surface_map[index]) if map.surface_map.size()>index else _surface_fallback(map,index)
	return [Color("706c57"),Color("a09267"),Color("89816a"),Color("a19c83"),Color("848a86"),Color("a7a290"),Color("3b403b"),WATER_COLOR][surface]
