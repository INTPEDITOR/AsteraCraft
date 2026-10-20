extends SceneTree
func _initialize():
	for race in range(3):
		var c=ACCore.new();c.setup({"map":0,"players":[{"race":race},{"race":race}]})
		for i in range(200):c.add_unit(i%2,1,Vector2(60+i%10,60+int(i/10)*.3))
		c._rebuild_collision_index();c._update_vision();c.visibility[0].fill(1)
		var stats={"snapshot_us":0,"view_us":0,"serialize_us":0,"compress_us":0,"bytes":0}
		for i in range(30):
			var started=Time.get_ticks_usec();var state=c.snapshot(0);stats.snapshot_us+=Time.get_ticks_usec()-started
			started=Time.get_ticks_usec();var bytes=var_to_bytes(state);stats.serialize_us+=Time.get_ticks_usec()-started
			started=Time.get_ticks_usec();var packed=bytes.compress(FileAccess.COMPRESSION_FASTLZ);stats.compress_us+=Time.get_ticks_usec()-started;stats.bytes=packed.size()
			started=Time.get_ticks_usec();c.snapshot(0,true);stats.view_us+=Time.get_ticks_usec()-started
		for key in ["snapshot_us","view_us","serialize_us","compress_us"]:stats[key]/=30
		print("SNAPSHOT_COST ",race," ",JSON.stringify(stats))
	quit()
