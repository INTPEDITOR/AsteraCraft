class_name ACEffectSprite
extends Sprite2D
## A registered effect atlas: all frames share one ground point and scale.
var shader_material: ShaderMaterial
var columns=4
var rows=4
var frame_count=16
var pivot=Vector2(.5,.5)
var cell_size=Vector2.ONE
var frame_offsets: Array=[]
static var _shared_shader: Shader
static var _white: ImageTexture

func configure(atlas: Texture2D,count: int,grid: Vector2i=Vector2i(4,4),anchor: Vector2=Vector2(.5,.5)) -> void:
	columns=maxi(1,grid.x);rows=maxi(1,grid.y);frame_count=mini(count,columns*rows)
	pivot=anchor;cell_size=atlas.get_size()/Vector2(columns,rows)
	if _white==null:
		var white=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
		_white=ImageTexture.create_from_image(white)
	texture=_white;offset=Vector2(.5,.5)-pivot
	if _shared_shader==null:
		_shared_shader=Shader.new()
		_shared_shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas_image : filter_linear, repeat_disable;
uniform vec4 frame_uv;
uniform vec4 next_uv;
uniform float frame_blend;
uniform float opacity=1.0;
uniform vec2 frame_shift=vec2(0.0);
uniform vec2 next_shift=vec2(0.0);
uniform float edge_feather=0.0;
vec4 registered_frame(vec2 q,vec4 region){
 if(q.x<0.0||q.y<0.0||q.x>1.0||q.y>1.0)return vec4(0.0);
 vec4 p=texture(atlas_image,region.xy+q*region.zw);
 if(edge_feather>0.0)p.a*=smoothstep(0.0,edge_feather,q.x)*smoothstep(0.0,edge_feather,q.y)*(1.0-smoothstep(1.0-edge_feather,1.0,q.x))*(1.0-smoothstep(1.0-edge_feather,1.0,q.y));
 return p;
}
void fragment() {
 vec4 a=registered_frame(UV+frame_shift,frame_uv);
 vec4 b=registered_frame(UV+next_shift,next_uv);
 vec4 p=mix(vec4(a.rgb*a.a,a.a),vec4(b.rgb*b.a,b.a),frame_blend);
 COLOR=vec4(p.rgb/max(p.a,0.00001),p.a*opacity);
}"""
	shader_material=ShaderMaterial.new();shader_material.shader=_shared_shader
	shader_material.set_shader_parameter("atlas_image",atlas);material=shader_material

func update_frame(ground: Vector2,width: float,frame: float,opacity: float=1.0) -> void:
	var value=clampf(frame,0,maxi(0,frame_count-1))
	var first=int(floor(value));var second=mini(first+1,frame_count-1)
	var inset=Vector2(.5,.5)/(cell_size*Vector2(columns,rows))
	for item in [["frame_uv",first],["next_uv",second]]:
		var index=int(item[1])
		shader_material.set_shader_parameter(item[0],Vector4(float(index%columns)/columns+inset.x,float(index/columns)/rows+inset.y,1.0/columns-inset.x*2,1.0/rows-inset.y*2))
	shader_material.set_shader_parameter("frame_shift",ACData.point(frame_offsets[first]) if frame_offsets.size()==frame_count else Vector2.ZERO)
	shader_material.set_shader_parameter("next_shift",ACData.point(frame_offsets[second]) if frame_offsets.size()==frame_count else Vector2.ZERO)
	shader_material.set_shader_parameter("frame_blend",value-floor(value))
	shader_material.set_shader_parameter("opacity",opacity)
	scale=Vector2(width,width*cell_size.y/cell_size.x)
	position=ground
