extends SceneTree

const SIZES=[Vector2i(220,48),Vector2i(300,48),Vector2i(220,44),Vector2i(300,44)]
var checks=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)

func run() -> void:
	var layer=ACMenuLayer.new()
	root.add_child(layer)
	for race in range(3):
		layer.button_race=race
		for extent in SIZES:
			for state in ["normal","hover","pressed"]:
				var path="res://assets/ui_native/modal_%dx%d_r%d_%s.png"%[extent.x,extent.y,race,state]
				check(ResourceLoader.exists(path),"native modal plate exists: "+path)
				if ResourceLoader.exists(path):
					var texture=load(path)
					check(texture.get_size()==Vector2(extent),"native plate dimensions match control: "+path)
					var visible=texture.get_image().get_used_rect()
					check(visible.size.x>=extent.x*.9&&visible.size.y>=extent.y*.88,"visible frame fills its native control: "+path)
			var button=Button.new()
			button.text="준비"
			button.add_theme_font_size_override("font_size",20)
			layer.add_child(button)
			layer.style_control(button,Vector2(extent))
			check(button.size==Vector2(extent),"control remains at exact native dimensions")
			var style=button.get_theme_stylebox("normal")
			check(style is StyleBoxTexture,"normal state uses generated native plate")
			if style is StyleBoxTexture:
				for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:check(style.get_texture_margin(side)==0,"native artwork never uses nine-slice margins")
			layer.remove_child(button)
			button.free()
	layer.free()
	print("NATIVE_MODAL_ART_TEST checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
