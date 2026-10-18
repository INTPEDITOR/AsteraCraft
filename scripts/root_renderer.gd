class_name ACRootRenderer
extends RefCounted

const FIELD=preload("res://scripts/root_field.gd")
var texture: CanvasTexture
var mesh: ArrayMesh
var signature=0
var tile_count=0
var vertex_count=0

func load_art() -> void:
	var image=load("res://assets/citrus_root_ground_v058.png").get_image()
	image.generate_mipmaps()
	texture=CanvasTexture.new();texture.diffuse_texture=ImageTexture.create_from_image(image)
	texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture.texture_repeat=CanvasItem.TEXTURE_REPEAT_MIRROR

func _corner_value(corner: Vector2i, cells: Dictionary, map: ACMap) -> float:
	var total=0.0
	for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		var cell=corner+offset
		# Fade into the bank on the land side. Never paint the vertical wall,
		# water, or a blocked cell and never let the texture bridge a gap.
		if not FIELD.terrain_allows(map,cell):return 0.0
		total+=float(cells.get(cell.y*FIELD.WIDTH+cell.x,0.0))
	return smoothstep(.08,.8,total*.25)

func build(map: ACMap, packed, fog: Callable) -> void:
	var cells={};var candidates={}
	for value in packed:
		var index=int(value)&0xffff;var cell=Vector2i(index%256,index/256)
		if fog.call(FIELD.ground_index(index))==0 or not FIELD.terrain_allows(map,cell):continue
		cells[index]=float(int(value)>>18)/255.0
		for y in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				var neighbor=Vector2i(x,y)
				if FIELD.terrain_allows(map,neighbor) and fog.call(FIELD.ground_index(y*256+x))>0:candidates[y*256+x]=neighbor
	tile_count=cells.size();var builder=ACTerrainRenderer.new()._builder();var corners={}
	for index in candidates:
		var cell: Vector2i=candidates[index]
		var vertices=PackedVector2Array();var uv=PackedVector2Array();var alpha=PackedFloat32Array()
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
			var corner=cell+offset
			if not corners.has(corner):corners[corner]=_corner_value(corner,cells,map)
			var point=Vector2(corner)*.5-Vector2.ONE*.5
			point=point.clamp(Vector2.ZERO,Vector2.ONE*128)
			vertices.append(Vector2(point.x*32,point.y*32-map.visual_elevation(point)))
			# Continuous world UVs keep tiny growth tiles from looking like stamps.
			uv.append(point*32.0/192.0);alpha.append(corners[corner])
		if maxf(maxf(alpha[0],alpha[1]),maxf(alpha[2],alpha[3]))<.001:continue
		var start=builder.vertices.size()
		builder.vertices.append_array(vertices);builder.uv.append_array(uv)
		var shade=.38 if fog.call(FIELD.ground_index(index))==1 else 1.0
		for a in alpha:builder.colors.append(Color(.86*shade,.79*shade,.68*shade,.88*a))
		builder.indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	vertex_count=builder.vertices.size()
	mesh=ACTerrainRenderer.new()._mesh(builder) if vertex_count>0 else null

func draw(canvas: CanvasItem, map: ACMap, packed, fog: Callable, zoom: float, project: Callable, fog_signature: int) -> void:
	if texture==null:load_art()
	var next=hash([map.get_instance_id(),packed,fog_signature])
	if next!=signature:
		signature=next;build(map,packed,fog)
	if mesh!=null:canvas.draw_mesh(mesh,texture,Transform2D(Vector2(zoom,0),Vector2(0,zoom),project.call(Vector2.ZERO)))
