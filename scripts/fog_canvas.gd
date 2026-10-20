class_name ACFogCanvas
extends Control
## Upload the two existing byte masks directly. The GPU blends fog; the
## display thread never walks all 16,384 cells to rebuild RGBA pixels.
var visibility_texture: ImageTexture
var explored_texture: ImageTexture
var revision=-1
var uploads=0
var destination=Rect2()
var clip=Rect2()
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D explored_mask : filter_linear, repeat_disable;
void fragment(){
 float visible=clamp(texture(TEXTURE,UV).r*255.0,0.0,1.0);
 float known=clamp(texture(explored_mask,UV).r*255.0,0.0,1.0);
 COLOR=vec4(0.0,0.0,0.0,1.0-max(visible,known*0.32));
}"""
	var shader_material=ShaderMaterial.new();shader_material.shader=shader;material=shader_material
func update_masks(fog: PackedByteArray,seen: PackedByteArray,stamp: int,world: Rect2,view: Rect2) -> void:
	visible=fog.size()==16384 and seen.size()==16384
	if not visible:return
	var first=visibility_texture==null
	if stamp!=revision or visibility_texture==null:
		var fog_image=Image.create_from_data(128,128,false,Image.FORMAT_L8,fog)
		var seen_image=Image.create_from_data(128,128,false,Image.FORMAT_L8,seen)
		if visibility_texture==null:
			visibility_texture=ImageTexture.create_from_image(fog_image);explored_texture=ImageTexture.create_from_image(seen_image)
			material.set_shader_parameter("explored_mask",explored_texture)
		else:visibility_texture.update(fog_image);explored_texture.update(seen_image)
		revision=stamp;uploads+=1
	if first or destination!=world or clip!=view:
		destination=world;clip=view;queue_redraw()
func _draw() -> void:
	if visibility_texture==null or not destination.has_area():return
	var cropped=destination.intersection(clip)
	if not cropped.has_area():return
	var scale=Vector2(128,128)/destination.size
	draw_texture_rect_region(visibility_texture,cropped,Rect2((cropped.position-destination.position)*scale,cropped.size*scale))
