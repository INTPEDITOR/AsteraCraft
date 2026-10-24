extends SceneTree
var updater: Node
var started=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	updater=load("res://scripts/game_updater.gd").new();root.add_child(updater)
	updater.metadata={"tag":"read-only-old-fixture","built_at_unix":1};updater.install_enabled=true
	started=Time.get_ticks_msec();updater.check_updates(true)
	while updater.state=="checking" and Time.get_ticks_msec()-started<25000:await process_frame
	var passed=updater.state in ["available","failed"] and not updater.target.is_empty() and updater.request==null
	var result={"passed":passed,"state":updater.state,"target":updater.target,"scope":"Actual official GitHub release metadata over Godot HTTPS only; no archive download or installation"}
	DirAccess.make_dir_recursive_absolute("res://build/updater-test-20261024")
	FileAccess.open("res://build/updater-test-20261024/feed-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UPDATER_LIVE_FEED ",JSON.stringify(result));quit(0 if passed else 1)
