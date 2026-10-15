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
var relief_textures: Array[Texture2D] = []
var prop_textures: Array[Texture2D] = []
var transition_textures: Array[Texture2D] = []
var fog_samples := PackedFloat32Array()
var last_stats: Dictionary = {}
var _cache: Dictionary = {}

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
	transition_textures = _load_cells("res://assets/terrain_transitions.png",false)
	_cache.clear()

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

func draw(canvas: CanvasItem, map: ACMap, view: Rect2, zoom: float, project: Callable, _unproject: Callable, fog: Callable, _clock: float) -> void:
	var started = Time.get_ticks_usec()
	if not loaded:load_art()
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	canvas.draw_rect(view,Color.BLACK)
	var key = map.get_instance_id()
	var signature = hash([map.terrain,map.height_map,map.surface_map,map.theme])
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
	_update_fog(data,fog)
	if data.fog_texture != null:
		_draw_cropped(canvas,data.fog_texture,world_rect,clip,Color.WHITE)
		calls += 1
	var detail=_texture(16+map.theme)
	last_stats = {"draw_commands":calls,"mesh_vertices":data.vertices,"cache_build_ms":data.build_ms,"draw_cpu_ms":float(Time.get_ticks_usec()-started)/1000.0,"map_bounds":world_rect,"material_signature":signature,"detail_resolution":Vector2i(detail.get_width(),detail.get_height()) if detail!=null else Vector2i.ZERO,"detail_world_span":DETAIL_WORLD_PIXELS,"detail_texels_per_screen_pixel":float(detail.get_width())/(DETAIL_WORLD_PIXELS*zoom) if detail!=null else 0.0}

func _texture(slot: int) -> Texture2D:
	if slot<0:return null
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

