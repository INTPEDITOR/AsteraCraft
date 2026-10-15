extends SceneTree
var results: Array=[]
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for race in range(3):
		for difficulty in range(3):
			var c=ACCore.new()
			c.setup({"map":race,"seed":7719,"spawn_slots":[0,2],"players":[{"race":race,"bot":true,"difficulty":difficulty},{"race":(race+1)%3}]})
			for i in range(2400):c.step(.1);c.resolve_spells()
			var workers=0;var army=0;var sites=0
			for u in c.units:
				if u.owner!=0 or u.get("technical",false):continue
				if u.kind==0:workers+=1
				else:army+=1
			for b in c.buildings:
				if b.owner==0:sites+=1
			var p=c.players[0]
			var row={"race":race,"difficulty":difficulty,"workers":workers,"army":army,"buildings":sites,"as":p.as,"gathered":p.gathered,"spent":p.spent}
			results.append(row);print(JSON.stringify(row))
			if workers<5 or army<1 or sites<3:failures.append("opening stalled "+JSON.stringify(row))
			if p.as<0 or p.tera<0:failures.append("negative economy")
			c=null
	var report={"results":results,"failures":failures}
	var file=FileAccess.open("res://build/bot-v051-report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BOT_V051 "+JSON.stringify(report));quit(0 if failures.is_empty() else 1)
