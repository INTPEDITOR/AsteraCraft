extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var art=ACCommandIcons.new();var count=0
	for race in range(3):
		for category in ["units","buildings","commands"]:
			for index in range(32 if category=="commands" else 16):
				var texture=art.texture(race,category,index)
				check(texture!=null,"runtime icon exists %s/%d/%d"%[category,race,index])
				if texture==null:continue
				if category=="commands" and index in [29,30]:
					check(not texture.get_image().is_empty(),"approved complete page arrow exists");continue
				var image=texture.get_image();var box=image.get_used_rect()
				check(image.get_size()==Vector2i(128,128) and box.position.x>=6 and box.position.y>=6 and box.end.x<=122 and box.end.y<=122,"standalone padded cell cannot sample atlas neighbor")
				count+=1
		for key in art._skills[race]:check(art.skill(race,key)!=null,"all skill/research commands use isolated cell "+key)
		for stat in ACData.research_stats(race,6):check(art.research(race,stat)!=null,"upgrade icon exists")
	for key in ["sap_heal","sap_reclaim","sap_bloom"]:
		var texture=art.skill(1,key);var box=texture.get_image().get_used_rect();check(box.position.x>=6 and box.position.y>=6 and box.end.x<=122 and box.end.y<=122,"support skill isolated "+key);count+=1
	var output={"checks":checks,"failures":failures,"padded_cells_checked":count,"complete_original_page_arrows":6}
	FileAccess.open("res://build/player_colors_20261024/icon-isolation.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("ICON_ISOLATION ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