func _build_cache(map: ACMap, signature: int) -> Dictionary:
	var started = Time.get_ticks_usec()
	var classes := PackedByteArray()
	classes.resize(128*128)
	for i in range(classes.size()):
		var surface = int(map.surface_map[i]) if map.surface_map.size()>i else _surface_fallback(map,i)
		classes[i] = 5 if map.is_water(i) else (4 if map.terrain[i]==1 else (1 if surface==3 else (2 if surface==4 else (3 if surface==5 else (6 if surface==1 else 0)))))
	var fields: Array = []
	for layer in range(7):
		var field := PackedFloat32Array()
		field.resize(STRIDE*STRIDE)
		fields.append(field)
	var points := PackedVector2Array()
	points.resize(STRIDE*STRIDE)
	for gy in range(STRIDE):
		for gx in range(STRIDE):
			var p = Vector2(gx*.5,gy*.5)
			# Boundary displacement affects art alone, preserving every nav cell.
			var warp = Vector2(sin(p.y*1.31+p.x*.17),sin(p.x*1.13-p.y*.23))*.18
			var sample = p+warp-Vector2(.5,.5)
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
					rise += weight*_rise(map,source%128,source/128)
			points[index] = Vector2(p.x*32.0,clampf(p.y*32.0-rise,0,WORLD_PIXELS))
	var layers: Array = []
	var vertices = 0
	var default_slot = 1 if map.theme==0 else (13 if map.theme==1 else 3)
	var ground_slot=16+map.theme if _texture(16+map.theme)!=null else default_slot
	var floor_slot=35+map.theme if _texture(35+map.theme)!=null else 8
	var slots = [ground_slot,floor_slot,ground_slot,ground_slot,floor_slot,10,ground_slot]
	for layer in range(7):
		var builder = _builder()
		for gy in range(GRID):
			for gx in range(GRID):
				var indices = [gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
				var alpha = PackedFloat32Array([1,1,1,1]) if layer==0 else PackedFloat32Array([fields[layer][indices[0]],fields[layer][indices[1]],fields[layer][indices[2]],fields[layer][indices[3]]])
				# Secondary surfaces blend with the same planet's base material;
				# they must not look like a pasted patch from another tileset.
				if layer in [1,2,3]:
					for corner in range(4):alpha[corner]*=.32 if layer==1 else .48
				if layer==4:
					for corner in range(4):alpha[corner]*=.46
				if layer>0 and maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
				# Detail has uniform texel density on both axes. The old 2:1 UV
				# magnified one axis, turning a 313px crop into several screen px
				# per source pixel at zoom2. Water keeps its previous UV unchanged.
				var pixel = Vector2(gx*STEP,gy*STEP)
				var span=DETAIL_WORLD_PIXELS if layer in [0,2,3,6] else MATERIAL_WORLD_PIXELS
				var legacy=layer==5 or (layer in [0,6] and ground_slot==default_slot)
				var uv=PackedVector2Array()
				for offset in [Vector2.ZERO,Vector2(STEP,0),Vector2(STEP,STEP),Vector2(0,STEP)]:
					uv.append(_ground_uv(pixel+offset) if legacy else _detail_uv(pixel+offset,span))
				_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
				if layer==0:
					# Slow world-space variation breaks up mirrored texture motifs
					# without introducing per-tile borders or new draw calls.
					var base=builder.colors.size()-4
					for corner in range(4):
						var p=Vector2(indices[corner]%STRIDE,indices[corner]/STRIDE)*STEP
						var shade=1.0+.035*sin(p.x*.006+p.y*.003)+.025*cos(p.y*.009-p.x*.002)
						builder.colors[base+corner]=Color(shade,shade,shade,1)
		if not builder.vertices.is_empty():
			var tint = Color(.93,.92,.89,1) if layer!=5 else WATER_MODULATE
			if layer==6:tint=Color(1.04,1.02,.98,1)
			if layer==2:tint=Color(.85,.88,.88,1)
			if layer==3:tint=Color(1.06,1.03,.97,1)
			if _texture(slots[layer])==null:tint *= PALETTE[slots[layer]]
			layers.append({"mesh":_mesh(builder),"slot":slots[layer],"tint":tint})
			vertices += builder.vertices.size()
	# Broad flat diamonds fade along their perimeter, without a frame or bevel.
	for variation in range(2):
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
	var ramps_mesh=_ramp_mesh(map,points)
	if ramps_mesh!=null:layers.append({"mesh":ramps_mesh,"slot":floor_slot,"role":"ramp","tint":Color(1.05,1.02,.96,1)})
	var cliffs = _cliff_mesh(map,points,fields[4])
	var cliff_slot=32+map.theme if _texture(32+map.theme)!=null else 9
	if cliffs != null:layers.append({"mesh":cliffs,"slot":cliff_slot,"role":"cliff","tint":Color(.70,.69,.66,1) if map.theme==0 else (Color(.65,.61,.57,1) if map.theme==1 else Color(.60,.63,.68,1))})
	var lighting=_relief_lighting(points,fields[4],fields[5])
	if lighting[0]!=null:layers.append({"mesh":lighting[0],"slot":-1,"role":"foot_shadow","tint":Color(.045,.039,.033,1)})
	if lighting[1]!=null:layers.append({"mesh":lighting[1],"slot":ground_slot,"role":"upper_lip","tint":Color(1.45,1.37,1.23,1)})
	return {"signature":signature,"layers":layers,"vertices":vertices,"build_ms":float(Time.get_ticks_usec()-started)/1000.0,"fog_texture":null,"fog_hash":0,"fog_updated":-1000}

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

func _ramp_mesh(map: ACMap, points: PackedVector2Array) -> ArrayMesh:
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
				light[index]=lerpf(1.16,.86,fraction.y)
	for gy in range(GRID):
		for gx in range(GRID):
			var indices=[gy*STRIDE+gx,gy*STRIDE+gx+1,(gy+1)*STRIDE+gx+1,(gy+1)*STRIDE+gx]
			var alpha=PackedFloat32Array([opacity[indices[0]],opacity[indices[1]],opacity[indices[2]],opacity[indices[3]]])
			if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
			var uv=PackedVector2Array()
			for index in indices:uv.append(_detail_uv(Vector2(index%STRIDE,index/STRIDE)*STEP,MATERIAL_WORLD_PIXELS))
			_append_quad(builder,PackedVector2Array([points[indices[0]],points[indices[1]],points[indices[2]],points[indices[3]]]),uv,alpha)
			var base=builder.colors.size()-4
			for vertex in range(4):
				var shade=light[indices[vertex]]
				builder.colors[base+vertex]=Color(shade,shade,shade,alpha[vertex])
	return _mesh(builder) if not builder.vertices.is_empty() else null

func _update_fog(data: Dictionary, fog: Callable) -> void:
	var now = Time.get_ticks_msec()
	if now-int(data.fog_updated)<100:return
	data.fog_updated=now
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
	# Reconstruct only terrain cover at 8px resolution; entity fog stays strict.
	image.resize(512,512,Image.INTERPOLATE_CUBIC)
	if data.fog_texture==null:data.fog_texture=ImageTexture.create_from_image(image)
	else:data.fog_texture.update(image)

func _draw_cropped(canvas: CanvasItem, texture: Texture2D, destination: Rect2, clip: Rect2, color: Color) -> void:
	var cropped = destination.intersection(clip)
	if not cropped.has_area():return
	var scale = Vector2(texture.get_width(),texture.get_height())/destination.size
	canvas.draw_texture_rect_region(texture,cropped,Rect2((cropped.position-destination.position)*scale,cropped.size*scale),color,false,true)

func _draw_props(canvas: CanvasItem, map: ACMap, clip: Rect2, zoom: float, project: Callable, fog: Callable) -> void:
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
