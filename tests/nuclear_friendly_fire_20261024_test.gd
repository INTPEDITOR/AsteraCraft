extends "res://tests/abilities_v060_test.gd"
func run() -> void:
	var c=arena(0,0);c.mode="teams";c.players.append(c.players[0].duplicate(true));c.players[2].team=c.players[0].team
	var caster=c.add_unit(0,7,Vector2(40,40));caster.hp=3000;caster.shield=0
	var own=c.add_unit(0,1,Vector2(42,40));var ally=c.add_unit(2,1,Vector2(40,42));var enemy=c.add_unit(1,1,Vector2(38,40))
	var outside=c.add_unit(0,1,Vector2(46,40));var air=c.add_unit(0,9,Vector2(40,39))
	var building=c.add_building(0,0,Vector2(38,38),true)
	for target in [own,ally,enemy,outside,air,building]:target.hp=3000;target.shield=0
	c._rebuild_collision_index();c.ability_events=[{"owner":0,"caster":caster.id,"skill":"nuclear","when":0,"pos":[40,40],"source":[40,40],"committed":true}]
	ACAbilities.update(c,0)
	check(caster.hp<3000,"launcher itself takes nuclear blast damage")
	check(own.hp<3000 and ally.hp<3000 and enemy.hp<3000,"own, allied and enemy ground units take blast damage")
	check(is_equal_approx(own.hp,ally.hp) and is_equal_approx(own.hp,enemy.hp),"identical units at equal distance receive identical damage regardless of allegiance")
	check(air.hp<3000 and building.hp<3000,"own air units and buildings take blast damage")
	check(outside.hp==3000,"outside-radius ally is unharmed")
	var before=own.hp;c._damage(caster,own,100,false,"spell")
	check(is_equal_approx(own.hp,before),"ordinary friendly spell protection is preserved")
	check("자신과 아군" in ACAbilities.description("nuclear"),"tooltip explains friendly damage")
	DirAccess.make_dir_recursive_absolute("res://build/nuclear_20261024")
	var result={"checks":checks,"failures":failures,"damage":3000-own.hp,"radius":5,"ordinary_friendly_spell_protection":true}
	FileAccess.open("res://build/nuclear_20261024/friendly-fire.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("NUCLEAR_FRIENDLY_FIRE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
