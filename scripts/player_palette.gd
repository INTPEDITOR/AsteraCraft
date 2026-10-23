class_name ACPlayerPalette
extends RefCounted
var _materials={}
var _marked={}
var _marker: Texture2D
var _shader: Shader
func _init():
	var image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.BLACK);_marker=ImageTexture.create_from_image(image)
	_shader=Shader.new();_shader.code="""
shader_type canvas_item;
uniform int faction=0;
uniform bool building=false;
uniform vec4 team_color : source_color=vec4(0.3,0.6,0.9,1.0);
varying vec4 vertex_tint;
vec3 rgb_hsv(vec3 c){
 vec4 K=vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
 vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
 vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
 float d=q.x-min(q.w,q.y);return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.00001)),d/(q.x+0.00001),q.x);
}
vec3 hsv_rgb(vec3 c){vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);return c.z*mix(vec3(1),clamp(p-1.0,0.0,1.0),c.y);}
void vertex(){vertex_tint=COLOR;}
void fragment(){
 vec4 pixel=texture(TEXTURE,UV);vec3 hsv=rgb_hsv(pixel.rgb);
 float source_hue=faction==0?0.135:(faction==1?0.075:0.0);
 float distance_hue=abs(hsv.x-source_hue);distance_hue=min(distance_hue,1.0-distance_hue);
 float width=faction==0?0.05:0.06;
 float mask=(1.0-smoothstep(0.025,width,distance_hue))*smoothstep(0.43,0.70,hsv.y)*smoothstep(0.12,0.26,hsv.z);
 if(faction==1 && building)mask*=smoothstep(0.45,0.64,hsv.z);
 if(faction==2)mask*=1.0-smoothstep(0.80,0.97,hsv.z);
 mask*=1.0-texture(SPECULAR_SHININESS_TEXTURE,UV).r;
 vec3 target=rgb_hsv(team_color.rgb);vec3 mapped=hsv_rgb(vec3(target.x,mix(hsv.y,target.y,0.75),hsv.z));
 COLOR=vec4(mix(pixel.rgb,mapped,mask),pixel.a)*vertex_tint;
}
"""
func material(race: int,id: int,is_building: bool) -> ShaderMaterial:
	if id==ACPlayerColors.NATIVE[clampi(race,0,2)]:return null
	var key=Vector3i(race,id,1 if is_building else 0)
	if not _materials.has(key):
		var result=ShaderMaterial.new();result.shader=_shader;result.set_shader_parameter("faction",race);result.set_shader_parameter("team_color",ACPlayerColors.color(id));result.set_shader_parameter("building",is_building);_materials[key]=result
	return _materials[key]
func marked(source: Texture2D) -> Texture2D:
	var key=source.get_instance_id()
	if _marked.has(key):return _marked[key]
	var result: Texture2D
	if source is AtlasTexture:
		var atlas=AtlasTexture.new();atlas.atlas=marked(source.atlas);atlas.region=source.region;atlas.margin=source.margin;atlas.filter_clip=true;result=atlas
	else:
		var canvas=CanvasTexture.new();canvas.diffuse_texture=source;canvas.specular_texture=_marker;result=canvas
	_marked[key]=result;return result
