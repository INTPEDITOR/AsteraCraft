extends SceneTree
class Settings extends Control:
	var race_choice=0
	var color_choice=6
	var map_choice=0
	var bot_count=1
	var game_mode="ffa"
	var difficulty=5
	var account={"nickname":"색상 검사"}
var checks=0
var failures=[]
var records=[]
func _initialize():call_deferred("run")
func check(value,label):
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func run():
	var settings=Settings.new();var menu=ACMenuPages.new(settings)
	for race in range(3):
		settings.race_choice=race;settings.map_choice=race
		for mode in ["ffa","teams"]:
			settings.game_mode=mode;settings.bot_count=1
			var seen={};var chosen={}
			for seed_value in range(256):
				var random=RandomNumberGenerator.new();random.seed=seed_value
				var config=menu.single_config(random)
				for player in config.players.slice(1):seen[int(player.race)]=true
				if config.players.slice(1).all(func(p):return int(p.race)==race):chosen=config
			check(seen.size()==3 and not chosen.is_empty(),"all races including mirror are drawn race%d %s"%[race,mode])
			if chosen.is_empty():continue
			var c=ACCore.new();c.setup(chosen)
			var colors={}
			for p in c.players:colors[int(p.color_id)]=true
			check(c.players.size()==(4 if mode=="teams" else 2),"player count follows selected game mode")
			check(c.players.all(func(p):return int(p.race)==race) and colors.size()==c.players.size(),"actual same-race match starts with distinct player colors")
			check(c.players[0].color_id==settings.color_choice,"chosen human color is preserved")
			check(c.players.slice(1).all(func(p):return bool(p.bot) and int(p.difficulty)==settings.difficulty),"bot difficulty is preserved")
			if mode=="teams":check(c.allied(0,2) and not c.allied(0,1),"team assignments are preserved")
			records.append({"race":race,"mode":mode,"colors":c.players.map(func(p):return int(p.color_id)),"players":c.players.size()})
	# FFA bot counts and default racial colors go through the same production path.
	settings.game_mode="ffa";settings.color_choice=-1
	for count in [1,2,3]:
		settings.bot_count=count;var config=menu.single_config();var unique={}
		for p in config.players:unique[p.color_id]=true
		check(config.players.size()==count+1 and unique.size()==count+1,"FFA count and unique colors for %d bots"%count)
		check(config.players[0].color_id==ACPlayerColors.NATIVE[settings.race_choice],"default human pigment is preserved")
	settings.free()
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"matches":records}
	DirAccess.make_dir_recursive_absolute("res://build/single-mirror-20261025")
	FileAccess.open("res://build/single-mirror-20261025/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SINGLE_MIRROR ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
