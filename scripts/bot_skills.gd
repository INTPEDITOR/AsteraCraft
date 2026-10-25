extends RefCounted
const T=preload("res://scripts/bot_tactics.gd")

static func cast(c,u: Dictionary,key: String,point: Vector2,target: int=-1) -> bool:
	if c.command(int(u.owner),{"type":"skill","skill":key,"ids":[u.id],"pos":ACData.packed(point),"target":target})!="":return false
	T.log_action(c.players[u.owner],"skill:"+key);return true

static func nearby(c,u: Dictionary,items: Array,radius: float,ground: bool=false) -> Array:
	return items.filter(func(e):return e.hp>0 and int(e.get("container",-1))<0 and c.center(u).distance_squared_to(c.center(e))<=radius*radius and (not ground or e.has("progress") or not c.unit_data(e).air))

static func tick(c,owner: int,army: Array,visible: Array,plan: Dictionary,engaged: bool,goal: Vector2) -> void:
	var p: Dictionary=c.players[owner]
	if int(p.difficulty)<1:return
	for u in army:
		if u.hp<=0 or u.container>=0 or not u.get("channel",{}).is_empty():continue
		var d=c.unit_data(u);var enemies=nearby(c,u,visible,10);var friends=nearby(c,u,army,4)
		var ground=nearby(c,u,visible,8,true)
		if int(u.race)==0 and int(u.kind)==7 and not u.get("cloak_active",false) and float(u.energy)>=30 and not enemies.is_empty():
			c.command(owner,{"type":"ability","ids":[u.id]});T.log_action(p,"cloak")
		for skill in ACAbilities.catalog(int(u.race),int(u.kind)):
			var key=str(skill.id)
			if key=="nuclear" or not ACAbilities.unlocked(p,skill) or float(u.energy)<float(skill.energy) or float(u.get("skill_ready",{}).get(key,0))>c.time:continue
			var targets=nearby(c,u,visible,float(skill.range))
			var allies=nearby(c,u,army,float(skill.range))
			var used=false
			match key:
				"stim":
					if not enemies.is_empty() and float(u.hp)>maxf(10,float(d.hp)*.4) and float(u.get("stim_until",0))<=c.time:used=cast(c,u,key,c.center(u))
				"smoke":
					if enemies.size()>=2 and friends.size()>=3:used=cast(c,u,key,c.center(friends[0]))
				"field_repair":
					if enemies.is_empty() and u.hp<float(d.hp)*.7 and float(u.get("self_repair_until",0))<=c.time:used=cast(c,u,key,c.center(u))
				"scan":
					if engaged and c.center(u).distance_to(goal)<=float(skill.range) and not c.reveals.any(func(r):return int(r.owner)==owner and ACData.point(r.pos).distance_to(goal)<6):used=cast(c,u,key,goal)
				"carapace":
					if not ground.is_empty() and float(u.get("carapace_until",0))<=c.time:used=cast(c,u,key,c.center(u))
				"scatter","pierce":
					if ground.size()>=3:used=cast(c,u,key,c.center(u))
				"shed":
					if float(u.slow_until)>c.time or float(u.get("rooted_until",0))>c.time:used=cast(c,u,key,c.center(u))
				"neural","mind_control":
					var best={};var value=0.0
					for e in targets:
						if e.has("progress") or e.get("technical",false) or not e.get("cargo",[]).is_empty():continue
						var ed=c.unit_data(e);var worth=float(ed.as)+float(ed.tera)*1.5 if key=="mind_control" else float(ed.damage)/maxf(.1,float(ed.period))
						if key=="neural" and float(e.get("attack_slow_until",0))>c.time:continue
						if key=="neural" and ACResearch.level(p,"mind_control")>0 and u.energy>=150:continue
						if worth>value:value=worth;best=e
					if not best.is_empty() and (key!="mind_control" or value>=175):used=cast(c,u,key,c.center(best),int(best.id))
				"sap_heal":
					if not u.get("sap_heal_enabled",true):used=cast(c,u,key,c.center(u))
				"sap_reclaim":
					if u.energy<float(u.max_energy)*.3:
						for ally in allies:
							var ad=c.unit_data(ally)
							if int(ally.kind)>0 and not ad.air and float(ad.as)+float(ad.tera)*1.5<=80 and ally.hp<float(ad.hp)*.3 and ally.get("cargo",[]).is_empty():used=cast(c,u,key,c.center(ally),int(ally.id));break
				"sap_bloom":
					if not enemies.is_empty() and friends.filter(func(a):return float(c.unit_data(a).damage)>0 and float(a.get("bloom_until",0))<=c.time).size()>=3:used=cast(c,u,key,c.center(u))
				"judgment","overcharge","shockwave","root_surge","discipline":
					var best={};var count=1
					for e in targets:
						if key in ["overcharge","shockwave","root_surge"] and not e.has("progress") and c.unit_data(e).air:continue
						var clustered=visible.filter(func(x):return c.center(x).distance_to(c.center(e))<2.2 and (not key in ["overcharge","shockwave","root_surge"] or x.has("progress") or not c.unit_data(x).air)).size()
						if clustered>count:count=clustered;best=e
					if not best.is_empty():used=cast(c,u,key,c.center(best))
				"silence","bind":
					for e in targets:
						if e.has("progress"):continue
						var ed=c.unit_data(e)
						if key=="silence" and ed.role in ["medic","healer_detector","mage","priest","parasite"] and float(e.get("silenced_until",0))<=c.time:used=cast(c,u,key,c.center(e),int(e.id));break
						if key=="bind" and e.get("moving",false) and float(e.get("control_guard_until",0))<=c.time and float(ed.as)+float(ed.tera)*1.5>=100:used=cast(c,u,key,c.center(e),int(e.id));break
				"march":
					if engaged and friends.size()>=3 and c.center(u).distance_to(goal)>6 and float(u.get("march_until",0))<=c.time:used=cast(c,u,key,c.center(u))
				"barrier","purify":
					for ally in allies:
						if key=="barrier" and c.time-float(ally.damaged)<3 and float(ally.get("ward",0))<=0:used=cast(c,u,key,c.center(ally),int(ally.id));break
						if key=="purify" and (float(ally.slow_until)>c.time or float(ally.get("rooted_until",0))>c.time or float(ally.get("attack_slow_until",0))>c.time):used=cast(c,u,key,c.center(ally),int(ally.id));break
				"verdict":
					for e in targets:
						var axis=(c.center(e)-c.center(u)).normalized()
						var hits=visible.filter(func(x):return (c.center(x)-c.center(u)).dot(axis)>0 and (c.center(x)-c.center(u)).dot(axis)<11 and absf((c.center(x)-c.center(u)).cross(axis))<1).size()
						if hits>=2:used=cast(c,u,key,c.center(u)+axis*10.5);break
			if used:break
