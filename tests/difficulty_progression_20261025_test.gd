extends "res://tests/abilities_v060_test.gd"
const BOT=preload("res://scripts/bot_ai.gd")
var records=[]
func run():
	var args=OS.get_cmdline_user_args();var mode=args[0] if not args.is_empty() else "response"
	var selected_race=int(args[1]) if args.size()>1 else 0
	if mode=="opening":
		for level in range(6):
			var c=ACCore.new();c.setup({"map":0,"seed":251025,"spawn_slots":[0,2],"players":[{"race":selected_race,"bot":true,"difficulty":level},{"race":(selected_race+1)%3}]})
			var first_wave=-1.0;var first_expansion=-1.0
			for tick in range(6000):
				c.step(.1)
				if first_wave<0 and not c.players[0].get("_ai_wave",[]).is_empty():first_wave=c.time
				if first_expansion<0 and c.buildings.filter(func(b):return b.owner==0 and b.kind==0 and b.hp>0).size()>1:first_expansion=c.time
				if c.ended:break
			var p=c.players[0]
			var r={"race":selected_race,"level":level,"time":c.time,"won":c.ended and not p.lost,"workers":c.units.filter(func(u):return u.owner==0 and u.kind==0).size(),"army":c.units.filter(func(u):return u.owner==0 and u.kind>0 and not u.get("technical",false)).size(),"spent":p.spent,"gathered":p.gathered,"buildings":c.buildings.filter(func(b):return b.owner==0).size(),"first_wave":first_wave,"first_expansion":first_expansion}
			records.append(r);print("OPENING ",JSON.stringify(r))
		for level in range(1,6):
			check(records[level].first_wave>0 and records[level].first_wave<records[level-1].first_wave,"actual opening pressure increases at level "+str(level))
	else:
		for race in range(3):
			for level in range(6):
				var response=[];var hp=[];var survivors=[]
				for onset in [1.05,2.15,3.25,4.35,5.45]:
					var c=arena(race,0);c.players[0].as=0;c.players[0].tera=0;c.players[0].bot=true;c.players[0].difficulty=level
					var home=c.add_building(0,0,Vector2(40,40),true);c.players[0].home=home.id
					c.add_building(1,0,Vector2(100,100),true)
					var defenders=[]
					for i in range(6):defenders.append(c.add_unit(0,1,Vector2(41+i*.8,53)))
					for u in defenders:u.order="hold"
					var spawned=false;var response_at=-1.0
					for tick in range(240):
						if not spawned and c.time>=onset:
							spawned=true
							for i in range(4):
								var enemy=c.add_unit(1,1,Vector2(44+i*.7,39))
								c.command(1,{"type":"attack","ids":[enemy.id],"target":home.id})
							c._update_vision()
						if not spawned:
							for i in range(defenders.size()):
								var u=defenders[i];u.order="hold";u.path=[];c._set_unit_position(u,Vector2(41+i*.8,53))
						c.step(.05)
						if spawned and response_at<0 and defenders.any(func(u):return u.order!="hold" and u.order!="idle"):
							response_at=c.time-onset
					response.append(response_at);hp.append(home.hp);survivors.append(defenders.filter(func(u):return u.hp>0).size())
				var r={"race":race,"level":level,"reaction_seconds":response,"mean_reaction":response.reduce(func(a,b):return a+b,0.0)/response.size(),"hq_hp":hp,"survivors":survivors}
				records.append(r);print("RESPONSE ",JSON.stringify(r))
		for race in range(3):
			for level in range(1,6):
				var a=records[race*6+level-1];var b=records[race*6+level]
				check(b.mean_reaction<a.mean_reaction,"measured response gets faster race %d level %d"%[race,level])
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"mode":mode,"records":records}
	DirAccess.make_dir_recursive_absolute("res://build/difficulty-progression-20261025")
	FileAccess.open("res://build/difficulty-progression-20261025/%s-%d.json"%[mode,selected_race],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("DIFFICULTY_PROGRESSION ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
