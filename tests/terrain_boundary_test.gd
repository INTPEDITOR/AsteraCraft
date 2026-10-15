extends SceneTree

class BoundaryCanvas extends Control:
	var renderer=ACTerrainRenderer.new()
	var map=ACMap.new()
	var origin=Vector2(-1648,-3720)
	func _ready() -> void:
		renderer.load_art()
		map.make(0)
	func project(point: Vector2) -> Vector2:return origin+point*32.0
	func unproject(point: Vector2) -> Vector2:return (point-origin)/32.0
	func _draw() -> void:
		if map.terrain.is_empty():return
		renderer.draw(self,map,Rect2(Vector2.ZERO,Vector2(800,600)),1,project,unproject,func(_index):return 2,0)
		# Simulate a sprite that spills beyond the raised southern boundary.
		draw_rect(Rect2(Vector2(250,330),Vector2(300,70)),Color.RED)
		draw_circle(Vector2(400,320),4,Color.GREEN)
		renderer.draw_boundary_mask(self,map,Rect2(Vector2.ZERO,Vector2(800,600)),1,project)

var canvas: BoundaryCanvas

func _initialize() -> void:
	root.size=Vector2i(800,600)
	canvas=BoundaryCanvas.new()
	root.add_child.call_deferred(canvas)
	verify.call_deferred()

func verify() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var failures=[]
	# Actual bottom edge: 4096 - (24 + 6) - 3720 = 346, not 376.
	for y in [349,360,375,390,500]:
		for x in [260,400,540]:
			var color=image.get_pixel(x,y)
			if color.r>.005 or color.g>.005 or color.b>.005:failures.append("Outside perimeter must be opaque black at %s"%Vector2i(x,y))
	if image.get_pixel(400,320).g<.9:failures.append("Mask must preserve a visible interior marker")
	if image.get_pixel(300,338).r<.9:failures.append("Mask must preserve the spill sprite's interior part")
	image.save_png("res://build/terrain-v04-boundary.png")
	var result={"passed":failures.is_empty(),"checks":17,"failures":failures,"boundary_world_y":4066,"logical_world_y":4096}
	FileAccess.open("res://build/terrain-v04-boundary-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TERRAIN_BOUNDARY_TEST ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
