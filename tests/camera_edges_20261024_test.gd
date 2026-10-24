extends SceneTree
var checks=0
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value and not failures.has(message):failures.append(message);printerr(message)
func north_screen_edge(main: Control,boundary: PackedVector3Array) -> float:
	var lowest=-INF
	for index in range(boundary.size()-1):
		var a=boundary[index];var b=boundary[index+1]
		if a.y!=0 or b.y!=0:continue
		var left=main.world_to_screen(Vector2(a.x,0))-Vector2(0,a.z*main.zoom)
		var right=main.world_to_screen(Vector2(b.x,0))-Vector2(0,b.z*main.zoom)
		if right.x<0 or left.x>main.size.x:continue
		var begin=left.lerp(right,clampf((0-left.x)/(right.x-left.x),0,1))
		var end=left.lerp(right,clampf((main.size.x-left.x)/(right.x-left.x),0,1))
		lowest=maxf(lowest,maxf(begin.y,end.y))
	return lowest
func run() -> void:
	var main=load("res://scripts/main.gd").new();main.size=Vector2(1600,900)
	var hud=ACRtsHUD.new();hud.main=main;hud.size=main.size;hud._load_art();main.battle_hud=hud
	var report=[];var opened_north=0
	for map_index in range(3):
		main.draw_map.make(map_index);var boundary=main.draw_map.visual_boundary()
		var unchanged=hash([main.draw_map.terrain,main.draw_map.height_map,main.draw_map.resources])
		var renderer=ACTerrainRenderer.new()
		for vertex in boundary:
			var pixel=Vector2(vertex.x,vertex.y)*32
			check(absf(renderer._bank_point(main.draw_map,pixel).y-(pixel.y-vertex.z))<.005,"terrain preserves actual perimeter height m%d"%map_index)
		for race in range(3):
			hud.race=race;hud._update_body_outline()
			var deepest=-INF
			for i in range(hud._body_outline.size()-2):deepest=maxf(deepest,hud._body_outline[i].y)
			check(absf(main._camera_view_bottom()-deepest)<.01,"camera follows actual opaque HUD contour race%d"%race)
			for zoom in [1.0,1.75,2.5]:
				main.zoom=zoom
				for x in [0,16,32,64,96,112,128]:
					main.camera=Vector2(x,-10000);main._clamp_camera()
					var top=north_screen_edge(main,boundary)
					check(absf(top+main.CAMERA_EDGE_GUARD)<.05,"north is tight without void m%d r%d z%.2f x%d"%[map_index,race,zoom,x])
					var legacy=main._view_rect().get_center().y/(32*zoom)
					if main.camera.y<legacy-.1:opened_north+=1
					var north_camera=main.camera
					main.camera.y-=(main.CAMERA_EDGE_GUARD+1)/(32*zoom)
					check(north_screen_edge(main,boundary)>.9,"north limit leaves only the guard margin")
					main.camera=Vector2(x,10000);main._clamp_camera()
					var bottom=main.world_to_screen(Vector2(64,ACMap.SIZE)).y
					check(absf(bottom-deepest-main.CAMERA_EDGE_GUARD)<.05,"south covers deepest HUD valley m%d r%d z%.2f"%[map_index,race,zoom])
					var south_camera=main.camera
					main.camera.y+=(main.CAMERA_EDGE_GUARD+1)/(32*zoom)
					check(main.world_to_screen(Vector2(64,ACMap.SIZE)).y<deepest-.9,"south limit is not unnecessarily restrictive")
					main.camera=south_camera
					var mini=Rect2(50,650,180,180);var camera_box=main._minimap_camera_rect(mini)
					check(mini.encloses(camera_box),"minimap camera footprint remains in its frame")
					report.append({"map":map_index,"race":race,"zoom":zoom,"x":x,"north_camera":str(north_camera),"south_camera":str(south_camera),"north_edge_y":top,"south_edge_y":bottom,"hud_visible_bottom":deepest})
				main.camera=Vector2(64,64);main._clamp_camera();check(main.camera==Vector2(64,64),"interior camera positions unchanged")
		check(unchanged==hash([main.draw_map.terrain,main.draw_map.height_map,main.draw_map.resources]),"map terrain/resource data unchanged")
	check(opened_north>0,"raised northern terrain gains visible room")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":report.size(),"raised_north_cases_opened":opened_north,"guard_pixels":main.CAMERA_EDGE_GUARD,"matrix":report}
	DirAccess.make_dir_recursive_absolute("res://build/camera-edges-20261024")
	FileAccess.open("res://build/camera-edges-20261024/geometry.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("CAMERA_EDGES ",JSON.stringify({"passed":result.passed,"checks":checks,"cases":report.size(),"opened_north":opened_north,"failures":failures}));hud.free();main.free();quit(0 if failures.is_empty() else 1)
