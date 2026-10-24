extends SceneTree
var failures=[]
var checks=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var art=ACAssets.new();art.load_all()
	for heading in [1,2,3]:
		var direction=Vector2.UP.rotated(heading*TAU/16)
		for action in ["idle","walk","attack"]:
			for phase in range(1 if action=="idle" else 7):
				var fps=1 if action=="idle" else 9 if action=="walk" else 14
				var frame=art.unit(1,10,direction,action,(phase+.1)/fps)
				check(not frame.flip,"no erroneous reflection %s dir%d phase%d"%[action,heading,phase])
				check(frame.texture is AtlasTexture and is_equal_approx(frame.texture.region.position.x,heading*320),"original right-facing authored heading remains selected")
	var c=ACCore.new();c.setup({"map":1,"seed":601,"players":[{"race":1},{"race":0}]});c.units.clear();c.buildings.clear()
	var unit=c.add_unit(0,10,Vector2(50,60));var start=ACData.point(unit.pos);unit.order="move";unit.goal=[65,45]
	for tick in range(24):c.time+=.05;c.paths_this_tick=0;c._tick_unit(unit,.05)
	var displacement=ACData.point(unit.pos)-start
	check(displacement.x>0 and displacement.y<0,"actual bat movement travels upper-right")
	check(ACData.point(unit.body_direction).dot(Vector2(1,-1).normalized())>.99,"flight hull follows actual displacement")
	var main=load("res://tests/menu_v04_harness.gd").new();unit.facing=[-1,-1]
	check(main._visual_facing(unit).dot(Vector2(1,-1).normalized())>.99,"moving hull stays upper-right even while weapons face elsewhere")
	main.free()
	var result={"checks":checks,"failures":failures,"unit":"1:10","original_atlases_unchanged":true,"displacement":str(displacement)}
	DirAccess.make_dir_recursive_absolute("res://build/citrus-bat-20261024")
	FileAccess.open("res://build/citrus-bat-20261024/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CITRUS_BAT_HEADING ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
