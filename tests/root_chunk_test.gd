extends SceneTree
func _initialize():call_deferred("run")
func run():
	var core=ACCore.new();core.setup({"map":0,"seed":617,"players":[{"race":1},{"race":0}]})
	core.roots.update(core);core.time=20;core.roots.update(core)
	var packed=core.roots.snapshot(core,-1);var renderer=ACRootRenderer.new()
	var fog=PackedByteArray();fog.resize(16384);fog.fill(2)
	var read_fog=func(i):return fog[i]
	var frames=0;var peak=0.0
	while frames==0 or not renderer.pending.is_empty():
		var before=renderer.build_count;var start=Time.get_ticks_usec()
		renderer.update_chunks(core.map,packed,read_fog,hash(fog))
		peak=maxf(peak,(Time.get_ticks_usec()-start)/1000.0)
		assert(renderer.build_count-before<=3)
		frames+=1;assert(frames<200)
	var builds=renderer.build_count
	for i in range(60):renderer.update_chunks(core.map,packed,read_fog,hash(fog))
	assert(builds==renderer.build_count)
	fog[0]=1;renderer.update_chunks(core.map,packed,read_fog,hash(fog))
	assert(builds==renderer.build_count)
	var corner=Vector2i(40,40);fog.fill(2);fog[ACRootField.ground_index(39*256+39)]=0
	assert(renderer._corner_fog(corner,read_fog).y==0)
	fog.fill(2);fog[ACRootField.ground_index(39*256+39)]=1
	var light=renderer._corner_fog(corner,read_fog).x
	assert(light>.38 and light<1.0)
	var revision=core.roots.revision;core.time+=10;core.roots.update(core)
	assert(revision==core.roots.revision)
	print("ROOT_CHUNKS PASS cells=",packed.size()," chunks=",builds," frames=",frames," peak_update_ms=",peak)
	quit()
