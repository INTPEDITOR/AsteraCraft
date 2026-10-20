extends "res://tests/abilities_v060_test.gd"
func run():
	var c=arena();c.add_building(0,0,Vector2(40,40),true)
	var u=c.add_unit(0,1,Vector2(43,43));var enemy=c.add_unit(1,1,Vector2(90,90));reveal(c)
	var before=c.visibility[0].duplicate();var revision=int(c.vision_revisions[0])
	u.pos=[44,43];c._update_vision()
	check(c.visibility[0]==before and int(c.vision_revisions[0])==revision,"movement entirely inside HQ vision does not invalidate fog")
	enemy.pos=[95,90];c._update_vision()
	check(int(c.vision_revisions[0])==revision,"hidden opponent movement cannot invalidate local fog")
	u.pos=[65,43];c._update_vision()
	check(int(c.vision_revisions[0])==revision+1 and c.visibility[0]!=before,"exploring new ground invalidates fog exactly once")
	c._update_vision();check(int(c.vision_revisions[0])==revision+1,"unchanged actual visibility remains cached")
	print("FOG_REVISION_V061 ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
