extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label)
func _initialize():
	var renderer=ACTerrainRenderer.new()
	var map=ACMap.new();map.make(2)
	for role in ["coast","height_bank"]:
		for degree in range(360):
			var direction=Vector2.from_angle(deg_to_rad(degree))
			if absf(direction.y)<.00001:direction.y=0
			var tangent=Vector2(-direction.y,direction.x)
			var a=renderer._bank_section(map,Vector2(2000,2000),direction,role)
			var b=renderer._bank_section(map,Vector2(2000,2000)+tangent*64,direction,role)
			var face=renderer._builder();var rim=renderer._builder();var shadow=renderer._builder()
			renderer._emit_bank_piece(face,rim,shadow,a,b,0,.5)
			check(rim.vertices.size()==4,"all orientations keep a narrow ground outline")
			if direction.y<=0:
				check(face.vertices.is_empty() and shadow.vertices.is_empty(),"hidden north and side slopes emit no wall or contact shadow")
				check(a.top.is_equal_approx(a.bottom),"hidden walls collapse onto the ground silhouette")
			else:
				check(face.vertices.size()==4 and shadow.vertices.size()==4,"south-facing walls stay visible")
				check(a.bottom.y>a.top.y,"visible walls descend toward camera")
		# A convex/concave corner can cross the camera silhouette mid-piece.
		# Its visible face must end exactly there, not extend into the rear half.
		for reverse in [false,true]:
			var a=renderer._bank_section(map,Vector2(2000,2000),Vector2(1,-1).normalized(),role)
			var b=renderer._bank_section(map,Vector2(2064,2000),Vector2(1,1).normalized(),role)
			if reverse:var temporary=a;a=b;b=temporary
			var face=renderer._builder();var rim=renderer._builder();var shadow=renderer._builder()
			renderer._emit_bank_piece(face,rim,shadow,a,b,0,.5)
			var edge=a.silhouette.lerp(b.silhouette,.5)
			var index=1 if reverse else 0
			check(face.vertices[index].is_equal_approx(edge) and face.vertices[3-index].is_equal_approx(edge),"crossing corner clips both wall edges at the camera silhouette")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://build/source-terrain/bank-camera.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BANK_CAMERA ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
