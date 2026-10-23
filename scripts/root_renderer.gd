class_name ACRootRenderer
extends RefCounted

const FIELD=preload("res://scripts/root_field.gd")
var texture: CanvasTexture
var mesh: ArrayMesh
var signature=0
var tile_count=0
var vertex_count=0
var geometry_key=0
var allowed_cache={}
var vertex_cache={}
var uv_cache={}
var build_count=0
var visibility_input=0
var local_visibility_signature=0
const CHUNK_SIZE=8
const CHUNKS_PER_FRAME=3
var chunks={}
var pending=[]
var chunk_input=0
var region=Rect2i()

func _corner_fog(corner: Vector2i, fog: Callable) -> Vector2:
	var light=0.0;var known=1.0
	for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		var cell=(corner+offset).clamp(Vector2i.ZERO,Vector2i(255,255))
		var value=int(fog.call(FIELD.ground_index(cell.y*256+cell.x)))
		if value==0:known=0.0
		light+=1.0 if value==2 else .38
	return Vector2(light*.25,known)

func _allowed(map: ACMap, cell: Vector2i) -> bool:
	if cell.x<0 or cell.y<0 or cell.x>=256 or cell.y>=256:return false
	var key=cell.y*256+cell.x
	if not allowed_cache.has(key):allowed_cache[key]=FIELD.terrain_allows(map,cell)
	return allowed_cache[key]

func relevant_fog_signature(packed, fog: Callable) -> int:
	var values=PackedByteArray();var seen={}
	for value in packed:
		var index=FIELD.ground_index(int(value)&0xffff)
		if seen.has(index):continue
		seen[index]=true
		for y in range(maxi(0,index/128-1),mini(128,index/128+2)):
			for x in range(maxi(0,index%128-1),mini(128,index%128+2)):values.append(fog.call(y*128+x))
	return hash(values)

func load_art() -> void:
	var file="res://assets/v062/terrain/citrus_root_ground_readable_20261024.png"
	if not ResourceLoader.exists(file):file="res://assets/v062/terrain/citrus_root_ground.png"
	if not ResourceLoader.exists(file):file="res://assets/citrus_root_ground_v058.png"
	var image=load(file).get_image()
	image.generate_mipmaps()
	texture=CanvasTexture.new();texture.diffuse_texture=ImageTexture.create_from_image(image)
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED

func _ground_uv(point: Vector2) -> Vector2:
	# Smooth world-space variation breaks the visible tile rhythm without
	# mirrors, seams, camera-dependent movement, or per-frame image generation.
	var pixels=point*32.0
	var warp=Vector2(
		sin(pixels.y/173.0+pixels.x/457.0)*27.0+sin(pixels.y/311.0)*19.0,
		sin(pixels.x/211.0-pixels.y/521.0)*25.0+sin(pixels.x/367.0)*21.0)
	return (pixels+warp)/768.0

func _corner_value(corner: Vector2i, cells: Dictionary, map: ACMap) -> float:
	var total=0.0
	for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		var cell=corner+offset
		# Fade into the bank on the land side. Never paint the vertical wall,
		# water, or a blocked cell and never let the texture bridge a gap.
		if not _allowed(map,cell):return 0.0
		total+=float(cells.get(cell.y*FIELD.WIDTH+cell.x,0.0))
	return smoothstep(.08,.8,total*.25)

