extends SceneTree
var checks=0
var failures=[]
func check(ok,label):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var c=ACCore.new();c.setup({"map":0,"seed":913,"players":[{"race":0},{"race":2}]})
	c.units.clear();c.buildings.clear();c.map.resources.clear();c.map.terrain.fill(0);c.map.height_map.fill(0);c.map.reset_solids([]);c.collision_index_valid=false
	for y in range(128):
		for x in range(66,128):c.map.height_map[y*128+x]=1
	var low=c.add_unit(0,1,Vector2(64,64));var high=c.add_unit(1,2,Vector2(68,64));var neighbor=c.add_unit(1,2,Vector2(69,65))
	c.vision_signatures.clear();c._update_vision()
	check(not c.can_see(0,high),"low ground cannot see high-ground enemy")
	check(c.can_see(1,low),"high ground sees downhill")
	check(c.command(0,{"type":"attack","ids":[low.id],"target":high.id})!="","unseen high ground cannot be targeted")
	c._damage(high,low,1);c._update_vision()
	check(c.can_see(0,high),"receiving high-ground fire briefly reveals attacker")
	check(c.can_see(0,neighbor),"brief high-ground exposure includes nearby firing position")
	check(c.visibility[0][64*128+68]>0 and c.visibility[0][64*128+73]==0,"only small firing area opens, not the whole plateau")
	var snap=c.snapshot(0)
	check(snap.units.any(func(u):return int(u.id)==int(high.id)),"exposed firing unit reaches authorized snapshot")
	c.time+=1.6;c._update_vision()
	check(not c.can_see(0,high),"attacker exposure expires after fire stops")
	var air=c.add_unit(0,8,Vector2(64,65));c._update_vision()
	check(c.can_see(0,high),"air spotter opens high ground")
	air.hp=0;c._update_vision();check(not c.can_see(0,high),"losing air spotter closes high ground")
	low.pos=[67,64];c._update_vision();check(c.can_see(0,high),"climbing plateau provides regular high-ground sight")
	low.pos=[64,64];c._update_vision()
	var enemy_air=c.add_unit(1,9,Vector2(69,65));check(c.can_see(0,enemy_air),"aircraft itself remains visible above an unseen plateau")
	c.units.clear();c.effects.clear();c.map.height_map.fill(0);c.collision_index_valid=false
	var beam=c.add_unit(1,13,Vector2(64,64));var target=c.add_unit(0,1,Vector2(68,64));target.hp=10000;target.shield=0
	var expected=0.0;var d=ACData.unit(2,13)
	for tick in range(20):
		c.time+=.05
		var focus=1.0+minf(2,maxf(0,float(tick)*.05)*.35)
		expected+=maxf(1,float(d.damage)*focus-float(ACData.unit(0,1).armor))*.05/float(d.period)
		c._tick_chaser_beam(beam,target,.05)
		check(beam.beam_active and int(beam.beam_target)==int(target.id),"beam connected each simulation tick")
	check(absf((10000-target.hp)-expected)<.001,"continuous damage preserves period-based DPS, scaling armor once per period")
	check(c.effects.filter(func(fx):return fx.type=="shot").is_empty(),"continuous attack creates no repeated shot projectiles")
	var second=c.add_unit(0,1,Vector2(68,65));c._tick_chaser_beam(beam,second,.05)
	check(beam.focus_target==second.id and is_equal_approx(beam.focus_started,c.time),"new target resets accumulated focus")
	for fog in c.visibility:fog.fill(1)
	beam.order="attack";beam.target=second.id;second.pos=[100,100];c._tick_unit(beam,.05)
	check(not beam.beam_active and int(beam.focus_target)==-1,"leaving range breaks beam and focus")
	check(ACData.unit(2,12).visual_extent==118,"Great Judgment flagship larger display size")
	var output={"checks":checks,"failures":failures,"beam_damage_one_second":10000-target.hp}
	FileAccess.open("res://build/player_colors_20261024/highground-beam.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("HIGHGROUND_BEAM ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
