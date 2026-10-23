extends SceneTree

var failures=[]
var checks=0
var report=[]

func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)

func frames(n=2):
	for _i in range(n):await process_frame

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1600,900)
	seed(20261024)
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/loading_art_20261024.json"))
	var approval=JSON.parse_string(FileAccess.get_file_as_string("res://docs/loading-art-approval-20261024.json"))
	for item in catalog.images:
		check(item.id in approval.approved_ids,"only explicitly approved images registered: "+str(item.id))
	ACLoadingScreen._last_art.clear()
	for race in range(3):
		var allowed=[]
		for item in catalog.images:
			if int(item.race)==race and item.approved:allowed.append(str(item.file))
		var previous="";var seen={}
		for index in range(80 if not allowed.is_empty() else 1):
			var screen=ACLoadingScreen.new();root.add_child(screen);screen.configure(race,race);screen.set_progress(.63,"지형 표면 준비 중")
			await frames(1)
			check(screen.background!=null,"background loads as a real texture")
			if allowed.is_empty():
				check("menu_planet_" in screen.background_path,"unapproved faction retains existing background")
			else:
				check(screen.background_path in allowed,"selected image belongs to this approved faction")
				if allowed.size()>1 and not previous.is_empty():check(previous!=screen.background_path,"no consecutive duplicate background")
			seen[screen.background_path]=true;previous=screen.background_path
			if index==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/player_colors_20261024/loading-art-in-game-r%d.png"%race)
			screen.queue_free();await frames(1)
		if not allowed.is_empty():check(seen.size()==allowed.size(),"all ten approved faction images selectable")
		report.append({"race":race,"approved":allowed.size(),"seen":seen.size()})
	var result={"checks":checks,"failures":failures,"factions":report}
	FileAccess.open("res://build/player_colors_20261024/loading-art-selection.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("LOADING_ART_SELECTION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
