extends SceneTree

var failures: Array=[]
var checks:=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)

func _initialize() -> void:
	var renderer=ACTerrainRenderer.new()
	renderer.load_art()
	check(renderer.quiet_materials.size()==12 and renderer.world_materials.size()==9,"all new original terrain materials load")
	check(renderer.bank_materials.size()==15,"straight convex concave shore and ramp materials load for each map")
	for active in renderer.quiet_materials+renderer.world_materials:
		check(active.get_width()>=288 and active.get_height()>=288,"new terrain swatches retain their source detail")
		check(active.texture_filter in [CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC],"new materials use mipmapped sampling")
	for theme in range(3):
		var floor_texture=renderer.quiet_materials[theme*4]
		check(mini(floor_texture.get_width(),floor_texture.get_height())>=1024,"active base floor is an independent HD texture, not a small atlas crop")
		check(float(mini(floor_texture.get_width(),floor_texture.get_height()))/(renderer.QUIET_WORLD_SPAN*2.0)>=1.0,"actual active floor retains source texels at zoom 2")
	var assets: Array=[]
	for theme in range(3):
		var texture=renderer.quiet_materials[theme*4]
		check(texture is CanvasTexture,"Dedicated ground texture %d must load"%theme)
		if texture==null:continue
		check(texture.get_width()>=1024 and texture.get_height()>=1024,"Ground image must provide actual high-resolution source texels")
		check(texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Ground uses trilinear sampling")
		check(texture.texture_repeat==CanvasItem.TEXTURE_REPEAT_MIRROR,"Ground uses seamless mirror sampler")
		var image=texture.diffuse_texture.get_image()
		check(image.has_mipmaps() and image.get_mipmap_count()>=9,"Ground mip chain exists at runtime")
		var zero=renderer._detail_uv(Vector2.ZERO,renderer.QUIET_WORLD_SPAN)
		var dx=(renderer._detail_uv(Vector2(1,0),renderer.QUIET_WORLD_SPAN)-zero)*Vector2(texture.get_width(),texture.get_height())
		var dy=(renderer._detail_uv(Vector2(0,1),renderer.QUIET_WORLD_SPAN)-zero)*Vector2(texture.get_width(),texture.get_height())
		check(absf(dx.length()-dy.length())<.01,"No stretched low-density UV axis")
		check(minf(dx.length(),dy.length())/2.0>=.99,"Zoom2 retains at least one source texel per screen pixel")
		assets.append({"theme":theme,"resolution":[texture.get_width(),texture.get_height()],"mip_levels":image.get_mipmap_count(),"texels_per_world_pixel":dx.length(),"texels_per_screen_pixel_at_zoom2":dx.length()/2.0})
	var total_vertices=0
	for slot in range(6):
		var relief=renderer._texture(32+slot)
		check(relief is CanvasTexture,"Generated cliff/ramp texture %d must load"%slot)
		if relief!=null:
			check(relief.get_width()>=160 and relief.get_height()>=100,"Relief uses a real generated face/floor patch")
			var span=renderer.CLIFF_WORLD_PIXELS if slot<3 else Vector2(64,64)
			check(float(relief.get_width())/(span.x*2)>=1 and float(relief.get_height())/(span.y*2)>=1,"Generated relief retains one source texel per screen pixel at zoom2")
	for theme in range(3):
		var map=ACMap.new()
		map.make(theme)
		var before=hash([map.terrain,map.height_map,map.surface_map,map.buildable_map,map.resources,map.starts])
		var data=renderer._build_cache(map,0)
		check(map.source_info.origin=="source_chk_cv5_vf4","Original map geometry retained")
		var floor_points=data.layers[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var surface_points: Dictionary={}
		for point in floor_points:surface_points[point]=true
		var roles: Dictionary={}
		for layer in data.layers:
			var role=String(layer.get("role",""))
			if role.is_empty():continue
			roles[role]=true
			var arrays=layer.mesh.surface_get_arrays(0)
			var vertices=arrays[Mesh.ARRAY_VERTEX]
			if role.begins_with("coast") or role.begins_with("height_bank"):
				# Contour ribbons follow the boundary between levels, independently
				# tessellated from the floor grid. They must be solid, not soft blends.
				if role in ["coast","height_bank"]:
					check(layer.slot in [240+theme*5,241+theme*5,242+theme*5,243+theme*5],"level boundary uses its own modular face material")
					for color in arrays[Mesh.ARRAY_COLOR]:check(is_equal_approx(color.a,1.0),"water and height boundaries have opaque rock faces")
				continue
			for index in range(vertices.size()):
				check(surface_points.has(vertices[index]),"Relief must reuse the ground triangles without floating or flattened quads")
				if role=="cliff":check((vertices[index]/renderer.CLIFF_WORLD_PIXELS).distance_to(arrays[Mesh.ARRAY_TEX_UV][index])<.0001,"Cliff UV uses projected face size to prevent vertical stretching")
			if role=="ramp":
				check(layer.slot==192+theme*4,"Ramp shares the continuous HD soil of both landings")
				for uv in arrays[Mesh.ARRAY_TEX_UV]:check(uv.is_finite(),"ramp soil world coordinates remain continuous")
		check(roles.has("ramp")==not map.visual_ramps.is_empty(),"Ramp rendering follows each original map ramp data")
		check(roles.has("height_bank") and roles.has("height_bank_shadow") and roles.has("height_bank_rim"),"Vertical face, upper rim and contact shadow remain distinct layers")
		check(roles.has("coast") and roles.has("height_bank"),"water and land height boundaries are separate visible contours")
		var boundary=map.visual_boundary()
		check(boundary.size()==1024,"Visual boundary follows every half-cell perimeter segment")
		for vertex in boundary:
			var gx=roundi(vertex.x*2)
			var gy=roundi(vertex.y*2)
			var cell_x=mini(gx,255)
			var cell_y=mini(gy,255)
			var corner=0 if gx<256 and gy<256 else (1 if gy<256 else (2 if gx==256 else 3))
			var expected=floor_points[(cell_y*256+cell_x)*4+corner]
			check(Vector2(vertex.x*32,vertex.y*32-vertex.z).distance_to(expected)<.001,"Outer mask boundary matches actual terrain mesh")
		var mask=renderer._boundary_mask_mesh(map).surface_get_arrays(0)
		check(mask[Mesh.ARRAY_VERTEX].size()==4096,"Perimeter mask is a single closed 1024-quad mesh")
		for vertex in mask[Mesh.ARRAY_VERTEX]:check(vertex.is_finite(),"Outer boundary mask vertices remain finite")
		for sample in range(2000):
			var gx=posmod(sample*73,255)
			var gy=posmod(sample*97,255)
			var fraction=Vector2(fposmod(sample*.193,1),fposmod(sample*.317,1))
			var offset=(gy*256+gx)*4
			var expected_y=0.0
			if fraction.x>=fraction.y:expected_y=floor_points[offset].y*(1-fraction.x)+floor_points[offset+1].y*(fraction.x-fraction.y)+floor_points[offset+2].y*fraction.y
			else:expected_y=floor_points[offset].y*(1-fraction.y)+floor_points[offset+2].y*fraction.x+floor_points[offset+3].y*(fraction.y-fraction.x)
			var point=(Vector2(gx,gy)+fraction)*.5
			check(absf(point.y*32.0-map.visual_elevation(point)-expected_y)<.001,"Unit/input elevation must match the drawn mesh plane")
		for layer in data.layers:
			var arrays=layer.mesh.surface_get_arrays(0)
			for point in arrays[Mesh.ARRAY_VERTEX]:
				total_vertices+=1
				check(point.x>=0 and point.y>=0 and point.x<=4096 and point.y<=4096,"Terrain mesh remains inside map")
			for uv in arrays[Mesh.ARRAY_TEX_UV]:check(uv.is_finite(),"Material UV remains finite")
		check(before==hash([map.terrain,map.height_map,map.surface_map,map.buildable_map,map.resources,map.starts]),"Texture quality changes must preserve all map gameplay data")
	check(renderer.WATER_COLOR==Color("112d3b") and renderer.WATER_MODULATE==Color(.72,.82,.98,1),"Existing water palette preserved")
	var output={"passed":failures.is_empty(),"checks":checks,"failures":failures,"vertices":total_vertices,"textures":assets}
	print("TERRAIN_QUALITY_TEST ",JSON.stringify(output))
	FileAccess.open("res://build/terrain-v04-audit.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	quit(0 if failures.is_empty() else 1)