func build(map: ACMap, packed, fog: Callable) -> void:
	build_count+=1
	var geometry=hash([map.get_instance_id(),map.render_signature,map.source_detail_active])
	if geometry!=geometry_key:
		geometry_key=geometry;allowed_cache.clear();vertex_cache.clear();uv_cache.clear()
	var cells={};var candidates={}
	for value in packed:
		var index=int(value)&0xffff;var cell=Vector2i(index%256,index/256)
		if fog.call(FIELD.ground_index(index))==0 or not _allowed(map,cell):continue
		cells[index]=float(int(value)>>18)/255.0
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				var neighbor=Vector2i(x,y)
				if not candidates.has(y*256+x) and _allowed(map,neighbor) and fog.call(FIELD.ground_index(y*256+x))>0:candidates[y*256+x]=neighbor
	tile_count=cells.size();var builder=ACTerrainRenderer.new()._builder();var corners={};var corner_lights={}
	for index in candidates:
		var cell: Vector2i=candidates[index]
		if region.has_area() and not region.has_point(cell):continue
		var vertices=PackedVector2Array();var uv=PackedVector2Array();var alpha=PackedFloat32Array()
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
			var corner=cell+offset
			if not corners.has(corner):corners[corner]=_corner_value(corner,cells,map)
			var point=Vector2(corner)*.5-Vector2.ONE*.5
			point=point.clamp(Vector2.ZERO,Vector2.ONE*128)
			if not vertex_cache.has(corner):vertex_cache[corner]=Vector2(point.x*32,point.y*32-map.visual_elevation(point))
			vertices.append(vertex_cache[corner])
			# Continuous world UVs keep tiny growth tiles from looking like stamps.
			if not uv_cache.has(corner):uv_cache[corner]=_ground_uv(point)
			uv.append(uv_cache[corner]);alpha.append(corners[corner])
		if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
		var start=builder.vertices.size()
		builder.vertices.append_array(vertices);builder.uv.append_array(uv)
		# Shared vertex lighting removes square fog seams. Unknown ground stays hidden.
		var offsets=[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]
		for i in range(4):
			var corner=cell+offsets[i]
			if not corner_lights.has(corner):corner_lights[corner]=_corner_fog(corner,fog)
			var visibility: Vector2=corner_lights[corner]
			builder.colors.append(Color(.9*visibility.x,.9*visibility.x,.9*visibility.x,.88*alpha[i]*visibility.y))
		builder.indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	vertex_count=builder.vertices.size()
	mesh=ACTerrainRenderer.new()._mesh(builder) if vertex_count>0 else null

func draw(canvas: CanvasItem, map: ACMap, packed, fog: Callable, zoom: float, project: Callable, fog_signature: int) -> void:
	if texture==null:load_art()
	update_chunks(map,packed,fog,fog_signature)
	var transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),project.call(Vector2.ZERO))
	for chunk in chunks.values():
		if chunk.display_mesh!=null:canvas.draw_mesh(chunk.display_mesh,texture,transform)
	# The battle viewport redraws every process frame. Deferred redraws here
	# could rebuild several chunk batches inside one frame and cause a spike.

func update_chunks(map: ACMap, packed, fog: Callable, fog_signature: int) -> void:
	var geometry=hash([map.get_instance_id(),map.render_signature,map.source_detail_active])
	if geometry!=geometry_key:
		geometry_key=geometry;chunks.clear();pending.clear();chunk_input=0
	var next=hash([geometry,packed,fog_signature])
	if next!=chunk_input:
		chunk_input=next
		var groups={}
		# A one-cell halo supplies identical corner values across chunk borders.
		for value in packed:
			var index=int(value)&0xffff;var cell=Vector2i(index%256,index/256)
			for cy in range(maxi(0,cell.y-1)/CHUNK_SIZE,mini(255,cell.y+1)/CHUNK_SIZE+1):
				for cx in range(maxi(0,cell.x-1)/CHUNK_SIZE,mini(255,cell.x+1)/CHUNK_SIZE+1):
					var key=Vector2i(cx,cy)
					if not groups.has(key):groups[key]=PackedInt32Array()
					groups[key].append(value)
		for key in chunks.keys():
			if not groups.has(key):chunks.erase(key)
		pending.clear();tile_count=packed.size()
		for key in groups:
			var values=groups[key]
			var fog_hash=relevant_fog_signature(values,fog)
			var version=hash([values,fog_hash])
			if not chunks.has(key):chunks[key]={"mesh":null,"display_mesh":null,"signature":0,"fog":fog_hash,"renderer":get_script().new()}
			var chunk=chunks[key]
			if chunk.fog!=fog_hash:chunk.mesh=null # Never show stale visibility while queued.
			chunk.fog=fog_hash
			if chunk.signature!=version:pending.append({"key":key,"values":values,"signature":version})
	var started=Time.get_ticks_usec();var count=0
	while not pending.is_empty() and count<CHUNKS_PER_FRAME:
		var job=pending.pop_front();var chunk=chunks[job.key];var renderer=chunk.renderer
		renderer.region=Rect2i(job.key*CHUNK_SIZE,Vector2i.ONE*CHUNK_SIZE)
		renderer.build(map,job.values,fog)
		chunk.mesh=renderer.mesh;chunk.signature=job.signature;build_count+=1;count+=1
		if Time.get_ticks_usec()-started>=2000:break
	# Publish a complete boundary together, never expose rectangular work tiles.
	if pending.is_empty():
		for chunk in chunks.values():chunk.display_mesh=chunk.mesh
