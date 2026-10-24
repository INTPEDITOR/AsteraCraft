class_name ACPlayerOverlayCanvas
extends Control
## Separate materials keep team pigments on bodies/markers without recoloring
## blood, explosions, placement outlines or the terrain below them.
var main
var data: Dictionary={}
var role=""
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	draw.connect(_draw_overlay)
func _draw_overlay() -> void:
	if data.is_empty():return
	var previous=main.world_canvas;var previous_palette=main._palette_entity
	main.world_canvas=self;main._palette_entity=data;main._world_transform()
	match role:
		"death":main._draw_death_body(data)
		"rally":main._draw_rally_beacon(data)
		"ghost":main._draw_building_ghost(int(data.race),int(data.kind),ACData.point(data.pos),bool(data.valid))
	main.world_canvas=previous;main._palette_entity=previous_palette
