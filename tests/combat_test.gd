extends SceneTree

var failures: Array=[]
var checks=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func _initialize() -> void:
	var c=ACCore.new()
	c.setup({"map":0,"players":[{"race":0},{"race":1},{"race":2}]})
	var attacker=c.add_unit(0,1,Vector2(50,50))
	var owl=c.add_unit(2,1,Vector2(51,50))
	var hp=owl.hp
	var shield=owl.shield
	c._damage(attacker,owl,20)
	check(owl.hp==hp and owl.shield==shield-20,"shield absorbs before HP")
	c.players[2].shield=3
	shield=owl.shield
	c._damage(attacker,owl,20)
	check(owl.shield==shield-17,"shield research reduces damage")
	owl.shield=5
	c._damage(attacker,owl,20)
	check(owl.shield==0 and owl.hp<hp,"shield overflow reaches HP")
	var ally=c.add_unit(0,1,Vector2(52,50))
	hp=ally.hp
	c._damage(attacker,ally,500)
	check(ally.hp==hp,"friendly fire rejected")
	var citrus=c.add_unit(1,1,Vector2(50,51))
	c._damage(attacker,citrus,999)
	check(citrus.hp<=0 and c.players[0].kills==1,"lethal damage increments kills")
	var medic=c.add_unit(0,4,Vector2(52,51))
	ally.hp-=20
	hp=ally.hp
	c._support(medic,ACData.unit(0,4),1)
	check(ally.hp>hp and medic.energy<100,"medic spends energy healing biological infantry")
	for i in range(30):c.add_building(0,2,Vector2(5+i,80),true)
	c._recalculate_supply()
	check(c.players[0].cap==200,"supply cap clamps at 200")
	var siege=c.add_unit(0,5,Vector2(55,55))
	c.command(0,{"type":"ability","ids":[siege.id]})
	check(siege.anchored,"siege toggles anchoring")
	var p=siege.pos.duplicate()
	c._move(siege,Vector2(60,60),1)
	check(siege.pos==p,"anchored siege cannot move")
	var mage=c.add_unit(2,5,Vector2(59,59))
	var target=c.add_unit(1,3,Vector2(60,60))
	hp=target.hp
	c.command(2,{"type":"ability","ids":[mage.id],"pos":[60,60]})
	check(mage.energy==25 and target.hp==hp,"spell spends energy and telegraphs before damage")
	c.time+=1.1
	c.resolve_spells()
	check(target.hp<hp,"telegraphed spell resolves")
	var before=target.hp
	c.resolve_spells()
	check(target.hp==before,"spell resolves once")
	c.command(0,{"type":"move","ids":[attacker.id,ally.id],"pos":[45,45],"formation":true})
	check(attacker.goal!=ally.goal,"group movement spreads destinations")
	var snapshot=c.snapshot()
	var amount=snapshot.resources[0].amount
	c.map.resources[0].amount-=1
	check(snapshot.resources[0].amount==amount,"snapshot resource values are immutable")
	print("COMBAT_TEST checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
