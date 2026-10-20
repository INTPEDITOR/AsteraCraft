extends "res://tests/view_input_v03_test.gd"
func files():
	var result=[]
	if DirAccess.dir_exists_absolute("user://replays"):
		for file in DirAccess.get_files_at("user://replays"):
			if file.ends_with(".acr"):result.append(file)
	return result
func run():
	main=load("res://scripts/main.gd").new();root.add_child(main);await frames(4)
	main._start_local({"map":0,"players":[{"race":0},{"race":1}]});main.paused=true;main.set_process(false)
	var c=main.core;var u=c.units[0];u.path=[[15,15],[16,16]];c.players[1]._ai_wave=[u.id]
	var before=files();var live=c.snapshot(0,true)
	check(live._live_view and live.units[0].has("path"),"local render keeps cheap internal navigation view")
	var frame=main._encode_replay_frame(live);var decoded=main._replay_state(frame)
	check(not decoded.get("_live_view",false) and decoded.units.all(func(e):return not e.has("path") and not e.has("_definition")),"recorded frames strip paths and private cached definitions")
	check(decoded.players.all(func(p):return not p.has("_ai_wave")),"AI strategy state is not sent to clients or replays")
	main.replay_frames=[frame]
	c.players[0].lost=true;c._check_end();main.state=c.snapshot(0);main._update_hud();await frames(3)
	check(files()==before,"ending a game creates no replay file automatically")
	main._save_replay();main._save_replay()
	var after=files();var created=after.filter(func(file):return not file in before)
	check(created.size()==2,"two explicit saves in the same second preserve two distinct files")
	for file in created:
		var saved=FileAccess.open_compressed("user://replays/"+file,FileAccess.READ,FileAccess.COMPRESSION_DEFLATE)
		var data=saved.get_var(false);saved.close()
		check(data.version=="0.6.0" and data.frames.size()==1 and not main._replay_state(data.frames[0]).units[0].has("path"),"saved file loads with the exact sanitized frame")
	print("REPLAY_PRIVACY_V060 ",JSON.stringify({"checks":checks,"failures":failures,"explicit_files":created.size()}));main.queue_free();await frames();quit(0 if failures.is_empty() else 1)
