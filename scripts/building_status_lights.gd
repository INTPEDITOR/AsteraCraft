class_name ACBuildingStatusLights
extends RefCounted
## A separate emissive pixel part; the building body, doors and shadow stay fixed.
var parts: Dictionary={}

func part(texture: Texture2D,race: int) -> Dictionary:
	var key=texture.get_instance_id()
	if parts.has(key):return parts[key]
	var source=texture.get_image()
	if source==null or source.is_empty():return {}
	if source.get_format()!=Image.FORMAT_RGBA8:source.convert(Image.FORMAT_RGBA8)
	var bytes=source.get_data();var candidates: Array=[];var opaque=0
	for offset in range(0,bytes.size(),4):
		if bytes[offset+3]<192:continue
		opaque+=1
		var r=float(bytes[offset])/255;var g=float(bytes[offset+1])/255;var b=float(bytes[offset+2])/255
		var strength=0.0
		if minf(g,b)>.42 and r<minf(g,b)*.65:strength=minf(g,b)-r
		elif race==2 and r>.72 and maxf(g,b)<r*.40:strength=r-maxf(g,b)
		if strength>0:candidates.append(Vector2(offset,strength))
	candidates.sort_custom(func(a,b):return a.y>b.y)
	var count=mini(candidates.size(),maxi(1,int(opaque*.018)))
	var light_bytes=PackedByteArray();light_bytes.resize(bytes.size());light_bytes.fill(0)
	for i in range(count):
		var offset=int(candidates[i].x)
		for channel in range(4):light_bytes[offset+channel]=bytes[offset+channel]
	var mask=Image.create_from_data(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8,light_bytes)
	var result={"texture":ImageTexture.create_from_image(mask),"pixels":count,"opaque":opaque}
	parts[key]=result;return result

func draw(canvas: CanvasItem,texture: Texture2D,rect: Rect2,race: int,clock: float,active: bool) -> void:
	if not active:return
	var light=part(texture,race)
	if light.is_empty() or int(light.pixels)==0:return
	var pulse=.5+.5*sin(clock*2.2)
	var opacity=.10*pulse
	canvas.draw_texture_rect(light.texture,rect,false,Color(1.55,1.55,1.55,opacity))
