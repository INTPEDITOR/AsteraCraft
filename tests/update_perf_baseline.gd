extends SceneTree
func _initialize():call_deferred("run")
func run():
	var renderer=ACTerrainRenderer.new();var terrain=ACMap.new();terrain.make(1)
	var data={"fog_updated":0,"fog_hash":0,"fog_texture":null}
	var samples=[]
	for i in range(20):
		data.fog_updated=-1000
		var before=Time.get_ticks_usec()
		renderer._update_fog(data,func(index):return 2 if (index+i)%37<12 else 1)
		samples.append((Time.get_ticks_usec()-before)/1000.0)
	print("FOG_PROFILE ",JSON.stringify(samples))
	quit()
