class_name ACFogCanvas
extends Control
## Project the byte masks on the same relief triangles as the terrain.
## A retained transparent viewport resolves overlapping cliff triangles
## before compositing fog, so a hidden back surface cannot darken visible land.
var visibility_texture: ImageTexture
var explored_texture: ImageTexture
var revision=-1
var uploads=0
var destination=Rect2()
var clip=Rect2()
var viewport_updates=0
var mesh_builds=0
var _viewport: SubViewport
var _surface: MeshInstance2D
var _meshes: Dictionary={}
var _geometry_signature=-1
var _screen_rect=Rect2()
const PROJECTION_ORIGIN=Vector2(0,-256)
const PROJECTION_SIZE=Vector2(4096,4608)
const PROJECTION_SCALE=.5
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_viewport=SubViewport.new();_viewport.disable_3d=true;_viewport.world_2d=World2D.new();_viewport.transparent_bg=true
	_viewport.gui_disable_input=true;_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(_viewport)
	_surface=MeshInstance2D.new();_viewport.add_child(_surface)
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D explored_mask : filter_linear, repeat_disable;
void fragment(){
 float visible=clamp(texture(TEXTURE,UV).r*255.0,0.0,1.0);
 float known=clamp(texture(explored_mask,UV).r*255.0,0.0,1.0);
 COLOR=vec4(0.0,0.0,0.0,1.0-max(visible,known*0.32));
}"""
	var shader_material=ShaderMaterial.new();shader_material.shader=shader;_surface.material=shader_material

func _projection_mesh(map: ACMap) -> ArrayMesh:
	var vertices=PackedVector2Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
	var stride=257 if map!=null else 2
	for y in range(stride):
		for x in range(stride):
			var p=Vector2(x,y)*.5 if map!=null else Vector2(x,y)*128
			vertices.append(Vector2(p.x*32,p.y*32-map._visual_vertex(Vector2i(x,y))) if map!=null else p)
			uv.append((p+Vector2.ONE*.5)/128.0 if map!=null else p/128.0)
	for y in range(stride-1):
		for x in range(stride-1):
			var i=y*stride+x
			indices.append_array(PackedInt32Array([i,i+1,i+stride+1,i,i+stride+1,i+stride]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	mesh_builds+=1;return mesh

func update_masks(fog: PackedByteArray,seen: PackedByteArray,stamp: int,world: Rect2,view: Rect2,map: ACMap=null) -> void:
	visible=fog.size()==16384 and seen.size()==16384
	if not visible:return
	var first=visibility_texture==null
	var signature=hash([map.theme,map.render_signature]) if map!=null else 0
	var geometry_changed=signature!=_geometry_signature
	var masks_changed=stamp!=revision or first or geometry_changed
	if masks_changed:
		var fog_image=Image.create_from_data(128,128,false,Image.FORMAT_L8,fog)
		var seen_image=Image.create_from_data(128,128,false,Image.FORMAT_L8,seen)
		if visibility_texture==null:
			visibility_texture=ImageTexture.create_from_image(fog_image);explored_texture=ImageTexture.create_from_image(seen_image)
			_surface.material.set_shader_parameter("explored_mask",explored_texture)
		else:visibility_texture.update(fog_image);explored_texture.update(seen_image)
		revision=stamp;uploads+=1
	if geometry_changed:
		if not _meshes.has(signature):_meshes[signature]=_projection_mesh(map)
		_surface.mesh=_meshes[signature];_geometry_signature=signature
	var placement_changed=destination!=world or clip!=view
	if masks_changed or geometry_changed or placement_changed:
		destination=world;clip=view
		_surface.texture=visibility_texture
		if map!=null:
			# Resolve relief once in world space. Panning only repositions this
			# retained image; it must not redraw 131072 triangles every frame.
			_viewport.size=Vector2i(PROJECTION_SIZE*PROJECTION_SCALE)
			_surface.position=-PROJECTION_ORIGIN*PROJECTION_SCALE
			_surface.scale=Vector2.ONE*PROJECTION_SCALE
			var scale_value=world.size/4096.0
			_screen_rect=Rect2(world.position+PROJECTION_ORIGIN*scale_value,PROJECTION_SIZE*scale_value)
		else:
			_viewport.size=Vector2i(view.size.ceil()).max(Vector2i.ONE)
			_surface.position=world.position-view.position
			_surface.scale=world.size/128.0
			_screen_rect=view
		if masks_changed or geometry_changed or (map==null and placement_changed):
			_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;viewport_updates+=1
		queue_redraw()
func _draw() -> void:
	if visibility_texture==null or not destination.has_area():return
	if clip.has_area():draw_texture_rect(_viewport.get_texture(),_screen_rect,false)
