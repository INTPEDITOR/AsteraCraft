extends SceneTree
const OUT="res://build/rock-terrain-20261024/"
class RockView extends Control:
	var renderer=ACTerrainRenderer.new()
	var map=ACMap.new()
	var camera=Vector2(32,32)
	var zoom=1.4
	func project(p: Vector2) -> Vector2:return (p-camera)*32*zoom+Vector2(640,400)
	func unproject(p: Vector2) -> Vector2:return (p-Vector2(640,400))/(32*zoom)+camera
	func _draw() -> void:
		renderer.draw(self,map,Rect2(0,0,1280,800),zoom,project,unproject,func(_i):return 2,0)
		renderer.draw_boundary_mask(self,map,Rect2(0,0,1280,800),zoom,project)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var view=RockView.new();root.add_child(view);view.renderer.load_art()
	var report=[]
	for theme in range(3):
		view.map=ACMap.new();view.map.make(theme)
		var before=hash([view.map.source_walk_masks,view.map.terrain,view.map.visual_ramps,view.map.resources])
		view.camera=Vector2(32,32);view.zoom=1.4;view.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"rock-terrain-%d.png"%theme)
		var data=view.renderer._cache[view.map.get_instance_id()]
		var roles=[]
		for layer in data.layers:roles.append(str(layer.get("role","")))
		assert("source_rock_top" in roles and "source_rock_wall" in roles)
		assert(not "source_blockers" in roles)
		assert(before==hash([view.map.source_walk_masks,view.map.terrain,view.map.visual_ramps,view.map.resources]))
		var water=0;var conflicts=0
		for y in range(512):
			for x in range(512):
				var tile=(y/4)*128+x/4;var bit=1<<((y%4)*4+x%4)
				if (view.map.source_water_masks[tile]&bit)==0:continue
				water+=1
				if view.renderer._source_land_blocked(view.map,x,y) or (view.map.source_walk_masks[tile]&bit)!=0:conflicts+=1
		assert(conflicts==0,"Water is never rock terrain and walkable bridges are never water")
		report.append({"theme":theme,"source_cells":data.source_blocked_cells,"build_ms":data.build_ms,"vertices":data.vertices,"unchanged_navigation_and_resources":true})
		report.back().water_minitiles=water;report.back().water_rock_or_bridge_conflicts=conflicts
		view.camera=Vector2(64,64);view.zoom=.18;view.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"overview-%d.png"%theme)
		view.camera=[Vector2(24,51),Vector2(21,48),Vector2(50,28)][theme];view.zoom=1.4;view.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"river-%d.png"%theme)
	FileAccess.open(OUT+"result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROCK_TERRAIN ",JSON.stringify(report));quit()
