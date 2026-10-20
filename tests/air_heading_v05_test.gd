extends SceneTree

func _initialize() -> void:
	var view=load("res://scripts/main.gd").new()
	view.paused=true
	var failures: Array=[]
	var checks=0
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			if not ACData.unit(race,kind).air:continue
			for heading in range(32):
				var travel=Vector2.UP.rotated(TAU*heading/32.0)
				var unit={"id":1,"race":race,"kind":kind,"moving":true,"facing":ACData.packed(-travel),"body_direction":ACData.packed(travel)}
				checks+=1
				if view._visual_facing(unit).dot(travel)<.999:
					failures.append("moving aircraft points away from displacement: %d:%d:%d"%[race,kind,heading])
				unit.moving=false
				checks+=1
				if view._visual_facing(unit).dot(-travel)<.999:
					failures.append("stationary aircraft cannot face its target: %d:%d:%d"%[race,kind,heading])
	# This verifies direction selection, not the visual correctness of generated art.
	var report={"checks":checks,"failures":failures,"scope":"All aircraft including the new carrier and drone, 32 headings, moving and stationary direction selection. Artwork still requires visual review."}
	FileAccess.open("res://build/air-heading-v05-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("AIR_HEADING_V05 checks=",checks," failures=",failures.size())
	view.free()
	quit(0 if failures.is_empty() else 1)
