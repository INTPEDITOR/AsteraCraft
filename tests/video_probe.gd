extends SceneTree

var ticks=0

func _initialize() -> void:
	root.size=Vector2i(320,180)
	var fill=ColorRect.new()
	fill.color=Color(.06,.15,.22)
	fill.size=Vector2(320,180)
	root.add_child(fill)

func _process(_delta: float) -> bool:
	ticks+=1
	if ticks>=20:quit()
	return false
