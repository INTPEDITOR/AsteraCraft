extends SceneTree

func _initialize() -> void:
	var face=FontFile.new()
	face.data=FileAccess.get_file_as_bytes("res://assets/fonts/Galmuri14.ttf")
	var ok=face.get_font_name().contains("Galmuri") and face.has_char(0xac00) and face.has_char(0xd7a3)
	var width=face.get_string_size("아스 테라 인구 승리 패배",HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
	ok=ok and is_finite(width) and width>100
	print("FONT_V04_TEST family=%s hangul=%s width=%.1f failures=%d"%[face.get_font_name(),face.has_char(0xac00) and face.has_char(0xd7a3),width,0 if ok else 1])
	quit(0 if ok else 1)
