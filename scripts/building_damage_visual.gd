class_name ACBuildingDamageVisual
extends RefCounted
## Read-only presentation of current building damage. No simulation effects.
var _anchor_cache: Dictionary={}
var _surface_cache: Dictionary={}
var _juice_frames: Array=[]

static func frame_rect(frame: Dictionary,foundation: Vector2,extent: float) -> Rect2:
	var factor=extent/maxf(1,float(frame.scale_hint))
	return Rect2(foundation-Vector2(frame.anchor)*factor,frame.texture.get_size()*factor)

static func health_capacity(maximum: float,progress: float=1.0) -> float:
	if not is_finite(maximum) or maximum<=0:return 0.0
	if not is_finite(progress):progress=0.0
	return maximum*(.1+.9*clampf(progress,0.0,1.0))

static func damage_stage(hp: float, maximum: float) -> int:
	if not is_finite(hp) or not is_finite(maximum) or maximum<=0:return 0
	var ratio=clampf(hp/maximum,0.0,1.0)
	if ratio>=1.0:return 0
	if ratio>.75:return 1
	if ratio>.5:return 2
	if ratio>.25:return 3
	return 4

static func plan(race: int,hp: float,maximum: float,remembered: bool=false) -> Dictionary:
	var level=0 if remembered else damage_stage(hp,maximum)
	var severity=clampf(1.0-hp/maximum,0.0,1.0) if maximum>0 and is_finite(hp) and is_finite(maximum) else 0.0
	return {"stage":level,"severity":severity,"count":level+1 if level>0 else 0,"effect":["red_fire","citrus_juice","blue_fire"][clampi(race,0,2)],"visible":level>0}

func _anchors(texture: Texture2D) -> Array:
	var key=texture.get_instance_id()
	if _anchor_cache.has(key):return _anchor_cache[key]
	var image=texture.get_image()
	if image==null or image.is_empty():return []
	var used=image.get_used_rect()
	_surface_cache[key]=Rect2(Vector2(used.position)/Vector2(image.get_size()),Vector2(used.size)/Vector2(image.get_size()))
	var candidates: Array=[]
	for row in range(12):
		for column in range(14):
			var p=Vector2(used.position)+Vector2(used.size)*Vector2((column+.5)/14.0,(row+.5)/12.0)
			var pixel=Vector2i(p).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
			if image.get_pixelv(pixel).a>.65:candidates.append(p)
	var points: Array=[]
	for target in [Vector2(.30,.46),Vector2(.67,.48),Vector2(.49,.27),Vector2(.19,.68),Vector2(.79,.68)]:
		var desired=Vector2(used.position)+Vector2(used.size)*target
		var best=desired;var distance=INF
		for candidate in candidates:
			if candidate in points:continue
			var value=candidate.distance_squared_to(desired)
			if value<distance:distance=value;best=candidate
		points.append(best)
	var normalized: Array=[]
	for p in points:normalized.append(p/Vector2(image.get_size()))
	_anchor_cache[key]=normalized
	return normalized

func draw(canvas: CanvasItem,race: int,hp: float,maximum: float,texture: Texture2D,rect: Rect2,clock: float,seed_value: int=0) -> void:
	var info=plan(race,hp,maximum)
	if not info.visible or texture==null or not rect.has_area():return
	var anchors=_anchors(texture)
	var normalized_surface: Rect2=_surface_cache.get(texture.get_instance_id(),Rect2(0,0,1,1))
	var surface=Rect2(rect.position+normalized_surface.position*rect.size,normalized_surface.size*rect.size)
	var scale_value=maxf(1.0,surface.size.x/180.0)
	var strength=float(info.severity)
	for i in range(mini(int(info.count),anchors.size())):
		var point=rect.position+Vector2(anchors[i])*rect.size
		var phase=clock*5.7+float(seed_value)*.61+i*2.37
		if race==1:
			_juice(canvas,point,surface,strength,phase,scale_value,i)
		else:
			_flame(canvas,point,strength,phase,scale_value,race==2)

func _flame(canvas: CanvasItem,point: Vector2,severity: float,phase: float,scale_value: float,blue: bool) -> void:
	var height=(9.0+severity*34.0)*(1.0+sin(phase)*.12)*scale_value
	var width=(4.0+severity*11.0)*scale_value
	var lean=sin(phase*.67)*width*.38
	var color=Color(.18,.38,1.0,.66+.25*severity) if blue else Color(1.0,.13,.035,.66+.25*severity)
	var hot=Color(.46,.87,1.0,.9) if blue else Color(1.0,.69,.08,.92)
	var core=Color(.82,.98,1.0,.95) if blue else Color(1.0,.94,.60,.95)
	var outer=PackedVector2Array([point+Vector2(-width*.4,0),point+Vector2(-width*.7,-height*.3),point+Vector2(-width*.3,-height*.57),point+Vector2(lean,-height),point+Vector2(width*.18,-height*.65),point+Vector2(width*.65,-height*.30),point+Vector2(width*.34,0)])
	canvas.draw_colored_polygon(outer,color)
	canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(-width*.35,0),point+Vector2(-width*.32,-height*.3),point+Vector2(lean*.6,-height*.7),point+Vector2(width*.31,-height*.3),point+Vector2(width*.24,0)]),hot)
	canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(-width*.16,0),point+Vector2(lean*.3,-height*.36),point+Vector2(width*.18,0)]),core)
	if severity>.45:
		var rise=fposmod(phase*.17,1.0)
		canvas.draw_circle(point+Vector2(sin(phase*1.3)*width*.4,-height*(.8+rise*.6)),maxf(.7,scale_value*(1.3-rise)),Color(hot,1.0-rise))

func _juice(canvas: CanvasItem,point: Vector2,rect: Rect2,severity: float,phase: float,scale_value: float,index: int) -> void:
	if _juice_frames.is_empty():
		var source: Texture2D=load("res://assets/effects/building_juice_drips_20261024.png")
		if source==null:return
		var cell=source.get_size()/Vector2(4,2)
		for i in range(8):
			var frame=AtlasTexture.new();frame.atlas=source;frame.filter_clip=true
			frame.region=Rect2(Vector2(i%4,i/4)*cell,cell);_juice_frames.append(frame)
	var length=minf((10.0+severity*28.0)*scale_value,maxf(4.0,rect.end.y-point.y))
	var width=length*.75
	var texture: Texture2D=_juice_frames[posmod(int(floor(phase*.75))+index,8)]
	canvas.draw_texture_rect(texture,Rect2(point-Vector2(width*.5,0),Vector2(width,length)),false,Color(1,1,1,.42+.32*severity))
