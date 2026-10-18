extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok and not failures.has(label):failures.append(label)
func _initialize():
	var renderer=ACTerrainRenderer.new()
	var map=ACMap.new();map.make(0)
	map.terrain.fill(0);map.height_map.fill(0);map.visual_roles.fill(0);map._build_visual_relief()
	var fields=[]
	for i in range(7):
		var field=PackedFloat32Array();field.resize(renderer.STRIDE*renderer.STRIDE)
		# Uniform mixed soil must stay uniform even on shared diamond edges.
		field.fill(.6 if i==2 else 0.0);fields.append(field)
	var layers=renderer._diamond_layers(map,fields).layers
	check(layers.size()==2,"base and mixed-soil layers exist")
	var shared=0
	for layer in layers:
		var a=layer.mesh.surface_get_arrays(0);var seen={}
		# ArrayMesh packs vertex colors into eight-bit channels.
		var expected=1.0 if layer.slot==192 else roundf(.6*255)/255.0
		for i in range(a[Mesh.ARRAY_VERTEX].size()):
			var p=a[Mesh.ARRAY_VERTEX][i];var uv=a[Mesh.ARRAY_TEX_UV][i];var color=a[Mesh.ARRAY_COLOR][i]
			check(absf(color.a-expected)<.00001,"uniform coverage does not fade at tile borders")
			check(uv.distance_to(renderer._detail_uv(p,renderer._material_span(layer.slot)))<.00001,"UVs do not restart per tile")
			if seen.has(p):
				shared+=1;check(seen[p].is_equal_approx(uv),"shared vertices sample identical material")
			seen[p]=uv
	check(shared>1000,"shared diamond edges were checked")
	# Check continuous weights either side of a material transition, including
	# samples straddling grid vertices that previously used nearest-neighbor.
	for y in range(renderer.STRIDE):
		for x in range(renderer.STRIDE):fields[2][y*renderer.STRIDE+x]=float(x)/renderer.GRID
	for x in range(1,256):
		var p=Vector2(x*16,120)
		check(absf(renderer._field_at(fields[2],p-Vector2(.001,0))-renderer._field_at(fields[2],p+Vector2(.001,0)))<.00001,"material transition remains continuous")
	for direction in [Vector2(128,0),Vector2(0,128),Vector2(64,-128),Vector2(-128,-64)]:
		var bank=renderer._bank_paths([[Vector2.ZERO,direction]])[0]
		check(absf(bank.u1-bank.u0-direction.length()/128.0)<.00001,"bank texel density is independent of direction")
	var loop=renderer._bank_paths([[Vector2(0,0),Vector2(64,0)],[Vector2(64,0),Vector2(64,64)],[Vector2(64,64),Vector2(0,64)],[Vector2(0,64),Vector2(0,0)]])
	check(loop.size()==4 and is_equal_approx(loop[-1].u1,2.0),"closed bank joins at a complete mirrored texture period")
	print("TERRAIN_SEAMS ",JSON.stringify({"checks":checks,"shared_vertices":shared,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
