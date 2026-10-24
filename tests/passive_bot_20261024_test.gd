extends "res://tests/abilities_v060_test.gd"
const BotAI=preload("res://scripts/bot_ai.gd")
func run() -> void:
	for race in range(3):
		var c=arena(race,race);c.time=20;c.players[0].difficulty=1
		var hq=c.add_building(0,0,Vector2(20,20),true);c.players[0].home=hq.id
		var building=c.add_building(0,[7,4,6][race],Vector2(30,20),true)
		for kind in ([9] if race==1 else [7] if race==2 else []):c.add_building(0,kind,Vector2(25,30),true)
		for index in range(8):c.add_unit(0,1,Vector2(35+index,35))
		BotAI.tick(c,0)
		var key=["frontline_vitality","claw_overdrive","guardian_march"][race]
		check(str(building.research)==key,"AI chooses the owned army's passive in its designated building, race "+str(race))
		check(c.players[0].as<10000 and c.players[0].tera<10000,"AI pays real research resources, race "+str(race))
		ACResearch.tick(c,building,100)
		check(ACResearch.level(c.players[0],key)==1,"AI's queued passive completes normally, race "+str(race))
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Three-race AI queues and pays for an appropriate army passive, then completes its actual research."}
	FileAccess.open("res://build/passives-20261024/bot-result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PASSIVE_BOT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
