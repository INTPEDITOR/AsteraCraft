extends SceneTree
func _initialize():call_deferred("run")
func run():
	var core=ACCore.new();core.setup({"map":0,"seed":617,"players":[{"race":1},{"race":0}]})
	core.roots.update(core);core.time=20;core.roots.update(core)
	var packed=core.roots.snapshot(core,-1);var renderer=ACRootRenderer.new()
	var start=Time.get_ticks_usec()
	for i in range(10):renderer.build(core.map,packed,func(_index):return 2)
	print("ROOT_RENDER_PROFILE ",JSON.stringify({"cells":packed.size(),"average_build_ms":(Time.get_ticks_usec()-start)/10000.0}))
	if FileAccess.file_exists("res://build/root-renderer-before.txt"):
		var old_script=GDScript.new();old_script.source_code=FileAccess.get_file_as_string("res://build/root-renderer-before.txt").replace("class_name ACRootRenderer","");old_script.reload()
		var previous=old_script.new();start=Time.get_ticks_usec()
		for i in range(10):previous.build(core.map,packed,func(_index):return 2)
		print("ROOT_RENDER_BASELINE ",JSON.stringify({"cells":packed.size(),"average_build_ms":(Time.get_ticks_usec()-start)/10000.0}))
		assert(previous.vertex_count==renderer.vertex_count)
		assert(previous.mesh.surface_get_arrays(0)==renderer.mesh.surface_get_arrays(0))
	var fog=PackedByteArray();fog.resize(16384);fog.fill(2)
	var read_fog=func(index):return fog[index]
	var signature=renderer.relevant_fog_signature(packed,read_fog)
	fog[0]=1
	assert(signature==renderer.relevant_fog_signature(packed,read_fog))
	fog[ACRootField.ground_index(int(packed[0])&0xffff)]=1
	assert(signature!=renderer.relevant_fog_signature(packed,read_fog))
	print("ROOT_RENDER_EQUIVALENCE PASS")
	quit()
