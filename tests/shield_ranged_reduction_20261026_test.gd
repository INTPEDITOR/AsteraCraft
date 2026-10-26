extends "res://tests/two_workers_per_as_20261026_test.gd"
func damage(c,attacker,target,amount,kind="attack",fraction=1.0):
	var before=float(target.hp)+float(target.shield)
	c._damage(attacker,target,amount,false,kind,fraction,fraction)
	return before-float(target.hp)-float(target.shield)
func run():
	var c=fixture(0);c.time=300;c.players[1].race=2
	var guard=c.add_unit(0,3,Vector2(80,80));var archer=c.add_unit(1,2,Vector2(86,80));var melee=c.add_unit(1,1,Vector2(81,80))
	guard.facing=[0,1];var original=c.unit_data(guard).duplicate();var without=original.duplicate();without.ranged_damage_reduction=0
	guard._definition=without;var normal=damage(c,archer,guard,21)
	guard.hp=175;guard._definition=original;var protected=damage(c,archer,guard,21)
	check(is_equal_approx(normal-protected,5),"normal ranged hit loses exactly five less real health after armour")
	guard.hp=175;guard._definition=without;normal=damage(c,melee,guard,13)
	guard.hp=175;guard._definition=original;protected=damage(c,melee,guard,13)
	check(is_equal_approx(normal,protected),"ordinary melee hits do not receive the ranged-only reduction")
	guard.facing=[1,0];guard.hp=175;guard._definition=without;normal=damage(c,archer,guard,21)
	guard.hp=175;guard._definition=original;protected=damage(c,archer,guard,21)
	check(is_equal_approx(normal-protected,5),"flat ranged reduction composes with existing frontal protection after its calculation")
	guard.hp=175;guard._definition=without;normal=damage(c,archer,guard,40,"spell")
	guard.hp=175;guard._definition=original;protected=damage(c,archer,guard,40,"spell")
	check(is_equal_approx(normal,protected),"spell damage is separate from ordinary ranged attacks")
	guard.facing=[0,1];guard.hp=175;guard._definition=without;normal=0
	for packet in range(10):normal+=damage(c,archer,guard,4,"attack",.1)
	guard.hp=175;guard._definition=original;protected=0
	for packet in range(10):protected+=damage(c,archer,guard,4,"attack",.1)
	check(is_equal_approx(normal-protected,5),"beam packets apply five per complete attack rather than five every frame")
	guard.hp=175;protected=damage(c,archer,guard,1)
	check(is_equal_approx(protected,1),"weak ranged hits retain the minimum one damage")
	archer.hp=0;melee.hp=0;guard.hp=175;guard.pos=[60,90];c.command(0,{"type":"move","ids":[guard.id],"pos":[110,90]})
	for tick in range(200):c.step(.05);c.resolve_spells()
	check(c.center(guard).x>82 and c.center(guard).x<84 and original.speed==2.28 and original.base_speed==1.9,"actual ten-second walking reflects the modest shield-infantry speed increase")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build/shield-ranged-reduction-20261026")
	FileAccess.open("res://build/shield-ranged-reduction-20261026/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SHIELD_RANGED_REDUCTION ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
