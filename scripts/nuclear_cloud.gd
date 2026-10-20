class_name ACNuclearCloud
extends Sprite2D

var shader_material: ShaderMaterial
var columns=4
var rows=8

func configure(atlas: Texture2D,frame_count: int) -> void:
	rows=8 if frame_count==32 else 2
	var white=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	texture=ImageTexture.create_from_image(white)
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas_image : filter_linear;
uniform vec4 frame_uv;
uniform vec4 next_uv;
uniform float frame_blend;
uniform float opacity=1.0;
void fragment() {
 vec4 a=texture(atlas_image,frame_uv.xy+UV*frame_uv.zw);
 vec4 b=texture(atlas_image,next_uv.xy+UV*next_uv.zw);
 vec4 p=mix(vec4(a.rgb*a.a,a.a),vec4(b.rgb*b.a,b.a),frame_blend);
 COLOR=vec4(p.rgb/max(p.a,0.00001),p.a*opacity);
}
"""
	shader_material=ShaderMaterial.new();shader_material.shader=shader
	shader_material.set_shader_parameter("atlas_image",atlas);material=shader_material
	z_index=10

func update_cloud(ground: Vector2,width: float,elapsed: float,duration: float) -> void:
	var normalized=clampf(elapsed/maxf(.01,duration),0,1)
	var frame=0.0
	if rows==8:
		if elapsed<2:frame=elapsed/2*7
		elif elapsed<5:frame=7+(elapsed-2)/3*8
		elif elapsed<9:frame=15+(elapsed-5)/4*8
		else:frame=23+clampf((elapsed-9)/7,0,1)*8
	else:frame=normalized*7
	var first=clampi(int(floor(frame)),0,columns*rows-1);var second=mini(first+1,columns*rows-1)
	for item in [["frame_uv",first],["next_uv",second]]:
		var index=int(item[1]);shader_material.set_shader_parameter(item[0],Vector4(float(index%columns)/columns,float(index/columns)/rows,1.0/columns,1.0/rows))
	shader_material.set_shader_parameter("frame_blend",frame-floor(frame))
	shader_material.set_shader_parameter("opacity",1-smoothstep(.56,1,normalized))
	var atlas: Texture2D=shader_material.get_shader_parameter("atlas_image")
	var height=width*(atlas.get_height()/float(rows))/(atlas.get_width()/float(columns))
	var dimensions=Vector2(width,height)*(1+normalized*.08)
	scale=dimensions;position=ground-Vector2(0,dimensions.y*.36)
