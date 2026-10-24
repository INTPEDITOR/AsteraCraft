extends "res://tests/abilities_v060_test.gd"
func run() -> void:
	check(ACAbilities.catalog(0,4).all(func(s):return s.id!="stim"),"medic no longer owns stim")
	for kind in [1,2]:
		var c=arena(0,0);var u=c.add_unit(0,kind,Vector2(40,40));u.energy=0
		var skill=ACAbilities.catalog(0,kind).filter(func(s):return s.id=="stim")[0]
		check(skill.target=="self" and skill.energy==0 and skill.hp_cost==10,"rifle and assault receive self stim with HP10 cost")
		var hp=u.hp
		check(cast(c,u,"stim")!="" and u.hp==hp,"missing research spends no HP")
		c.players[0].technologies.stim=1
		for health in [1.0,9.0,10.0]:
			u.hp=health
			check(cast(c,u,"stim")!="" and u.hp==health and not u.get("skill_ready",{}).has("stim"),"HP at or below10 cannot activate or spend cooldown")
		u.hp=11
		check(cast(c,u,"stim")=="" and u.hp==1 and u.energy==0,"HP11 activation spends exactly10HP without energy")
		check(u.stim_until==c.time+7,"existing seven-second buff is preserved")
		check(cast(c,u,"stim")!="" and u.hp==1,"cooldown prevents repeated HP charges")
		u.hp=100;u.pos=[40,40];u.order="move";u.goal=[50,40];u.path=[];u.path_rev=-1;c.paths_this_tick=0
		c._move(u,Vector2(50,40),.05,.25)
		check(ACData.point(u.pos).x>40,"stimmed infantry can move normally")
	var result={"checks":checks,"failures":failures,"casters":[1,2],"hp_cost":10,"minimum_hp_exclusive":10,"duration":7,"speed_multiplier":1.25,"attack_period_multiplier":.75}
	DirAccess.make_dir_recursive_absolute("res://build/stim-20261024")
	FileAccess.open("res://build/stim-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("STIM_SELF ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
