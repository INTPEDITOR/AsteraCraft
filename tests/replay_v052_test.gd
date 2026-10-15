extends SceneTree
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func _initialize() -> void:
	var main=load("res://scripts/main.gd").new()
	check(main._minimum_zoom()==main.DEFAULT_ZOOM,"player cannot zoom below default")
	main.spectator=true
	check(main._minimum_zoom()<main.DEFAULT_ZOOM,"observer can zoom out")
	main.spectator=false;main.replay_mode=true
	for codec in [FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_FASTLZ]:
		main.replay_codec=codec;main.replay_frames=[];main.paused=false
		for tick in range(4):
			var unit={"id":1,"race":0,"kind":1,"pos":[10.0+tick*3.0,10.0],"facing":[1,0],"container":-1}
			var snapshot={"time":float(tick),"units":[unit]}
			main.replay_frames.append(var_to_bytes(snapshot).compress(codec) if codec==FileAccess.COMPRESSION_DEFLATE else main._encode_replay_frame(snapshot))
		main._begin_replay()
		main._tick_replay(.5)
		check(main.replay_index==1,"one-second recording not played at double speed")
		check(is_equal_approx(main._visual_position(main.state.units[0]).x,11.5),"half-frame position interpolates smoothly")
		main.paused=true
		main._tick_replay(3)
		check(is_equal_approx(main._visual_position(main.state.units[0]).x,11.5),"pause holds interpolated position")
		main.paused=false;main._tick_replay(.7)
		check(main.replay_index==2 and is_equal_approx(main.replay_clock,.2),"irregular frame time preserves remainder")
		main._tick_replay(10)
		check(main.paused and main.replay_index==3,"playback stops at end")
	main.free()
	print("REPLAY_V052 "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
