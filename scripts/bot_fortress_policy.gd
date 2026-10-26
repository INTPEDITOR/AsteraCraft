extends RefCounted
## This unit is an occasional anti-swarm support purchase, never an opening.
static func favorable(c,owner: int,army_size: int) -> bool:
	var p: Dictionary=c.players[owner]
	if int(p.race)!=0 or army_size<24 or float(p.as)<900 or float(p.tera)<600 or c.time<float(p.get("_ai_fortress_next",0)):return false
	var own=0.0
	for unit in c.units:
		if int(unit.owner)!=owner or unit.hp<=0 or int(unit.kind)==0 or unit.get("technical",false):continue
		var d=c.unit_data(unit)
		if float(d.damage)>0 and "g" in str(d.targets) or d.role=="carrier":own+=float(d.pop)
	if own<30:return false
	var ground=0.0;var air=0.0;var heavy=0.0;var counters=0.0
	for item in p.get("_ai_sightings",{}).values():
		if item.building or c.time-float(item.seen)>45 or str(item.role)=="worker":continue
		var population=maxf(.5,float(item.pop));var d=ACData.unit(int(item.race),int(item.kind))
		if item.air:air+=population
		else:
			ground+=population
			if str(item.armor_class)=="heavy":heavy+=population
		if d.role in ["siege","mage","chaser"] or float(d.get("bonus_heavy",0))>=4 and float(d.range)>=4:counters+=population
	return ground>=12 and own>=ground*1.2 and air<=1 and heavy<=ground*.35 and counters<2
