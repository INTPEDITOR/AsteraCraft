extends SceneTree

class TerrainCanvas extends Control:
	var renderer=ACTerrainRenderer.new()
	var map=ACMap.new()
	var map_id=0
	var zoom=.18
	var map_origin=Vector2.ZERO
	func _ready() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		renderer.load_art()
	func project(point: Vector2) -> Vector2:
		return point*32.0*zoom+map_origin
	func unproject(point: Vector2) -> Vector2:
		return (point-map_origin)/(32.0*zoom)
	func _draw() -> void:
		var viewport_size=get_viewport_rect().size
		var side=minf(viewport_size.x-64,viewport_size.y-128)
		zoom=side/4096.0
		map_origin=Vector2((viewport_size.x-side)*.5,104)
		draw_rect(Rect2(Vector2.ZERO,viewport_size),Color("10171c"))
		if map.terrain.is_empty():return
		renderer.draw(self,map,Rect2(map_origin,Vector2.ONE*side),zoom,project,unproject,func(_index):return 2,15.0)
		for resource in map.resources:
			var point=project(ACData.point(resource.pos))
			var size=Vector2(2,1) if resource.type=="as" else Vector2(4,2)
			var half=size*32.0*zoom*.40
			var polygon=PackedVector2Array([point+Vector2(-half.x,0),point+Vector2(-half.x*.4,-half.y),point+Vector2(half.x*.65,-half.y*.75),point+Vector2(half.x,half.y*.7),point+Vector2(-half.x*.7,half.y)])
			draw_colored_polygon(polygon,Color("ffce44") if resource.type=="as" else Color("51bafb"))
		for slot in range(4):
			var point=project(ACData.point(map.starts[slot]))
			draw_circle(point,14,Color("1b333b"))
			draw_arc(point,14,0,TAU,48,Color("b4f3df"),2,true)
			draw_string(ThemeDB.fallback_font,point+Vector2(-5,6),str(slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		for base in map.bases:
			if base.main:continue
			var point=project(ACData.point(base.pos))
			draw_arc(point,8,0,TAU,32,Color("d5dbd5"),1.2,true)
		renderer.draw_boundary_mask(self,map,Rect2(Vector2.ZERO,viewport_size),zoom,project)
		draw_string(ThemeDB.fallback_font,Vector2(map_origin.x,43),map.source_info.name+" / "+str(map.source_info.get("layout",map.source_info.get("origin","original"))),HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("ebdfbe"))
		draw_string(ThemeDB.fallback_font,Vector2(map_origin.x,77),"Original four-player map | X/Y mirror symmetry | 12 bases | 96 As + 12 Tera",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a3b4ba"))

var scene: TerrainCanvas

func _initialize() -> void:
	root.size=Vector2i(1440,900)
	scene=TerrainCanvas.new()
	root.add_child.call_deferred(scene)
	capture.call_deferred()

func capture() -> void:
	await process_frame
	for theme in range(3):
		scene.map_id=theme
		scene.map.make(theme)
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var path="res://build/map-overview-%d.png"%theme
		assert(image.save_png(path)==OK,"Overview capture saved")
		print("TERRAIN_OVERVIEW ",path," ",scene.renderer.last_stats)
	quit()

