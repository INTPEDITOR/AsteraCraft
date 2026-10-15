extends SceneTree
const Baker=preload("res://tools_make_construction.gd")

class Gallery:
	extends Node2D
	var visual: ACConstructionVisual
	var art: ACAssets
	func _draw() -> void:
		for race in range(3):
			for column in range(4):
				var texture:=art.building(race,0)
				if texture==null:continue
				var width:=210.0
				var height:=width*texture.get_height()/texture.get_width()
				var rect:=Rect2(Vector2(40+column*280,250+race*245-height),Vector2(width,height))
				visual.draw(self,race,0,texture,rect,[.1,.5,.85,1.0][column],0.0)

var checks := 0
var failures: Array=[]

func check(value: bool, detail: String) -> void:
	checks+=1
	if not value:
		failures.append(detail)
		printerr("FAIL: "+detail)

func _initialize() -> void:
	call_deferred("run")

func alpha_signature(texture: Texture2D) -> int:
	var image:=texture.get_image()
	var bytes:=PackedByteArray()
	for y in range(32):
		for x in range(32):
			bytes.append(1 if image.get_pixel(mini(image.get_width()-1,int((x+.5)*image.get_width()/32.0)),mini(image.get_height()-1,int((y+.5)*image.get_height()/32.0))).a>.25 else 0)
	return hash(bytes)

func run() -> void:
	check(ACConstructionVisual.stage(-1)==0 and ACConstructionVisual.stage(0)==0 and ACConstructionVisual.stage(.332)==0,"foundation phase occupies the first third")
	check(ACConstructionVisual.stage(1.0/3)==1 and ACConstructionVisual.stage(.665)==1,"partial frame phase occupies the second third")
	check(ACConstructionVisual.stage(2.0/3)==2 and ACConstructionVisual.stage(.9999)==2,"assembled phase occupies the final construction third")
	check(ACConstructionVisual.stage(1)==-1 and ACConstructionVisual.stage(10)==-1,"finished buildings use the unchanged complete art")
	check(ACConstructionVisual.stage(NAN)==0,"invalid visual progress cannot produce an invalid stage index")
	var original_fixture:=Image.create(32,48,false,Image.FORMAT_RGBA8)
	original_fixture.fill(Color.TRANSPARENT)
	original_fixture.fill_rect(Rect2i(10,4,12,38),Color(.8,.2,.1,1))
	original_fixture.fill_rect(Rect2i(3,36,26,12),Color(.7,.4,.1,1))
	var scaffold_fixture:=Image.create(64,32,false,Image.FORMAT_RGBA8)
	scaffold_fixture.fill(Color(.1,.7,.8,.8))
	var original_hash:=Baker.digest(original_fixture.get_data())
	var phase_hashes: Dictionary={}
	for phase in range(3):
		var result:=Baker.bake(original_fixture,scaffold_fixture,phase)
		phase_hashes[result.rgba_sha256]=true
		check(result.image.get_size()==original_fixture.get_size() and int(result.outside_silhouette)==0 and int(result.generated_pixels)>0,"independent bake keeps the original canvas and clips an oversized generated structure, phase %d"%phase)
	check(Baker.digest(original_fixture.get_data())==original_hash and phase_hashes.size()==3,"baking three phases preserves the original source and produces distinct composite art")
	var visual:=ACConstructionVisual.new()
	visual.load_all()
	for width in [64.0,128.0,320.0]:
		for height in [64.0,176.0,420.0]:
			var size_value:=Vector2(width,height)
			var rect:=Rect2(Vector2(53,71),size_value*1.4)
			for progress in [.0,.5,.9,1.0]:
				var plan:=ACConstructionVisual.stages_plan(size_value,rect,progress)
				var source: Rect2=plan.source_rect
				var destination: Rect2=plan.final_rect
				check(is_equal_approx(source.end.y,height) and is_equal_approx(destination.end.y,rect.end.y) and plan.foundation==Vector2(rect.get_center().x,rect.end.y),"all construction stages retain the exact foundation anchor")
				check(is_equal_approx(destination.size.x/source.size.x,destination.size.y/source.size.y),"partial assembly crops original art without stretching either axis")
	var scaffold:={"size":Vector2(400,230),"pivot":Vector2(200,220),"width_factor":1.04}
	var final_rect:=Rect2(100,100,160,180)
	var scaffold_rect:=visual.scaffold_rect(scaffold,final_rect)
	var factor:=scaffold_rect.size.x/400.0
	check(is_equal_approx(factor,scaffold_rect.size.y/230.0) and (scaffold_rect.position+Vector2(scaffold.pivot)*factor).is_equal_approx(Vector2(final_rect.get_center().x,final_rect.end.y)),"generated scaffold preserves its own proportions and attaches to the same foundation")
	var require_art:="--require-art" in OS.get_cmdline_user_args()
	var original_art: ACAssets
	if require_art:
		original_art=ACAssets.new()
		original_art.load_all()
	var complete:=0
	var composite_hashes: Dictionary={}
	for race in range(3):
		for kind in range(13):
			if visual.available(race,kind):
				complete+=1
				var stages: Array=visual.frames["%d:%d"%[race,kind]]
				check(alpha_signature(stages[0].texture)!=alpha_signature(stages[1].texture) and alpha_signature(stages[1].texture)!=alpha_signature(stages[2].texture),"generated construction stages have different structural masks, race %d kind %d"%[race,kind])
				if require_art:
					var original:=original_art.building(race,kind).get_image()
					original.convert(Image.FORMAT_RGBA8)
					var original_bytes:=original.get_data()
					for frame in stages:
						var image: Image=frame.texture.get_image()
						image.convert(Image.FORMAT_RGBA8)
						composite_hashes[hash(image.get_data())]=true
						var same_canvas:=image.get_size()==original.get_size()
						check(bool(frame.get("composite",false)) and same_canvas,"baked construction preserves the original full canvas, race %d kind %d stage %d"%[race,kind,frame.stage])
						var outside:=0
						if same_canvas:
							var output_bytes:=image.get_data()
							for offset in range(3,output_bytes.size(),4):
								if output_bytes[offset]>original_bytes[offset]:outside+=1
						check(outside==0,"generated structural pixels remain inside the original building silhouette, race %d kind %d stage %d"%[race,kind,frame.stage])
			elif require_art:
				check(false,"missing real generated construction stages, race %d kind %d"%[race,kind])
	if require_art:
		check(complete==39 and visual.diagnostics.is_empty(),"all thirty-nine buildings have three valid generated scaffold stages")
		check(composite_hashes.size()==117,"one hundred seventeen independently composed RGBA frames are unique")
		if FileAccess.file_exists("res://build/construction-v04-audit.json"):
			var audit=JSON.parse_string(FileAccess.get_file_as_string("res://build/construction-v04-audit.json"))
			check(audit is Dictionary and bool(audit.get("passed",false)) and int(audit.get("frames",0))==117 and int(audit.get("unique_rgba_frames",0))==117,"bake audit verifies one hundred seventeen unique, unmodified-source composites")
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()=="headless":
			check(false,"capture requires a GUI renderer")
		else:
			root.size=Vector2i(1180,830)
			var art:=ACAssets.new()
			art.load_all()
			var gallery:=Gallery.new()
			gallery.visual=visual
			gallery.art=art
			root.add_child(gallery)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/preview-construction-v04.png")
	print("Construction visual v0.4: %d checks, %d failures; generated stages ready for %d/39 buildings"%[checks,failures.size(),complete])
	quit(0 if failures.is_empty() else 1)
