extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args();assert(args.size()==3)
	var old_folder=args[0];var new_folder=args[1];var new_tag=args[2]
	var expected=JSON.parse_string(FileAccess.get_file_as_string("res://build/"+new_folder+"/package-result.json"))
	assert(ProjectSettings.load_resource_pack("res://build/"+old_folder+"/AsteraCraft.pck",true))
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://data/update_channel.json"))
	var updater=load("res://scripts/game_updater.gd").new();root.add_child(updater);updater.metadata=old;updater.install_enabled=true
	updater.check_updates(true);var started=Time.get_ticks_msec()
	while updater.state=="checking" and Time.get_ticks_msec()-started<25000:await process_frame
	var passed=updater.state=="available" and updater.target.get("tag")==new_tag and updater.target.get("sha256")==expected.sha256
	var result={"passed":passed,"old_packed_tag":old.tag,"state":updater.state,"target":updater.target,"scope":"Actual previous PCK metadata and updater, live public GitHub HTTPS release feed; no archive download or installation"}
	FileAccess.open("res://build/"+new_folder+"/public-feed-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("PUBLIC_UPDATE_FEED ",JSON.stringify(result));quit(0 if passed else 1)
