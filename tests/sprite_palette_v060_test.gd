extends SceneTree
var checks=0
var failures=[]
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func _initialize():call_deferred("run")
func run():
	var assets=ACAssets.new();assets.load_all()
	for kind in [0,1,2,3,4,5,6,7,8,9,12]:
		var key="1:%d"%kind
		check(assets.motion_frames[key].size()==10 and assets.motion_frames[key][0].size()==9,"retained90 poses "+key)
		var image: Image=load("res://assets/citrus_palette_v060/r1_u%02d.png"%kind).get_image()
		var bytes=image.get_data();var green=0;var orange=0;var cyan=0
		for i in range(0,bytes.size(),4):
			if bytes[i+3]<180:continue
			var r=int(bytes[i]);var g=int(bytes[i+1]);var b=int(bytes[i+2])
			if g>r*1.12 and g>b*1.35 and g>60:green+=1
			if r>g*1.25 and g>b*1.35 and r>125:orange+=1
			if b>r*1.35 and g>r*1.2 and g>90:cyan+=1
		check(green>100 and orange>100 and cyan>10,"orange green cyan all present "+key)
	var medic: Image=load("res://assets/medic_motion_v060.png").get_image();var red=0;var data=medic.get_data()
	for i in range(0,data.size(),4):
		if data[i+3]>180 and data[i]>190 and data[i+1]<65 and data[i+2]<65:red+=1
	check(red<5,"no saturated red medical markings in actual medic sheet")
	check(assets.motion_frames["0:4"].size()==12 and assets.motion_frames["0:4"][0].size()==9,"108 complete medic poses loaded")
	check(assets.motion_regions.units["0:4"].actions.walk.size()==8 and assets.directional_air["1:10"].phases==8,"eight actual walking and leaf-wing phases")
	for race in range(3):
		for kind in range(ACData.unit_count(race)):
			for dir in [Vector2.UP,Vector2(1,-1).normalized(),Vector2.RIGHT,Vector2(1,1).normalized(),Vector2.DOWN,Vector2.LEFT]:
				var frame=assets.unit(race,kind,dir,"attack",.06)
				var offset=ACWeaponSockets.local_offset(frame,race,kind,dir)
				check(offset.is_finite() and offset.length()<frame.texture.get_size().length()*1.2,"registered socket finite and local %d:%d"%[race,kind])
	check(ACData.unit(0,6).weapon=="missile" and ACData.unit(1,2).weapon=="acid" and ACData.unit(1,6).weapon=="seed","distinct weapon projectiles retained")
	for phase in range(8):
		var southeast=assets.unit(0,13,Vector2(1,1).normalized(),"move",phase/12.0)
		var southwest=assets.unit(0,13,Vector2(-1,1).normalized(),"move",phase/12.0)
		check(southeast.flip and not southwest.flip,"painted southwest row corrected for both lower diagonals")
		check(southeast.source_mirror and southwest.source_mirror,"flamer socket uses the same source correction")
		var right_tip=ACWeaponSockets.local_offset(southeast,0,13,Vector2(1,1).normalized())
		var left_tip=ACWeaponSockets.local_offset(southwest,0,13,Vector2(-1,1).normalized())
		check(right_tip.x>0 and left_tip.x<0 and is_equal_approx(right_tip.y,left_tip.y),"flame originates on the matching diagonal side")
	print("SPRITE_PALETTE_V060 ",JSON.stringify({"checks":checks,"failures":failures,"red_pixels":red}));quit(0 if failures.is_empty() else 1)
