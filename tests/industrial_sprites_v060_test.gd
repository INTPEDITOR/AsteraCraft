extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var assets=ACAssets.new();assets.load_all()
	for kind in [9,10,12,15]:
		var key="0:%d"%kind
		check(assets.v060_units[key].size()==40,"five headings by eight phases: "+key)
		for registered in assets.v060_units[key]:
			var pixels=registered.texture.get_image()
			var used=pixels.get_used_rect()
			check(used.position.x>=8 and used.position.y>=8 and used.end.x<=248 and used.end.y<=248,"whole silhouette has transparent gutters; no clipped frame")
		for action in ["idle","walk","attack"]:
			for heading in range(8):
				var direction=Vector2.UP.rotated(TAU*heading/8.0)
				for phase in range(8):
					var frame=assets.unit(0,kind,direction,action,(phase+.01)/12.0)
					check(frame.industrial and frame.embedded_pilot,"new painted hull selected")
					check(frame.texture.get_size()==Vector2(256,256) and frame.rotation==0,"fixed padded grid with true directional views")
					check(frame.anchor==Vector2(128,128 if kind!=12 else 224),"stable air center / ground feet")
					var socket=ACWeaponSockets.local_offset(frame,0,kind,direction)
					check(socket.is_finite() and socket.length()<256,"visible weapon registration remains local")
		for phase in range(8):
			var north=assets.unit(0,kind,Vector2.UP,"walk",phase/12.0)
			var south=assets.unit(0,kind,Vector2.DOWN,"walk",phase/12.0)
			check(north.texture.region!=south.texture.region,"front and rear occupy different painted directions")
			check(hash(north.texture.get_image().get_data())!=hash(south.texture.get_image().get_data()),"front is not a duplicate rear view")
	check(assets.vehicle(0,12,Vector2.DOWN,Vector2.DOWN).is_empty(),"old turret composite cannot cover new fortress")
	for heading in range(5):
		var image=assets.v060_units["0:12"][heading*8].texture.get_image()
		var used=image.get_used_rect();var left=256;var right=-1
		for y in range(used.position.y+int(used.size.y*.55),used.end.y):
			for x in range(used.position.x,used.end.x):
				if image.get_pixel(x,y).a>.36:left=mini(left,x);right=maxi(right,x)
		check(abs(right-left+1-200)<=4,"direction-independent chassis scale registered by feet instead of cannon length")
	for heading in range(8):
		var dir=Vector2.UP.rotated(TAU*heading/8.0)
		var frame=assets.unit(0,12,dir,"attack",0)
		var sockets=[]
		for barrel in range(3):sockets.append(ACWeaponSockets.local_offset(frame,0,12,dir,barrel))
		check(sockets[0].distance_to(sockets[1])>3 and sockets[1].distance_to(sockets[2])>3,"three separate registered cannon mouths in every heading")
	for dir in [Vector2.DOWN,Vector2(1,1).normalized()]:
		var hashes=[]
		for phase in range(8):
			var image=assets.unit(0,12,dir,"walk",phase/12.0).texture.get_image()
			var h=hash(image.get_data());if h not in hashes:hashes.append(h)
		check(hashes.size()==8,"eight distinct down-facing walking poses")
	print("INDUSTRIAL_SPRITES_V060 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
